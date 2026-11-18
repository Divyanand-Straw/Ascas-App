import { Router } from 'express';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { createAuthMiddleware } from './auth.middleware';
import { validateRequest } from '../../middleware/validate';
import {
  sendOtpSchema,
  verifyOtpSchema,
  refreshTokenSchema,
  logoutSchema,
} from './auth.schema';
import {
  MockUserRepository,
  MockPatientProfileRepository,
  MockOtpRepository,
  MockRefreshTokenRepository,
} from './mock.auth.repository';
import {
  PostgresUserRepository,
  PostgresPatientProfileRepository,
  PostgresOtpRepository,
  PostgresRefreshTokenRepository,
} from './postgres.auth.repository';
import { createSmsProvider } from './sms.provider';
import { ISmsProvider } from './sms.provider.interface';
import { Pool } from 'pg';
import { pool } from '../../config/database';

export interface AuthModuleDependencies {
  authService?: AuthService;
}

let defaultAuthServiceInstance: AuthService | null = null;

/**
 * Creates a production-ready AuthService backed by PostgreSQL repositories.
 */
export const createPersistentAuthService = (
  customPool?: Pool,
  customSmsProvider?: ISmsProvider
): AuthService => {
  const dbUrl = process.env.DATABASE_URL?.trim();
  if (
    process.env.NODE_ENV === 'production' &&
    (!dbUrl || dbUrl === 'your_supabase_connection_string')
  ) {
    throw new Error(
      'Authentication module initialization failed in production: DATABASE_URL must be configured with a valid PostgreSQL URI.'
    );
  }

  const p = customPool || pool;
  const userRepo = new PostgresUserRepository(p);
  const profileRepo = new PostgresPatientProfileRepository(p);
  const otpRepo = new PostgresOtpRepository(p);
  const tokenRepo = new PostgresRefreshTokenRepository(p);
  const smsProvider = customSmsProvider || createSmsProvider();

  return new AuthService(
    userRepo,
    profileRepo,
    otpRepo,
    tokenRepo,
    smsProvider
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

  if (!defaultAuthServiceInstance) {
    const defaultUserRepo = new MockUserRepository();
    const defaultProfileRepo = new MockPatientProfileRepository();
    const defaultOtpRepo = new MockOtpRepository();
    const defaultTokenRepo = new MockRefreshTokenRepository();
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

export const resetDefaultAuthServiceForTesting = (): void => {
  defaultAuthServiceInstance = null;
};

export const createAuthRouter = (deps?: AuthModuleDependencies): Router => {
  if (process.env.NODE_ENV === 'production' && !deps?.authService) {
    throw new Error(
      'Authentication module initialization failed: In-memory mock repositories cannot be used in production. An explicit production AuthService backed by persistent repositories must be provided.'
    );
  }

  const router = Router();
  const service = deps?.authService || getDefaultAuthService();
  const controller = new AuthController(service);
  const requireAuth = createAuthMiddleware(service);

  /**
   * POST /api/v1/auth/otp/send
   * Requests a 6-digit OTP challenge for LOGIN, REGISTRATION, or LINKED_MEMBER.
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
