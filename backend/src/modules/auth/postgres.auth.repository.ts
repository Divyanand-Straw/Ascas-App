import { Pool, PoolClient } from 'pg';
import { pool as defaultPool } from '../../config/database';
import {
  IUserRepository,
  IPatientProfileRepository,
  IOtpRepository,
  IEmailOtpRepository,
  IPasswordResetGrantRepository,
  IPasswordLoginRateLimitRepository,
  IRefreshTokenRepository,
  OtpChallengeIssueResult,
  PasswordSetupResult,
  RegistrationCredentialsSetupResult,
} from './auth.repository.interface';
import {
  User,
  UserCredentials,
  UserRole,
  UserStatus,
  EmailPasswordEligibility,
  PatientProfile,
  OtpChallenge,
  OtpPurpose,
  EmailOtpChallenge,
  EmailOtpPurpose,
  PasswordResetGrant,
  RefreshToken,
  PreferredLanguage,
  LinkingStatus,
  normalizeEmailAddress,
} from './auth.types';
import {
  ConflictError,
  AppError,
  ValidationError,
} from '../../utils/errors';

const requireNormalizedEmail = (email: string): string => {
  const normalizedEmail = normalizeEmailAddress(email);
  if (!normalizedEmail) {
    throw new ValidationError('Email address is required.');
  }
  return normalizedEmail;
};

const EMAIL_TRIM_CHARS_SQL = String.raw`E' \t\n\r\f' || CHR(11) || U&'\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'`;

const PARTNER_ACCOUNT_EXISTS_SQL = `SELECT
  EXISTS (
    SELECT 1
    FROM care_unit_members
    WHERE user_id = $1
      AND member_role = 'PARTNER'
      AND member_status = 'ACTIVE'
  ) OR EXISTS (
    SELECT 1
    FROM care_unit_invitations invitation
    JOIN users invited_user ON invited_user.phone = invitation.invitee_phone
    WHERE invited_user.id = $1
      AND invitation.status = 'PENDING'
      AND invitation.expires_at > NOW()
  ) AS is_partner_account;`;

const validateEmailOtpCreateData = (
  data: Parameters<IEmailOtpRepository['create']>[0]
): string => {
  const email = requireNormalizedEmail(data.email);
  if (
    data.purpose !== 'PASSWORD_RESET' &&
    data.purpose !== 'DEVELOPER_EMAIL_TEST' &&
    !data.userId
  ) {
    throw new ValidationError('A user is required for this email challenge.');
  }
  if (data.maxAttempts !== undefined && data.maxAttempts < 1) {
    throw new ValidationError('Maximum attempts must be greater than zero.');
  }
  return email;
};

/**
 * ============================================================================
 * PostgreSQL User Repository
 * Backed by public.users table.
 * ============================================================================
 */
