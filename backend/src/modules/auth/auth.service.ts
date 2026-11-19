import crypto from 'crypto';
import jwt, { SignOptions, VerifyOptions } from 'jsonwebtoken';
import {
  IUserRepository,
  IPatientProfileRepository,
  IOtpRepository,
  IRefreshTokenRepository,
} from './auth.repository.interface';
import { ISmsProvider } from './sms.provider.interface';
import {
  User,
  PatientProfile,
  OtpPurpose,
  AuthTokens,
  AuthSession,
  TokenPayload,
} from './auth.types';
import {
  AppError,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
} from '../../utils/errors';

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

export class AuthService {
  private userRepo: IUserRepository;
  private profileRepo: IPatientProfileRepository;
  private otpRepo: IOtpRepository;
  private refreshTokenRepo: IRefreshTokenRepository;
  private smsProvider: ISmsProvider;
  private config: Required<AuthServiceConfig>;

  constructor(
    userRepo: IUserRepository,
    profileRepo: IPatientProfileRepository,
    otpRepo: IOtpRepository,
    refreshTokenRepo: IRefreshTokenRepository,
    smsProvider: ISmsProvider,
    config?: Partial<AuthServiceConfig>
  ) {
    this.userRepo = userRepo;
    this.profileRepo = profileRepo;
    this.otpRepo = otpRepo;
    this.refreshTokenRepo = refreshTokenRepo;
    this.smsProvider = smsProvider;

    const isProduction = process.env.NODE_ENV === 'production';
    const fallbackSecret = 'ascas_dev_fallback_secret_32_characters_minimum_length!';

    const accessSecret = config?.jwtAccessSecret || process.env.JWT_ACCESS_SECRET;
    const otpSec = config?.otpSecret || process.env.OTP_SECRET;

    if (isProduction && (!accessSecret || accessSecret.length < 32)) {
      throw new Error('JWT_ACCESS_SECRET must be at least 32 characters in production.');
    }
    if (isProduction && (!otpSec || otpSec.length < 32)) {
      throw new Error('OTP_SECRET must be at least 32 characters in production.');
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
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    // 1. IP Rate Limiting (15 requests/hour per IP)
    if (ipAddress) {
      const ipCount = await this.otpRepo.getRecentRequestCountByIp(ipAddress, oneHourAgo);
      if (ipCount >= this.config.maxRequestsPerHourPerIp) {
        throw new AppError(
          'Too many verification requests from this network. Please try again later.',
          429,
          'RATE_LIMIT_EXCEEDED'
        );
      }
    }

    // 2. Phone Hourly Rate Limiting (5 requests/hour per phone)
    const phoneCount = await this.otpRepo.getRecentRequestCountByPhone(phone, oneHourAgo);
    if (phoneCount >= this.config.maxRequestsPerHourPerPhone) {
      throw new AppError(
        'Too many verification attempts for this phone number. Please try again later.',
        429,
        'PHONE_RATE_LIMIT_EXCEEDED'
      );
    }

    // 3. Phone Resend Cooldown (45 seconds)
    const lastRequest = await this.otpRepo.getLastRequestTime(phone);
    if (lastRequest) {
      const elapsedSeconds = Math.floor((now.getTime() - lastRequest.getTime()) / 1000);
      if (elapsedSeconds < this.config.resendCooldownSeconds) {
        const remainingCooldown = this.config.resendCooldownSeconds - elapsedSeconds;
        throw new AppError(
          `Please wait ${remainingCooldown} seconds before requesting another verification code.`,
          429,
          'COOLDOWN_ACTIVE',
          { retryAfterSeconds: remainingCooldown }
        );
      }
    }

    // 4. Check user existence for anti-enumeration behavior
    const existingUser = await this.userRepo.findByPhone(phone);

    // Anti-enumeration:
    // If LOGIN is requested for an unknown account, or REGISTRATION for an existing account:
    // We create a decoy challenge record or standard challenge so verifyOtp returns the appropriate
    // structured error only after OTP challenge verification, without leaking account status on send.
    // If the account does not exist for LOGIN, do not dispatch real SMS to save cost,
    // but still track challenge to respond identically.
    let shouldDispatchSms = true;

    if (purpose === 'LOGIN' && (!existingUser || existingUser.status === 'SUSPENDED')) {
      shouldDispatchSms = false;
    }

    // Invalidate active predecessors for this phone and purpose
    await this.otpRepo.invalidatePredecessors(phone, purpose);

    // Generate cryptographically secure 6-digit OTP
    const otp = this.generateOtp();
    const otpHash = this.hashOtp(phone, purpose, otp);
    const expiresAt = new Date(now.getTime() + this.config.otpExpiresInMinutes * 60 * 1000);

    const challenge = await this.otpRepo.create({
      phone,
      otpHash,
      purpose,
      maxAttempts: this.config.maxOtpAttempts,
      expiresAt,
      ipAddress,
    });

    if (shouldDispatchSms) {
      await this.smsProvider.sendOtp(phone, otp, purpose);
    }

    return {
      challengeId: challenge.id,
      expiresInSeconds: this.config.otpExpiresInMinutes * 60,
      retryAfterSeconds: this.config.resendCooldownSeconds,
    };
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

    if (purpose === 'LOGIN') {
      if (!user) {
        throw new AppError('No active account found for this mobile number. Please register.', 404, 'USER_NOT_FOUND');
      }
      if (user.status === 'SUSPENDED') {
        throw new AppError('Your account has been suspended. Please contact clinic support.', 403, 'ACCOUNT_SUSPENDED');
      }
    } else if (purpose === 'REGISTRATION') {
      if (user) {
        throw new AppError('An account with this mobile number already exists. Please log in.', 409, 'USER_ALREADY_EXISTS');
      }
      // Create new user record
      user = await this.userRepo.create({
        phone,
        role: 'PATIENT',
        status: 'ACTIVE',
      });
      isNewUser = true;
    } else if (purpose === 'LINKED_MEMBER') {
      if (!user) {
        user = await this.userRepo.create({
          phone,
          role: 'PATIENT',
          status: 'ACTIVE',
        });
        isNewUser = true;
      }
      if (user.status === 'SUSPENDED') {
        throw new AppError('Account is suspended. Please contact clinic support.', 403, 'ACCOUNT_SUSPENDED');
      }
    }

    if (!user) {
      throw new AppError('Failed to establish user identity', 500);
    }

    // Fetch existing patient profile (if any)
    const profile = await this.profileRepo.findByUserId(user.id);
    const hasCompletedProfile = Boolean(profile);

    // Generate JWT access & refresh tokens
    const tokens = await this.generateTokenPair(user, profile, deviceInfo, ipAddress);

    return {
      user: {
        id: user.id,
        phone: user.phone,
        role: user.role,
        status: user.status,
      },
      profile: profile
        ? {
            id: profile.id,
            firstName: profile.firstName,
            lastName: profile.lastName,
            dob: profile.dob ? profile.dob.toISOString().split('T')[0] : null,
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

  // ==========================================================================
  // 3. Token Generation & Refresh
  // ==========================================================================

  private async generateTokenPair(
    user: User,
    profile?: PatientProfile | null,
    deviceInfo?: string,
    ipAddress?: string
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
