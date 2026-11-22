import crypto from 'crypto';
import {
  IEmailOtpRepository,
  IPasswordResetGrantRepository,
  IUserRepository,
} from './auth.repository.interface';
import {
  EmailOtpPurpose,
  User,
  UserCredentials,
  normalizeEmailAddress,
} from './auth.types';
import { IEmailProvider } from './email.provider.interface';
import {
  AppError,
  ConflictError,
  ForbiddenError,
  UnauthorizedError,
  ValidationError,
} from '../../utils/errors';
import {
  getStagingDeveloperEmailOtpRateLimits,
  isDeveloperEmailOtpTestEnabled,
  requiresConfiguredAuthSecrets,
} from '../../config/runtime';
import { normalizePhoneNumber } from './auth.schema';

const EMAIL_OTP_EXPIRES_IN_SECONDS = 5 * 60;
const EMAIL_OTP_RESEND_COOLDOWN_SECONDS = 30;
const EMAIL_OTP_MAX_ATTEMPTS = 5;
const PASSWORD_RESET_GRANT_EXPIRES_IN_SECONDS = 10 * 60;
const DEVELOPMENT_OTP_SECRET =
  'ascas_email_otp_dev_secret_32_characters_minimum!';

export interface EmailOtpSendResult {
  challengeId: string;
  expiresInSeconds: number;
  retryAfterSeconds: number;
}

export type EmailOtpVerificationResult =
  | { purpose: 'ACCOUNT_ACTIVATION'; verified: true }
  | { purpose: 'EMAIL_CHANGE'; verified: true; email: string }
  | {
      purpose: 'PASSWORD_RESET';
      verified: true;
      resetGrant: string;
      expiresInSeconds: number;
    }
  | { purpose: 'DEVELOPER_EMAIL_TEST'; verified: true };

export interface EmailAuthServiceConfig {
  otpSecret: string;
}

export class EmailAuthService {
  private readonly otpRepo: IEmailOtpRepository;
  private readonly passwordResetGrantRepo: IPasswordResetGrantRepository;
  private readonly userRepo: IUserRepository;
  private readonly emailProvider: IEmailProvider;
  private readonly otpSecret: string;

  constructor(
    userRepo: IUserRepository,
    otpRepo: IEmailOtpRepository,
    passwordResetGrantRepo: IPasswordResetGrantRepository,
    emailProvider: IEmailProvider,
    config?: Partial<EmailAuthServiceConfig>
  ) {
    this.userRepo = userRepo;
    this.otpRepo = otpRepo;
    this.passwordResetGrantRepo = passwordResetGrantRepo;
    this.emailProvider = emailProvider;

    const configuredOtpSecret = config?.otpSecret ?? process.env.OTP_SECRET;
    if (
      requiresConfiguredAuthSecrets(process.env) &&
      (!configuredOtpSecret || configuredOtpSecret.length < 32)
    ) {
      throw new Error(
        'OTP_SECRET must be at least 32 characters in production or staging.'
      );
    }
    this.otpSecret = configuredOtpSecret || DEVELOPMENT_OTP_SECRET;
  }

  public generateOtp(): string {
    return crypto.randomInt(100000, 1000000).toString();
  }

  public hashOtp(
    email: string,
    purpose: EmailOtpPurpose,
    userId: string | null,
    otp: string
  ): string {
    return crypto
      .createHmac('sha256', this.otpSecret)
      .update(`${email}:${purpose}:${userId ?? 'NO_USER'}:${otp}`)
      .digest('hex');
  }

  async sendOtp(
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string,
    ipAddress?: string
  ): Promise<EmailOtpSendResult> {
    const normalizedEmail = this.requireNormalizedEmail(email);
    this.assertPurpose(purpose);
    if (purpose === 'ACCOUNT_ACTIVATION' || purpose === 'PASSWORD_RESET') {
      throw new ValidationError(
        purpose === 'PASSWORD_RESET'
          ? 'Use the password reset request endpoint.'
          : 'Use the authenticated email activation endpoint.'
      );
    }

    let user: User | null = null;
    if (purpose === 'EMAIL_CHANGE') {
      if (!userId) {
        throw new UnauthorizedError('Authenticated user is required.');
      }
      user = await this.userRepo.findById(userId);
      if (!user) {
        throw new UnauthorizedError('Authenticated user is no longer available.');
      }
      if (user.status === 'SUSPENDED') {
        throw new ForbiddenError('Suspended accounts cannot change email.');
      }
      if (!user.email) {
        throw new ForbiddenError(
          'Email change requires an existing email address.'
        );
      }
      if (user.email === normalizedEmail) {
        throw new ValidationError('The email address is already on this account.');
      }
      const emailOwner = await this.userRepo.findByEmail(normalizedEmail);
      if (emailOwner && emailOwner.id !== user.id) {
        throw new ConflictError('An account with this email address already exists.');
      }
    } else {
      const credentials =
        await this.userRepo.findByEmailWithPasswordHash(normalizedEmail);
      user = credentials?.user ?? null;
      if (
        !user ||
        !credentials?.passwordHash ||
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
        (await this.userRepo.isPartnerAccount(user.id))
      ) {
        return this.createGenericSendResult();
      }
    }

    return this.issueOtp(normalizedEmail, purpose, user.id, ipAddress);
  }

