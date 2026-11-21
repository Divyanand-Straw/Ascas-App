import { describe, it, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import { Pool, PoolClient, QueryResult } from 'pg';
import {
  PostgresUserRepository,
  PostgresPatientProfileRepository,
  PostgresOtpRepository,
  PostgresRefreshTokenRepository,
} from '../src/modules/auth/postgres.auth.repository';
import {
  DevelopmentSmsProvider,
  ProductionSmsProvider,
} from '../src/modules/auth/sms.provider';
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
              email_password_eligibility: 'IDENTITY_REQUIRED',
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
      assert.deepEqual(executedQueries[0].params, [
        '+919876543210',
        'PATIENT',
        'ACTIVE',
        null,
      ]);
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

    it('records phone verification once for the authenticated user', async () => {
      const { mockPool } = createMockPool(async (text, params) => {
        assert.match(text, /phone_verified_at = COALESCE\(phone_verified_at, NOW\(\)\)/);
        assert.deepEqual(params, ['user-uuid-1']);
        return { rowCount: 1, rows: [] };
      });

      await new PostgresUserRepository(mockPool).markPhoneVerified(
        'user-uuid-1'
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
          assert.deepEqual(params, [
            'user-1',
            'Priya',
            'Sharma',
            null,
            'Female',
            '+919123456789',
            'ta',
          ]);
          return {
            rowCount: 1,
            rows: [
              {
                id: 'profile-1',
                user_id: 'user-1',
                first_name: 'Priya',
                last_name: 'Sharma',
                dob: null,
                gender: 'Female',
                emergency_contact: '+919123456789',
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
        gender: 'Female',
        emergencyContact: '+919123456789',
        preferredLanguage: 'ta',
      });

      assert.equal(profile.id, 'profile-1');
      assert.equal(profile.firstName, 'Priya');
      assert.equal(profile.gender, 'Female');
      assert.equal(profile.emergencyContact, '+919123456789');
      assert.equal(profile.preferredLanguage, 'ta');

      const found = await repo.findByUserId('user-1');
      assert.ok(found);
      assert.equal(found.id, 'profile-1');
    });

    it('does not overwrite an existing profile when profile creation is retried', async () => {
      const now = new Date();
      const statements: string[] = [];
      const { mockPool } = createMockPool(async (text) => {
        statements.push(text);
        if (text.includes('INSERT INTO patient_profiles')) {
          return { rowCount: 0, rows: [] };
        }
        return {
          rowCount: 1,
          rows: [
            {
              id: 'existing-profile',
              user_id: 'user-1',
              first_name: 'Priya',
              last_name: 'Sharma',
              dob: '1994-06-15',
              gender: 'Female',
              emergency_contact: null,
              clinic_mrn: null,
              preferred_language: 'ta',
              linking_status: 'UNLINKED',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const profile = await new PostgresPatientProfileRepository(
        mockPool
      ).createOrGet({
        userId: 'user-1',
        firstName: 'Changed',
        lastName: 'Name',
        dob: new Date('2000-01-01T00:00:00.000Z'),
        gender: 'Other',
        preferredLanguage: 'en',
      });

      assert.equal(profile.id, 'existing-profile');
      assert.equal(profile.firstName, 'Priya');
      assert.equal(profile.gender, 'Female');
      assert.equal(profile.clinicMrn, null);
      assert.equal(statements.length, 2);
      assert.match(statements[0], /ON CONFLICT \(user_id\) DO NOTHING/);
      assert.match(statements[1], /WHERE user_id = \$1/);
    });

    it('maps PostgreSQL DATE text without changing its calendar day', async () => {
      const now = new Date();
      let statement = '';
      const { mockPool } = createMockPool(async (text) => {
        statement = text;
        return {
          rowCount: 1,
          rows: [
            {
              id: 'profile-1',
              user_id: 'user-1',
              first_name: 'Priya',
              last_name: 'Sharma',
              dob: '1994-06-15',
              gender: null,
              clinic_mrn: null,
              preferred_language: 'en',
              linking_status: 'UNLINKED',
              created_at: now,
              updated_at: now,
            },
          ],
        };
      });

      const profile = await new PostgresPatientProfileRepository(
        mockPool
      ).findByUserId('user-1');

      assert.equal(profile?.dob?.toISOString(), '1994-06-15T00:00:00.000Z');
      assert.match(statement, /dob::text AS dob/);
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

    it('serializes issuance by phone and purpose and reuses an active challenge during cooldown', async () => {
      const now = new Date();
      const queries: string[] = [];
      let released = false;
      const activeChallenge = {
        id: 'existing-otp',
        phone: '+919876543210',
        otp_hash: 'stored-hash',
        purpose: 'REGISTRATION',
        attempts_count: 0,
        max_attempts: 3,
        expires_at: new Date(now.getTime() + 240000),
        consumed_at: null,
        ip_address: '127.0.0.1',
        created_at: new Date(now.getTime() - 15000),
        retry_after_seconds: 30,
      };
      const client = {
        query: async (text: string) => {
          queries.push(text);
          if (text.includes('retry_after_seconds')) {
            return { rowCount: 1, rows: [activeChallenge] };
          }
          return { rowCount: 0, rows: [] };
        },
        release: () => {
          released = true;
        },
      } as unknown as PoolClient;
      const pool = {
        connect: async () => client,
      } as unknown as Pool;

      const result = await new PostgresOtpRepository(
        pool
      ).createOrReuseForCooldown(
        {
          phone: '+919876543210',
          purpose: 'REGISTRATION',
        },
        {
          resendCooldownSeconds: 45,
          maxRequestsPerHourPerPhone: 5,
          maxRequestsPerHourPerIp: 15,
        },
        () => ({
          otpHash: 'unused-on-reuse',
          expiresAt: new Date(now.getTime() + 300000),
        })
      );

      assert.equal(result.created, false);
      assert.equal(result.challenge?.id, 'existing-otp');
      assert.equal(result.retryAfterSeconds, 30);
      assert.ok(queries.some((query) => query.includes('READ COMMITTED')));
      assert.ok(queries.some((query) => query.includes('pg_advisory_xact_lock')));
      assert.ok(queries.some((query) => query.includes('FOR UPDATE')));
      assert.ok(queries.some((query) => query.includes('COMMIT')));
      assert.equal(
        queries.some((query) => query.includes('INSERT INTO otp_verifications')),
        false
      );
      assert.equal(released, true);
    });

    it('invalidates and inserts a fresh purpose-specific challenge in one transaction after cooldown', async () => {
      const now = new Date();
      const queries: string[] = [];
      let released = false;
      const insertedChallenge = {
        id: 'new-otp',
        phone: '+919876543210',
        otp_hash: 'new-hash',
        purpose: 'EXISTING_PATIENT',
        attempts_count: 0,
        max_attempts: 3,
        expires_at: new Date(now.getTime() + 300000),
        consumed_at: null,
        ip_address: null,
        created_at: now,
      };
      const client = {
        query: async (text: string) => {
          queries.push(text);
          if (text.includes('INSERT INTO otp_verifications')) {
            return { rowCount: 1, rows: [insertedChallenge] };
          }
          return { rowCount: 0, rows: [] };
        },
        release: () => {
          released = true;
        },
      } as unknown as PoolClient;
      const pool = {
        connect: async () => client,
      } as unknown as Pool;

      const result = await new PostgresOtpRepository(
        pool
      ).createOrReuseForCooldown(
        {
          phone: '+919876543210',
          purpose: 'EXISTING_PATIENT',
        },
        {
          resendCooldownSeconds: 45,
          maxRequestsPerHourPerPhone: 5,
          maxRequestsPerHourPerIp: 15,
        },
        () => ({
          otpHash: 'new-hash',
          expiresAt: insertedChallenge.expires_at,
        })
      );

      const invalidationIndex = queries.findIndex((query) =>
        query.includes('SET consumed_at = NOW()')
      );
      const insertIndex = queries.findIndex((query) =>
        query.includes('INSERT INTO otp_verifications')
      );
      const commitIndex = queries.findIndex((query) =>
        query.trim() === 'COMMIT;'
      );
      assert.equal(result.created, true);
      assert.equal(result.challenge?.purpose, 'EXISTING_PATIENT');
      assert.ok(invalidationIndex > -1);
      assert.ok(insertIndex > invalidationIndex);
      assert.ok(commitIndex > insertIndex);
      assert.ok(queries.some((query) => query.includes('pg_advisory_xact_lock')));
      assert.equal(released, true);
    });

    it('checks the global IP request limit while holding its transaction-scoped lock', async () => {
      const queries: string[] = [];
      let released = false;
      const client = {
        query: async (text: string) => {
          queries.push(text);
          if (text.includes('WHERE ip_address = $1')) {
            return { rowCount: 1, rows: [{ count: 15 }] };
          }
          return { rowCount: 0, rows: [] };
        },
        release: () => {
          released = true;
        },
      } as unknown as PoolClient;
      const pool = {
        connect: async () => client,
      } as unknown as Pool;

      const result = await new PostgresOtpRepository(
        pool
      ).createOrReuseForCooldown(
        {
          phone: '+919876543210',
          purpose: 'REGISTRATION',
          ipAddress: '192.0.2.1',
        },
        {
          resendCooldownSeconds: 45,
          maxRequestsPerHourPerPhone: 5,
          maxRequestsPerHourPerIp: 15,
        },
        () => ({
          otpHash: 'unused-on-rate-limit',
          expiresAt: new Date(Date.now() + 300000),
        })
      );

      const ipLockIndex = queries.findIndex((query) =>
        query.includes('pg_advisory_xact_lock(hashtext($1), 2)')
      );
      const ipCountIndex = queries.findIndex((query) =>
        query.includes('WHERE ip_address = $1')
      );
      assert.equal(result.rateLimit, 'ip');
      assert.equal(result.challenge, null);
      assert.ok(ipLockIndex > -1);
      assert.ok(ipCountIndex > ipLockIndex);
      assert.ok(queries.some((query) => query.includes('COMMIT')));
      assert.equal(
        queries.some((query) => query.includes('INSERT INTO otp_verifications')),
        false
      );
      assert.equal(released, true);
    });
  });

  describe('PostgresRefreshTokenRepository', () => {
    it('should handle atomic token rotation inside transaction', async () => {
      const now = new Date();
      const expires = new Date(Date.now() + 604800000);
      const queries: string[] = [];

      const { mockPool } = createMockPool(async (text, params) => {
        queries.push(text);

        if (text.includes('SELECT user_id') && text.includes('FROM refresh_tokens')) {
          return {
            rowCount: 1,
            rows: [{ user_id: 'user-1' }],
          };
        }

        if (text.includes('SELECT id') && text.includes('FROM users')) {
          return {
            rowCount: 1,
            rows: [{ id: 'user-1' }],
          };
        }

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
        if (text.includes('SELECT user_id') && text.includes('FROM refresh_tokens')) {
          return {
            rowCount: 1,
            rows: [{ user_id: 'user-1' }],
          };
        }
        if (text.includes('SELECT id') && text.includes('FROM users')) {
          return {
            rowCount: 1,
            rows: [{ id: 'user-1' }],
          };
        }
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
      const provider = new ProductionSmsProvider({
        apiKey: '',
        gatewayUrl: 'https://sms.example.test/send',
      });
      await assert.rejects(
        () => provider.sendOtp('+919876543210', '123456', 'LOGIN'),
        (err: unknown) => {
          assert.ok(err instanceof AppError);
          assert.equal((err as AppError).errorCode, 'SMS_GATEWAY_UNCONFIGURED');
          return true;
        }
      );
    });

    it('requires a gateway URL even when an API key is configured', async () => {
      const provider = new ProductionSmsProvider({
        apiKey: 'test-api-key-12345',
        gatewayUrl: '',
      });
      await assert.rejects(
        () => provider.sendOtp('+919876543210', '987654', 'LOGIN'),
        (err: unknown) =>
          err instanceof AppError &&
          err.errorCode === 'SMS_GATEWAY_UNCONFIGURED'
      );
    });

    it('dispatches only over HTTPS and does not log the OTP', async () => {
      let requestUrl = '';
      let requestBody = '';
      const originalConsoleLog = console.log;
      const logLines: string[] = [];
      console.log = (...args: unknown[]) => logLines.push(args.join(' '));
      const provider = new ProductionSmsProvider({
        apiKey: 'test-api-key-12345',
        gatewayUrl: 'https://sms.example.test/send',
        fetchImpl: async (input, init) => {
          requestUrl = input.toString();
          requestBody = String(init?.body);
          return new Response(null, { status: 200 });
        },
      });
      try {
        const result = await provider.sendOtp(
          '+919876543210',
          '987654',
          'LOGIN'
        );
        assert.equal(result, true);
      } finally {
        console.log = originalConsoleLog;
      }

      assert.equal(requestUrl, 'https://sms.example.test/send');
      assert.equal(JSON.parse(requestBody).code, '987654');
      assert.deepEqual(logLines, []);
    });

    it('rejects a non-HTTPS gateway without dispatching', async () => {
      let dispatched = false;
      const provider = new ProductionSmsProvider({
        apiKey: 'test-api-key-12345',
        gatewayUrl: 'http://sms.example.test/send',
        fetchImpl: async () => {
          dispatched = true;
          return new Response(null, { status: 200 });
        },
      });
      await assert.rejects(
        () => provider.sendOtp('+919876543210', '987654', 'LOGIN'),
        (err: unknown) =>
          err instanceof AppError &&
          err.errorCode === 'SMS_GATEWAY_UNCONFIGURED'
      );
      assert.equal(dispatched, false);
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

    it('commits successful REGISTRATION OTP verification and its session atomically', async () => {
      const previousNodeEnv = process.env.NODE_ENV;
      const previousAppEnv = process.env.APP_ENV;
      const queryLog: string[] = [];
      const now = new Date();
      const challengeId = 'challenge-uuid-1';
      const userId = 'user-uuid-1';
      const phone = '+919876543210';
      const otp = '123456';
      let otpHash = '';
      const { mockPool } = createMockPool(async (text, params) => {
        queryLog.push(text.trim());
        if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(text.trim())) {
          return { rowCount: 0, rows: [] };
        }
        if (text.includes('FROM otp_verifications') && text.includes('WHERE id = $1')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: challengeId,
                phone,
                otp_hash: otpHash,
                purpose: 'REGISTRATION',
                attempts_count: 0,
                max_attempts: 3,
                expires_at: new Date(Date.now() + 300_000),
                consumed_at: null,
                ip_address: null,
                created_at: now,
              },
            ],
          };
        }
        if (text.includes('UPDATE otp_verifications') && text.includes('consumed_at = NOW()')) {
          return { rowCount: 1, rows: [{ id: challengeId }] };
        }
        if (text.includes('FROM users') && text.includes('WHERE phone = $1')) {
          return { rowCount: 0, rows: [] };
        }
        if (text.includes('INSERT INTO users')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: userId,
                phone,
                email: null,
                email_verified_at: null,
                role: 'PATIENT',
                status: 'ACTIVE',
                email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
                created_at: now,
                updated_at: now,
              },
            ],
          };
        }
        if (text.includes('UPDATE users') && text.includes('phone_verified_at')) {
          return { rowCount: 1, rows: [] };
        }
        if (text.includes('FROM patient_profiles') && text.includes('WHERE user_id = $1')) {
          return { rowCount: 0, rows: [] };
        }
        if (text.includes('INSERT INTO refresh_tokens')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: 'refresh-token-uuid-1',
                user_id: userId,
                token_hash: params?.[1],
                device_info: params?.[2],
                ip_address: params?.[3],
                expires_at: params?.[4],
                revoked_at: null,
                created_at: now,
              },
            ],
          };
        }
        throw new Error(`Unexpected query in OTP verification test: ${text}`);
      });

      try {
        process.env.NODE_ENV = 'test';
        process.env.APP_ENV = 'development';
        const { createPersistentAuthService } = await import('../src/modules/auth/auth.routes');
        const authService = createPersistentAuthService(
          mockPool,
          new DevelopmentSmsProvider()
        );
        otpHash = authService.hashOtp(phone, 'REGISTRATION', otp);

        const session = await authService.verifyOtp(
          challengeId,
          phone,
          'REGISTRATION',
          otp
        );

        assert.equal(session.user.id, userId);
        assert.equal(session.user.phone, phone);
        assert.equal(session.isNewUser, true);
        assert.equal(session.hasCompletedProfile, false);
        assert.ok(session.tokens.accessToken);
        assert.deepEqual(
          queryLog.filter((query) =>
            /^(BEGIN|COMMIT|ROLLBACK)$/.test(query)
          ),
          ['BEGIN', 'COMMIT']
        );
      } finally {
        if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
        else process.env.NODE_ENV = previousNodeEnv;
        if (previousAppEnv === undefined) delete process.env.APP_ENV;
        else process.env.APP_ENV = previousAppEnv;
      }
    });

    it('rolls back OTP consumption and account creation when phone verification persistence fails', async () => {
      const previousNodeEnv = process.env.NODE_ENV;
      const previousAppEnv = process.env.APP_ENV;
      const queryLog: string[] = [];
      const now = new Date();
      const challengeId = 'challenge-uuid-1';
      const userId = 'user-uuid-1';
      const phone = '+919876543210';
      const otp = '123456';
      let otpHash = '';
      const databaseError = Object.assign(
        new Error('phone_verified_at column is missing'),
        { code: '42703' }
      );
      const { mockPool } = createMockPool(async (text) => {
        queryLog.push(text.trim());
        if (/^(BEGIN|COMMIT|ROLLBACK)$/.test(text.trim())) {
          return { rowCount: 0, rows: [] };
        }
        if (text.includes('FROM otp_verifications') && text.includes('WHERE id = $1')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: challengeId,
                phone,
                otp_hash: otpHash,
                purpose: 'REGISTRATION',
                attempts_count: 0,
                max_attempts: 3,
                expires_at: new Date(Date.now() + 300_000),
                consumed_at: null,
                ip_address: null,
                created_at: now,
              },
            ],
          };
        }
        if (text.includes('UPDATE otp_verifications') && text.includes('consumed_at = NOW()')) {
          return { rowCount: 1, rows: [{ id: challengeId }] };
        }
        if (text.includes('FROM users') && text.includes('WHERE phone = $1')) {
          return { rowCount: 0, rows: [] };
        }
        if (text.includes('INSERT INTO users')) {
          return {
            rowCount: 1,
            rows: [
              {
                id: userId,
                phone,
                email: null,
                email_verified_at: null,
                role: 'PATIENT',
                status: 'ACTIVE',
                email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
                created_at: now,
                updated_at: now,
              },
            ],
          };
        }
        if (text.includes('UPDATE users') && text.includes('phone_verified_at')) {
          throw databaseError;
        }
        throw new Error(`Unexpected query in OTP verification test: ${text}`);
      });

      try {
        process.env.NODE_ENV = 'test';
        process.env.APP_ENV = 'development';
        const { createPersistentAuthService } = await import('../src/modules/auth/auth.routes');
        const authService = createPersistentAuthService(
          mockPool,
          new DevelopmentSmsProvider()
        );
        otpHash = authService.hashOtp(phone, 'REGISTRATION', otp);

        await assert.rejects(
          () =>
            authService.verifyOtp(
              challengeId,
              phone,
              'REGISTRATION',
              otp
            ),
          (error: unknown) =>
            (error as { code?: string }).code === '42703'
        );

        assert.deepEqual(
          queryLog.filter((query) =>
            /^(BEGIN|COMMIT|ROLLBACK)$/.test(query)
          ),
          ['BEGIN', 'ROLLBACK']
        );
      } finally {
        if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
        else process.env.NODE_ENV = previousNodeEnv;
        if (previousAppEnv === undefined) delete process.env.APP_ENV;
        else process.env.APP_ENV = previousAppEnv;
      }
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
        if (prevDb === undefined) delete process.env.DATABASE_URL;
        else process.env.DATABASE_URL = prevDb;
      }
    });

    it('should initialize production auth router with injected persistent AuthService', async () => {
      const prevEnv = process.env.NODE_ENV;
      const prevDb = process.env.DATABASE_URL;
      const prevJwt = process.env.JWT_ACCESS_SECRET;
      const prevOtp = process.env.OTP_SECRET;
      try {
        process.env.NODE_ENV = 'production';
        process.env.DATABASE_URL = 'postgresql://test:test@127.0.0.1:5432/test';
        process.env.JWT_ACCESS_SECRET = 'production_test_jwt_secret_must_be_32_characters_long!';
        process.env.OTP_SECRET = 'production_test_otp_secret_must_be_32_characters_long!';

        const { mockPool } = createMockPool(async () => ({ rowCount: 0, rows: [] }));
        const mockSms = new ProductionSmsProvider({ apiKey: 'key-123' });
        const {
          createPersistentAuthService,
          createPersistentEmailAuthService,
          createPersistentPasswordAuthService,
          createAuthRouter,
        } = await import('../src/modules/auth/auth.routes');

        const persistentService = createPersistentAuthService(mockPool, mockSms);
        const persistentEmailService = createPersistentEmailAuthService(
          mockPool,
          { sendOtp: async () => {} }
        );
        const persistentPasswordService =
          createPersistentPasswordAuthService(
            mockPool,
            persistentService
          );
        const router = createAuthRouter({
          authService: persistentService,
          emailAuthService: persistentEmailService,
          passwordAuthService: persistentPasswordService,
        });
        assert.ok(router);
      } finally {
        process.env.NODE_ENV = prevEnv;
        if (prevDb === undefined) delete process.env.DATABASE_URL;
        else process.env.DATABASE_URL = prevDb;
        if (prevJwt) process.env.JWT_ACCESS_SECRET = prevJwt;
        else delete process.env.JWT_ACCESS_SECRET;
        if (prevOtp) process.env.OTP_SECRET = prevOtp;
        else delete process.env.OTP_SECRET;
      }
    });
  });
});
