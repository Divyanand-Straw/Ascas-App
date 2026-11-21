import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { Pool, PoolClient, QueryResult } from 'pg';
import {
  MockEmailOtpRepository,
  MockPasswordResetGrantRepository,
  MockRefreshTokenRepository,
  MockUserRepository,
} from '../src/modules/auth/mock.auth.repository';
import {
  PostgresEmailOtpRepository,
  PostgresPasswordResetGrantRepository,
  PostgresUserRepository,
} from '../src/modules/auth/postgres.auth.repository';
import { AppError, ConflictError } from '../src/utils/errors';

function createMockPool(
  queryHandler: (
    text: string,
    params?: unknown[]
  ) => Promise<Partial<QueryResult>>
) {
  const mockClient = {
    query: async (text: string, params?: unknown[]) =>
      (await queryHandler(text, params)) as QueryResult,
    release: () => {},
  } as unknown as PoolClient;

  const mockPool = {
    query: async (text: string, params?: unknown[]) =>
      (await queryHandler(text, params)) as QueryResult,
    connect: async () => mockClient,
  } as unknown as Pool;

  return mockPool;
}

const userRow = (overrides: Record<string, unknown> = {}) => ({
  id: 'user-1',
  phone: '+919876543210',
  email: null,
  email_verified_at: null,
  password_hash: null,
  role: 'PATIENT',
  status: 'ACTIVE',
  created_at: new Date('2026-01-01T00:00:00Z'),
  updated_at: new Date('2026-01-01T00:00:00Z'),
  ...overrides,
});

const emailTrimCharsSql = String.raw`E' \t\n\r\f' || CHR(11) || U&'\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'`;

