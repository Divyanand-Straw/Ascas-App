import crypto from 'crypto';
import jwt, { SignOptions, VerifyOptions } from 'jsonwebtoken';
import {
  IUserRepository,
  IPatientProfileRepository,
  IOtpRepository,
  IRefreshTokenRepository,
} from './auth.repository.interface';
import { ISmsProvider } from './sms.provider.interface';
import { DevelopmentSmsProvider } from './sms.provider';
import {
  User,
  PatientProfile,
  OtpPurpose,
  AuthTokens,
  AuthSession,
  TokenPayload,
  PreferredLanguage,
  serializeDateOfBirth,
} from './auth.types';
import {
  AppError,
  ValidationError,
  UnauthorizedError,
  NotFoundError,
  ConflictError,
} from '../../utils/errors';
import {
  requiresConfiguredAuthSecrets,
} from '../../config/runtime';

export interface AuthServiceConfig {
  jwtAccessSecret: string;
  jwtIssuer?: string;
  jwtAudience?: string;
  otpSecret: string;
  otpExpiresInMinutes?: number;
  maxOtpAttempts?: number;
  resendCooldownSeconds?: number;
  maxRequestsPerHourPerPhone?: number;
  maxRequestsPerHourPerIp?: number;
}

export type OtpVerificationTransactionRunner = (
  verify: (transactionalService: AuthService) => Promise<AuthSession>
) => Promise<AuthSession>;

export class AuthService {
  private userRepo: IUserRepository;
  private profileRepo: IPatientProfileRepository;
  private otpRepo: IOtpRepository;
  private refreshTokenRepo: IRefreshTokenRepository;
  private smsProvider: ISmsProvider;
  private config: Required<AuthServiceConfig>;
  private readonly otpVerificationTransactionRunner?: OtpVerificationTransactionRunner;

  constructor(
    userRepo: IUserRepository,
    profileRepo: IPatientProfileRepository,
    otpRepo: IOtpRepository,
    refreshTokenRepo: IRefreshTokenRepository,
    smsProvider: ISmsProvider,
    config?: Partial<AuthServiceConfig>,
    otpVerificationTransactionRunner?: OtpVerificationTransactionRunner
  ) {
    this.userRepo = userRepo;
    this.profileRepo = profileRepo;
    this.otpRepo = otpRepo;
    this.refreshTokenRepo = refreshTokenRepo;
    this.smsProvider = smsProvider;
    this.otpVerificationTransactionRunner =
      otpVerificationTransactionRunner;

    const requiresConfiguredSecrets = requiresConfiguredAuthSecrets(
      process.env
    );
    const fallbackSecret = 'ascas_dev_fallback_secret_32_characters_minimum_length!';

    const accessSecret = config?.jwtAccessSecret || process.env.JWT_ACCESS_SECRET;
    const otpSec = config?.otpSecret || process.env.OTP_SECRET;

    if (
      requiresConfiguredSecrets &&
      (!accessSecret || accessSecret.length < 32)
    ) {
      throw new Error(
        'JWT_ACCESS_SECRET must be at least 32 characters in production or staging.'
      );
    }
    if (requiresConfiguredSecrets && (!otpSec || otpSec.length < 32)) {
      throw new Error(
        'OTP_SECRET must be at least 32 characters in production or staging.'
      );
    }

    this.config = {
      jwtAccessSecret: accessSecret || fallbackSecret,
      jwtIssuer: config?.jwtIssuer || 'ascas-api',
      jwtAudience: config?.jwtAudience || 'ascas-mobile',
      otpSecret: otpSec || fallbackSecret,
      otpExpiresInMinutes: config?.otpExpiresInMinutes ?? 5,
      maxOtpAttempts: config?.maxOtpAttempts ?? 3,
      resendCooldownSeconds: config?.resendCooldownSeconds ?? 45,
      maxRequestsPerHourPerPhone: config?.maxRequestsPerHourPerPhone ?? 5,
      maxRequestsPerHourPerIp: config?.maxRequestsPerHourPerIp ?? 15,
    };
  }

  // ==========================================================================
  // OTP Hashing & Generation Helpers
  // ==========================================================================

