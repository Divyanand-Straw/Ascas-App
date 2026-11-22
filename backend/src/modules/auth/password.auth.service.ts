import crypto from 'crypto';
import {
  IPasswordLoginRateLimitRepository,
  IPasswordResetGrantRepository,
  IUserRepository,
} from './auth.repository.interface';
import { AuthService } from './auth.service';
import { normalizeEmailAddress } from './auth.types';
import { IPasswordHasher } from './password.hasher';
import {
  AppError,
  ConflictError,
  ForbiddenError,
  UnauthorizedError,
  ValidationError,
} from '../../utils/errors';
import { requiresConfiguredAuthSecrets } from '../../config/runtime';

const EMAIL_LOGIN_ATTEMPT_LIMIT = 5;
const IP_LOGIN_ATTEMPT_LIMIT = 15;
const DEVELOPMENT_RATE_LIMIT_SECRET =
  'ascas_password_login_rate_limit_dev_secret_32_chars';

export class PasswordAuthService {
  private readonly userRepo: IUserRepository;
  private readonly resetGrantRepo: IPasswordResetGrantRepository;
  private readonly rateLimitRepo: IPasswordLoginRateLimitRepository;
  private readonly authService: AuthService;
  private readonly passwordHasher: IPasswordHasher;
  private readonly rateLimitSecret: string;

  constructor(
    userRepo: IUserRepository,
    resetGrantRepo: IPasswordResetGrantRepository,
    rateLimitRepo: IPasswordLoginRateLimitRepository,
    authService: AuthService,
    passwordHasher: IPasswordHasher,
    config?: { rateLimitSecret?: string }
  ) {
    this.userRepo = userRepo;
    this.resetGrantRepo = resetGrantRepo;
    this.rateLimitRepo = rateLimitRepo;
    this.authService = authService;

    const configuredSecret =
      config?.rateLimitSecret ?? process.env.OTP_SECRET;
    if (
      requiresConfiguredAuthSecrets(process.env) &&
      (!configuredSecret || configuredSecret.length < 32)
    ) {
      throw new Error(
        'OTP_SECRET must be at least 32 characters in production or staging.'
      );
    }
    this.rateLimitSecret = configuredSecret || DEVELOPMENT_RATE_LIMIT_SECRET;
    this.passwordHasher = passwordHasher;
  }

  async setupPassword(userId: string, password: string): Promise<void> {
    if (!userId) {
      throw new UnauthorizedError('Authenticated user is required.');
    }
    this.validateNewPassword(password);
    const credentials = await this.userRepo.findByIdWithPasswordHash(userId);
    if (!credentials) {
      throw new UnauthorizedError('Authenticated account is unavailable.');
    }
    if (
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE'
    ) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    if (
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE'
    ) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    if (!credentials.user.email || !credentials.user.emailVerifiedAt) {
      throw new ForbiddenError(
        'A verified email is required to set a password.'
      );
    }
    if (await this.userRepo.isPartnerAccount(userId)) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    if (credentials.passwordHash) {
      throw new ConflictError('Password credentials are already configured.');
    }

    const passwordHash = await this.passwordHasher.hash(password);
    const result = await this.userRepo.setInitialPasswordHash(
      userId,
      passwordHash
    );

    if (result === 'SET') return;
    if (result === 'USER_NOT_FOUND') {
      throw new UnauthorizedError('Authenticated account is unavailable.');
    }
    if (result === 'EMAIL_UNVERIFIED') {
      throw new ForbiddenError('A verified email is required to set a password.');
    }
    if (result === 'PASSWORD_ALREADY_SET') {
      throw new ConflictError('Password credentials are already configured.');
    }
    throw new ForbiddenError(
      'This account is not eligible for email/password credentials.'
    );
  }

  async setupRegistrationCredentials(
    userId: string,
    email: string,
    password: string
  ): Promise<void> {
    if (!userId) {
      throw new UnauthorizedError('Authenticated user is required.');
    }
    const normalizedEmail = normalizeEmailAddress(email);
    if (!normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }
    this.validateNewPassword(password);

    const credentials = await this.userRepo.findByIdWithPasswordHash(userId);
    if (!credentials) {
      throw new UnauthorizedError('Authenticated account is unavailable.');
    }
    if (
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE' ||
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      (await this.userRepo.isPartnerAccount(userId))
    ) {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }

    if (credentials.passwordHash) {
      if (
        credentials.user.email === normalizedEmail &&
        !credentials.user.emailVerifiedAt &&
        (await this.passwordHasher.verify(password, credentials.passwordHash))
      ) {
        return;
      }
      throw new ConflictError('Password credentials are already configured.');
    }
    if (credentials.user.email || credentials.user.emailVerifiedAt) {
      throw new ConflictError('Email credentials are already configured.');
    }

    const passwordHash = await this.passwordHasher.hash(password);
    const result = await this.userRepo.setInitialRegistrationCredentials(
      userId,
      normalizedEmail,
      passwordHash
    );
    if (result === 'SET') return;
    if (result === 'USER_NOT_FOUND') {
      throw new UnauthorizedError('Authenticated account is unavailable.');
    }
    if (result === 'CREDENTIALS_ALREADY_CONFIGURED') {
      const current =
        await this.userRepo.findByIdWithPasswordHash(userId);
      if (
        current?.user.email === normalizedEmail &&
        !current.user.emailVerifiedAt &&
        current.passwordHash &&
        (await this.passwordHasher.verify(password, current.passwordHash))
      ) {
        return;
      }
      throw new ConflictError('Password credentials are already configured.');
    }
    if (result === 'PARTNER_MEMBER') {
      throw new ForbiddenError(
        'This account is not eligible for email/password credentials.'
      );
    }
    throw new ForbiddenError(
      'This account is not eligible for email/password credentials.'
    );
  }

