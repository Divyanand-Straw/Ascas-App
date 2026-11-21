import { NextFunction, Request, Response, Router } from 'express';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import type { OtpVerificationTransactionRunner } from './auth.service';
import { EmailAuthController } from './email.auth.controller';
import { EmailAuthService } from './email.auth.service';
import { PasswordAuthController } from './password.auth.controller';
import { PasswordAuthService } from './password.auth.service';
import {
  completePasswordResetSchema,
  emailPasswordLoginSchema,
  setupRegistrationCredentialsSchema,
  setupPasswordSchema,
} from './password.auth.schema';
import { BcryptPasswordHasher } from './password.hasher';
import { createAuthMiddleware } from './auth.middleware';
import { validateRequest } from '../../middleware/validate';
import {
  sendOtpSchema,
  verifyOtpSchema,
  savePatientProfileSchema,
  updatePatientProfileSchema,
  refreshTokenSchema,
  logoutSchema,
} from './auth.schema';
import {
  sendDeveloperEmailTestOtpSchema,
  sendEmailActivationOtpSchema,
  sendEmailOtpSchema,
  sendPasswordResetOtpSchema,
  verifyDeveloperEmailTestOtpSchema,
  verifyEmailActivationOtpSchema,
  verifyEmailOtpSchema,
} from './email.auth.schema';
import {
  MockUserRepository,
  MockPatientProfileRepository,
  MockOtpRepository,
  MockEmailOtpRepository,
  MockPasswordResetGrantRepository,
  MockPasswordLoginRateLimitRepository,
  MockRefreshTokenRepository,
} from './mock.auth.repository';
import {
  PostgresUserRepository,
  PostgresPatientProfileRepository,
  PostgresOtpRepository,
  PostgresEmailOtpRepository,
  PostgresPasswordResetGrantRepository,
  PostgresPasswordLoginRateLimitRepository,
  PostgresRefreshTokenRepository,
} from './postgres.auth.repository';
import { createSmsProvider } from './sms.provider';
import { ISmsProvider } from './sms.provider.interface';
import { createEmailProvider } from './email.provider';
import { IEmailProvider } from './email.provider.interface';
import { Pool } from 'pg';
import { pool } from '../../config/database';
import { AppError } from '../../utils/errors';
import {
  isDeveloperEmailOtpTestEnabled,
  getStagingDatabaseUrl,
} from '../../config/runtime';

export interface AuthModuleDependencies {
  authService?: AuthService;
  emailAuthService?: EmailAuthService;
  passwordAuthService?: PasswordAuthService;
}

let defaultAuthServiceInstance: AuthService | null = null;
let defaultEmailAuthServiceInstance: EmailAuthService | null = null;
let defaultPasswordAuthServiceInstance: PasswordAuthService | null = null;
let defaultUserRepository: MockUserRepository | null = null;
let defaultRefreshTokenRepository: MockRefreshTokenRepository | null = null;
let defaultPasswordResetGrantRepository: MockPasswordResetGrantRepository | null =
  null;

const assertProductionDatabaseConfigured = (): void => {
  if (process.env.APP_ENV === 'staging') {
    getStagingDatabaseUrl(process.env);
    return;
  }

  const dbUrl = process.env.DATABASE_URL?.trim();
  if (
    process.env.NODE_ENV === 'production' &&
    (!dbUrl || dbUrl === 'your_supabase_connection_string')
  ) {
    throw new Error(
      'Authentication module initialization failed in production: DATABASE_URL must be configured with a valid PostgreSQL URI.'
    );
  }
};

/**
 * Creates a production-ready AuthService backed by PostgreSQL repositories.
 */