  public generateOtp(): string {
    // Generates a uniform 6-digit integer from 100000 to 999999 (inclusive)
    return crypto.randomInt(100000, 1000000).toString();
  }

  public hashOtp(phone: string, purpose: OtpPurpose, otp: string): string {
    return crypto
      .createHmac('sha256', this.config.otpSecret)
      .update(`${phone}:${purpose}:${otp}`)
      .digest('hex');
  }

  get usesDevelopmentSmsProvider(): boolean {
    return this.smsProvider instanceof DevelopmentSmsProvider;
  }

  async getActiveDevelopmentOtp(
    phone: string,
    purpose: OtpPurpose
  ): Promise<string | null> {
    if (!(this.smsProvider instanceof DevelopmentSmsProvider)) {
      return null;
    }

    const message = this.smsProvider.getLatestMessage(phone, purpose);
    if (!message) return null;

    const challenge = await this.otpRepo.findLatestActiveChallenge(
      phone,
      purpose
    );
    if (
      !challenge ||
      challenge.phone !== phone ||
      challenge.purpose !== purpose ||
      challenge.consumedAt != null ||
      challenge.attemptsCount >= challenge.maxAttempts ||
      challenge.expiresAt.getTime() <= Date.now() ||
      message.sentAt.getTime() < challenge.createdAt.getTime()
    ) {
      return null;
    }

    const storedHash = Buffer.from(challenge.otpHash, 'hex');
    const candidateHash = Buffer.from(
      this.hashOtp(phone, purpose, message.otp),
      'hex'
    );
    if (
      storedHash.length !== candidateHash.length ||
      storedHash.length === 0 ||
      !crypto.timingSafeEqual(storedHash, candidateHash)
    ) {
      return null;
    }

    return message.otp;
  }

  private hashToken(rawToken: string): string {
    return crypto.createHash('sha256').update(rawToken).digest('hex');
  }

  // ==========================================================================
  // 1. Send OTP Challenge
  // ==========================================================================

  async sendOtp(
    phone: string,
    purpose: OtpPurpose,
    ipAddress?: string
  ): Promise<{ challengeId: string; expiresInSeconds: number; retryAfterSeconds: number }> {
    // Check user existence for anti-enumeration behavior.
    const existingUser = await this.userRepo.findByPhone(phone);

    // Anti-enumeration:
    // Login and Existing Patient requests for unknown accounts are decoys.
    // We create a decoy challenge record or standard challenge so verifyOtp returns the appropriate
    // structured error only after OTP challenge verification, without leaking account status on send.
    // If the account does not exist for LOGIN, do not dispatch real SMS to save cost,
    // but still track challenge to respond identically.
    let shouldDispatchSms = true;

    if (
      (purpose === 'LOGIN' || purpose === 'EXISTING_PATIENT') &&
      (!existingUser || existingUser.status === 'SUSPENDED')
    ) {
      shouldDispatchSms = false;
    }

    let generatedOtp: string | null = null;
    const issuance = await this.otpRepo.createOrReuseForCooldown(
      {
        phone,
        purpose,
        maxAttempts: this.config.maxOtpAttempts,
        ipAddress,
      },
      {
        resendCooldownSeconds: this.config.resendCooldownSeconds,
        maxRequestsPerHourPerPhone: this.config.maxRequestsPerHourPerPhone,
        maxRequestsPerHourPerIp: this.config.maxRequestsPerHourPerIp,
      },
      () => {
        generatedOtp = this.generateOtp();
        return {
          otpHash: this.hashOtp(phone, purpose, generatedOtp),
          expiresAt: new Date(
            Date.now() + this.config.otpExpiresInMinutes * 60 * 1000
          ),
        };
      }
    );
    if (issuance.rateLimit === 'ip') {
      throw new AppError(
        'Too many verification requests from this network. Please try again later.',
        429,
        'RATE_LIMIT_EXCEEDED'
      );
    }
    if (issuance.rateLimit === 'phone') {
      throw new AppError(
        'Too many verification attempts for this phone number. Please try again later.',
        429,
        'PHONE_RATE_LIMIT_EXCEEDED'
      );
    }
    if (!issuance.challenge) {
      throw new AppError(
        `Please wait ${issuance.retryAfterSeconds} seconds before requesting another verification code.`,
        429,
        'COOLDOWN_ACTIVE',
        { retryAfterSeconds: issuance.retryAfterSeconds }
      );
    }

    if (issuance.created && shouldDispatchSms) {
      if (generatedOtp === null) {
        throw new AppError(
          'Unable to create the verification challenge.',
          500,
          'OTP_CHALLENGE_CREATION_FAILED'
        );
      }
      await this.smsProvider.sendOtp(phone, generatedOtp, purpose);
    }

    return {
      challengeId: issuance.challenge.id,
      expiresInSeconds: Math.max(
        0,
        Math.ceil((issuance.challenge.expiresAt.getTime() - Date.now()) / 1000)
      ),
      retryAfterSeconds: issuance.retryAfterSeconds,
    };
  }

