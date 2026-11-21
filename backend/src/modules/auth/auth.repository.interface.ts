import {
  User,
  UserRole,
  UserStatus,
  PatientProfile,
  OtpChallenge,
  OtpPurpose,
  EmailOtpChallenge,
  EmailOtpPurpose,
  PasswordResetGrant,
  RefreshToken,
  PreferredLanguage,
  UserCredentials,
} from './auth.types';

export interface IUserRepository {
  findByPhone(phone: string): Promise<User | null>;
  findById(id: string): Promise<User | null>;
  findByIdWithPasswordHash(id: string): Promise<UserCredentials | null>;
  findByEmail(email: string): Promise<User | null>;
  findByEmailWithPasswordHash(email: string): Promise<UserCredentials | null>;
  create(data: {
    phone: string;
    role?: UserRole;
    status?: UserStatus;
    emailPasswordEligibility?: 'NEW_PATIENT_ELIGIBLE' | 'PARTNER_INELIGIBLE';
  }): Promise<User>;
  markPhoneVerified(id: string): Promise<void>;
  updateEmail(
    id: string,
    email: string | null,
    emailVerifiedAt: Date | null,
    expectedEmail: string | null
  ): Promise<User | null>;
  attachInitialVerifiedEmail(
    id: string,
    email: string,
    emailVerifiedAt: Date
  ): Promise<User | null>;
  markLinkedMemberIneligible(id: string): Promise<void>;
  setPasswordHash(id: string, passwordHash: string): Promise<boolean>;
  setInitialPasswordHash(
    id: string,
    passwordHash: string
  ): Promise<PasswordSetupResult>;
  setInitialRegistrationCredentials(
    id: string,
    email: string,
    passwordHash: string
  ): Promise<RegistrationCredentialsSetupResult>;
  isPartnerAccount(id: string): Promise<boolean>;
  updateStatus(id: string, status: UserStatus): Promise<User | null>;
}

export type PasswordSetupResult =
  | 'SET'
  | 'USER_NOT_FOUND'
  | 'EMAIL_UNVERIFIED'
  | 'ACCOUNT_INELIGIBLE'
  | 'PASSWORD_ALREADY_SET'
  | 'PARTNER_MEMBER';

export type RegistrationCredentialsSetupResult =
  | 'SET'
  | 'USER_NOT_FOUND'
  | 'ACCOUNT_INELIGIBLE'
  | 'CREDENTIALS_ALREADY_CONFIGURED'
  | 'PARTNER_MEMBER';

export interface IPatientProfileRepository {
  findByUserId(userId: string): Promise<PatientProfile | null>;
  update(userId: string, data: {
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile>;
  create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile>;
  createOrGet(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile>;
}

export interface OtpChallengeIssueResult {
  challenge: OtpChallenge | null;
  created: boolean;
  retryAfterSeconds: number;
  rateLimit?: 'ip' | 'phone';
}

export interface IOtpRepository {
  create(data: {
    phone: string;
    otpHash: string;
    purpose: OtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    ipAddress?: string;
  }): Promise<OtpChallenge>;

  findActiveChallenge(id: string, phone: string, purpose: OtpPurpose): Promise<OtpChallenge | null>;

  findLatestActiveChallenge(
    phone: string,
    purpose: OtpPurpose
  ): Promise<OtpChallenge | null>;

  createOrReuseForCooldown(
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
  ): Promise<OtpChallengeIssueResult>;

  incrementAttempts(id: string): Promise<number>;

  consume(id: string): Promise<boolean>;

  getRecentRequestCountByPhone(phone: string, since: Date): Promise<number>;

  getRecentRequestCountByIp(ipAddress: string, since: Date): Promise<number>;

}

export interface IEmailOtpRepository {
  create(data: {
    userId?: string | null;
    email: string;
    otpHash: string;
    purpose: EmailOtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    resendAfter: Date;
    ipAddress?: string;
  }): Promise<EmailOtpChallenge>;

  replaceActiveChallenge(data: {
    userId?: string | null;
    email: string;
    otpHash: string;
    purpose: EmailOtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    resendAfter: Date;
    ipAddress?: string;
  }, resendCooldownSeconds?: number, rateLimits?: {
    maxRequestsPerHourPerEmail: number;
    maxRequestsPerHourPerIp: number;
  }): Promise<EmailOtpChallenge>;

  findActiveChallenge(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<EmailOtpChallenge | null>;

  incrementAttempts(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<number>;

  consume(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<boolean>;

  getLastResendAfter(
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<Date | null>;
}

export interface IPasswordResetGrantRepository {
  create(data: {
    userId: string;
    grantHash: string;
    expiresAt: Date;
  }): Promise<PasswordResetGrant>;

  findActiveByHash(grantHash: string): Promise<PasswordResetGrant | null>;

  consume(grantHash: string): Promise<boolean>;

  completePasswordReset(
    grantHash: string,
    passwordHash: string
  ): Promise<boolean>;
}

export interface IPasswordLoginRateLimitRepository {
  recordAttempt(
    emailBucketHash: string,
    ipBucketHash?: string
  ): Promise<{ emailAttempts: number; ipAttempts: number | null }>;
}

export interface IRefreshTokenRepository {
  create(data: {
    userId: string;
    tokenHash: string;
    deviceInfo?: string;
    ipAddress?: string;
    expiresAt: Date;
    expectedPasswordHash?: string;
  }): Promise<RefreshToken>;

  findByTokenHash(tokenHash: string): Promise<RefreshToken | null>;

  revoke(id: string): Promise<void>;

  revokeAllForUser(userId: string): Promise<void>;

  rotateToken(
    oldTokenId: string,
    newToken: {
      userId: string;
      tokenHash: string;
      deviceInfo?: string;
      ipAddress?: string;
      expiresAt: Date;
    }
  ): Promise<RefreshToken>;
}
