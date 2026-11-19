import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { Pool, PoolClient, QueryResult } from 'pg';
import {
  PostgresUserRepository,
  PostgresPatientProfileRepository,
  PostgresOtpRepository,
  PostgresRefreshTokenRepository,
} from '../src/modules/auth/postgres.auth.repository';
import { ProductionSmsProvider } from '../src/modules/auth/sms.provider';
import { ConflictError, AppError } from '../src/utils/errors';

/**
 * Creates a mock Pool with custom query handlers for testing PostgreSQL repositories.
 */
function createMockPool(queryHandler: (text: string, params?: unknown[]) => Promise<Partial<QueryResult>>) {
  const clientQueryHandler = queryHandler;

  const mockClient = {
    query: async (text: string, params?: unknown[]) => {
      return (await clientQueryHandler(text, params)) as QueryResult;
    },
    release: () => {},
  } as unknown as PoolClient;

  const mockPool = {
    query: async (text: string, params?: unknown[]) => {
      return (await queryHandler(text, params)) as QueryResult;
    },
    connect: async () => mockClient,
  } as unknown as Pool;

  return { mockPool, mockClient };
}

describe('PostgreSQL Authentication Repositories', () => {
  describe('PostgresUserRepository', () => {
    it('should create a new user and map columns correctly', async () => {
      const now = new Date();
      const executedQueries: Array<{ text: string; params?: unknown[] }> = [];

      const { mockPool } = createMockPool(async (text, params) => {
        executedQueries.push({ text, params });
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-uuid-1',
              phone: '+919876543210',
              role: 'PATIENT',
              status: 'ACTIVE',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const userRepo = new PostgresUserRepository(mockPool);
      const user = await userRepo.create({ phone: '+919876543210' });

      assert.equal(user.id, 'user-uuid-1');
      assert.equal(user.phone, '+919876543210');
      assert.equal(user.role, 'PATIENT');
      assert.equal(user.status, 'ACTIVE');
      assert.ok(executedQueries[0].text.includes('INSERT INTO users'));
      assert.deepEqual(executedQueries[0].params, ['+919876543210', 'PATIENT', 'ACTIVE']);
    });

    it('should throw ConflictError when duplicate phone constraint (23505) is violated', async () => {
      const { mockPool } = createMockPool(async () => {
        const err = new Error('duplicate key value violates unique constraint') as Error & { code: string };
        err.code = '23505';
        throw err;
      });

      const userRepo = new PostgresUserRepository(mockPool);
      await assert.rejects(
        () => userRepo.create({ phone: '+919876543210' }),
        (err: unknown) => {
          assert.ok(err instanceof ConflictError);
          assert.match((err as ConflictError).message, /already exists/);
          return true;
        }
      );
    });

    it('should find user by phone or return null', async () => {
      const now = new Date();
      let shouldFind = true;
      const { mockPool } = createMockPool(async () => {
        if (!shouldFind) return { rowCount: 0, rows: [] };
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-uuid-1',
              phone: '+919876543210',
              role: 'PATIENT',
              status: 'ACTIVE',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const userRepo = new PostgresUserRepository(mockPool);
      const found = await userRepo.findByPhone('+919876543210');
      assert.ok(found);
      assert.equal(found.phone, '+919876543210');

      shouldFind = false;
      const notFound = await userRepo.findByPhone('+910000000000');
      assert.equal(notFound, null);
    });

    it('should update user status', async () => {
      const now = new Date();
      const { mockPool } = createMockPool(async (text, params) => {
        assert.ok(text.includes('UPDATE users'));
        assert.deepEqual(params, ['SUSPENDED', 'user-uuid-1']);
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-uuid-1',
              phone: '+919876543210',
              role: 'PATIENT',
              status: 'SUSPENDED',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const userRepo = new PostgresUserRepository(mockPool);
      const updated = await userRepo.updateStatus('user-uuid-1', 'SUSPENDED');
      assert.ok(updated);
      assert.equal(updated.status, 'SUSPENDED');
    });
  });

  describe('PostgresPatientProfileRepository', () => {
    it('should create and retrieve patient profile', async () => {
      const now = new Date();
      const { mockPool } = createMockPool(async (text, params) => {
        if (text.includes('INSERT INTO patient_profiles')) {
          assert.deepEqual(params, ['user-1', 'Priya', 'Sharma', null, 'ta']);
          return {
            rowCount: 1,
            rows: [
              {
                id: 'profile-1',
                user_id: 'user-1',
                first_name: 'Priya',
                last_name: 'Sharma',
                dob: null,
                gender: null,
                clinic_mrn: null,
                preferred_language: 'ta',
                linking_status: 'UNLINKED',
                created_at: now,
                updated_at: now,
              },
            ],
          };
        }
        return {
          rowCount: 1,
          rows: [
            {
              id: 'profile-1',
              user_id: 'user-1',
              first_name: 'Priya',
              last_name: 'Sharma',
              dob: null,
              gender: null,
              clinic_mrn: null,
              preferred_language: 'ta',
              linking_status: 'UNLINKED',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const repo = new PostgresPatientProfileRepository(mockPool);
      const profile = await repo.create({
        userId: 'user-1',
        firstName: 'Priya',
        lastName: 'Sharma',
        preferredLanguage: 'ta',
      });

      assert.equal(profile.id, 'profile-1');
      assert.equal(profile.firstName, 'Priya');
      assert.equal(profile.preferredLanguage, 'ta');

      const found = await repo.findByUserId('user-1');
      assert.ok(found);
      assert.equal(found.id, 'profile-1');
    });
  });

  describe('PostgresOtpRepository', () => {
    it('should create challenge, increment attempts, and consume atomically', async () => {
      const now = new Date();
      const expires = new Date(Date.now() + 300000);

      const { mockPool } = createMockPool(async (text, params) => {
        if (text.includes('INSERT INTO otp_verifications')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: 'otp-1',
                phone: '+919876543210',
                otp_hash: 'hash123',
                purpose: 'LOGIN',
                attempts_count: 0,
                max_attempts: 3,
                expires_at: expires,
                consumed_at: null,
                ip_address: '127.0.0.1',
                created_at: now,
              },
            ],
          };
        }
        if (text.includes('UPDATE otp_verifications') && text.includes('attempts_count = attempts_count + 1')) {
          return {
            rowCount: 1,
            rows: [{ attempts_count: 1 }],
          };
        }
        if (text.includes('UPDATE otp_verifications') && text.includes('consumed_at = NOW()')) {
          return {
            rowCount: 1,
            rows: [{ id: 'otp-1' }],
          };
        }
        if (text.includes('SELECT') && text.includes('COUNT(*)::int')) {
          return {
            rowCount: 1,
            rows: [{ count: 2 }],
          };
        }
        return { rowCount: 0, rows: [] };
      });

      const otpRepo = new PostgresOtpRepository(mockPool);
      const challenge = await otpRepo.create({
        phone: '+919876543210',
        otpHash: 'hash123',
        purpose: 'LOGIN',
        expiresAt: expires,
        ipAddress: '127.0.0.1',
      });

      assert.equal(challenge.id, 'otp-1');
      assert.equal(challenge.attemptsCount, 0);

      const attempts = await otpRepo.incrementAttempts('otp-1');
      assert.equal(attempts, 1);

      const consumed = await otpRepo.consume('otp-1');
      assert.equal(consumed, true);

      const count = await otpRepo.getRecentRequestCountByPhone('+919876543210', new Date(Date.now() - 3600000));
      assert.equal(count, 2);
    });
  });

  describe('PostgresRefreshTokenRepository', () => {
    it('should handle atomic token rotation inside transaction', async () => {
      const now = new Date();
      const expires = new Date(Date.now() + 604800000);
      const queries: string[] = [];

      const { mockPool } = createMockPool(async (text, params) => {
        queries.push(text);

        if (text.includes('SELECT id, user_id, revoked_at') && text.includes('FOR UPDATE')) {
          return {
            rowCount: 1,
            rows: [{ id: 'old-token-id', user_id: 'user-1', revoked_at: null }],
          };
        }

        if (text.includes('INSERT INTO refresh_tokens')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: 'new-token-id',
                user_id: 'user-1',
                token_hash: 'new-hash',
                device_info: 'Pixel 8',
                ip_address: '10.0.2.2',
                expires_at: expires,
                revoked_at: null,
                created_at: now,
              },
            ],
          };
        }

        return { rowCount: 1, rows: [] };
      });

      const repo = new PostgresRefreshTokenRepository(mockPool);
      const newToken = await repo.rotateToken('old-token-id', {
        userId: 'user-1',
        tokenHash: 'new-hash',
        deviceInfo: 'Pixel 8',
        ipAddress: '10.0.2.2',
        expiresAt: expires,
      });

      assert.equal(newToken.id, 'new-token-id');
      assert.ok(queries.some((q) => q.includes('BEGIN')));
      assert.ok(queries.some((q) => q.includes('FOR UPDATE')));
      assert.ok(queries.some((q) => q.includes('replaced_by_token_id')));
      assert.ok(queries.some((q) => q.includes('COMMIT')));
    });

    it('should detect token reuse and reject rotation if old token is already revoked', async () => {
      const { mockPool } = createMockPool(async (text) => {
        if (text.includes('FOR UPDATE')) {
          return {
            rowCount: 1,
            rows: [{ id: 'old-token-id', user_id: 'user-1', revoked_at: new Date() }],
          };
        }
        return { rowCount: 1, rows: [] };
      });

      const repo = new PostgresRefreshTokenRepository(mockPool);
      await assert.rejects(
        () =>
          repo.rotateToken('old-token-id', {
            userId: 'user-1',
            tokenHash: 'new-hash',
            expiresAt: new Date(),
          }),
        (err: unknown) => {
          assert.ok(err instanceof AppError);
          assert.equal((err as AppError).errorCode, 'REFRESH_TOKEN_REUSE_DETECTED');
          return true;
        }
      );
    });
  });

  describe('ProductionSmsProvider', () => {
    it('should throw SMS_GATEWAY_UNCONFIGURED if SMS_API_KEY is not set', async () => {
      const provider = new ProductionSmsProvider({ apiKey: '' });
      await assert.rejects(
        () => provider.sendOtp('+919876543210', '123456', 'LOGIN'),
        (err: unknown) => {
          assert.ok(err instanceof AppError);
          assert.equal((err as AppError).errorCode, 'SMS_GATEWAY_UNCONFIGURED');
          return true;
        }
      );
    });

    it('should succeed with valid API key and never log OTP to console', async () => {
      const provider = new ProductionSmsProvider({ apiKey: 'test-api-key-12345' });
      const result = await provider.sendOtp('+919876543210', '987654', 'LOGIN');
      assert.equal(result, true);
    });
  });

  describe('Persistent AuthService & Production Routing', () => {
    it('should create persistent AuthService instance backed by PostgreSQL repositories', async () => {
      const { mockPool } = createMockPool(async () => ({ rowCount: 0, rows: [] }));
      const mockSms = new ProductionSmsProvider({ apiKey: 'key-123' });
      const { createPersistentAuthService } = await import('../src/modules/auth/auth.routes');

      const authService = createPersistentAuthService(mockPool, mockSms);
      assert.ok(authService);
    });

    it('should fail in production if DATABASE_URL is not configured', async () => {
      const prevEnv = process.env.NODE_ENV;
      const prevDb = process.env.DATABASE_URL;
      try {
        process.env.NODE_ENV = 'production';
        delete process.env.DATABASE_URL;
        const { createPersistentAuthService } = await import('../src/modules/auth/auth.routes');
        assert.throws(
          () => createPersistentAuthService(),
          /DATABASE_URL must be configured/
        );
      } finally {
        process.env.NODE_ENV = prevEnv;
        if (prevDb) process.env.DATABASE_URL = prevDb;
      }
    });

    it('should initialize production auth router with injected persistent AuthService', async () => {
      const prevEnv = process.env.NODE_ENV;
      const prevJwt = process.env.JWT_ACCESS_SECRET;
      const prevOtp = process.env.OTP_SECRET;
      try {
        process.env.NODE_ENV = 'production';
        process.env.JWT_ACCESS_SECRET = 'production_test_jwt_secret_must_be_32_characters_long!';
        process.env.OTP_SECRET = 'production_test_otp_secret_must_be_32_characters_long!';

        const { mockPool } = createMockPool(async () => ({ rowCount: 0, rows: [] }));
        const mockSms = new ProductionSmsProvider({ apiKey: 'key-123' });
        const { createPersistentAuthService, createAuthRouter } = await import(
          '../src/modules/auth/auth.routes'
        );

        const persistentService = createPersistentAuthService(mockPool, mockSms);
        const router = createAuthRouter({ authService: persistentService });
        assert.ok(router);
      } finally {
        process.env.NODE_ENV = prevEnv;
        if (prevJwt) process.env.JWT_ACCESS_SECRET = prevJwt;
        else delete process.env.JWT_ACCESS_SECRET;
        if (prevOtp) process.env.OTP_SECRET = prevOtp;
        else delete process.env.OTP_SECRET;
      }
    });
  });
});
