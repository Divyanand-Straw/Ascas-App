import crypto from 'crypto';
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
} from './auth.types';
import { ConflictError, AppError } from '../../utils/errors';

/**
 * ============================================================================
 * [DEVELOPMENT / TEST ONLY] Mock User Repository
 * In-memory storage simulating PostgreSQL public.users table.
 * ============================================================================
 */
export class MockUserRepository implements IUserRepository {
  private usersById: Map<string, User> = new Map();
  private usersByPhone: Map<string, string> = new Map(); // phone -> userId

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockUserRepository cannot be used in production environments.');
    }
  }

  async findByPhone(phone: string): Promise<User | null> {
    const userId = this.usersByPhone.get(phone);
    if (!userId) return null;
    const user = this.usersById.get(userId);
    return user ? { ...user } : null;
  }

  async findById(id: string): Promise<User | null> {
    const user = this.usersById.get(id);
    return user ? { ...user } : null;
  }

  async create(data: { phone: string; role?: UserRole; status?: UserStatus }): Promise<User> {
    if (this.usersByPhone.has(data.phone)) {
      throw new ConflictError('User with this mobile number already exists');
    }

    const now = new Date();
    const user: User = {
      id: crypto.randomUUID(),
      phone: data.phone,
      role: data.role || 'PATIENT',
      status: data.status || 'ACTIVE',
      createdAt: now,
      updatedAt: now,
    };

    this.usersById.set(user.id, user);
    this.usersByPhone.set(user.phone, user.id);
    return { ...user };
  }

  async updateStatus(id: string, status: UserStatus): Promise<User | null> {
    const user = this.usersById.get(id);
    if (!user) return null;
    user.status = status;
    user.updatedAt = new Date();
    return { ...user };
  }

  // Test helper
  clear(): void {
    this.usersById.clear();
    this.usersByPhone.clear();
  }
}

/**
 * ============================================================================
 * [DEVELOPMENT / TEST ONLY] Mock Patient Profile Repository
 * In-memory storage simulating PostgreSQL public.patient_profiles table.
 * ============================================================================
 */
export class MockPatientProfileRepository implements IPatientProfileRepository {
  private profilesByUserId: Map<string, PatientProfile> = new Map();

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockPatientProfileRepository cannot be used in production environments.');
    }
  }

  async findByUserId(userId: string): Promise<PatientProfile | null> {
    const profile = this.profilesByUserId.get(userId);
    return profile ? { ...profile } : null;
  }

  async create(data: {
    userId: string;
    firstName: string;
    lastName: string;
    dob?: Date | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const now = new Date();
    const profile: PatientProfile = {
      id: crypto.randomUUID(),
      userId: data.userId,
      firstName: data.firstName,
      lastName: data.lastName,
      dob: data.dob ?? null,
      gender: null,
      clinicMrn: null,
      preferredLanguage: data.preferredLanguage || 'en',
      linkingStatus: 'UNLINKED',
      createdAt: now,
      updatedAt: now,
    };

    this.profilesByUserId.set(profile.userId, profile);
    return { ...profile };
  }

  // Test helper
  clear(): void {
    this.profilesByUserId.clear();
  }
}

/**
 * ============================================================================
 * [DEVELOPMENT / TEST ONLY] Mock OTP Repository
 * In-memory storage simulating PostgreSQL public.otp_verifications table.
 * Implements atomic updates for challenge verification, attempt counting, and consumption.
 * ============================================================================
 */