export const createPersistentAuthService = (
  customPool?: Pool,
  customSmsProvider?: ISmsProvider
): AuthService => {
  assertProductionDatabaseConfigured();

  const p = customPool || pool;
  const smsProvider = customSmsProvider || createSmsProvider();
  const createService = (
    repositoryPool: Pool,
    transactionRunner?: OtpVerificationTransactionRunner
  ): AuthService =>
    new AuthService(
      new PostgresUserRepository(repositoryPool),
      new PostgresPatientProfileRepository(repositoryPool),
      new PostgresOtpRepository(repositoryPool),
      new PostgresRefreshTokenRepository(repositoryPool),
      smsProvider,
      undefined,
      transactionRunner
    );

  const transactionRunner: OtpVerificationTransactionRunner = async (
    verify
  ) => {
    const client = await p.connect();
    let transactionStarted = false;
    let releaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN');
      transactionStarted = true;

      const transactionPool = new Proxy(p, {
        get(target, property, receiver) {
          if (property === 'query') {
            return client.query.bind(client);
          }
          if (property === 'connect') {
            return async () => {
              throw new Error(
                'Nested database connections are not supported during OTP verification.'
              );
            };
          }
          return Reflect.get(target, property, receiver);
        },
      });

      const session = await verify(createService(transactionPool));
      await client.query('COMMIT');
      transactionStarted = false;
      return session;
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          // Keep deliberate OTP attempt and challenge-state changes.
          await client.query(error instanceof AppError ? 'COMMIT' : 'ROLLBACK');
          transactionStarted = false;
        } catch (transactionError: unknown) {
          releaseError =
            transactionError instanceof Error ? transactionError : true;
          throw new AggregateError(
            [error, transactionError],
            'OTP verification and transaction finalization both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(releaseError);
    }
  };

  return createService(p, transactionRunner);
};

export const createPersistentEmailAuthService = (
  customPool?: Pool,
  customEmailProvider?: IEmailProvider
): EmailAuthService => {
  assertProductionDatabaseConfigured();

  const p = customPool || pool;
  return new EmailAuthService(
    new PostgresUserRepository(p),
    new PostgresEmailOtpRepository(p),
    new PostgresPasswordResetGrantRepository(p),
    customEmailProvider || createEmailProvider()
  );
};

/**
 * Returns the shared default AuthService for development and test environments.
 * Strictly prevents mock repository instantiation in production.
 */
export const getDefaultAuthService = (): AuthService => {
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'Authentication module initialization failed: In-memory mock repositories cannot be used in production. A persistent repository-backed AuthService must be provided.'
    );
  }
  if (process.env.APP_ENV === 'staging') {
    throw new Error(
      'In-memory authentication repositories cannot be used in staging.'
    );
  }

  if (!defaultAuthServiceInstance) {
    const defaultUserRepo = new MockUserRepository();
    defaultUserRepository = defaultUserRepo;
    const defaultProfileRepo = new MockPatientProfileRepository();
    const defaultOtpRepo = new MockOtpRepository();
    const defaultTokenRepo = new MockRefreshTokenRepository(defaultUserRepo);
    defaultRefreshTokenRepository = defaultTokenRepo;
    const defaultSmsProvider = createSmsProvider();

    defaultAuthServiceInstance = new AuthService(
      defaultUserRepo,
      defaultProfileRepo,
      defaultOtpRepo,
      defaultTokenRepo,
      defaultSmsProvider
    );
  }

  return defaultAuthServiceInstance;
};

export const getDefaultEmailAuthService = (): EmailAuthService => {
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'Authentication module initialization failed: In-memory email repositories cannot be used in production.'
    );
  }
  if (process.env.APP_ENV === 'staging') {
    throw new Error(
      'In-memory email repositories cannot be used in staging.'
    );
  }

  if (!defaultEmailAuthServiceInstance) {
    if (!defaultUserRepository) {
      getDefaultAuthService();
    }
    if (!defaultUserRepository) {
      throw new Error('Default user repository was not initialized.');
    }
    const resetGrantRepository = getDefaultPasswordResetGrantRepository();
    defaultEmailAuthServiceInstance = new EmailAuthService(
      defaultUserRepository,
      new MockEmailOtpRepository(),
      resetGrantRepository,
      createEmailProvider()
    );
  }

  return defaultEmailAuthServiceInstance;
};