  async sendPasswordResetOtp(
    phone: string,
    email: string,
    ipAddress?: string
  ): Promise<EmailOtpSendResult> {
    const normalizedPhone = normalizePhoneNumber(phone);
    if (!/^\+[1-9]\d{9,14}$/.test(normalizedPhone)) {
      throw new ValidationError('Please provide a valid mobile number.');
    }
    const normalizedEmail = this.requireNormalizedEmail(email);
    const user = await this.userRepo.findByPhone(normalizedPhone);
    const credentials = user
      ? await this.userRepo.findByIdWithPasswordHash(user.id)
      : null;
    if (
      !user ||
      !credentials?.passwordHash ||
      credentials.user.email !== normalizedEmail ||
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE' ||
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      (await this.userRepo.isPartnerAccount(user.id))
    ) {
      return this.createGenericSendResult();
    }

    return this.issueOtp(normalizedEmail, 'PASSWORD_RESET', user.id, ipAddress);
  }

  async sendActivationOtp(
    email: string,
    userId: string | undefined,
    ipAddress?: string
  ): Promise<EmailOtpSendResult> {
    if (!userId) {
      throw new UnauthorizedError('Authenticated user is required.');
    }
    const normalizedEmail = this.requireNormalizedEmail(email);
    await this.requireEligibleActivationAccount(userId);
    const emailOwner = await this.userRepo.findByEmail(normalizedEmail);
    if (emailOwner && emailOwner.id !== userId) {
      throw new ConflictError('An account with this email address already exists.');
    }
    return this.issueOtp(
      normalizedEmail,
      'ACCOUNT_ACTIVATION',
      userId,
      ipAddress
    );
  }