export class PostgresUserRepository implements IUserRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async markPhoneVerified(id: string): Promise<void> {
    const res = await this.pool.query(
      `UPDATE users
       SET phone_verified_at = COALESCE(phone_verified_at, NOW())
       WHERE id = $1;`,
      [id]
    );
    if (res.rowCount !== 1) {
      throw new Error('Phone verification could not be recorded for the user.');
    }
  }

  async findByPhone(phone: string): Promise<User | null> {
    const res = await this.pool.query(
      `SELECT id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at
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
      `SELECT id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at
       FROM users
       WHERE id = $1
       LIMIT 1;`,
      [id]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  async findByIdWithPasswordHash(
    id: string
  ): Promise<UserCredentials | null> {
    const res = await this.pool.query(
      `SELECT id, phone, email, email_verified_at, password_hash, role, status, email_password_eligibility, created_at, updated_at
       FROM users
       WHERE id = $1
       LIMIT 1;`,
      [id]
    );

    if (res.rowCount === 0) return null;
    return {
      user: this.mapUserRow(res.rows[0]),
      passwordHash: res.rows[0].password_hash ?? null,
    };
  }

  async findByEmail(email: string): Promise<User | null> {
    const normalizedEmail = requireNormalizedEmail(email);
    const res = await this.pool.query(
      `SELECT id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at
       FROM users
       WHERE LOWER(BTRIM(email, ${EMAIL_TRIM_CHARS_SQL})) = $1
       LIMIT 1;`,
      [normalizedEmail]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  async findByEmailWithPasswordHash(
    email: string
  ): Promise<UserCredentials | null> {
    const normalizedEmail = requireNormalizedEmail(email);
    const res = await this.pool.query(
      `SELECT id, phone, email, email_verified_at, password_hash, role, status, email_password_eligibility, created_at, updated_at
       FROM users
       WHERE LOWER(BTRIM(email, ${EMAIL_TRIM_CHARS_SQL})) = $1
       LIMIT 1;`,
      [normalizedEmail]
    );

    if (res.rowCount === 0) return null;
    return {
      user: this.mapUserRow(res.rows[0]),
      passwordHash: res.rows[0].password_hash ?? null,
    };
  }

  async create(data: {
    phone: string;
    role?: UserRole;
    status?: UserStatus;
    emailPasswordEligibility?: 'NEW_PATIENT_ELIGIBLE' | 'PARTNER_INELIGIBLE';
  }): Promise<User> {
    try {
      const res = await this.pool.query(
        `INSERT INTO users (phone, role, status, email_password_eligibility)
         VALUES ($1, $2, $3, COALESCE($4, 'IDENTITY_REQUIRED'))
         RETURNING id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at;`,
        [
          data.phone,
          data.role || 'PATIENT',
          data.status || 'ACTIVE',
          data.emailPasswordEligibility ?? null,
        ]
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

  async updateEmail(
    id: string,
    email: string | null,
    emailVerifiedAt: Date | null,
    expectedEmail: string | null
  ): Promise<User | null> {
    const normalizedEmail =
      email === null ? null : requireNormalizedEmail(email);
    const normalizedExpectedEmail =
      expectedEmail === null
        ? null
        : requireNormalizedEmail(expectedEmail);

    if (normalizedEmail === null && emailVerifiedAt !== null) {
      throw new ValidationError('An email address is required for verification.');
    }

    try {
      const res = await this.pool.query(
        `UPDATE users
         SET email = $2,
             email_verified_at = $3,
             password_hash = CASE WHEN $3::timestamptz IS NULL THEN NULL ELSE password_hash END,
             updated_at = NOW()
         WHERE id = $1
           AND email IS NOT DISTINCT FROM $4
         RETURNING id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at;`,
        [id, normalizedEmail, emailVerifiedAt, normalizedExpectedEmail]
      );

      if (res.rowCount === 0) return null;
      return this.mapUserRow(res.rows[0]);
    } catch (err: unknown) {
      const pgErr = err as { code?: string; constraint?: string };
      if (
        pgErr.code === '23505' &&
        pgErr.constraint === 'idx_users_email_unique'
      ) {
        throw new ConflictError('An account with this email address already exists.');
      }
      throw err;
    }
  }

  async attachInitialVerifiedEmail(
    id: string,
    email: string,
    emailVerifiedAt: Date
  ): Promise<User | null> {
    const normalizedEmail = requireNormalizedEmail(email);
    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      const userRes = await client.query(
        `SELECT id, phone, email, email_verified_at, password_hash, role, status,
                email_password_eligibility, created_at, updated_at
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [id]
      );
      const user = userRes.rows[0];
      if (
        !user ||
        user.email !== null ||
        user.password_hash !== null ||
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        user.email_password_eligibility !== 'NEW_PATIENT_ELIGIBLE'
      ) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return null;
      }

      const partnerRes = await client.query(PARTNER_ACCOUNT_EXISTS_SQL, [id]);
      if (partnerRes.rows[0]?.is_partner_account === true) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return null;
      }

      const updateRes = await client.query(
        `UPDATE users
         SET email = $2, email_verified_at = $3, updated_at = NOW()
         WHERE id = $1
           AND email IS NULL
           AND email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'
           AND password_hash IS NULL
         RETURNING id, phone, email, email_verified_at, role, status,
                   email_password_eligibility, created_at, updated_at;`,
        [id, normalizedEmail, emailVerifiedAt]
      );
      if ((updateRes.rowCount ?? 0) === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return null;
      }

      await client.query('COMMIT');
      transactionStarted = false;
      return this.mapUserRow(updateRes.rows[0]);
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Initial email activation and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      const pgErr = error as { code?: string; constraint?: string };
      if (
        pgErr.code === '23505' &&
        pgErr.constraint === 'idx_users_email_unique'
      ) {
        throw new ConflictError('An account with this email address already exists.');
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  async markLinkedMemberIneligible(id: string): Promise<void> {
    const result = await this.pool.query(
      `UPDATE users
       SET email_password_eligibility = 'PARTNER_INELIGIBLE',
           updated_at = NOW()
       WHERE id = $1;`,
      [id]
    );
    if ((result.rowCount ?? 0) === 0) {
      throw new AppError('Unable to mark the linked-member account ineligible.', 404);
    }
  }

  async setPasswordHash(id: string, passwordHash: string): Promise<boolean> {
    return (
      (await this.setInitialPasswordHash(id, passwordHash)) === 'SET'
    );
  }

  async setInitialPasswordHash(
    id: string,
    passwordHash: string
  ): Promise<PasswordSetupResult> {
    if (!passwordHash) {
      throw new ValidationError('Password hash is required.');
    }

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      const userRes = await client.query(
        `SELECT id, email, email_verified_at, password_hash, role, status,
                email_password_eligibility
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [id]
      );

      if (userRes.rowCount === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'USER_NOT_FOUND';
      }

      const user = userRes.rows[0];
      let result:
        | 'EMAIL_UNVERIFIED'
        | 'ACCOUNT_INELIGIBLE'
        | 'PASSWORD_ALREADY_SET'
        | null = null;
      if (
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        user.email_password_eligibility !== 'NEW_PATIENT_ELIGIBLE'
      ) {
        result = 'ACCOUNT_INELIGIBLE';
      } else if (!user.email || !user.email_verified_at) {
        result = 'EMAIL_UNVERIFIED';
      } else if (user.password_hash) {
        result = 'PASSWORD_ALREADY_SET';
      }

      if (result) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return result;
      }

      const partnerRes = await client.query(PARTNER_ACCOUNT_EXISTS_SQL, [id]);
      if (partnerRes.rows[0]?.is_partner_account === true) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'PARTNER_MEMBER';
      }

      const updateRes = await client.query(
        `UPDATE users
         SET password_hash = $2, updated_at = NOW()
         WHERE id = $1
           AND role = 'PATIENT'
           AND status = 'ACTIVE'
           AND email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'
           AND email IS NOT NULL
           AND email_verified_at IS NOT NULL
           AND password_hash IS NULL
         RETURNING id;`,
        [id, passwordHash]
      );
      if ((updateRes.rowCount ?? 0) === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'PASSWORD_ALREADY_SET';
      }

      await client.query('COMMIT');
      transactionStarted = false;
      return 'SET';
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Initial password setup and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  async setInitialRegistrationCredentials(
    id: string,
    email: string,
    passwordHash: string
  ): Promise<RegistrationCredentialsSetupResult> {
    if (!passwordHash) {
      throw new ValidationError('Password hash is required.');
    }
    const normalizedEmail = requireNormalizedEmail(email);
    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      const userRes = await client.query(
        `SELECT id, email, email_verified_at, password_hash, role, status,
                email_password_eligibility
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [id]
      );
      if (userRes.rowCount === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'USER_NOT_FOUND';
      }

      const user = userRes.rows[0];
      if (
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        user.email_password_eligibility !== 'NEW_PATIENT_ELIGIBLE'
      ) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'ACCOUNT_INELIGIBLE';
      }
      if (user.email || user.email_verified_at || user.password_hash) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'CREDENTIALS_ALREADY_CONFIGURED';
      }

      const partnerRes = await client.query(PARTNER_ACCOUNT_EXISTS_SQL, [id]);
      if (partnerRes.rows[0]?.is_partner_account === true) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'PARTNER_MEMBER';
      }

      const updateRes = await client.query(
        `UPDATE users
         SET email = $2,
             password_hash = $3,
             updated_at = NOW()
         WHERE id = $1
           AND role = 'PATIENT'
           AND status = 'ACTIVE'
           AND email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'
           AND email IS NULL
           AND email_verified_at IS NULL
           AND password_hash IS NULL
         RETURNING id;`,
        [id, normalizedEmail, passwordHash]
      );
      if ((updateRes.rowCount ?? 0) === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return 'CREDENTIALS_ALREADY_CONFIGURED';
      }

      await client.query('COMMIT');
      transactionStarted = false;
      return 'SET';
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Registration credentials and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      const pgErr = error as { code?: string };
      if (pgErr.code === '23505') {
        throw new ConflictError(
          'An account with this email address already exists.'
        );
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  async isPartnerAccount(id: string): Promise<boolean> {
    const res = await this.pool.query(PARTNER_ACCOUNT_EXISTS_SQL, [id]);
    return res.rows[0]?.is_partner_account === true;
  }

  async updateStatus(id: string, status: UserStatus): Promise<User | null> {
    const res = await this.pool.query(
      `UPDATE users
       SET status = $1, updated_at = NOW()
       WHERE id = $2
       RETURNING id, phone, email, email_verified_at, role, status, email_password_eligibility, created_at, updated_at;`,
      [status, id]
    );

    if (res.rowCount === 0) return null;
    return this.mapUserRow(res.rows[0]);
  }

  private mapUserRow(row: {
    id: string;
    phone: string;
    email?: string | null;
    email_verified_at?: Date | string | null;
    role: string;
    status: string;
    email_password_eligibility?: string | null;
    created_at: Date;
    updated_at: Date;
  }): User {
    return {
      id: row.id,
      phone: row.phone,
      email: row.email ?? null,
      emailVerifiedAt: row.email_verified_at
        ? new Date(row.email_verified_at)
        : null,
      role: row.role as UserRole,
      status: row.status as UserStatus,
      emailPasswordEligibility:
        (row.email_password_eligibility as EmailPasswordEligibility | null) ??
        'IDENTITY_REQUIRED',
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
      `SELECT id, user_id, first_name, last_name, dob::text AS dob, gender, emergency_contact, clinic_mrn, preferred_language, linking_status, created_at, updated_at
       FROM patient_profiles
       WHERE user_id = $1
       LIMIT 1;`,
      [userId]
    );

    if (res.rowCount === 0) return null;
    return this.mapProfileRow(res.rows[0]);
  }

  async update(userId: string, data: {
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const res = await this.pool.query(
      `UPDATE patient_profiles
       SET first_name = $2,
           last_name = $3,
           dob = COALESCE($4, dob),
           gender = COALESCE($5, gender),
           emergency_contact = COALESCE($6, emergency_contact),
           preferred_language = COALESCE($7, preferred_language),
           updated_at = NOW()
       WHERE user_id = $1
       RETURNING id, user_id, first_name, last_name, dob::text AS dob, gender, emergency_contact, clinic_mrn, preferred_language, linking_status, created_at, updated_at;`,
      [
        userId,
        data.firstName,
        data.lastName,
        data.dob ?? null,
        data.gender ?? null,
        data.emergencyContact ?? null,
        data.preferredLanguage ?? null,
      ]
    );
    if (res.rowCount === 0) {
      throw new Error('Patient profile could not be found.');
    }
    return this.mapProfileRow(res.rows[0]);
  }

  async create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const res = await this.pool.query(
      `INSERT INTO patient_profiles (user_id, first_name, last_name, dob, gender, emergency_contact, preferred_language, linking_status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'UNLINKED')
       RETURNING id, user_id, first_name, last_name, dob::text AS dob, gender, emergency_contact, clinic_mrn, preferred_language, linking_status, created_at, updated_at;`,
      [
        data.userId,
        data.firstName,
        data.lastName,
        data.dob ?? null,
        data.gender ?? null,
        data.emergencyContact ?? null,
        data.preferredLanguage || 'en',
      ]
    );

    return this.mapProfileRow(res.rows[0]);
  }

  async createOrGet(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const res = await this.pool.query(
      `INSERT INTO patient_profiles
         (user_id, first_name, last_name, dob, gender, emergency_contact, preferred_language, linking_status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'UNLINKED')
       ON CONFLICT (user_id) DO NOTHING
       RETURNING id, user_id, first_name, last_name, dob::text AS dob, gender, clinic_mrn,
                 emergency_contact, preferred_language, linking_status, created_at, updated_at;`,
      [
        data.userId,
        data.firstName,
        data.lastName,
        data.dob ?? null,
        data.gender ?? null,
        data.emergencyContact ?? null,
        data.preferredLanguage || 'en',
      ]
    );

    if (res.rowCount) return this.mapProfileRow(res.rows[0]);
    const existing = await this.findByUserId(data.userId);
    if (!existing) {
      throw new Error('Patient profile could not be created or retrieved.');
    }
    return existing;
  }

  private mapProfileRow(row: {
    id: string;
    user_id: string;
    first_name: string;
    last_name: string;
    dob: string | null;
    gender: string | null;
    emergency_contact: string | null;
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
      dob: row.dob ? new Date(`${row.dob}T00:00:00.000Z`) : null,
      gender: row.gender,
      emergencyContact: row.emergency_contact ?? null,
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

  async findLatestActiveChallenge(
    phone: string,
    purpose: OtpPurpose
  ): Promise<OtpChallenge | null> {
    const res = await this.pool.query(
      `SELECT id, phone, otp_hash, purpose, attempts_count, max_attempts, expires_at, consumed_at, ip_address, created_at
       FROM otp_verifications
       WHERE phone = $1
         AND purpose = $2
         AND consumed_at IS NULL
         AND expires_at > NOW()
         AND attempts_count < max_attempts
       ORDER BY created_at DESC, id DESC
       LIMIT 1;`,
      [phone, purpose]
    );

    if (res.rowCount === 0) return null;
    return this.mapOtpRow(res.rows[0]);
  }

  async createOrReuseForCooldown(
    data: {
      phone: string;
      purpose: OtpPurpose;
      maxAttempts?: number;
      ipAddress?: string;
    },
    rateLimits: {
      resendCooldownSeconds: number;
      maxRequestsPerHourPerPhone: number;
      maxRequestsPerHourPerIp: number;
    },
    createChallenge: () => { otpHash: string; expiresAt: Date }
  ): Promise<OtpChallengeIssueResult> {
    const {
      resendCooldownSeconds,
      maxRequestsPerHourPerPhone,
      maxRequestsPerHourPerIp,
    } = rateLimits;
    if (
      !Number.isInteger(resendCooldownSeconds) ||
      resendCooldownSeconds < 1 ||
      !Number.isInteger(maxRequestsPerHourPerPhone) ||
      maxRequestsPerHourPerPhone < 1 ||
      !Number.isInteger(maxRequestsPerHourPerIp) ||
      maxRequestsPerHourPerIp < 1
    ) {
      throw new ValidationError(
        'OTP rate limits and cooldowns must be positive integers.'
      );
    }

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;
    try {
      await client.query('BEGIN;');
      transactionStarted = true;
      await client.query('SET TRANSACTION ISOLATION LEVEL READ COMMITTED;');
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtext($1), 1);',
        [data.phone]
      );
      if (data.ipAddress) {
        await client.query(
          'SELECT pg_advisory_xact_lock(hashtext($1), 2);',
          [data.ipAddress]
        );
      }
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2));',
        [data.phone, data.purpose]
      );

      if (data.ipAddress) {
        const ipCountResult = await client.query<{ count: number }>(
          `SELECT COUNT(*)::int AS count
           FROM otp_verifications
           WHERE ip_address = $1 AND created_at >= NOW() - INTERVAL '1 hour';`,
          [data.ipAddress]
        );
        if (Number(ipCountResult.rows[0]?.count ?? 0) >= maxRequestsPerHourPerIp) {
          await client.query('COMMIT;');
          transactionStarted = false;
          return {
            challenge: null,
            created: false,
            retryAfterSeconds: 0,
            rateLimit: 'ip',
          };
        }
      }

      const phoneCountResult = await client.query<{ count: number }>(
        `SELECT COUNT(*)::int AS count
         FROM otp_verifications
         WHERE phone = $1 AND created_at >= NOW() - INTERVAL '1 hour';`,
        [data.phone]
      );
      if (Number(phoneCountResult.rows[0]?.count ?? 0) >= maxRequestsPerHourPerPhone) {
        await client.query('COMMIT;');
        transactionStarted = false;
        return {
          challenge: null,
          created: false,
          retryAfterSeconds: 0,
          rateLimit: 'phone',
        };
      }

      const latestResult = await client.query<{
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
        retry_after_seconds: number;
      }>(
        `SELECT id, phone, otp_hash, purpose, attempts_count, max_attempts,
                expires_at, consumed_at, ip_address, created_at,
                GREATEST(
                  0,
                  CEIL(EXTRACT(EPOCH FROM (
                    created_at + ($3::int * INTERVAL '1 second') - NOW()
                  )))
                )::int AS retry_after_seconds
         FROM otp_verifications
         WHERE phone = $1 AND purpose = $2
         ORDER BY created_at DESC, id DESC
         LIMIT 1
         FOR UPDATE;`,
        [data.phone, data.purpose, resendCooldownSeconds]
      );
      const latest = latestResult.rows[0];
      if (latest && latest.retry_after_seconds > 0) {
        const isResumable =
          latest.consumed_at === null &&
          latest.expires_at.getTime() > Date.now() &&
          Number(latest.attempts_count) < Number(latest.max_attempts);
        const challenge = isResumable ? this.mapOtpRow(latest) : null;
        await client.query('COMMIT;');
        transactionStarted = false;
        return {
          challenge,
          created: false,
          retryAfterSeconds: latest.retry_after_seconds,
        };
      }

      await client.query(
        `UPDATE otp_verifications
         SET consumed_at = NOW()
         WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL;`,
        [data.phone, data.purpose]
      );
      const challengeData = createChallenge();
      const inserted = await client.query(
        `INSERT INTO otp_verifications (phone, otp_hash, purpose, attempts_count, max_attempts, expires_at, ip_address, created_at)
         VALUES ($1, $2, $3, 0, $4, $5, $6, NOW())
         RETURNING id, phone, otp_hash, purpose, attempts_count, max_attempts,
                   expires_at, consumed_at, ip_address, created_at;`,
        [
          data.phone,
          challengeData.otpHash,
          data.purpose,
          data.maxAttempts || 3,
          challengeData.expiresAt,
          data.ipAddress ?? null,
        ]
      );
      await client.query('COMMIT;');
      transactionStarted = false;
      return {
        challenge: this.mapOtpRow(inserted.rows[0]),
        created: true,
        retryAfterSeconds: resendCooldownSeconds,
      };
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK;');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'OTP challenge issuance failed and its transaction could not be rolled back.'
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
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
 * PostgreSQL email OTP repository.
 * Challenge mutation predicates make expiry, attempt limits, and consumption atomic.
 */