const getDefaultPasswordResetGrantRepository =
  (): MockPasswordResetGrantRepository => {
    if (!defaultUserRepository || !defaultRefreshTokenRepository) {
      getDefaultAuthService();
    }
    if (!defaultUserRepository || !defaultRefreshTokenRepository) {
      throw new Error('Default authentication repositories were not initialized.');
    }
    if (!defaultPasswordResetGrantRepository) {
      defaultPasswordResetGrantRepository =
        new MockPasswordResetGrantRepository(
          defaultUserRepository,
          defaultRefreshTokenRepository
        );
    }
    return defaultPasswordResetGrantRepository;
  };

export const getDefaultPasswordAuthService = (): PasswordAuthService => {
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'Authentication module initialization failed: In-memory password repositories cannot be used in production.'
    );
  }
  if (process.env.APP_ENV === 'staging') {
    throw new Error(
      'In-memory password repositories cannot be used in staging.'
    );
  }
  if (!defaultPasswordAuthServiceInstance) {
    const authService = defaultAuthServiceInstance || getDefaultAuthService();
    if (!defaultUserRepository) {
      throw new Error('Default user repository was not initialized.');
    }
    defaultPasswordAuthServiceInstance = new PasswordAuthService(
      defaultUserRepository,
      getDefaultPasswordResetGrantRepository(),
      new MockPasswordLoginRateLimitRepository(),
      authService,
      new BcryptPasswordHasher()
    );
  }
  return defaultPasswordAuthServiceInstance;
};

export const createPersistentPasswordAuthService = (
  customPool?: Pool,
  customAuthService?: AuthService
): PasswordAuthService => {
  assertProductionDatabaseConfigured();
  const p = customPool || pool;
  return new PasswordAuthService(
    new PostgresUserRepository(p),
    new PostgresPasswordResetGrantRepository(p),
    new PostgresPasswordLoginRateLimitRepository(p),
    customAuthService || createPersistentAuthService(p),
    new BcryptPasswordHasher()
  );
};

export const resetDefaultAuthServiceForTesting = (): void => {
  defaultAuthServiceInstance = null;
  defaultEmailAuthServiceInstance = null;
  defaultPasswordAuthServiceInstance = null;
  defaultUserRepository = null;
  defaultRefreshTokenRepository = null;
  defaultPasswordResetGrantRepository = null;
};

