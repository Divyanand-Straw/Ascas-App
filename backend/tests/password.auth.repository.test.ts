import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { Pool, PoolClient, QueryResult } from 'pg';
import {
  PostgresPasswordLoginRateLimitRepository,
  PostgresPasswordResetGrantRepository,
  PostgresRefreshTokenRepository,
  PostgresUserRepository,
} from '../src/modules/auth/postgres.auth.repository';
import { AppError } from '../src/utils/errors';

function createMockPool(
  queryHandler: (
    text: string,
    params?: unknown[]
  ) => Promise<Partial<QueryResult>>
) {
  const client = {
    query: async (text: string, params?: unknown[]) =>
      (await queryHandler(text, params)) as QueryResult,
    release: () => {},
  } as unknown as PoolClient;
  const pool = {
    query: async (text: string, params?: unknown[]) =>
      (await queryHandler(text, params)) as QueryResult,
    connect: async () => client,
  } as unknown as Pool;
  return { pool, client };
}

describe('Password authentication repositories', () => {
  it('sets initial credentials only for verified eligible patients in a locked transaction', async () => {
    const statements: string[] = [];
    let released = false;
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: 'patient@example.com',
              email_verified_at: new Date(),
              password_hash: null,
            },
          ],
        };
      }
      if (text.includes('SELECT') && text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: false }] };
      }
      if (text.includes('UPDATE users')) {
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      if (text.trim() === 'COMMIT') return { rowCount: 0, rows: [] };
      return { rowCount: 0, rows: [] };
    });
    const client = await pool.connect();
    (client as unknown as { release: () => void }).release = () => {
      released = true;
    };

    const repo = new PostgresUserRepository(pool);
    assert.equal(
      await repo.setInitialPasswordHash('user-1', 'bcrypt-password-hash'),
      'SET'
    );
    assert.match(statements[0], /BEGIN ISOLATION LEVEL READ COMMITTED/);
    assert.ok(statements.some((statement) => /FOR UPDATE/.test(statement)));
    assert.ok(
      statements.some((statement) =>
        /member_role = 'PARTNER'/.test(statement)
      )
    );
    assert.ok(statements.some((statement) => statement.includes('UPDATE users')));
    assert.ok(statements.includes('COMMIT'));
    assert.equal(released, true);
  });

  it('sets normalized registration credentials atomically without verifying email', async () => {
    const statements: string[] = [];
    const parameters: unknown[][] = [];
    const { pool } = createMockPool(async (text, params) => {
      statements.push(text);
      parameters.push(params ?? []);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: null,
              email_verified_at: null,
              password_hash: null,
            },
          ],
        };
      }
      if (text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: false }] };
      }
      if (text.includes('UPDATE users')) {
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      return { rowCount: 0, rows: [] };
    });
    const repo = new PostgresUserRepository(pool);

    assert.equal(
      await repo.setInitialRegistrationCredentials(
        'user-1',
        ' New.Patient@Example.COM ',
        'bcrypt-password-hash'
      ),
      'SET'
    );
    const updateIndex = statements.findIndex((statement) =>
      statement.includes('UPDATE users')
    );
    assert.ok(updateIndex >= 0);
    assert.deepEqual(parameters[updateIndex], [
      'user-1',
      'new.patient@example.com',
      'bcrypt-password-hash',
    ]);
    assert.doesNotMatch(
      statements[updateIndex],
      /SET[\s\S]*email_verified_at\s*=/i
    );
    assert.ok(statements.includes('COMMIT'));
  });

  it('maps a normalized unique email violation to a conflict and rolls back', async () => {
    const statements: string[] = [];
    const duplicateError = Object.assign(new Error('duplicate key'), {
      code: '23505',
    });
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: null,
              email_verified_at: null,
              password_hash: null,
            },
          ],
        };
      }
      if (text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: false }] };
      }
      if (text.includes('UPDATE users')) throw duplicateError;
      return { rowCount: 0, rows: [] };
    });
    const repo = new PostgresUserRepository(pool);

    await assert.rejects(
      () =>
        repo.setInitialRegistrationCredentials(
          'user-1',
          'duplicate@example.com',
          'bcrypt-password-hash'
        ),
      (error: unknown) =>
        error instanceof AppError &&
        error.statusCode === 409 &&
        error.message.includes('email address already exists')
    );
    assert.ok(statements.includes('ROLLBACK'));
    assert.equal(statements.includes('COMMIT'), false);
  });

  it('rejects active partner members without updating their password', async () => {
    const statements: string[] = [];
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'partner-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: 'partner@example.com',
              email_verified_at: new Date(),
              password_hash: null,
            },
          ],
        };
      }
      if (text.includes('SELECT') && text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: true }] };
      }
      return { rowCount: 0, rows: [] };
    });

    const repo = new PostgresUserRepository(pool);
    assert.equal(
      await repo.setInitialPasswordHash('partner-1', 'bcrypt-password-hash'),
      'PARTNER_MEMBER'
    );
    assert.equal(
      statements.some((statement) => statement.includes('UPDATE users')),
      false
    );
    assert.ok(statements.includes('ROLLBACK'));
  });

  it('updates the password, consumes the grant, and revokes sessions in one transaction', async () => {
    const statements: string[] = [];
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM password_reset_grants') && text.includes('FOR UPDATE')) {
        return { rowCount: 1, rows: [{ id: 'grant-1', user_id: 'user-1' }] };
      }
      if (text.includes('FROM password_reset_grants')) {
        return { rowCount: 1, rows: [{ user_id: 'user-1' }] };
      }
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: 'patient@example.com',
              email_verified_at: null,
              password_hash: 'old-hash',
            },
          ],
        };
      }
      if (text.includes('SELECT') && text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: false }] };
      }
      if (text.includes('UPDATE users')) {
        return { rowCount: 1, rows: [{ id: 'user-1' }] };
      }
      if (text.includes('UPDATE password_reset_grants')) {
        return { rowCount: 1, rows: [{ id: 'grant-1' }] };
      }
      return { rowCount: 1, rows: [] };
    });
    const repo = new PostgresPasswordResetGrantRepository(pool);

    assert.equal(
      await repo.completePasswordReset('grant-hash', 'new-password-hash'),
      true
    );
    assert.match(statements[0], /BEGIN ISOLATION LEVEL READ COMMITTED/);
    assert.ok(statements.some((statement) => /FOR UPDATE/.test(statement)));
    assert.ok(statements.some((statement) => statement.includes('UPDATE users')));
    assert.ok(
      statements.some((statement) =>
        statement.includes('UPDATE refresh_tokens')
      )
    );
    assert.ok(
      statements.some((statement) =>
        statement.includes('UPDATE password_reset_grants')
      )
    );
    assert.ok(
      statements.some((statement) =>
        statement.includes("email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'")
      )
    );
    assert.ok(
      statements.findIndex(
        (statement) => statement.includes('FROM users') && statement.includes('FOR UPDATE')
      ) <
        statements.findIndex(
          (statement) =>
            statement.includes('FROM password_reset_grants') &&
            statement.includes('FOR UPDATE')
        )
    );
    assert.ok(statements.includes('COMMIT'));
    assert.equal(statements.includes('ROLLBACK'), false);
  });

  it('rolls back password reset if session revocation fails', async () => {
    const updateError = new Error('session revocation failed');
    const statements: string[] = [];
    let released = false;
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM password_reset_grants') && text.includes('FOR UPDATE')) {
        return { rowCount: 1, rows: [{ id: 'grant-1', user_id: 'user-1' }] };
      }
      if (text.includes('FROM password_reset_grants')) {
        return { rowCount: 1, rows: [{ user_id: 'user-1' }] };
      }
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
              email: 'patient@example.com',
              email_verified_at: null,
              password_hash: 'old-hash',
            },
          ],
        };
      }
      if (text.includes('SELECT EXISTS') && text.includes('care_unit_members')) {
        return { rowCount: 1, rows: [{ is_partner_member: false }] };
      }
      if (text.includes('UPDATE refresh_tokens')) throw updateError;
      return { rowCount: 1, rows: [{ id: 'user-1' }] };
    });
    const client = await pool.connect();
    (client as unknown as { release: () => void }).release = () => {
      released = true;
    };
    const repo = new PostgresPasswordResetGrantRepository(pool);
    let result: boolean | undefined;

    await assert.rejects(
      async () => {
        result = await repo.completePasswordReset(
          'grant-hash',
          'new-password-hash'
        );
      },
      (error: unknown) => error === updateError
    );
    assert.equal(result, undefined);
    assert.ok(statements.some((statement) => statement.includes('UPDATE users')));
    assert.ok(statements.includes('ROLLBACK'));
    assert.equal(statements.includes('COMMIT'), false);
    assert.equal(released, true);
  });

  it('creates password-login sessions under the same account lock used by resets', async () => {
    const statements: string[] = [];
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email: 'patient@example.com',
              email_verified_at: null,
              password_hash: 'verified-password-hash',
              email_password_eligibility: 'NEW_PATIENT_ELIGIBLE',
            },
          ],
        };
      }
      if (text.includes('care_unit_invitations')) {
        return { rowCount: 1, rows: [{ is_partner_account: false }] };
      }
      if (text.includes('INSERT INTO refresh_tokens')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'refresh-1',
              user_id: 'user-1',
              token_hash: 'refresh-hash',
              device_info: 'Test Device',
              ip_address: '192.0.2.1',
              expires_at: expiresAt,
              revoked_at: null,
              created_at: new Date(),
            },
          ],
        };
      }
      return { rowCount: 0, rows: [] };
    });
    const repo = new PostgresRefreshTokenRepository(pool);

    const token = await repo.create({
      userId: 'user-1',
      tokenHash: 'refresh-hash',
      deviceInfo: 'Test Device',
      ipAddress: '192.0.2.1',
      expiresAt,
      expectedPasswordHash: 'verified-password-hash',
    });

    assert.equal(token.id, 'refresh-1');
    assert.ok(
      statements.findIndex(
        (statement) => statement.includes('FROM users') && statement.includes('FOR UPDATE')
      ) <
        statements.findIndex((statement) =>
          statement.includes('INSERT INTO refresh_tokens')
        )
    );
    assert.ok(statements.includes('COMMIT'));
  });

  it('does not create a session when the password changed after verification', async () => {
    const statements: string[] = [];
    const { pool } = createMockPool(async (text) => {
      statements.push(text);
      if (text.includes('FROM users') && text.includes('FOR UPDATE')) {
        return {
          rowCount: 1,
          rows: [
            {
              id: 'user-1',
              role: 'PATIENT',
              status: 'ACTIVE',
              email: 'patient@example.com',
              email_verified_at: new Date(),
              password_hash: 'new-password-hash',
            },
          ],
        };
      }
      return { rowCount: 0, rows: [] };
    });
    const repo = new PostgresRefreshTokenRepository(pool);

    await assert.rejects(
      () =>
        repo.create({
          userId: 'user-1',
          tokenHash: 'refresh-hash',
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
          expectedPasswordHash: 'old-password-hash',
        }),
      (error: unknown) =>
        error instanceof AppError &&
        error.errorCode === 'EMAIL_PASSWORD_INVALID_CREDENTIALS'
    );
    assert.equal(
      statements.some((statement) =>
        statement.includes('INSERT INTO refresh_tokens')
      ),
      false
    );
    assert.ok(statements.includes('ROLLBACK'));
  });

  it('atomically records HMAC buckets for email and IP in one transaction', async () => {
    const statements: string[] = [];
    const counts = new Map<string, number>();
    const { pool } = createMockPool(async (text, params) => {
      statements.push(text);
      if (text.includes('INSERT INTO password_login_rate_limits')) {
        const key = `${String(params?.[0])}:${String(params?.[1])}`;
        const count = (counts.get(key) ?? 0) + 1;
        counts.set(key, count);
        return {
          rowCount: 1,
          rows: [{ attempts_count: count }],
        };
      }
      return { rowCount: 0, rows: [] };
    });
    const repo = new PostgresPasswordLoginRateLimitRepository(pool);

    assert.deepEqual(
      await repo.recordAttempt('a'.repeat(64), 'b'.repeat(64)),
      { emailAttempts: 1, ipAttempts: 1 }
    );
    assert.ok(statements.includes('BEGIN ISOLATION LEVEL READ COMMITTED'));
    assert.ok(
      statements.some((statement) => statement.includes('ON CONFLICT'))
    );
    assert.ok(statements.includes('COMMIT'));
    assert.equal(
      statements.some((statement) => statement.includes('patient@example.com')),
      false
    );
  });
});