export class MockOtpRepository implements IOtpRepository {
  private challenges: Map<string, OtpChallenge> = new Map();

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockOtpRepository cannot be used in production environments.');
    }
  }

  async create(data: {
    phone: string;
    otpHash: string;
    purpose: OtpPurpose;
    maxAttempts?: number;
    expiresAt: Date;
    ipAddress?: string;
    createdAt?: Date;
  }): Promise<OtpChallenge> {
    const challenge: OtpChallenge = {
      id: crypto.randomUUID(),
      phone: data.phone,
      otpHash: data.otpHash,
      purpose: data.purpose,
      attemptsCount: 0,
      maxAttempts: data.maxAttempts || 3,
      expiresAt: data.expiresAt,
      consumedAt: null,
      ipAddress: data.ipAddress,
      createdAt: data.createdAt || new Date(),
    };

    this.challenges.set(challenge.id, challenge);
    return { ...challenge };
  }

  expireChallengeForTesting(id: string): void {
    const challenge = this.challenges.get(id);
    if (challenge) {
      challenge.expiresAt = new Date(Date.now() - 10000);
    }
  }

  async findActiveChallenge(id: string, phone: string, purpose: OtpPurpose): Promise<OtpChallenge | null> {
    const challenge = this.challenges.get(id);
    if (!challenge) return null;

    if (challenge.phone !== phone || challenge.purpose !== purpose) {
      return null;
    }

    return { ...challenge };
  }

  async incrementAttempts(id: string): Promise<number> {
    const challenge = this.challenges.get(id);
    if (!challenge) return 0;
    challenge.attemptsCount += 1;
    return challenge.attemptsCount;
  }

  async consume(id: string): Promise<boolean> {
    const challenge = this.challenges.get(id);
    if (!challenge) return false;
    if (challenge.consumedAt !== null) {
      // Already consumed
      return false;
    }
    challenge.consumedAt = new Date();
    return true;
  }

  async invalidatePredecessors(phone: string, purpose: OtpPurpose): Promise<void> {
    const now = new Date();
    for (const challenge of this.challenges.values()) {
      if (challenge.phone === phone && challenge.purpose === purpose && challenge.consumedAt === null) {
        challenge.consumedAt = now; // Mark consumed/revoked
      }
    }
  }

  async getRecentRequestCountByPhone(phone: string, since: Date): Promise<number> {
    let count = 0;
    for (const challenge of this.challenges.values()) {
      if (challenge.phone === phone && challenge.createdAt >= since) {
        count++;
      }
    }
    return count;
  }

  async getRecentRequestCountByIp(ipAddress: string, since: Date): Promise<number> {
    let count = 0;
    for (const challenge of this.challenges.values()) {
      if (challenge.ipAddress === ipAddress && challenge.createdAt >= since) {
        count++;
      }
    }
    return count;
  }

  async getLastRequestTime(phone: string): Promise<Date | null> {
    let lastTime: Date | null = null;
    for (const challenge of this.challenges.values()) {
      if (challenge.phone === phone) {
        if (!lastTime || challenge.createdAt > lastTime) {
          lastTime = challenge.createdAt;
        }
      }
    }
    return lastTime;
  }

  // Test helper
  clear(): void {
    this.challenges.clear();
  }
}

/**
 * ============================================================================
 * [DEVELOPMENT / TEST ONLY] Mock Refresh Token Repository
 * In-memory storage simulating PostgreSQL public.refresh_tokens table.
 * Handles atomic token rotation and token-reuse tracking.
 * ============================================================================
 */
export class MockRefreshTokenRepository implements IRefreshTokenRepository {
  private tokensById: Map<string, RefreshToken> = new Map();
  private tokensByHash: Map<string, string> = new Map(); // tokenHash -> tokenId

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockRefreshTokenRepository cannot be used in production environments.');
    }
  }

  async create(data: {
    userId: string;
    tokenHash: string;
    deviceInfo?: string;
    ipAddress?: string;
    expiresAt: Date;
  }): Promise<RefreshToken> {
    const token: RefreshToken = {
      id: crypto.randomUUID(),
      userId: data.userId,
      tokenHash: data.tokenHash,
      deviceInfo: data.deviceInfo,
      ipAddress: data.ipAddress,
      expiresAt: data.expiresAt,
      revokedAt: null,
      createdAt: new Date(),
    };

    this.tokensById.set(token.id, token);
    this.tokensByHash.set(token.tokenHash, token.id);
    return { ...token };
  }

  async findByTokenHash(tokenHash: string): Promise<RefreshToken | null> {
    const tokenId = this.tokensByHash.get(tokenHash);
    if (!tokenId) return null;
    const token = this.tokensById.get(tokenId);
    return token ? { ...token } : null;
  }

  async revoke(id: string): Promise<void> {
    const token = this.tokensById.get(id);
    if (token) {
      token.revokedAt = new Date();
    }
  }

  async revokeAllForUser(userId: string): Promise<void> {
    const now = new Date();
    for (const token of this.tokensById.values()) {
      if (token.userId === userId && token.revokedAt === null) {
        token.revokedAt = now;
      }
    }
  }

  /**
   * Concurrency-safe atomic rotation.
   * If oldToken is already revoked or missing, rotation fails immediately.
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
    const oldToken = this.tokensById.get(oldTokenId);
    if (!oldToken) {
      throw new AppError('Old refresh token not found', 401, 'INVALID_REFRESH_TOKEN');
    }

    if (oldToken.revokedAt !== null) {
      // Token was already revoked: indicates concurrent attempt or replay
      throw new AppError('Refresh token has already been rotated or revoked', 401, 'REFRESH_TOKEN_REUSE_DETECTED');
    }

    const now = new Date();
    oldToken.revokedAt = now;

    const newToken: RefreshToken = {
      id: crypto.randomUUID(),
      userId: newTokenData.userId,
      tokenHash: newTokenData.tokenHash,
      deviceInfo: newTokenData.deviceInfo,
      ipAddress: newTokenData.ipAddress,
      expiresAt: newTokenData.expiresAt,
      revokedAt: null,
      createdAt: now,
    };

    this.tokensById.set(newToken.id, newToken);
    this.tokensByHash.set(newToken.tokenHash, newToken.id);

    return { ...newToken };
  }

  // Test helper
  clear(): void {
    this.tokensById.clear();
    this.tokensByHash.clear();
  }
}