  async login(
    email: string,
    password: string,
    deviceInfo?: string,
    ipAddress?: string
  ) {
    const normalizedEmail = normalizeEmailAddress(email);
    if (!normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }
    this.validateLoginPassword(password);

    const emailBucketHash = this.hashRateLimitBucket('EMAIL', normalizedEmail);
    const ipBucketHash = ipAddress?.trim()
      ? this.hashRateLimitBucket('IP', ipAddress.trim())
      : undefined;
    const attemptCounts = await this.rateLimitRepo.recordAttempt(
      emailBucketHash,
      ipBucketHash
    );
    if (
      attemptCounts.emailAttempts > EMAIL_LOGIN_ATTEMPT_LIMIT ||
      (attemptCounts.ipAttempts !== null &&
        attemptCounts.ipAttempts > IP_LOGIN_ATTEMPT_LIMIT)
    ) {
      throw new AppError(
        'Too many login attempts. Please try again later.',
        429,
        'LOGIN_RATE_LIMIT_EXCEEDED'
      );
    }

    const credentials =
      await this.userRepo.findByEmailWithPasswordHash(normalizedEmail);
    const passwordMatches = credentials?.passwordHash
      ? await this.passwordHasher.verify(password, credentials.passwordHash)
      : await this.performDummyPasswordWork(password);

    if (
      !credentials ||
      !credentials.passwordHash ||
      !passwordMatches ||
      credentials.user.role !== 'PATIENT' ||
      credentials.user.status !== 'ACTIVE' ||
      credentials.user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      (await this.userRepo.isPartnerAccount(credentials.user.id))
    ) {
      throw this.invalidCredentialsError();
    }

    try {
      return await this.authService.createEmailPasswordSession(
        credentials.user.id,
        credentials.passwordHash,
        deviceInfo,
        ipAddress
      );
    } catch (error: unknown) {
      if (
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PASSWORD_INVALID_CREDENTIALS'
      ) {
        throw this.invalidCredentialsError();
      }
      throw error;
    }
  }

  async completePasswordReset(
    resetGrant: string,
    newPassword: string
  ): Promise<void> {
    this.validateNewPassword(newPassword);
    const grantHash = crypto
      .createHash('sha256')
      .update(resetGrant)
      .digest('hex');
    const grant = await this.resetGrantRepo.findActiveByHash(grantHash);
    if (!grant) {
      throw this.invalidResetGrantError();
    }

    const passwordHash = await this.passwordHasher.hash(newPassword);
    const completed = await this.resetGrantRepo.completePasswordReset(
      grantHash,
      passwordHash
    );
    if (!completed) {
      throw this.invalidResetGrantError();
    }
  }

  private hashRateLimitBucket(type: 'EMAIL' | 'IP', value: string): string {
    return crypto
      .createHmac('sha256', this.rateLimitSecret)
      .update(`password-login:${type}:${value}`)
      .digest('hex');
  }

  private async performDummyPasswordWork(password: string): Promise<boolean> {
    await this.passwordHasher.hash(password);
    return false;
  }

  private validateNewPassword(password: string): void {
    if (typeof password !== 'string' || password.length < 12) {
      throw new ValidationError('Password must be at least 12 characters.');
    }
    if (
      password.length > 128 ||
      Buffer.byteLength(password, 'utf8') > 72
    ) {
      throw new ValidationError('Password must not exceed 72 UTF-8 bytes.');
    }
  }

  private validateLoginPassword(password: string): void {
    if (typeof password !== 'string' || password.length === 0) {
      throw new ValidationError('Password is required.');
    }
    if (
      password.length > 128 ||
      Buffer.byteLength(password, 'utf8') > 72
    ) {
      throw new ValidationError('Password must not exceed 72 UTF-8 bytes.');
    }
  }

  private invalidCredentialsError(): AppError {
    return new AppError(
      'Email or password is incorrect.',
      401,
      'EMAIL_PASSWORD_INVALID_CREDENTIALS'
    );
  }

  private invalidResetGrantError(): AppError {
    return new AppError(
      'Password reset grant is invalid or expired.',
      401,
      'INVALID_PASSWORD_RESET_GRANT'
    );
  }
}
