import { Pool, PoolClient } from 'pg';
import { pool as defaultPool } from '../../config/database';
import {
  IUserRepository,
  IPatientProfileRepository,
  IOtpRepository,
  IRefreshTokenRepository,
} from './auth.repository.interface';
import {
  User,
  UserRole,
  UserStatus,
  PatientProfile,
  OtpChallenge,
  OtpPurpose,
  RefreshToken,
  PreferredLanguage,
  LinkingStatus,
} from './auth.types';
import { ConflictError, AppError } from '../../utils/errors';

/**
 * ============================================================================
 * PostgreSQL User Repository
 * Backed by public.users table.
 * ============================================================================
 */
export class PostgresUserRepository implements IUserRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async findByPhone(phone: string): Promise<User | null> {
    const res = await this.pool.query(
      `SELECT id, phone, role, status, created_at, updated_at
       FROM users
       WHERE phone = $1
       LIMIT 1;`,
      [phone]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  async findById(id: string): Promise<User | null> {
    const res = await this.pool.query(
      `SELECT id, phone, role, status, created_at, updated_at
       FROM users
       WHERE id = $1
       LIMIT 1;`,
      [id]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  async create(data: { phone: string; role?: UserRole; status?: UserStatus }): Promise<User> {
    try {
      const res = await this.pool.query(
        `INSERT INTO users (phone, role, status)
         VALUES ($1, $2, $3)
         RETURNING id, phone, role, status, created_at, updated_at;`,
        [data.phone, data.role || 'PATIENT', data.status || 'ACTIVE']
      );

      return this.mapUserRow(res.rows[0]);
    } catch (err: unknown) {
      const pgErr = err as { code?: string; message?: string };
      if (pgErr.code === '23505') {
        throw new ConflictError('User with this mobile number already exists');
      }
      throw err;
    }
  }

  async updateStatus(id: string, status: UserStatus): Promise<User | null> {
    const res = await this.pool.query(
      `UPDATE users
       SET status = $1, updated_at = NOW()
       WHERE id = $2
       RETURNING id, phone, role, status, created_at, updated_at;`,
      [status, id]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  private mapUserRow(row: {
    id: string;
    phone: string;
    role: string;
    status: string;
    created_at: Date;
    updated_at: Date;
  }): User {
    return {
      id: row.id,
      phone: row.phone,
      role: row.role as UserRole,
      status: row.status as UserStatus,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}

/**
 * ============================================================================
 * PostgreSQL Patient Profile Repository
 * Backed by public.patient_profiles table.
 * ============================================================================
 */
export class PostgresPatientProfileRepository implements IPatientProfileRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async findByUserId(userId: string): Promise<PatientProfile | null> {
    const res = await this.pool.query(
      `SELECT id, user_id, first_name, last_name, dob, gender, clinic_mrn, preferred_language, linking_status, created_at, updated_at
       FROM patient_profiles
       WHERE user_id = $1
       LIMIT 1;`,
      [userId]
    );

    if (res.rowCount === 0) return null;
    return this.mapProfileRow(res.rows[0]);
  }

  async create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const res = await this.pool.query(
      `INSERT INTO patient_profiles (user_id, first_name, last_name, dob, preferred_language, linking_status)
       VALUES ($1, $2, $3, $4, $5, 'UNLINKED')
       RETURNING id, user_id, first_name, last_name, dob, gender, clinic_mrn, preferred_language, linking_status, created_at, updated_at;`,
      [
        data.userId,
        data.firstName,
        data.lastName,
        data.dob ?? null,
        data.preferredLanguage || 'en',
      ]
    );

    return this.mapProfileRow(res.rows[0]);
  }

  private mapProfileRow(row: {
    id: string;
    user_id: string;
    first_name: string;
    last_name: string;
    dob: Date | string | null;
    gender: string | null;
    clinic_mrn: string | null;
    preferred_language: string;
    linking_status: string;
    created_at: Date;
    updated_at: Date;
  }): PatientProfile {
    return {
      id: row.id,
      userId: row.user_id,
      firstName: row.first_name,
      lastName: row.last_name,
      dob: row.dob ? new Date(row.dob) : null,
      gender: row.gender,
      clinicMrn: row.clinic_mrn,
      preferredLanguage: row.preferred_language as PreferredLanguage,
      linkingStatus: row.linking_status as LinkingStatus,
      createdAt: new Date(row.created_at),
      updatedAt: new Date(row.updated_at),
    };
  }
}

/**
 * ============================================================================
 * PostgreSQL OTP Repository
 * Backed by public.otp_verifications table.
 * ============================================================================
 */
export class PostgresOtpRepository implements IOtpRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async create(data: {
    phone: string;
    otpHash: string;
    purpose: OtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    ipAddress?: string;
  }): Promise<OtpChallenge> {
    const res = await this.pool.query(
      `INSERT INTO otp_verifications (phone, otp_hash, purpose, attempts_count, max_attempts, expires_at, ip_address, created_at)
       VALUES ($1, $2, $3, 0, $4, $5, $6, NOW())
       RETURNING id, phone, otp_hash, purpose, attempts_count, max_attempts, expires_at, consumed_at, ip_address, created_at;`,
      [
        data.phone,
        data.otpHash,
        data.purpose,
        data.maxAttempts || 3,
        data.expiresAt,
        data.ipAddress ?? null,
      ]
    );

    return this.mapOtpRow(res.rows[0]);
  }

  async findActiveChallenge(id: string, phone: string, purpose: OtpPurpose): Promise<OtpChallenge | null> {
    const res = await this.pool.query(
      `SELECT id, phone, otp_hash, purpose, attempts_count, max_attempts, expires_at, consumed_at, ip_address, created_at
       FROM otp_verifications
       WHERE id = $1 AND phone = $2 AND purpose = $3
       LIMIT 1;`,
      [id, phone, purpose]
    );

    if (res.rowCount === 0) return null;
    return this.mapOtpRow(res.rows[0]);
  }

  async incrementAttempts(id: string): Promise<number> {
    const res = await this.pool.query(
      `UPDATE otp_verifications
       SET attempts_count = attempts_count + 1
       WHERE id = $1
       RETURNING attempts_count;`,
      [id]
    );

    if (res.rowCount === 0) return 0;
    return Number(res.rows[0].attempts_count);
  }

  async consume(id: string): Promise<boolean> {
    const res = await this.pool.query(
      `UPDATE otp_verifications
       SET consumed_at = NOW()
       WHERE id = $1 AND consumed_at IS NULL
       RETURNING id;`,
      [id]
    );

    return (res.rowCount ?? 0) > 0;
  }

  async invalidatePredecessors(phone: string, purpose: OtpPurpose): Promise<void> {
    await this.pool.query(
      `UPDATE otp_verifications
       SET consumed_at = NOW()
       WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL;`,
      [phone, purpose]
    );
  }

  async getRecentRequestCountByPhone(phone: string, since: Date): Promise<number> {
    const res = await this.pool.query(
      `SELECT COUNT(*)::int AS count
       FROM otp_verifications
       WHERE phone = $1 AND created_at >= $2;`,
      [phone, since]
    );

    return Number(res.rows[0]?.count ?? 0);
  }

  async getRecentRequestCountByIp(ipAddress: string, since: Date): Promise<number> {
    const res = await this.pool.query(
      `SELECT COUNT(*)::int AS count
       FROM otp_verifications
       WHERE ip_address = $1 AND created_at >= $2;`,
      [ipAddress, since]
    );

    return Number(res.rows[0]?.count ?? 0);
  }

  async getLastRequestTime(phone: string): Promise<Date | null> {
    const res = await this.pool.query(
      `SELECT MAX(created_at) AS last_time
       FROM otp_verifications
       WHERE phone = $1;`,
      [phone]
    );

    const lastTime = res.rows[0]?.last_time;
    return lastTime ? new Date(lastTime) : null;
  }

  private mapOtpRow(row: {
    id: string;
    phone: string;
    otp_hash: string;
    purpose: string;
    attempts_count: number;
    max_attempts: number;
    expires_at: Date;
    consumed_at: Date | null;
    ip_address: string | null;
    created_at: Date;
  }): OtpChallenge {
    return {
      id: row.id,
      phone: row.phone,
      otpHash: row.otp_hash,
      purpose: row.purpose as OtpPurpose,
      attemptsCount: Number(row.attempts_count),
      maxAttempts: Number(row.max_attempts),
      expiresAt: new Date(row.expires_at),
      consumedAt: row.consumed_at ? new Date(row.consumed_at) : null,
      ipAddress: row.ip_address ?? undefined,
      createdAt: new Date(row.created_at),
    };
  }
}

/**
 * ============================================================================
 * PostgreSQL Refresh Token Repository
 * Backed by public.refresh_tokens table.
 * ============================================================================
 */
export class PostgresRefreshTokenRepository implements IRefreshTokenRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async create(data: {
    userId: string;
    tokenHash: string;
    deviceInfo?: string;
    ipAddress?: string;
    expiresAt: Date;
  }): Promise<RefreshToken> {
    const res = await this.pool.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, device_info, ip_address, expires_at)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, user_id, token_hash, device_info, ip_address, expires_at, revoked_at, created_at;`,
      [
        data.userId,
        data.tokenHash,
        data.deviceInfo ?? null,
        data.ipAddress ?? null,
        data.expiresAt,
      ]
    );

    return this.mapTokenRow(res.rows[0]);
  }

  async findByTokenHash(tokenHash: string): Promise<RefreshToken | null> {
    const res = await this.pool.query(
      `SELECT id, user_id, token_hash, device_info, ip_address, expires_at, revoked_at, created_at
       FROM refresh_tokens
       WHERE token_hash = $1
       LIMIT 1;`,
      [tokenHash]
    );

    if (res.rowCount === 0) return null;
    return this.mapTokenRow(res.rows[0]);
  }

  async revoke(id: string): Promise<void> {
    await this.pool.query(
      `UPDATE refresh_tokens
       SET revoked_at = NOW()
       WHERE id = $1 AND revoked_at IS NULL;`,
      [id]
    );
  }

  async revokeAllForUser(userId: string): Promise<void> {
    await this.pool.query(
      `UPDATE refresh_tokens
       SET revoked_at = NOW()
       WHERE user_id = $1 AND revoked_at IS NULL;`,
      [userId]
    );
  }

  /**
   * Concurrency-safe atomic token rotation executed inside an isolated transaction.
   * Locks the old token row using FOR UPDATE to guard against concurrent replay attacks.
   */
  async rotateToken(
    oldTokenId: string,
    newTokenData: {
      userId: string;
      tokenHash: string;
      deviceInfo?: string;
      ipAddress?: string;
      expiresAt: Date;
    }
  ): Promise<RefreshToken> {
    const client: PoolClient = await this.pool.connect();
    try {
      await client.query('BEGIN;');

      // Lock old token row
      const oldRes = await client.query(
        `SELECT id, user_id, revoked_at
         FROM refresh_tokens
         WHERE id = $1
         FOR UPDATE;`,
        [oldTokenId]
      );

      if (oldRes.rowCount === 0) {
        await client.query('ROLLBACK;');
        throw new AppError('Old refresh token not found', 401, 'INVALID_REFRESH_TOKEN');
      }

      const oldToken = oldRes.rows[0];
      if (oldToken.revoked_at !== null) {
        await client.query('ROLLBACK;');
        throw new AppError(
          'Refresh token has already been rotated or revoked',
          401,
          'REFRESH_TOKEN_REUSE_DETECTED'
        );
      }

      // Insert new token
      const insertRes = await client.query(
        `INSERT INTO refresh_tokens (user_id, token_hash, device_info, ip_address, expires_at)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING id, user_id, token_hash, device_info, ip_address, expires_at, revoked_at, created_at;`,
        [
          newTokenData.userId,
          newTokenData.tokenHash,
          newTokenData.deviceInfo ?? null,
          newTokenData.ipAddress ?? null,
          newTokenData.expiresAt,
        ]
      );

      const newToken = insertRes.rows[0];

      // Mark old token revoked and link to replaced_by_token_id
      await client.query(
        `UPDATE refresh_tokens
         SET revoked_at = NOW(), replaced_by_token_id = $2
         WHERE id = $1;`,
        [oldTokenId, newToken.id]
      );

      await client.query('COMMIT;');
      return this.mapTokenRow(newToken);
    } catch (err) {
      try {
        await client.query('ROLLBACK;');
      } catch {
        // Suppress rollback errors if already aborted
      }
      throw err;
    } finally {
      client.release();
    }
  }

  private mapTokenRow(row: {
    id: string;
    user_id: string;
    token_hash: string;
    device_info: string | null;
    ip_address: string | null;
    expires_at: Date;
    revoked_at: Date | null;
    created_at: Date;
  }): RefreshToken {
    return {
      id: row.id,
      userId: row.user_id,
      tokenHash: row.token_hash,
      deviceInfo: row.device_info ?? undefined,
      ipAddress: row.ip_address ?? undefined,
      expiresAt: new Date(row.expires_at),
      revokedAt: row.revoked_at ? new Date(row.revoked_at) : null,
      createdAt: new Date(row.created_at),
    };
  }
}