  async createOrGetPatientProfile(
    userId: string,
    data: {
      firstName: string;
      lastName: string;
      dob: Date;
      gender?: string;
      emergencyContact?: string;
      preferredLanguage: PreferredLanguage;
    }
  ): Promise<PatientProfile> {
    const current = await this.getCurrentUser(userId);
    if (current.profile) return current.profile;
    if (current.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE') {
      throw new AppError(
        'Patient profile setup is not available for this account.',
        403,
        'PROFILE_SETUP_NOT_ALLOWED'
      );
    }
    if (
      data.emergencyContact &&
      data.emergencyContact === current.user.phone
    ) {
      throw new AppError(
        'Emergency contact must differ from the verified mobile number.',
        400,
        'INVALID_EMERGENCY_CONTACT'
      );
    }

    return this.profileRepo.createOrGet({
      userId,
      ...data,
    });
  }

  async updatePatientProfile(
    userId: string,
    data: {
      firstName: string;
      lastName: string;
      dob: Date;
      gender?: string;
      preferredLanguage: PreferredLanguage;
    }
  ): Promise<PatientProfile> {
    const current = await this.getCurrentUser(userId);
    if (!current.profile) {
      throw new AppError(
        'Patient profile setup is not available for this account.',
        403,
        'PROFILE_SETUP_NOT_ALLOWED'
      );
    }
    return this.profileRepo.update(userId, data);
  }

  // ==========================================================================
  // 2. Verify OTP Challenge & Authenticate
  // ==========================================================================

