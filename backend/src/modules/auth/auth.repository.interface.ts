import {
  User,
  UserRole,
  UserStatus,
  PatientProfile,
  OtpChallenge,
  OtpPurpose,
  RefreshToken,
  PreferredLanguage,
} from './auth.types';

export interface IUserRepository {
  findByPhone(phone: string): Promise<User | null>;
  findById(id: string): Promise<User | null>;
  create(data: { phone: string; role?: UserRole; status?: UserStatus }): Promise<User>;
  updateStatus(id: string, status: UserStatus): Promise<User | null>;
}

export interface IPatientProfileRepository {
  findByUserId(userId: string): Promise<PatientProfile | null>;
  create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile>;
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

  incrementAttempts(id: string): Promise<number>;

  consume(id: string): Promise<boolean>;

  invalidatePredecessors(phone: string, purpose: OtpPurpose): Promise<void>;

  getRecentRequestCountByPhone(phone: string, since: Date): Promise<number>;

  getRecentRequestCountByIp(ipAddress: string, since: Date): Promise<number>;

  getLastRequestTime(phone: string): Promise<Date | null>;
}

export interface IRefreshTokenRepository {
  create(data: {
    userId: string;
    tokenHash: string;
    deviceInfo?: string;
    ipAddress?: string;
    expiresAt: Date;
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