describe('Email and credential repositories', () => {
  describe('MockUserRepository', () => {
    it('normalizes email whitespace and case and rejects duplicate addresses', async () => {
      const repo = new MockUserRepository();
      const first = await repo.create({ phone: '+919876543210' });
      const second = await repo.create({ phone: '+919876543211' });
      const verifiedAt = new Date();

      const updated = await repo.updateEmail(
        first.id,
        '\t\nPatient@Example.COM\r\n\t',
        verifiedAt,
        null
      );

      assert.equal(updated?.email, 'patient@example.com');
      assert.equal(updated?.emailVerifiedAt?.getTime(), verifiedAt.getTime());
      assert.equal(
        (await repo.findByEmail(' PATIENT@example.com '))?.id,
        first.id
      );
      await assert.rejects(
        () =>
          repo.updateEmail(
            second.id,
            'PATIENT@example.com',
            verifiedAt,
            null
          ),
        ConflictError
      );
    });

    it('allows multiple OTP-only users with null email and keeps hashes out of User', async () => {
      const repo = new MockUserRepository();
      const first = await repo.create({ phone: '+919876543210' });
      const second = await repo.create({ phone: '+919876543211' });

      assert.equal(first.email, null);
      assert.equal(second.email, null);
      assert.equal(first.emailVerifiedAt, null);
      assert.equal(second.emailVerifiedAt, null);

      const verified = await repo.updateEmail(
        first.id,
        'patient@example.com',
        new Date(),
        null
      );
      assert.ok(verified?.emailVerifiedAt);
      repo.setEmailPasswordEligibilityForTesting(
        first.id,
        'NEW_PATIENT_ELIGIBLE'
      );
      assert.equal(await repo.setPasswordHash(first.id, 'bcrypt-hash'), true);

      const credentials = await repo.findByEmailWithPasswordHash(
        'patient@example.com'
      );
      assert.equal(credentials?.passwordHash, 'bcrypt-hash');
      assert.equal('passwordHash' in (credentials?.user ?? {}), false);
      assert.equal((await repo.findByPhone(second.phone))?.email, null);
    });

    it('uses the expected current email to prevent concurrent stale updates', async () => {
      const repo = new MockUserRepository();
      const user = await repo.create({ phone: '+919876543210' });
      const verifiedAt = new Date();

      const results = await Promise.all([
        repo.updateEmail(
          user.id,
          'first@example.com',
          verifiedAt,
          null
        ),
        repo.updateEmail(
          user.id,
          'second@example.com',
          verifiedAt,
          null
        ),
      ]);

      assert.equal(results.filter((result) => result !== null).length, 1);
      assert.ok(
        ['first@example.com', 'second@example.com'].includes(
          (await repo.findById(user.id))?.email ?? ''
        )
      );
    });

    it('attaches initial verified email only to a persisted eligible account', async () => {
      const repo = new MockUserRepository();
      const user = await repo.create({ phone: '+919876543210' });
      const verifiedAt = new Date();

      assert.equal(
        await repo.attachInitialVerifiedEmail(
          user.id,
          'patient@example.com',
          verifiedAt
        ),
        null
      );

      repo.setEmailPasswordEligibilityForTesting(
        user.id,
        'NEW_PATIENT_ELIGIBLE'
      );
      const attached = await repo.attachInitialVerifiedEmail(
        user.id,
        'patient@example.com',
        verifiedAt
      );
      assert.equal(attached?.email, 'patient@example.com');
      assert.equal(attached?.emailVerifiedAt?.getTime(), verifiedAt.getTime());
    });
  });

  it('uses the same whitespace normalization in PostgreSQL constraints and lookups', async () => {
    let capturedQuery = '';
    let capturedParams: unknown[] | undefined;
    const repo = new PostgresUserRepository(
      createMockPool(async (text, params) => {
        capturedQuery = text;
        capturedParams = params;
        return { rowCount: 0, rows: [] };
      })
    );

    await repo.findByEmail('\t\nPatient@Example.COM\r\n\t');
    assert.deepEqual(capturedParams, ['patient@example.com']);
    assert.ok(capturedQuery.includes(emailTrimCharsSql));

    const migration = readFileSync(
      resolve(__dirname, '../database/migrations/005_add_email_password_auth.sql'),
      'utf8'
    );
    const normalizedMigration = migration.replace(/\s+/g, ' ');
    const normalizedTrimCharsSql = emailTrimCharsSql.replace(/\s+/g, ' ');
    assert.equal(
      normalizedMigration.split(normalizedTrimCharsSql).length - 1,
      3
    );
    assert.match(
      migration,
      /CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique[\s\S]*WHERE email IS NOT NULL/
    );
  });

  describe('MockEmailOtpRepository', () => {
    it('persists normalized challenges and consumes them only once', async () => {
      const repo = new MockEmailOtpRepository();
      const resendAfter = new Date(Date.now() + 30_000);
      const challenge = await repo.create({
        userId: 'user-1',
        email: '  Patient@Example.COM ',
        otpHash: 'otp-hash',
        purpose: 'ACCOUNT_ACTIVATION',
        expiresAt: new Date(Date.now() + 300_000),
        resendAfter,
      });

      assert.equal(challenge.email, 'patient@example.com');
      assert.equal(challenge.resendAfter.getTime(), resendAfter.getTime());
      assert.equal(
        (
          await repo.findActiveChallenge(
            challenge.id,
            'PATIENT@example.com',
            'ACCOUNT_ACTIVATION',
            'user-1'
          )
        )?.id,
        challenge.id
      );
      assert.equal(
        (
          await repo.getLastResendAfter(
            'patient@example.com',
            'ACCOUNT_ACTIVATION',
            'user-1'
          )
        )?.getTime(),
        resendAfter.getTime()
      );

      const consumed = await Promise.all([
        repo.consume(
          challenge.id,
          'patient@example.com',
          'ACCOUNT_ACTIVATION',
          'user-1'
        ),
        repo.consume(
          challenge.id,
          'patient@example.com',
          'ACCOUNT_ACTIVATION',
          'user-1'
        ),
      ]);
      assert.deepEqual(consumed.sort(), [false, true]);
      assert.equal(
        await repo.findActiveChallenge(
          challenge.id,
          'patient@example.com',
          'ACCOUNT_ACTIVATION',
          'user-1'
        ),
        null
      );
    });

    it('atomically replaces prior active challenges for the same email and purpose', async () => {
      const repo = new MockEmailOtpRepository();
      const challengeData = {
        userId: 'user-1',
        email: ' Patient@Example.COM ',
        otpHash: 'otp-hash',
        purpose: 'ACCOUNT_ACTIVATION' as const,
        expiresAt: new Date(Date.now() + 300_000),
        resendAfter: new Date(Date.now() + 30_000),
      };
      const original = await repo.replaceActiveChallenge(challengeData);
      const differentPurpose = await repo.create({
        ...challengeData,
        purpose: 'EMAIL_CHANGE',
      });

      const replacements = await Promise.all(
        Array.from({ length: 8 }, (_, index) =>
          repo.replaceActiveChallenge({
            ...challengeData,
            email: index % 2 ? 'patient@example.com' : '\tPATIENT@example.com\n',
            otpHash: `replacement-${index}`,
          })
        )
      );

      assert.equal(
        await repo.findActiveChallenge(
          original.id,
          challengeData.email,
          challengeData.purpose,
          challengeData.userId
        ),
        null
      );
      assert.ok(
        await repo.findActiveChallenge(
          differentPurpose.id,
          challengeData.email,
          differentPurpose.purpose,
          challengeData.userId
        )
      );
      const activeReplacements = await Promise.all(
        replacements.map((challenge) =>
          repo.findActiveChallenge(
            challenge.id,
            challengeData.email,
            challengeData.purpose,
            challengeData.userId
          )
        )
      );
      assert.equal(activeReplacements.filter(Boolean).length, 1);
    });

    it('rejects expired, consumed, and incorrectly bound challenges', async () => {
      const repo = new MockEmailOtpRepository();
      const expired = await repo.create({
        userId: 'user-1',
        email: 'patient@example.com',
        otpHash: 'expired-hash',
        purpose: 'EMAIL_CHANGE',
        expiresAt: new Date(Date.now() + 300_000),
        resendAfter: new Date(Date.now() + 30_000),
      });
      repo.expireChallengeForTesting(expired.id);

      assert.equal(
        await repo.findActiveChallenge(
          expired.id,
          expired.email,
          expired.purpose,
          expired.userId
        ),
        null
      );
      assert.equal(
        await repo.consume(
          expired.id,
          expired.email,
          expired.purpose,
          expired.userId
        ),
        false
      );

      const active = await repo.create({
        userId: 'user-1',
        email: 'patient@example.com',
        otpHash: 'active-hash',
        purpose: 'EMAIL_CHANGE',
        expiresAt: new Date(Date.now() + 300_000),
        resendAfter: new Date(Date.now() + 30_000),
      });
      assert.equal(
        await repo.findActiveChallenge(
          active.id,
          active.email,
          active.purpose,
          'another-user'
        ),
        null
      );
      assert.equal(
        await repo.consume(active.id, active.email, active.purpose, 'user-1'),
        true
      );
      assert.equal(
        await repo.consume(active.id, active.email, active.purpose, 'user-1'),
        false
      );
    });
  });

  describe('MockPasswordResetGrantRepository', () => {
    it('allows a valid reset grant to be consumed only once', async () => {
      const repo = new MockPasswordResetGrantRepository(
        new MockUserRepository(),
        new MockRefreshTokenRepository()
      );
      const grant = await repo.create({
        userId: 'user-1',
        grantHash: 'sha256-hash',
        expiresAt: new Date(Date.now() + 600_000),
      });

      assert.equal((await repo.findActiveByHash(grant.grantHash))?.userId, 'user-1');
      const consumed = await Promise.all([
        repo.consume(grant.grantHash),
        repo.consume(grant.grantHash),
      ]);
      assert.deepEqual(consumed.sort(), [false, true]);
      assert.equal(await repo.findActiveByHash(grant.grantHash), null);
    });

    it('does not consume an expired reset grant', async () => {
      const repo = new MockPasswordResetGrantRepository(
        new MockUserRepository(),
        new MockRefreshTokenRepository()
      );
      const grant = await repo.create({
        userId: 'user-1',
        grantHash: 'expired-grant-hash',
        expiresAt: new Date(Date.now() - 1000),
      });

      assert.equal(await repo.findActiveByHash(grant.grantHash), null);
      assert.equal(await repo.consume(grant.grantHash), false);
    });
  });

  describe('PostgresUserRepository', () => {
    it('normalizes email query and returns credentials separately from the User', async () => {
      let capturedQuery = '';
      let capturedParams: unknown[] | undefined;
      const repo = new PostgresUserRepository(
        createMockPool(async (text, params) => {
          capturedQuery = text;
          capturedParams = params;
          return {
            rowCount: 1,
            rows: [
              userRow({
                email: 'patient@example.com',
                email_verified_at: new Date('2026-02-01T00:00:00Z'),
                password_hash: 'bcrypt-hash',
              }),
            ],
          };
        })
      );

      const result = await repo.findByEmailWithPasswordHash(
        ' Patient@Example.COM '
      );

      assert.deepEqual(capturedParams, ['patient@example.com']);
      assert.match(capturedQuery, /password_hash/);
      assert.equal(result?.user.email, 'patient@example.com');
      assert.equal(result?.passwordHash, 'bcrypt-hash');
      assert.equal('passwordHash' in (result?.user ?? {}), false);
    });

    it('keeps new phone-only accounts compatible with null email fields', async () => {
      let insertCount = 0;
      const repo = new PostgresUserRepository(
        createMockPool(async (text) => {
          assert.match(
            text,
            /INSERT INTO users \(phone, role, status, email_password_eligibility\)/
          );
          assert.match(text, /COALESCE\(\$4, 'IDENTITY_REQUIRED'\)/);
          insertCount += 1;
          return {
            rowCount: 1,
            rows: [
              userRow({
                id: `user-${insertCount}`,
                phone: `+91987654321${insertCount}`,
              }),
            ],
          };
        })
      );

      const first = await repo.create({ phone: '+919876543211' });
      const second = await repo.create({ phone: '+919876543212' });
      assert.equal(first.email, null);
      assert.equal(second.email, null);
      assert.equal(first.emailVerifiedAt, null);
      assert.equal(second.emailVerifiedAt, null);
      assert.equal(first.emailPasswordEligibility, 'IDENTITY_REQUIRED');
      assert.equal(second.emailPasswordEligibility, 'IDENTITY_REQUIRED');
    });

    it('persists new-patient email/password eligibility only when explicitly supplied', async () => {
      let capturedParams: unknown[] | undefined;
      const repo = new PostgresUserRepository(
        createMockPool(async (_text, params) => {
          capturedParams = params;
          return {
            rowCount: 1,
            rows: [
              userRow({
                email_password_eligibility: params?.[3],
              }),
            ],
          };
        })
      );

      const user = await repo.create({
        phone: '+919876543213',
        emailPasswordEligibility: 'NEW_PATIENT_ELIGIBLE',
      });

      assert.equal(capturedParams?.[3], 'NEW_PATIENT_ELIGIBLE');
      assert.equal(user.emailPasswordEligibility, 'NEW_PATIENT_ELIGIBLE');
      assert.equal(user.email, null);
    });

    it('normalizes and compare-and-swaps email updates', async () => {
      let capturedQuery = '';
      let capturedParams: unknown[] | undefined;
      const repo = new PostgresUserRepository(
        createMockPool(async (text, params) => {
          capturedQuery = text;
          capturedParams = params;
          return {
            rowCount: 1,
            rows: [
              userRow({
                email: 'patient@example.com',
                email_verified_at: new Date('2026-02-01T00:00:00Z'),
              }),
            ],
          };
        })
      );
      const verifiedAt = new Date('2026-02-01T00:00:00Z');

      const updated = await repo.updateEmail(
        'user-1',
        ' Patient@Example.COM ',
        verifiedAt,
        null
      );

      assert.equal(updated?.email, 'patient@example.com');
      assert.deepEqual(capturedParams, [
        'user-1',
        'patient@example.com',
        verifiedAt,
        null,
      ]);
      assert.match(capturedQuery, /email IS NOT DISTINCT FROM \$4/);
    });

    it('maps case-insensitive unique-index violations to a conflict', async () => {
      const repo = new PostgresUserRepository(
        createMockPool(async () => {
          const error = new Error('duplicate key') as Error & {
            code: string;
            constraint: string;
          };
          error.code = '23505';
          error.constraint = 'idx_users_email_unique';
          throw error;
        })
      );

      await assert.rejects(
        () =>
          repo.updateEmail(
            'user-2',
            'patient@example.com',
            new Date(),
            null
          ),
        ConflictError
      );
    });

    it('attaches initial email under a user lock and commits only for eligible users', async () => {
      const statements: string[] = [];
      const pool = createMockPool(async (text) => {
        statements.push(text);
        if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
          return {
            rowCount: 1,
            rows: [
              userRow({
                email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              }),
            ],
          };
        }
        if (text.includes('care_unit_invitations')) {
          return { rowCount: 1, rows: [{ is_partner_account: false }] };
        }
        if (text.includes('UPDATE users')) {
          return {
            rowCount: 1,
            rows: [
              userRow({
                email: 'patient@example.com',
                email_verified_at: new Date(),
                email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              }),
            ],
          };
        }
        return { rowCount: 0, rows: [] };
      });
      const repo = new PostgresUserRepository(pool);

      const result = await repo.attachInitialVerifiedEmail(
        'user-1',
        ' Patient@Example.com ',
        new Date()
      );

      assert.equal(result?.email, 'patient@example.com');
      assert.match(statements[0], /BEGIN ISOLATION LEVEL READ COMMITTED/);
      assert.ok(statements.some((statement) => /FOR UPDATE/.test(statement)));
      assert.ok(
        statements.some((statement) =>
          /email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'/.test(statement)
        )
      );
      assert.ok(statements.includes('COMMIT'));
      assert.equal(statements.includes('ROLLBACK'), false);
    });

    it('maps concurrent initial email uniqueness violations to a conflict and rolls back', async () => {
      const statements: string[] = [];
      const pool = createMockPool(async (text) => {
        statements.push(text);
        if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
          return {
            rowCount: 1,
            rows: [
              userRow({
                email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              }),
            ],
          };
        }
        if (text.includes('care_unit_invitations')) {
          return { rowCount: 1, rows: [{ is_partner_account: false }] };
        }
        if (text.includes('UPDATE users')) {
          const error = new Error('duplicate normalized email') as Error & {
            code: string;
            constraint: string;
          };
          error.code = '23505';
          error.constraint = 'idx_users_email_unique';
          throw error;
        }
        return { rowCount: 0, rows: [] };
      });
      const repo = new PostgresUserRepository(pool);

      await assert.rejects(
        () =>
          repo.attachInitialVerifiedEmail(
            'user-1',
            'taken@example.com',
            new Date()
          ),
        ConflictError
      );
      assert.ok(statements.includes('ROLLBACK'));
      assert.equal(statements.includes('COMMIT'), false);
    });
  });

  describe('PostgresEmailOtpRepository', () => {
    it('persists normalized challenge fields including resend timing', async () => {
      let capturedQuery = '';
      let capturedParams: unknown[] | undefined;
      const expiresAt = new Date('2026-02-01T00:05:00Z');
      const resendAfter = new Date('2026-02-01T00:00:30Z');
      const createdAt = new Date('2026-02-01T00:00:00Z');
      const repo = new PostgresEmailOtpRepository(
        createMockPool(async (text, params) => {
          capturedQuery = text;
          capturedParams = params;
          return {
            rowCount: 1,
            rows: [
              {
                id: 'challenge-1',
                user_id: 'user-1',
                email: 'patient@example.com',
                otp_hash: 'otp-hash',
                purpose: 'ACCOUNT_ACTIVATION',
                attempts_count: 0,
                max_attempts: 3,
                expires_at: expiresAt,
                resend_after: resendAfter,
                consumed_at: null,
                ip_address: '127.0.0.1',
                created_at: createdAt,
              },
            ],
          };
        })
      );

      const challenge = await repo.create({
        userId: 'user-1',
        email: ' Patient@Example.COM ',
        otpHash: 'otp-hash',
        purpose: 'ACCOUNT_ACTIVATION',
        expiresAt,
        resendAfter,
        ipAddress: '127.0.0.1',
      });

      assert.match(capturedQuery, /INSERT INTO email_otp_challenges/);
      assert.equal(capturedParams?.[1], 'patient@example.com');
      assert.equal(capturedParams?.[5], expiresAt);
      assert.equal(capturedParams?.[6], resendAfter);
      assert.equal(challenge.email, 'patient@example.com');
      assert.equal(challenge.resendAfter.getTime(), resendAfter.getTime());
    });

    it('serializes concurrent challenge replacements in one transaction per email and purpose', async () => {
      type StoredChallenge = {
        id: string;
        user_id: string | null;
        email: string;
        otp_hash: string;
        purpose: string;
        attempts_count: number;
        max_attempts: number;
        expires_at: Date;
        resend_after: Date;
        consumed_at: Date | null;
        ip_address: string | null;
        created_at: Date;
      };
      const stored: StoredChallenge[] = [];
      const lockTails = new Map<string, Promise<void>>();
      const statements: string[] = [];

      const acquireLock = async (key: string): Promise<() => void> => {
        const previous = lockTails.get(key) ?? Promise.resolve();
        let unlock = () => {};
        const current = new Promise<void>((resolveLock) => {
          unlock = resolveLock;
        });
        lockTails.set(key, current);
        await previous;
        return () => {
          unlock();
          if (lockTails.get(key) === current) lockTails.delete(key);
        };
      };

      const mockPool = {
        connect: async () => {
          let releaseLock: (() => void) | undefined;
          return {
            query: async (text: string, params: unknown[] = []) => {
              statements.push(text.trim());
              if (
                text.trim() === 'BEGIN ISOLATION LEVEL READ COMMITTED' ||
                text.trim() === 'COMMIT'
              ) {
                if (text.trim() === 'COMMIT') {
                  releaseLock?.();
                  releaseLock = undefined;
                }
                return { rowCount: 0, rows: [] };
              }
              if (text.includes('pg_advisory_xact_lock')) {
                releaseLock = await acquireLock(`${params[0]}|${params[1]}`);
                return { rowCount: 1, rows: [] };
              }
              if (text.includes('UPDATE email_otp_challenges')) {
                for (const challenge of stored) {
                  if (
                    challenge.email === params[0] &&
                    challenge.purpose === params[1] &&
                    challenge.consumed_at === null
                  ) {
                    challenge.consumed_at = new Date();
                  }
                }
                return { rowCount: 0, rows: [] };
              }
              if (text.includes('INSERT INTO email_otp_challenges')) {
                const challenge: StoredChallenge = {
                  id: `challenge-${stored.length + 1}`,
                  user_id: (params[0] as string | null) ?? null,
                  email: params[1] as string,
                  otp_hash: params[2] as string,
                  purpose: params[3] as string,
                  attempts_count: 0,
                  max_attempts: params[4] as number,
                  expires_at: params[5] as Date,
                  resend_after: params[6] as Date,
                  consumed_at: null,
                  ip_address: (params[7] as string | null) ?? null,
                  created_at: new Date(),
                };
                stored.push(challenge);
                return { rowCount: 1, rows: [challenge] };
              }
              if (text.trim() === 'ROLLBACK') {
                releaseLock?.();
                releaseLock = undefined;
                return { rowCount: 0, rows: [] };
              }
              assert.fail(`Unexpected PostgreSQL statement: ${text}`);
            },
            release: () => {
              releaseLock?.();
            },
          } as unknown as PoolClient;
        },
      } as unknown as Pool;
      const repo = new PostgresEmailOtpRepository(mockPool);
      const replacements = await Promise.all(
        Array.from({ length: 6 }, (_, index) =>
          repo.replaceActiveChallenge({
            userId: 'user-1',
            email: index % 2 ? 'patient@example.com' : '\tPatient@Example.COM\n',
            otpHash: `otp-hash-${index}`,
            purpose: 'ACCOUNT_ACTIVATION',
            expiresAt: new Date(Date.now() + 300_000),
            resendAfter: new Date(Date.now() + 30_000),
          })
        )
      );

      assert.equal(replacements.length, 6);
      assert.equal(stored.filter((challenge) => challenge.consumed_at === null).length, 1);
      assert.equal(
        statements.filter(
          (statement) => statement === 'BEGIN ISOLATION LEVEL READ COMMITTED'
        ).length,
        6
      );
      assert.equal(
        statements.filter((statement) => statement.includes('pg_advisory_xact_lock')).length,
        6
      );
      assert.equal(statements.filter((statement) => statement === 'COMMIT').length, 6);
    });

    it('checks resend cooldown under the advisory lock before invalidating challenges', async () => {
      const statements: string[] = [];
      const repo = new PostgresEmailOtpRepository(
        createMockPool(async (text) => {
          statements.push(text.trim());
          if (text.includes('MAX(resend_after)')) {
            return {
              rowCount: 1,
              rows: [{ retry_after_seconds: 30 }],
            };
          }
          return { rowCount: 0, rows: [] };
        })
      );

      await assert.rejects(
        () =>
          repo.replaceActiveChallenge(
            {
              userId: 'user-1',
              email: 'patient@example.com',
              otpHash: 'otp-hash',
              purpose: 'ACCOUNT_ACTIVATION',
              expiresAt: new Date(Date.now() + 300_000),
              resendAfter: new Date(Date.now() + 30_000),
            },
            30
          ),
        (error: unknown) =>
          error instanceof AppError &&
          error.errorCode === 'EMAIL_OTP_COOLDOWN_ACTIVE' &&
          error.details?.retryAfterSeconds === 30
      );

      const lockIndex = statements.findIndex((statement) =>
        statement.includes('pg_advisory_xact_lock')
      );
      const cooldownIndex = statements.findIndex((statement) =>
        statement.includes('MAX(resend_after)')
      );
      assert.ok(lockIndex >= 0);
      assert.ok(cooldownIndex > lockIndex);
      assert.match(statements[cooldownIndex], /NOW\(\)/);
      assert.ok(statements.includes('ROLLBACK'));
      assert.equal(
        statements.some((statement) =>
          statement.includes('UPDATE email_otp_challenges')
        ),
        false
      );
      assert.equal(
        statements.some((statement) =>
          statement.includes('INSERT INTO email_otp_challenges')
        ),
        false
      );
    });

    it('uses the database clock to calculate the remaining developer email hourly limit', async () => {
      let limiterQuery = '';
      const repo = new PostgresEmailOtpRepository(
        createMockPool(async (text) => {
          if (text.includes('COUNT(*)::int AS count')) {
            limiterQuery = text;
            return {
              rowCount: 1,
              rows: [{ count: 5, retry_after_seconds: 2050 }],
            };
          }
          return { rowCount: 0, rows: [] };
        })
      );

      await assert.rejects(
        () =>
          repo.replaceActiveChallenge(
            {
              userId: null,
              email: 'developer@example.com',
              otpHash: 'otp-hash',
              purpose: 'DEVELOPER_EMAIL_TEST',
              expiresAt: new Date(Date.now() + 300_000),
              resendAfter: new Date(Date.now() + 30_000),
              ipAddress: '127.0.0.1',
            },
            30,
            {
              maxRequestsPerHourPerEmail: 5,
              maxRequestsPerHourPerIp: 15,
            }
          ),
        (error: unknown) => {
          assert.ok(error instanceof AppError);
          assert.equal(error.errorCode, 'EMAIL_OTP_RATE_LIMITED');
          assert.deepEqual(error.details, {
            scope: 'email',
            retryAfterSeconds: 2050,
          });
          return true;
        }
      );
      assert.match(limiterQuery, /NOW\(\)/);
      assert.match(limiterQuery, /MIN\(created_at\)/);
    });

    it('rolls back a failed replacement, releases the client, and propagates the insert error', async () => {
      const insertError = new Error('replacement insert failed');
      const statements: string[] = [];
      let clientReleased = false;
      let previousChallengeActive = true;
      let invalidationExecuted = false;
      let replacementResult: unknown;
      const mockPool = {
        connect: async () => ({
          query: async (text: string) => {
            statements.push(text.trim());
            if (text.trim().startsWith('BEGIN ')) {
              return { rowCount: 0, rows: [] };
            }
            if (text.includes('pg_advisory_xact_lock')) {
              return { rowCount: 1, rows: [] };
            }
            if (text.includes('UPDATE email_otp_challenges')) {
              invalidationExecuted = true;
              previousChallengeActive = false;
              return { rowCount: 1, rows: [] };
            }
            if (text.includes('INSERT INTO email_otp_challenges')) {
              assert.equal(invalidationExecuted, true);
              throw insertError;
            }
            if (text.trim() === 'ROLLBACK') {
              previousChallengeActive = true;
              return { rowCount: 0, rows: [] };
            }
            assert.fail(`Unexpected PostgreSQL statement: ${text}`);
          },
          release: () => {
            clientReleased = true;
          },
        }),
      } as unknown as Pool;
      const repo = new PostgresEmailOtpRepository(mockPool);

      await assert.rejects(
        async () => {
          replacementResult = await repo.replaceActiveChallenge({
            userId: 'user-1',
            email: 'patient@example.com',
            otpHash: 'otp-hash',
            purpose: 'ACCOUNT_ACTIVATION',
            expiresAt: new Date(Date.now() + 300_000),
            resendAfter: new Date(Date.now() + 30_000),
          });
        },
        (error: unknown) => error === insertError
      );

      assert.equal(statements.includes('ROLLBACK'), true);
      assert.equal(clientReleased, true);
      assert.equal(previousChallengeActive, true);
      assert.equal(replacementResult, undefined);
    });

    it('preserves the insert error when rollback also fails and discards the client', async () => {
      const insertError = new Error('replacement insert failed');
      const rollbackError = new Error('rollback failed');
      let releasedWith: Error | boolean | undefined;
      const mockPool = {
        connect: async () => ({
          query: async (text: string) => {
            if (text.includes('INSERT INTO email_otp_challenges')) {
              throw insertError;
            }
            if (text.trim() === 'ROLLBACK') {
              throw rollbackError;
            }
            return { rowCount: 0, rows: [] };
          },
          release: (error?: Error | boolean) => {
            releasedWith = error;
          },
        }),
      } as unknown as Pool;
      const repo = new PostgresEmailOtpRepository(mockPool);

      await assert.rejects(
        () =>
          repo.replaceActiveChallenge({
            userId: 'user-1',
            email: 'patient@example.com',
            otpHash: 'otp-hash',
            purpose: 'ACCOUNT_ACTIVATION',
            expiresAt: new Date(Date.now() + 300_000),
            resendAfter: new Date(Date.now() + 30_000),
          }),
        (error: unknown) => {
          assert.ok(error instanceof AggregateError);
          assert.equal(error.cause, insertError);
          assert.deepEqual(error.errors, [insertError, rollbackError]);
          return true;
        }
      );

      assert.equal(releasedWith, rollbackError);
    });

    it('filters expired, consumed, exhausted, and incorrectly bound challenges', async () => {
      let activeQuery = '';
      let activeParams: unknown[] | undefined;
      const repo = new PostgresEmailOtpRepository(
        createMockPool(async (text, params) => {
          activeQuery = text;
          activeParams = params;
          return { rowCount: 0, rows: [] };
        })
      );

      const challenge = await repo.findActiveChallenge(
        'challenge-1',
        ' Patient@Example.COM ',
        'EMAIL_CHANGE',
        'user-1'
      );

      assert.equal(challenge, null);
      assert.deepEqual(activeParams, [
        'challenge-1',
        'patient@example.com',
        'EMAIL_CHANGE',
        'user-1',
      ]);
      assert.match(activeQuery, /consumed_at IS NULL/);
      assert.match(activeQuery, /expires_at > NOW\(\)/);
      assert.match(activeQuery, /attempts_count < max_attempts/);
      assert.match(activeQuery, /user_id IS NOT DISTINCT FROM \$4/);
    });

    it('uses a conditional update so a challenge can be consumed only once', async () => {
      let consumed = false;
      let consumeQuery = '';
      const repo = new PostgresEmailOtpRepository(
        createMockPool(async (text) => {
          if (text.includes('UPDATE email_otp_challenges')) {
            consumeQuery = text;
            if (consumed) return { rowCount: 0, rows: [] };
            consumed = true;
            return { rowCount: 1, rows: [{ id: 'challenge-1' }] };
          }
          return { rowCount: 0, rows: [] };
        })
      );

      const results = await Promise.all([
        repo.consume('challenge-1', 'patient@example.com', 'PASSWORD_RESET'),
        repo.consume('challenge-1', 'patient@example.com', 'PASSWORD_RESET'),
      ]);

      assert.deepEqual(results.sort(), [false, true]);
      assert.match(consumeQuery, /consumed_at IS NULL/);
      assert.match(consumeQuery, /expires_at > NOW\(\)/);
      assert.match(consumeQuery, /attempts_count < max_attempts/);
    });
  });

  describe('PostgresPasswordResetGrantRepository', () => {
    it('stores the grant hash and conditionally consumes it once', async () => {
      let consumed = false;
      let createParams: unknown[] | undefined;
      let consumeQuery = '';
      const expiresAt = new Date('2026-02-01T00:10:00Z');
      const createdAt = new Date('2026-02-01T00:00:00Z');
      const repo = new PostgresPasswordResetGrantRepository(
        createMockPool(async (text, params) => {
          if (text.includes('INSERT INTO password_reset_grants')) {
            createParams = params;
            return {
              rowCount: 1,
              rows: [
                {
                  id: 'grant-1',
                  user_id: 'user-1',
                  grant_hash: 'grant-hash',
                  expires_at: expiresAt,
                  consumed_at: null,
                  created_at: createdAt,
                },
              ],
            };
          }
          if (text.includes('UPDATE password_reset_grants')) {
            consumeQuery = text;
            if (consumed) return { rowCount: 0, rows: [] };
            consumed = true;
            return { rowCount: 1, rows: [{ id: 'grant-1' }] };
          }
          if (text.includes('SELECT id, user_id, grant_hash')) {
            return {
              rowCount: 0,
              rows: [],
            };
          }
          return { rowCount: 0, rows: [] };
        })
      );

      const grant = await repo.create({
        userId: 'user-1',
        grantHash: 'grant-hash',
        expiresAt,
      });
      assert.equal(grant.userId, 'user-1');
      assert.equal(grant.grantHash, 'grant-hash');
      assert.equal(createParams?.[1], 'grant-hash');

      const results = await Promise.all([
        repo.consume('grant-hash'),
        repo.consume('grant-hash'),
      ]);
      assert.deepEqual(results.sort(), [false, true]);
      assert.match(consumeQuery, /consumed_at IS NULL/);
      assert.match(consumeQuery, /expires_at > NOW\(\)/);
    });
  });
});