  async verifyOtp(
    challengeId: string,
    phone: string,
    purpose: OtpPurpose,
    otp: string,
    deviceInfo?: string,
    ipAddress?: string
  ): Promise<AuthSession> {
    if (this.otpVerificationTransactionRunner) {
      return this.otpVerificationTransactionRunner((transactionalService) =>
        transactionalService.verifyOtp(
          challengeId,
          phone,
          purpose,
          otp,
          deviceInfo,
          ipAddress
        )
      );
    }

    const challenge = await this.otpRepo.findActiveChallenge(challengeId, phone, purpose);

    if (!challenge) {
      throw new AppError('Verification challenge is invalid or has expired', 401, 'INVALID_CHALLENGE');
    }

    if (challenge.consumedAt !== null) {
      throw new AppError('This verification code has already been used. Please request a new one.', 401, 'OTP_ALREADY_USED');
    }

    if (new Date() > challenge.expiresAt) {
      throw new AppError('Verification code has expired. Please request a new one.', 401, 'OTP_EXPIRED');
    }

    if (challenge.attemptsCount >= challenge.maxAttempts) {
      throw new AppError('Maximum verification attempts exceeded. Please request a new code.', 403, 'MAX_ATTEMPTS_EXCEEDED');
    }

    // Verify OTP using constant-time hash comparison
    const candidateHash = this.hashOtp(phone, purpose, otp);
    const isMatch = crypto.timingSafeEqual(
      Buffer.from(candidateHash, 'hex'),
      Buffer.from(challenge.otpHash, 'hex')
    );

    if (!isMatch) {
      const attemptsNow = await this.otpRepo.incrementAttempts(challengeId);
      const remaining = Math.max(0, challenge.maxAttempts - attemptsNow);

      if (remaining === 0) {
        throw new AppError('Maximum verification attempts exceeded. Please request a new code.', 403, 'MAX_ATTEMPTS_EXCEEDED');
      }

      throw new AppError('Invalid verification code.', 401, 'INVALID_OTP', {
        remainingAttempts: remaining,
      });
    }

    // OTP is valid: atomically consume challenge
    const consumed = await this.otpRepo.consume(challengeId);
    if (!consumed) {
      throw new AppError('Verification challenge has already been consumed.', 401, 'OTP_ALREADY_USED');
    }

    // ------------------------------------------------------------------------
    // Process Authenticated Action based on Purpose
    // ------------------------------------------------------------------------
    let user: User | null = await this.userRepo.findByPhone(phone);
    let isNewUser = false;
    let profile: PatientProfile | null = null;
    let profileLoaded = false;

    if (purpose === 'LOGIN' || purpose === 'EXISTING_PATIENT') {
      if (!user) {
        throw new AppError('No active account found for this mobile number. Please register.', 404, 'USER_NOT_FOUND');
      }
      if (user.status === 'SUSPENDED') {
        throw new AppError('Your account has been suspended. Please contact clinic support.', 403, 'ACCOUNT_SUSPENDED');
      }
    } else if (purpose === 'REGISTRATION') {
      if (user) {
        const credentials = await this.userRepo.findByIdWithPasswordHash(
          user.id
        );
        profile = await this.profileRepo.findByUserId(user.id);
        profileLoaded = true;
        const canResumeRegistration =
          credentials?.user.status === 'ACTIVE' &&
          credentials.user.emailPasswordEligibility ===
            'NEW_PATIENT_ELIGIBLE' &&
          credentials.user.email === null &&
          credentials.passwordHash === null &&
          profile === null &&
          !(await this.userRepo.isPartnerAccount(user.id));
        if (!canResumeRegistration) {
          throw new AppError('An account with this mobile number already exists. Please log in.', 409, 'USER_ALREADY_EXISTS');
        }
        isNewUser = true;
      } else {
        user = await this.userRepo.create({
          phone,
          role: 'PATIENT',
          status: 'ACTIVE',
          emailPasswordEligibility: 'NEW_PATIENT_ELIGIBLE',
        });
        isNewUser = true;
      }
    } else if (purpose === 'LINKED_MEMBER') {
      if (!user) {
        user = await this.userRepo.create({
          phone,
          role: 'PATIENT',
          status: 'ACTIVE',
          emailPasswordEligibility: 'PARTNER_INELIGIBLE',
        });
        isNewUser = true;
      }
      if (user.status === 'SUSPENDED') {
        throw new AppError('Account is suspended. Please contact clinic support.', 403, 'ACCOUNT_SUSPENDED');
      }
      if (!isNewUser) {
        await this.userRepo.markLinkedMemberIneligible(user.id);
      }
    }

    if (!user) {
      throw new AppError('Failed to establish user identity', 500);
    }

    await this.userRepo.markPhoneVerified(user.id);

    // Fetch existing patient profile (if any)
    if (!profileLoaded) {
      profile = await this.profileRepo.findByUserId(user.id);
    }
    const hasCompletedProfile = Boolean(profile);

    // Generate JWT access & refresh tokens
    const tokens = await this.generateTokenPair(user, profile, deviceInfo, ipAddress);

    return {
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        role: user.role,
        status: user.status,
      },
      profile: profile
        ? {
            id: profile.id,
            userId: profile.userId,
            firstName: profile.firstName,
            lastName: profile.lastName,
            dob: serializeDateOfBirth(profile.dob),
            gender: profile.gender,
            emergencyContact: profile.emergencyContact,
            clinicMrn: profile.clinicMrn,
            preferredLanguage: profile.preferredLanguage,
            linkingStatus: profile.linkingStatus as any,
          }
        : null,
      tokens,
      isNewUser,
      hasCompletedProfile,
    };
  }

  async createEmailPasswordSession(
    userId: string,
    expectedPasswordHash: string,
    deviceInfo?: string,
    ipAddress?: string
  ): Promise<AuthSession> {
    const credentials = await this.userRepo.findByIdWithPasswordHash(userId);
    if (
      !credentials ||
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE' ||
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      !credentials.user.email ||
      !credentials.passwordHash ||
      credentials.passwordHash !== expectedPasswordHash ||
      (await this.userRepo.isPartnerAccount(userId))
    ) {
      throw new AppError(
        'Email or password is incorrect.',
        401,
        'EMAIL_PASSWORD_INVALID_CREDENTIALS'
      );
    }

    const user = credentials.user;
    const profile = await this.profileRepo.findByUserId(user.id);
    const tokens = await this.generateTokenPair(
      user,
      profile,
      deviceInfo,
      ipAddress,
      expectedPasswordHash
    );

    return {
      user: {
        id: user.id,
        phone: user.phone,
        email: user.email,
        role: user.role,
        status: user.status,
      },
      profile: profile
        ? {
            id: profile.id,
            userId: profile.userId,
            firstName: profile.firstName,
            lastName: profile.lastName,
            dob: serializeDateOfBirth(profile.dob),
            gender: profile.gender,
            emergencyContact: profile.emergencyContact,
            clinicMrn: profile.clinicMrn,
            preferredLanguage: profile.preferredLanguage,
            linkingStatus: profile.linkingStatus as any,
          }
        : null,
      tokens,
      isNewUser: false,
      hasCompletedProfile: Boolean(profile),
    };
  }

  // ==========================================================================
  // 3. Token Generation & Refresh
  // ==========================================================================

  private async generateTokenPair(
    user: User,
    profile?: PatientProfile | null,
    deviceInfo?: string,
    ipAddress?: string,
    expectedPasswordHash?: string
  ): Promise<AuthTokens> {
    const hasCompletedProfile = Boolean(profile);

    const payload: TokenPayload = {
      sub: user.id,
      phone: user.phone,
      role: user.role,
      status: user.status,
      profileId: profile?.id || null,
      hasCompletedProfile,
      tokenType: 'access',
    };

    const signOptions: SignOptions = {
      expiresIn: 15 * 60, // 15 minutes
      issuer: this.config.jwtIssuer,
      audience: this.config.jwtAudience,
      algorithm: 'HS256',
    };

    const accessToken = jwt.sign(payload, this.config.jwtAccessSecret, signOptions);

    // Generate 32 cryptographically random bytes for the refresh token
    const rawRefreshToken = crypto.randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(rawRefreshToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    await this.refreshTokenRepo.create({
      userId: user.id,
      tokenHash,
      deviceInfo,
      ipAddress,
      expiresAt,
      expectedPasswordHash,
    });

    return {
      accessToken,
      refreshToken: rawRefreshToken,
      expiresIn: 15 * 60,
    };
  }

  async refreshTokens(
    rawRefreshToken: string,
    deviceInfo?: string,
    ipAddress?: string
  ): Promise<AuthTokens> {
    if (!rawRefreshToken || typeof rawRefreshToken !== 'string') {
      throw new AppError('Refresh token is required', 400, 'INVALID_REFRESH_TOKEN');
    }

    const tokenHash = this.hashToken(rawRefreshToken);
    const storedToken = await this.refreshTokenRepo.findByTokenHash(tokenHash);

    if (!storedToken) {
      throw new AppError('Invalid refresh token', 401, 'INVALID_REFRESH_TOKEN');
    }

    // Reuse Detection:
    // If the token has already been revoked, a breach/replay attempt is suspected.
    // Revoke ALL sessions for this user immediately and return 401.
    if (storedToken.revokedAt !== null) {
      await this.refreshTokenRepo.revokeAllForUser(storedToken.userId);
      throw new AppError(
        'Refresh token reuse detected. All sessions for this account have been terminated.',
        401,
        'REFRESH_TOKEN_REUSE_DETECTED'
      );
    }

    // Check expiration
    if (new Date() > storedToken.expiresAt) {
      await this.refreshTokenRepo.revoke(storedToken.id);
      throw new AppError('Refresh token has expired. Please log in again.', 401, 'REFRESH_TOKEN_EXPIRED');
    }

    // Verify user account status
    const user = await this.userRepo.findById(storedToken.userId);
    if (!user || user.status === 'SUSPENDED') {
      await this.refreshTokenRepo.revoke(storedToken.id);
      throw new AppError('User account is suspended or no longer exists.', 403, 'ACCOUNT_SUSPENDED');
    }

    const profile = await this.profileRepo.findByUserId(user.id);
    const hasCompletedProfile = Boolean(profile);

    // Prepare new refresh token
    const newRawRefreshToken = crypto.randomBytes(32).toString('hex');
    const newTokenHash = this.hashToken(newRawRefreshToken);
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // 30 days

    // Rotate token atomically: revoke old token and insert new token
    await this.refreshTokenRepo.rotateToken(storedToken.id, {
      userId: user.id,
      tokenHash: newTokenHash,
      deviceInfo: deviceInfo || storedToken.deviceInfo,
      ipAddress: ipAddress || storedToken.ipAddress,
      expiresAt,
    });

    // Generate new access token
    const payload: TokenPayload = {
      sub: user.id,
      phone: user.phone,
      role: user.role,
      status: user.status,
      profileId: profile?.id || null,
      hasCompletedProfile,
      tokenType: 'access',
    };

    const accessToken = jwt.sign(payload, this.config.jwtAccessSecret, {
      expiresIn: 15 * 60,
      issuer: this.config.jwtIssuer,
      audience: this.config.jwtAudience,
      algorithm: 'HS256',
    });

    return {
      accessToken,
      refreshToken: newRawRefreshToken,
      expiresIn: 15 * 60,
    };
  }

  // ==========================================================================
  // 4. Session Revocation / Logout
  // ==========================================================================

  async logout(rawRefreshToken: string, userId: string): Promise<void> {
    if (!rawRefreshToken || typeof rawRefreshToken !== 'string' || rawRefreshToken.trim() === '') {
      throw new AppError('Refresh token is required', 400, 'INVALID_REFRESH_TOKEN');
    }

    if (!userId) {
      throw new AppError('Authenticated user identifier is required', 401, 'UNAUTHORIZED');
    }

    const tokenHash = this.hashToken(rawRefreshToken);
    const storedToken = await this.refreshTokenRepo.findByTokenHash(tokenHash);

    if (!storedToken) {
      throw new AppError('Invalid refresh token', 401, 'INVALID_REFRESH_TOKEN');
    }

    // Verify token ownership: the refresh token MUST belong to the authenticated user
    if (storedToken.userId !== userId) {
      throw new AppError(
        'Forbidden: Refresh token does not belong to the authenticated user.',
        403,
        'FORBIDDEN'
      );
    }

    // Revoke ONLY the matching session/device token
    if (storedToken.revokedAt === null) {
      await this.refreshTokenRepo.revoke(storedToken.id);
    }
  }

  // ==========================================================================
  // 5. Token Verification (for Middleware)
  // ==========================================================================

  public verifyAccessToken(token: string): TokenPayload {
    try {
      const verifyOptions: VerifyOptions = {
        issuer: this.config.jwtIssuer,
        audience: this.config.jwtAudience,
        algorithms: ['HS256'],
      };

      const decoded = jwt.verify(token, this.config.jwtAccessSecret, verifyOptions) as unknown as TokenPayload;

      if (!decoded || decoded.tokenType !== 'access') {
        throw new AppError('Invalid token type', 401, 'INVALID_TOKEN');
      }

      return decoded;
    } catch (err) {
      if (err instanceof jwt.TokenExpiredError) {
        throw new AppError('Access token has expired', 401, 'TOKEN_EXPIRED');
      }
      if (err instanceof jwt.JsonWebTokenError) {
        throw new AppError('Invalid access token', 401, 'INVALID_TOKEN');
      }
      throw err;
    }
  }

  // ==========================================================================
  // 6. User Account Query
  // ==========================================================================

  async getCurrentUser(userId: string): Promise<{
    user: User;
    profile: PatientProfile | null;
    hasCompletedProfile: boolean;
  }> {
    const user = await this.userRepo.findById(userId);
    if (!user) {
      throw new AppError('User not found', 404, 'USER_NOT_FOUND');
    }
    if (user.status === 'SUSPENDED') {
      throw new AppError('Account is suspended', 403, 'ACCOUNT_SUSPENDED');
    }

    const profile = await this.profileRepo.findByUserId(userId);

    return {
      user,
      profile,
      hasCompletedProfile: Boolean(profile),
    };
  }
}