export class PostgresEmailOtpRepository implements IEmailOtpRepository {
  constructor(private readonly pool: Pool = defaultPool) {}

  async create(data: {
    userId?: string | null;
    email: string;
    otpHash: string;
    purpose: EmailOtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    resendAfter: Date;
    ipAddress?: string;
  }): Promise<EmailOtpChallenge> {
    const email = validateEmailOtpCreateData(data);

    const res = await this.pool.query(
      `INSERT INTO email_otp_challenges
         (user_id, email, otp_hash, purpose, attempts_count, max_attempts, expires_at, resend_after, ip_address)
       VALUES ($1, $2, $3, $4, 0, $5, $6, $7, $8)
       RETURNING id, user_id, email, otp_hash, purpose, attempts_count, max_attempts,
                 expires_at, resend_after, consumed_at, ip_address, created_at;`,
      [
        data.userId ?? null,
        email,
        data.otpHash,
        data.purpose,
        data.maxAttempts ?? 3,
        data.expiresAt,
        data.resendAfter,
        data.ipAddress ?? null,
      ]
    );

    return this.mapChallengeRow(res.rows[0]);
  }

  async replaceActiveChallenge(
    data: Parameters<IEmailOtpRepository['create']>[0],
    resendCooldownSeconds?: number,
    rateLimits?: {
      maxRequestsPerHourPerEmail: number;
      maxRequestsPerHourPerIp: number;
    }
  ): Promise<EmailOtpChallenge> {
    const email = validateEmailOtpCreateData(data);
    if (
      resendCooldownSeconds !== undefined &&
      (!Number.isInteger(resendCooldownSeconds) || resendCooldownSeconds < 1)
    ) {
      throw new ValidationError('Resend cooldown must be greater than zero.');
    }

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      await client.query(
        'SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2));',
        [email, data.purpose]
      );
      if (rateLimits) {
        if (
          !Number.isInteger(rateLimits.maxRequestsPerHourPerEmail) ||
          rateLimits.maxRequestsPerHourPerEmail < 1 ||
          !Number.isInteger(rateLimits.maxRequestsPerHourPerIp) ||
          rateLimits.maxRequestsPerHourPerIp < 1
        ) {
          throw new ValidationError(
            'Email OTP rate limits must be positive integers.'
          );
        }

        const emailCountRes = await client.query(
          `SELECT COUNT(*)::int AS count,
                  GREATEST(
                    1,
                    3600 - FLOOR(EXTRACT(EPOCH FROM (NOW() - MIN(created_at))))
                  )::int AS retry_after_seconds
           FROM email_otp_challenges
           WHERE email = $1
             AND purpose = $2
             AND created_at >= NOW() - INTERVAL '1 hour';`,
          [email, data.purpose]
        );
        const emailCount = Number(emailCountRes.rows[0]?.count ?? 0);
        if (emailCount >= rateLimits.maxRequestsPerHourPerEmail) {
          const retryAfterSeconds = Number(
            emailCountRes.rows[0]?.retry_after_seconds ?? 3600
          );
          throw new AppError(
            'Too many email test codes were requested. Try again later.',
            429,
            'EMAIL_OTP_RATE_LIMITED',
            { scope: 'email', retryAfterSeconds }
          );
        }

        if (data.ipAddress) {
          await client.query(
            'SELECT pg_advisory_xact_lock(hashtext($1), hashtext($2));',
            ['email-otp-rate-limit-ip', data.ipAddress]
          );
          const ipCountRes = await client.query(
            `SELECT COUNT(*)::int AS count,
                      GREATEST(
                        1,
                        3600 - FLOOR(EXTRACT(EPOCH FROM (NOW() - MIN(created_at))))
                      )::int AS retry_after_seconds
             FROM email_otp_challenges
             WHERE ip_address = $1
               AND purpose = $2
               AND created_at >= NOW() - INTERVAL '1 hour';`,
            [data.ipAddress, data.purpose]
          );
          const ipCount = Number(ipCountRes.rows[0]?.count ?? 0);
          if (ipCount >= rateLimits.maxRequestsPerHourPerIp) {
            const retryAfterSeconds = Number(
              ipCountRes.rows[0]?.retry_after_seconds ?? 3600
            );
            throw new AppError(
              'Too many email test codes were requested. Try again later.',
              429,
              'EMAIL_OTP_RATE_LIMITED',
              { scope: 'ip', retryAfterSeconds }
            );
          }
        }
      }

      if (resendCooldownSeconds !== undefined) {
        const cooldownRes = await client.query(
          `SELECT CEIL(
                    EXTRACT(EPOCH FROM (MAX(resend_after) - NOW()))
                  )::int AS retry_after_seconds
           FROM email_otp_challenges
           WHERE email = $1
             AND purpose = $2;`,
          [email, data.purpose]
        );
        const retryAfterSeconds = Number(
          cooldownRes.rows[0]?.retry_after_seconds ?? 0
        );
        if (retryAfterSeconds > 0) {
          throw new AppError(
            'Please wait before requesting another verification code.',
            429,
            'EMAIL_OTP_COOLDOWN_ACTIVE',
            { retryAfterSeconds }
          );
        }
      }

      await client.query(
        `UPDATE email_otp_challenges
         SET consumed_at = NOW()
         WHERE email = $1
           AND purpose = $2
           AND consumed_at IS NULL;`,
        [email, data.purpose]
      );

      const res = await client.query(
        `INSERT INTO email_otp_challenges
           (user_id, email, otp_hash, purpose, attempts_count, max_attempts, expires_at, resend_after, ip_address)
         VALUES ($1, $2, $3, $4, 0, $5, $6, $7, $8)
         RETURNING id, user_id, email, otp_hash, purpose, attempts_count, max_attempts,
                   expires_at, resend_after, consumed_at, ip_address, created_at;`,
        [
          data.userId ?? null,
          email,
          data.otpHash,
          data.purpose,
          data.maxAttempts ?? 3,
          data.expiresAt,
          data.resendAfter,
          data.ipAddress ?? null,
        ]
      );

      await client.query('COMMIT');
      transactionStarted = false;
      return this.mapChallengeRow(res.rows[0]);
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Email challenge replacement and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  async findActiveChallenge(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<EmailOtpChallenge | null> {
    const res = await this.pool.query(
      `SELECT id, user_id, email, otp_hash, purpose, attempts_count, max_attempts,
              expires_at, resend_after, consumed_at, ip_address, created_at
       FROM email_otp_challenges
       WHERE id = $1
         AND email = $2
         AND purpose = $3
         AND user_id IS NOT DISTINCT FROM $4
         AND consumed_at IS NULL
         AND expires_at > NOW()
         AND attempts_count < max_attempts
       LIMIT 1;`,
      [id, requireNormalizedEmail(email), purpose, userId ?? null]
    );

    if (res.rowCount === 0) return null;
    return this.mapChallengeRow(res.rows[0]);
  }

  async incrementAttempts(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<number> {
    const res = await this.pool.query(
      `UPDATE email_otp_challenges
       SET attempts_count = attempts_count + 1
       WHERE id = $1
         AND email = $2
         AND purpose = $3
         AND user_id IS NOT DISTINCT FROM $4
         AND consumed_at IS NULL
         AND expires_at > NOW()
         AND attempts_count < max_attempts
       RETURNING attempts_count;`,
      [id, requireNormalizedEmail(email), purpose, userId ?? null]
    );

    return Number(res.rows[0]?.attempts_count ?? 0);
  }

  async consume(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<boolean> {
    const res = await this.pool.query(
      `UPDATE email_otp_challenges
       SET consumed_at = NOW()
       WHERE id = $1
         AND email = $2
         AND purpose = $3
         AND user_id IS NOT DISTINCT FROM $4
         AND consumed_at IS NULL
         AND expires_at > NOW()
         AND attempts_count < max_attempts
       RETURNING id;`,
      [id, requireNormalizedEmail(email), purpose, userId ?? null]
    );

    return (res.rowCount ?? 0) > 0;
  }

  async getLastResendAfter(
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<Date | null> {
    const res = await this.pool.query(
      `SELECT MAX(resend_after) AS last_resend_after
       FROM email_otp_challenges
       WHERE email = $1
         AND purpose = $2
         AND user_id IS NOT DISTINCT FROM $3;`,
      [requireNormalizedEmail(email), purpose, userId ?? null]
    );

    const lastResendAfter = res.rows[0]?.last_resend_after;
    return lastResendAfter ? new Date(lastResendAfter) : null;
  }

  private mapChallengeRow(row: {
    id: string;
    user_id: string | null;
    email: string;
    otp_hash: string;
    purpose: string;
    attempts_count: number;
    max_attempts: number;
    expires_at: Date | string;
    resend_after: Date | string;
    consumed_at: Date | string | null;
    ip_address: string | null;
    created_at: Date | string;
  }): EmailOtpChallenge {
    return {
      id: row.id,
      userId: row.user_id,
      email: row.email,
      otpHash: row.otp_hash,
      purpose: row.purpose as EmailOtpPurpose,
      attemptsCount: Number(row.attempts_count),
      maxAttempts: Number(row.max_attempts),
      expiresAt: new Date(row.expires_at),
      resendAfter: new Date(row.resend_after),
      consumedAt: row.consumed_at ? new Date(row.consumed_at) : null,
      ipAddress: row.ip_address ?? undefined,
      createdAt: new Date(row.created_at),
    };
  }
}

/**
 * PostgreSQL repository for hashed, single-use password reset grants.
 */
export class PostgresPasswordResetGrantRepository
  implements IPasswordResetGrantRepository
{
  constructor(private readonly pool: Pool = defaultPool) {}

  async create(data: {
    userId: string;
    grantHash: string;
    expiresAt: Date;
  }): Promise<PasswordResetGrant> {
    if (!data.grantHash) {
      throw new ValidationError('Password reset grant hash is required.');
    }

    try {
      const res = await this.pool.query(
        `INSERT INTO password_reset_grants (user_id, grant_hash, expires_at)
         VALUES ($1, $2, $3)
         RETURNING id, user_id, grant_hash, expires_at, consumed_at, created_at;`,
        [data.userId, data.grantHash, data.expiresAt]
      );
      return this.mapGrantRow(res.rows[0]);
    } catch (err: unknown) {
      const pgErr = err as { code?: string; constraint?: string };
      if (
        pgErr.code === '23505' &&
        pgErr.constraint === 'password_reset_grants_grant_hash_key'
      ) {
        throw new ConflictError('Password reset grant already exists.');
      }
      throw err;
    }
  }

  async findActiveByHash(grantHash: string): Promise<PasswordResetGrant | null> {
    const res = await this.pool.query(
      `SELECT id, user_id, grant_hash, expires_at, consumed_at, created_at
       FROM password_reset_grants
       WHERE grant_hash = $1
         AND consumed_at IS NULL
         AND expires_at > NOW()
       LIMIT 1;`,
      [grantHash]
    );

    if (res.rowCount === 0) return null;
    return this.mapGrantRow(res.rows[0]);
  }

  async consume(grantHash: string): Promise<boolean> {
    const res = await this.pool.query(
      `UPDATE password_reset_grants
       SET consumed_at = NOW()
       WHERE grant_hash = $1
         AND consumed_at IS NULL
         AND expires_at > NOW()
       RETURNING id;`,
      [grantHash]
    );

    return (res.rowCount ?? 0) > 0;
  }

  async completePasswordReset(
    grantHash: string,
    passwordHash: string
  ): Promise<boolean> {
    if (!grantHash || !passwordHash) {
      throw new ValidationError(
        'Password reset grant and password hash are required.'
      );
    }

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      const grantLookup = await client.query(
        `SELECT user_id
         FROM password_reset_grants
         WHERE grant_hash = $1
           AND consumed_at IS NULL
           AND expires_at > NOW()
         LIMIT 1;`,
        [grantHash]
      );
      if (grantLookup.rowCount === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      const userId = grantLookup.rows[0].user_id;
      const userRes = await client.query(
        `SELECT id, role, status, email, email_verified_at, password_hash,
                email_password_eligibility
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [userId]
      );
      const user = userRes.rows[0];
      if (
        !user ||
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        !user.email ||
        user.email_password_eligibility !== 'NEW_PATIENT_ELIGIBLE' ||
        !user.password_hash
      ) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      const partnerRes = await client.query(PARTNER_ACCOUNT_EXISTS_SQL, [
        userId,
      ]);
      if (partnerRes.rows[0]?.is_partner_account === true) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      const grantRes = await client.query(
        `SELECT id, user_id
         FROM password_reset_grants
         WHERE grant_hash = $1
           AND user_id = $2
           AND consumed_at IS NULL
           AND expires_at > NOW()
         FOR UPDATE;`,
        [grantHash, userId]
      );
      if (grantRes.rowCount === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      const userUpdate = await client.query(
        `UPDATE users
         SET password_hash = $2, updated_at = NOW()
         WHERE id = $1
           AND role = 'PATIENT'
           AND status = 'ACTIVE'
           AND email IS NOT NULL
           AND email_password_eligibility = 'NEW_PATIENT_ELIGIBLE'
           AND password_hash IS NOT NULL
         RETURNING id;`,
        [userId, passwordHash]
      );
      if ((userUpdate.rowCount ?? 0) === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      await client.query(
        `UPDATE refresh_tokens
         SET revoked_at = NOW()
         WHERE user_id = $1
           AND revoked_at IS NULL;`,
        [userId]
      );
      const grantUpdate = await client.query(
        `UPDATE password_reset_grants
         SET consumed_at = NOW()
         WHERE user_id = $1
           AND consumed_at IS NULL
         RETURNING id;`,
        [userId]
      );
      if ((grantUpdate.rowCount ?? 0) === 0) {
        await client.query('ROLLBACK');
        transactionStarted = false;
        return false;
      }

      await client.query('COMMIT');
      transactionStarted = false;
      return true;
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Password reset and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  private mapGrantRow(row: {
    id: string;
    user_id: string;
    grant_hash: string;
    expires_at: Date | string;
    consumed_at: Date | string | null;
    created_at: Date | string;
  }): PasswordResetGrant {
    return {
      id: row.id,
      userId: row.user_id,
      grantHash: row.grant_hash,
      expiresAt: new Date(row.expires_at),
      consumedAt: row.consumed_at ? new Date(row.consumed_at) : null,
      createdAt: new Date(row.created_at),
    };
  }
}

/**
 * PostgreSQL fixed-window counters for email/password login throttling.
 */
export class PostgresPasswordLoginRateLimitRepository
  implements IPasswordLoginRateLimitRepository
{
  constructor(private readonly pool: Pool = defaultPool) {}

  async recordAttempt(
    emailBucketHash: string,
    ipBucketHash?: string
  ): Promise<{ emailAttempts: number; ipAttempts: number | null }> {
    this.validateBucketHash(emailBucketHash);
    if (ipBucketHash) this.validateBucketHash(ipBucketHash);

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;

    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      await client.query(
        `WITH expired AS (
           SELECT ctid
           FROM password_login_rate_limits
           WHERE window_started_at < NOW() - INTERVAL '24 hours'
           ORDER BY window_started_at
           LIMIT 1000
           FOR UPDATE SKIP LOCKED
         )
         DELETE FROM password_login_rate_limits
         WHERE ctid IN (SELECT ctid FROM expired);`
      );

      const emailAttempts = await this.incrementBucket(
        client,
        'EMAIL',
        emailBucketHash
      );
      const ipAttempts = ipBucketHash
        ? await this.incrementBucket(client, 'IP', ipBucketHash)
        : null;

      await client.query('COMMIT');
      transactionStarted = false;
      return { emailAttempts, ipAttempts };
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Login rate-limit update and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
  }

  private async incrementBucket(
    client: PoolClient,
    bucketType: 'EMAIL' | 'IP',
    bucketHash: string
  ): Promise<number> {
    const res = await client.query(
      `INSERT INTO password_login_rate_limits
         (bucket_type, bucket_hash, window_started_at, attempts_count)
       VALUES ($1, $2, NOW(), 1)
       ON CONFLICT (bucket_type, bucket_hash) DO UPDATE
       SET attempts_count = CASE
             WHEN password_login_rate_limits.window_started_at <= NOW() - INTERVAL '1 hour' THEN 1
             ELSE password_login_rate_limits.attempts_count + 1
           END,
           window_started_at = CASE
             WHEN password_login_rate_limits.window_started_at <= NOW() - INTERVAL '1 hour' THEN NOW()
             ELSE password_login_rate_limits.window_started_at
           END
       RETURNING attempts_count;`,
      [bucketType, bucketHash]
    );
    if (res.rowCount !== 1 || !res.rows[0]) {
      throw new Error('Failed to record password login attempt.');
    }
    return Number(res.rows[0].attempts_count);
  }

  private validateBucketHash(bucketHash: string): void {
    if (!/^[a-f0-9]{64}$/.test(bucketHash)) {
      throw new ValidationError('Login rate-limit bucket hash is invalid.');
    }
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
    expectedPasswordHash?: string;
  }): Promise<RefreshToken> {
    if (data.expectedPasswordHash === undefined) {
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

    const client = await this.pool.connect();
    let transactionStarted = false;
    let clientReleaseError: Error | boolean | undefined;
    try {
      await client.query('BEGIN ISOLATION LEVEL READ COMMITTED');
      transactionStarted = true;
      const userRes = await client.query(
        `SELECT id, role, status, email, email_verified_at, password_hash,
                email_password_eligibility
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [data.userId]
      );
      const user = userRes.rows[0];
      if (
        !user ||
        user.role !== 'PATIENT' ||
        user.status !== 'ACTIVE' ||
        !user.email ||
        user.password_hash !== data.expectedPasswordHash ||
        user.email_password_eligibility !== 'NEW_PATIENT_ELIGIBLE'
      ) {
        throw new AppError(
          'Email or password is incorrect.',
          401,
          'EMAIL_PASSWORD_INVALID_CREDENTIALS'
        );
      }

      const partnerRes = await client.query(PARTNER_ACCOUNT_EXISTS_SQL, [
        data.userId,
      ]);
      if (partnerRes.rows[0]?.is_partner_account === true) {
        throw new AppError(
          'Email or password is incorrect.',
          401,
          'EMAIL_PASSWORD_INVALID_CREDENTIALS'
        );
      }

      const res = await client.query(
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
      await client.query('COMMIT');
      transactionStarted = false;
      return this.mapTokenRow(res.rows[0]);
    } catch (error: unknown) {
      if (transactionStarted) {
        try {
          await client.query('ROLLBACK');
        } catch (rollbackError: unknown) {
          clientReleaseError =
            rollbackError instanceof Error ? rollbackError : true;
          throw new AggregateError(
            [error, rollbackError],
            'Password session creation and transaction rollback both failed.',
            { cause: error }
          );
        }
      }
      throw error;
    } finally {
      client.release(clientReleaseError);
    }
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

      const ownerRes = await client.query(
        `SELECT user_id
         FROM refresh_tokens
         WHERE id = $1;`,
        [oldTokenId]
      );
      if (ownerRes.rowCount === 0) {
        await client.query('ROLLBACK;');
        throw new AppError('Old refresh token not found', 401, 'INVALID_REFRESH_TOKEN');
      }

      await client.query(
        `SELECT id
         FROM users
         WHERE id = $1
         FOR UPDATE;`,
        [ownerRes.rows[0].user_id]
      );

      // Lock the token after its owner to serialize rotation with password resets.
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