export const createAuthRouter = (deps?: AuthModuleDependencies): Router => {
  if (Boolean(deps?.authService) !== Boolean(deps?.passwordAuthService)) {
    throw new Error(
      'AuthService and PasswordAuthService must be injected together.'
    );
  }
  if (
    process.env.APP_ENV === 'staging' &&
    (!deps?.authService ||
      !deps.emailAuthService ||
      !deps.passwordAuthService)
  ) {
    throw new Error(
      'Authentication module initialization failed in staging. Persistent auth, email, and password services must be provided.'
    );
  }
  if (
    process.env.NODE_ENV === 'production' &&
    (!deps?.authService ||
      !deps.emailAuthService ||
      !deps.passwordAuthService)
  ) {
    throw new Error(
      'Authentication module initialization failed: In-memory repositories cannot be used in production. Persistent auth, email, and password services must be provided.'
    );
  }

  const router = Router();
  const service = deps?.authService || getDefaultAuthService();
  const emailAuthService =
    deps?.emailAuthService || getDefaultEmailAuthService();
  const passwordAuthService =
    deps?.passwordAuthService || getDefaultPasswordAuthService();
  const controller = new AuthController(service);
  const emailController = new EmailAuthController(emailAuthService);
  const passwordController = new PasswordAuthController(passwordAuthService);
  const requireAuth = createAuthMiddleware(service);
  const requireEmailChangeAuth = (
    req: Request,
    res: Response,
    next: NextFunction
  ): void => {
    if (req.body?.purpose === 'EMAIL_CHANGE') {
      return requireAuth(req, res, next);
    }
    next();
  };

  /**
   * POST /api/v1/auth/otp/send
   * Requests a 6-digit OTP challenge for LOGIN, REGISTRATION, EXISTING_PATIENT, or LINKED_MEMBER.
   */
  router.post(
    '/otp/send',
    validateRequest({ body: sendOtpSchema }),
    controller.sendOtp
  );

  /**
   * POST /api/v1/auth/otp/verify
   * Verifies the 6-digit OTP challenge and returns authenticated session with JWT tokens.
   */
  router.post(
    '/otp/verify',
    validateRequest({ body: verifyOtpSchema }),
    controller.verifyOtp
  );

  router.post(
    '/profile',
    requireAuth,
    validateRequest({ body: savePatientProfileSchema }),
    controller.savePatientProfile
  );

  router.put(
    '/profile',
    requireAuth,
    validateRequest({ body: updatePatientProfileSchema }),
    controller.updatePatientProfile
  );

  router.post(
    '/email/activation/otp/send',
    requireAuth,
    validateRequest({ body: sendEmailActivationOtpSchema }),
    emailController.sendActivationOtp
  );

  router.post(
    '/email/activation/otp/verify',
    requireAuth,
    validateRequest({ body: verifyEmailActivationOtpSchema }),
    emailController.verifyActivationOtp
  );

  router.post(
    '/email/otp/send',
    validateRequest({ body: sendEmailOtpSchema }),
    requireEmailChangeAuth,
    emailController.sendOtp
  );

  router.post(
    '/email/password/reset/otp/send',
    validateRequest({ body: sendPasswordResetOtpSchema }),
    emailController.sendPasswordResetOtp
  );

  router.post(
    '/email/otp/verify',
    validateRequest({ body: verifyEmailOtpSchema }),
    requireEmailChangeAuth,
    emailController.verifyOtp
  );

  if (isDeveloperEmailOtpTestEnabled(process.env)) {
    router.post(
      '/email/developer-test/otp/send',
      validateRequest({ body: sendDeveloperEmailTestOtpSchema }),
      emailController.sendDeveloperEmailTestOtp
    );
    router.post(
      '/email/developer-test/otp/verify',
      validateRequest({ body: verifyDeveloperEmailTestOtpSchema }),
      emailController.verifyDeveloperEmailTestOtp
    );
  }

  router.post(
    '/email/password/setup',
    requireAuth,
    validateRequest({ body: setupPasswordSchema }),
    passwordController.setupPassword
  );

  router.post(
    '/email/password/registration-setup',
    requireAuth,
    validateRequest({ body: setupRegistrationCredentialsSchema }),
    passwordController.setupRegistrationCredentials
  );

  router.post(
    '/email/password/login',
    validateRequest({ body: emailPasswordLoginSchema }),
    passwordController.login
  );

  router.post(
    '/email/password/reset',
    validateRequest({ body: completePasswordResetSchema }),
    passwordController.completePasswordReset
  );

  /**
   * POST /api/v1/auth/token/refresh
   * Rotates a refresh token and returns a new access/refresh token pair.
   */
  router.post(
    '/token/refresh',
    validateRequest({ body: refreshTokenSchema }),
    controller.refreshToken
  );

  /**
   * POST /api/v1/auth/logout
   * Revokes current refresh token / session. Requires valid Bearer access token.
   */
  router.post(
    '/logout',
    requireAuth,
    validateRequest({ body: logoutSchema }),
    controller.logout
  );

  /**
   * GET /api/v1/auth/me
   * Returns current authenticated user and profile status. Requires valid Bearer access token.
   */
  router.get(
    '/me',
    requireAuth,
    controller.getMe
  );

  return router;
};

// Default export router factory for backward compatibility
export default (deps?: AuthModuleDependencies): Router => createAuthRouter(deps);