  async sendDeveloperEmailTestOtp(
    email: string,
    ipAddress?: string
  ): Promise<EmailOtpSendResult> {
    this.assertDeveloperEmailTestEnabled();
    const normalizedEmail = this.requireNormalizedEmail(email);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) {
      throw new ValidationError('Please provide a valid email address.');
    }
    return this.issueOtp(
      normalizedEmail,
      'DEVELOPER_EMAIL_TEST',
      null,
      ipAddress,
      getStagingDeveloperEmailOtpRateLimits(process.env)
    );
  }

  private async issueOtp(
    normalizedEmail: string,
    purpose: EmailOtpPurpose,
    userId: string | null,
    ipAddress?: string,
    rateLimits?: {
      maxRequestsPerHourPerEmail: number;
      maxRequestsPerHourPerIp: number;
    }
  ): Promise<EmailOtpSendResult> {
    const now = new Date();
    const otp = this.generateOtp();
    let challenge;
    try {
      challenge = await this.otpRepo.replaceActiveChallenge(
        {
          userId,
          email: normalizedEmail,
          otpHash: this.hashOtp(normalizedEmail, purpose, userId, otp),
          purpose,
          maxAttempts: EMAIL_OTP_MAX_ATTEMPTS,
          expiresAt: new Date(
            now.getTime() + EMAIL_OTP_EXPIRES_IN_SECONDS * 1000
          ),
          resendAfter: new Date(
            now.getTime() + EMAIL_OTP_RESEND_COOLDOWN_SECONDS * 1000
          ),
          ipAddress,
        },
        EMAIL_OTP_RESEND_COOLDOWN_SECONDS,
        rateLimits
      );
    } catch (error: unknown) {
      if (
        purpose === 'PASSWORD_RESET' &&
        error instanceof AppError &&
        error.errorCode === 'EMAIL_OTP_COOLDOWN_ACTIVE'
      ) {
        return this.createGenericSendResult();
      }
      throw error;
    }

    try {
      await this.emailProvider.sendOtp(normalizedEmail, otp, purpose);
    } catch (error: unknown) {
      if (purpose === 'PASSWORD_RESET' && error instanceof AppError) {
        console.error('[Password Reset] Email delivery failed.', {
          errorCode: error.errorCode,
          statusCode: error.statusCode,
        });
      }
      if (error instanceof AppError) {
        const existingDetails =
          typeof error.details === 'object' && error.details !== null
            ? error.details
            : {};
        const retryAfterValue =
          'retryAfterSeconds' in existingDetails
            ? existingDetails.retryAfterSeconds
            : undefined;
        const providerRetryAfterSeconds =
          typeof retryAfterValue === 'number' &&
          Number.isSafeInteger(retryAfterValue) &&
          retryAfterValue > 0
            ? retryAfterValue
            : undefined;
        throw new AppError(
          error.message,
          error.statusCode,
          error.errorCode,
          {
            ...existingDetails,
            ...(providerRetryAfterSeconds === undefined
              ? {}
              : { providerRetryAfterSeconds }),
            retryAfterSeconds: Math.max(
              this.secondsRemaining(challenge.resendAfter),
              providerRetryAfterSeconds ?? 0
            ),
          }
        );
      }
      throw error;
    }

    return {
      challengeId: challenge.id,
      expiresInSeconds: this.secondsRemaining(challenge.expiresAt),
      retryAfterSeconds: this.secondsRemaining(challenge.resendAfter),
    };
  }

  async verifyDeveloperEmailTestOtp(
    challengeId: string,
    email: string,
    otp: string
  ): Promise<EmailOtpVerificationResult> {
    this.assertDeveloperEmailTestEnabled();
    const normalizedEmail = this.requireNormalizedEmail(email);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(normalizedEmail)) {
      throw new ValidationError('Please provide a valid email address.');
    }

    const purpose = 'DEVELOPER_EMAIL_TEST';
    const challenge = await this.otpRepo.findActiveChallenge(
      challengeId,
      normalizedEmail,
      purpose,
      null
    );
    if (!challenge || challenge.userId !== null) {
      throw this.invalidOtpError();
    }

    const candidateHash = Buffer.from(
      this.hashOtp(normalizedEmail, purpose, null, otp),
      'hex'
    );
    const storedHash = Buffer.from(challenge.otpHash, 'hex');
    const otpMatches =
      storedHash.length === candidateHash.length &&
      storedHash.length > 0 &&
      crypto.timingSafeEqual(storedHash, candidateHash);
    if (!otpMatches) {
      await this.otpRepo.incrementAttempts(
        challengeId,
        normalizedEmail,
        purpose,
        null
      );
      throw this.invalidOtpError();
    }

    const consumed = await this.otpRepo.consume(
      challengeId,
      normalizedEmail,
      purpose,
      null
    );
    if (!consumed) {
      throw this.invalidOtpError();
    }

    return { purpose, verified: true };
  }

  async verifyActivationOtp(
    challengeId: string,
    email: string,
    otp: string,
    userId: string | undefined
  ): Promise<EmailOtpVerificationResult> {
    if (!userId) {
      throw new UnauthorizedError('Authenticated user is required.');
    }
    const normalizedEmail = this.requireNormalizedEmail(email);
    const challenge = await this.otpRepo.findActiveChallenge(
      challengeId,
      normalizedEmail,
      'ACCOUNT_ACTIVATION',
      userId
    );
    if (!challenge || challenge.userId !== userId) {
      throw this.invalidOtpError();
    }
    await this.requireEligibleActivationAccount(userId);

    const candidateHash = Buffer.from(
      this.hashOtp(
        normalizedEmail,
        'ACCOUNT_ACTIVATION',
        userId,
        otp
      ),
      'hex'
    );
    const storedHash = Buffer.from(challenge.otpHash, 'hex');
    const otpMatches =
      storedHash.length === candidateHash.length &&
      storedHash.length > 0 &&
      crypto.timingSafeEqual(storedHash, candidateHash);
    if (!otpMatches) {
      await this.otpRepo.incrementAttempts(
        challengeId,
        normalizedEmail,
        'ACCOUNT_ACTIVATION',
        userId
      );
      throw this.invalidOtpError();
    }

    const consumed = await this.otpRepo.consume(
      challengeId,
      normalizedEmail,
      'ACCOUNT_ACTIVATION',
      userId
    );
    if (!consumed) {
      throw this.invalidOtpError();
    }

    const updated = await this.userRepo.attachInitialVerifiedEmail(
      userId,
      normalizedEmail,
      new Date()
    );
    if (!updated) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    return { purpose: 'ACCOUNT_ACTIVATION', verified: true };
  }

  async verifyOtp(
    challengeId: string,
    email: string,
    purpose: EmailOtpPurpose,
    otp: string,
    userId?: string
  ): Promise<EmailOtpVerificationResult> {
    const normalizedEmail = this.requireNormalizedEmail(email);
    this.assertPurpose(purpose);
    if (purpose === 'ACCOUNT_ACTIVATION') {
      throw new ValidationError(
        'Use the authenticated email activation endpoint.'
      );
    }

    let user: User | null = null;
    if (purpose === 'EMAIL_CHANGE') {
      if (!userId) {
        throw new UnauthorizedError('Authenticated user is required.');
      }
      user = await this.userRepo.findById(userId);
      if (!user) {
        throw new UnauthorizedError('Authenticated user is no longer available.');
      }
      if (user.status === 'SUSPENDED') {
        throw new ForbiddenError('Suspended accounts cannot change email.');
      }
      if (!user.email) {
        throw new ForbiddenError(
          'Email change requires an existing email address.'
        );
      }
      const emailOwner = await this.userRepo.findByEmail(normalizedEmail);
      if (emailOwner && emailOwner.id !== user.id) {
        throw new ConflictError('An account with this email address already exists.');
      }
    } else {
      const credentials =
        await this.userRepo.findByEmailWithPasswordHash(normalizedEmail);
      user = credentials?.user ?? null;
      if (
        !user ||
        !credentials?.passwordHash ||
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
        (await this.userRepo.isPartnerAccount(user.id))
      ) {
        throw this.invalidOtpError();
      }
    }

    const challenge = await this.otpRepo.findActiveChallenge(
      challengeId,
      normalizedEmail,
      purpose,
      user.id
    );
    if (!challenge || challenge.userId !== user.id) {
      throw this.invalidOtpError();
    }

    const candidateHash = Buffer.from(
      this.hashOtp(normalizedEmail, purpose, user.id, otp),
      'hex'
    );
    const storedHash = Buffer.from(challenge.otpHash, 'hex');
    const otpMatches =
      storedHash.length === candidateHash.length &&
      storedHash.length > 0 &&
      crypto.timingSafeEqual(storedHash, candidateHash);

    if (!otpMatches) {
      await this.otpRepo.incrementAttempts(
        challengeId,
        normalizedEmail,
        purpose,
        user.id
      );
      throw this.invalidOtpError();
    }

    const consumed = await this.otpRepo.consume(
      challengeId,
      normalizedEmail,
      purpose,
      user.id
    );
    if (!consumed) {
      throw this.invalidOtpError();
    }

    if (purpose === 'EMAIL_CHANGE') {
      const updated = await this.userRepo.updateEmail(
        user.id,
        normalizedEmail,
        new Date(),
        user.email
      );
      if (!updated) {
        throw new ConflictError('Email change could not be completed.');
      }
      return { purpose, verified: true, email: updated.email ?? normalizedEmail };
    }

    const resetGrant = crypto.randomBytes(32).toString('base64url');
    await this.passwordResetGrantRepo.create({
      userId: user.id,
      grantHash: crypto
        .createHash('sha256')
        .update(resetGrant)
        .digest('hex'),
      expiresAt: new Date(
        Date.now() + PASSWORD_RESET_GRANT_EXPIRES_IN_SECONDS * 1000
      ),
    });
    return {
      purpose,
      verified: true,
      resetGrant,
      expiresInSeconds: PASSWORD_RESET_GRANT_EXPIRES_IN_SECONDS,
    };
  }

  private requireNormalizedEmail(email: string): string {
    const normalizedEmail = normalizeEmailAddress(email);
    if (!normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }
    return normalizedEmail;
  }

  private assertPurpose(purpose: EmailOtpPurpose): void {
    if (
      ![
        'ACCOUNT_ACTIVATION',
        'PASSWORD_RESET',
        'EMAIL_CHANGE',
      ].includes(purpose)
    ) {
      throw new ValidationError('Invalid email verification purpose.');
    }
  }

  private assertDeveloperEmailTestEnabled(): void {
    if (!isDeveloperEmailOtpTestEnabled(process.env)) {
      throw new AppError(
        'Staging developer email testing is not enabled.',
        404,
        'DEVELOPER_EMAIL_OTP_TEST_DISABLED'
      );
    }
  }

  private async requireEligibleActivationAccount(
    userId: string
  ): Promise<UserCredentials> {
    const credentials = await this.userRepo.findByIdWithPasswordHash(userId);
    if (!credentials) {
      throw new UnauthorizedError('Authenticated account is no longer available.');
    }
    if (
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE' ||
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      credentials.user.email !== null ||
      credentials.user.emailVerifiedAt !== null ||
      credentials.passwordHash !== null ||
      (await this.userRepo.isPartnerAccount(userId))
    ) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    return credentials;
  }

  private createGenericSendResult(): EmailOtpSendResult {
    return {
      challengeId: crypto.randomUUID(),
      expiresInSeconds: EMAIL_OTP_EXPIRES_IN_SECONDS,
      retryAfterSeconds: EMAIL_OTP_RESEND_COOLDOWN_SECONDS,
    };
  }

  private secondsRemaining(deadline: Date): number {
    return Math.max(0, Math.ceil((deadline.getTime() - Date.now()) / 1000));
  }

  private invalidOtpError(): AppError {
    return new AppError(
      'Verification code is invalid or has expired.',
      401,
      'INVALID_EMAIL_OTP'
    );
  }
}
