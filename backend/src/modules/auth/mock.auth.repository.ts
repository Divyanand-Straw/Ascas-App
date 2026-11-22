import crypto from 'crypto';
import {
  IUserRepository,
  IPatientProfileRepository,
  IOtpRepository,
  OtpChallengeIssueResult,
  IEmailOtpRepository,
  IPasswordResetGrantRepository,
  IPasswordLoginRateLimitRepository,
  IRefreshTokenRepository,
} from './auth.repository.interface';
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
  EmailPasswordEligibility,
  normalizeEmailAddress,
} from './auth.types';
import {
  ConflictError,
  AppError,
  ValidationError,
} from '../../utils/errors';

/**
 * ============================================================================
 * [DEVELOPMENT / TEST ONLY] Mock User Repository
 * In-memory storage simulating PostgreSQL public.users table.
 * ============================================================================
 */
export class MockUserRepository implements IUserRepository {
  private usersById: Map<string, User> = new Map();
  private usersByPhone: Map<string, string> = new Map(); // phone -> userId
  private usersByEmail: Map<string, string> = new Map(); // normalized email -> userId
  private passwordHashes: Map<string, string> = new Map(); // userId -> hash
  private verifiedPhoneUserIds: Set<string> = new Set();
  private activePartnerMembers: Set<string> = new Set();
  private pendingPartnerInvitations: Set<string> = new Set();

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

  async findByIdWithPasswordHash(
    id: string
  ): Promise<UserCredentials | null> {
    const user = this.usersById.get(id);
    if (!user) return null;
    return {
      user: { ...user },
      passwordHash: this.passwordHashes.get(id) ?? null,
    };
  }

  async findByEmail(email: string): Promise<User | null> {
    const normalizedEmail = normalizeEmailAddress(email);
    if (!normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }

    const userId = this.usersByEmail.get(normalizedEmail);
    if (!userId) return null;
    const user = this.usersById.get(userId);
    return user ? { ...user } : null;
  }

  async findByEmailWithPasswordHash(
    email: string
  ): Promise<UserCredentials | null> {
    const user = await this.findByEmail(email);
    if (!user) return null;

    return {
      user,
      passwordHash: this.passwordHashes.get(user.id) ?? null,
    };
  }

  async create(data: {
    phone: string;
    role?: UserRole;
    status?: UserStatus;
    emailPasswordEligibility?: EmailPasswordEligibility;
  }): Promise<User> {
    if (this.usersByPhone.has(data.phone)) {
      throw new ConflictError('User with this mobile number already exists');
    }

    const now = new Date();
    const user: User = {
      id: crypto.randomUUID(),
      phone: data.phone,
      email: null,
      emailVerifiedAt: null,
      role: data.role || 'PATIENT',
      status: data.status || 'ACTIVE',
      emailPasswordEligibility:
        data.emailPasswordEligibility ??
        'IDENTITY_REQUIRED',
      createdAt: now,
      updatedAt: now,
    };

    this.usersById.set(user.id, user);
    this.usersByPhone.set(user.phone, user.id);
    return { ...user };
  }

  async markPhoneVerified(id: string): Promise<void> {
    if (!this.usersById.has(id)) {
      throw new Error('Cannot verify a phone number for an unknown user.');
    }
    this.verifiedPhoneUserIds.add(id);
  }

  isPhoneVerifiedForTesting(id: string): boolean {
    return this.verifiedPhoneUserIds.has(id);
  }

  async attachInitialVerifiedEmail(
    id: string,
    email: string,
    emailVerifiedAt: Date
  ): Promise<User | null> {
    const user = this.usersById.get(id);
    if (
      !user ||
      user.email !== null ||
      user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      user.role !== 'PATIENT' ||
      user.status !== 'ACTIVE' ||
      this.passwordHashes.has(id) ||
      this.hasPartnerAccount(id)
    ) {
      return null;
    }
    return this.updateEmail(id, email, emailVerifiedAt, null);
  }

  async markLinkedMemberIneligible(id: string): Promise<void> {
    const user = this.usersById.get(id);
    if (!user) return;
    user.emailPasswordEligibility = 'PARTNER_INELIGIBLE';
    user.updatedAt = new Date();
  }

  async updateEmail(
    id: string,
    email: string | null,
    emailVerifiedAt: Date | null,
    expectedEmail: string | null
  ): Promise<User | null> {
    const user = this.usersById.get(id);
    if (!user) return null;

    const normalizedEmail = email === null ? null : normalizeEmailAddress(email);
    const normalizedExpectedEmail =
      expectedEmail === null ? null : normalizeEmailAddress(expectedEmail);

    if (email !== null && !normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }
    if (normalizedEmail === null && emailVerifiedAt !== null) {
      throw new ValidationError('An email address is required for verification.');
    }
    if ((user.email ?? null) !== normalizedExpectedEmail) {
      return null;
    }

    if (normalizedEmail !== null) {
      const existingUserId = this.usersByEmail.get(normalizedEmail);
      if (existingUserId && existingUserId !== id) {
        throw new ConflictError('An account with this email address already exists.');
      }
    }

    if (user.email) {
      this.usersByEmail.delete(user.email);
    }
    user.email = normalizedEmail;
    user.emailVerifiedAt = normalizedEmail ? emailVerifiedAt : null;
    user.updatedAt = new Date();

    if (normalizedEmail) {
      this.usersByEmail.set(normalizedEmail, id);
    }
    if (user.emailVerifiedAt === null) {
      this.passwordHashes.delete(id);
    }

    return { ...user };
  }

  async setPasswordHash(id: string, passwordHash: string): Promise<boolean> {
    return (await this.setInitialPasswordHash(id, passwordHash)) === 'SET';
  }

  async setInitialPasswordHash(
    id: string,
    passwordHash: string
  ): Promise<
    | 'SET'
    | 'USER_NOT_FOUND'
    | 'EMAIL_UNVERIFIED'
    | 'ACCOUNT_INELIGIBLE'
    | 'PASSWORD_ALREADY_SET'
    | 'PARTNER_MEMBER'
  > {
    if (!passwordHash) {
      throw new ValidationError('Password hash is required.');
    }

    const user = this.usersById.get(id);
    if (!user) return 'USER_NOT_FOUND';
    if (
      user.role !== 'PATIENT' ||
      user.status !== 'ACTIVE' ||
      user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE'
    ) {
      return 'ACCOUNT_INELIGIBLE';
    }
    if (!user.email || !user.emailVerifiedAt) return 'EMAIL_UNVERIFIED';
    if (this.passwordHashes.has(id)) return 'PASSWORD_ALREADY_SET';
    if (this.hasPartnerAccount(id)) return 'PARTNER_MEMBER';

    this.passwordHashes.set(id, passwordHash);
    user.updatedAt = new Date();
    return 'SET';
  }

  async setInitialRegistrationCredentials(
    id: string,
    email: string,
    passwordHash: string
  ): Promise<
    | 'SET'
    | 'USER_NOT_FOUND'
    | 'ACCOUNT_INELIGIBLE'
    | 'CREDENTIALS_ALREADY_CONFIGURED'
    | 'PARTNER_MEMBER'
  > {
    if (!passwordHash) {
      throw new ValidationError('Password hash is required.');
    }
    const user = this.usersById.get(id);
    if (!user) return 'USER_NOT_FOUND';
    if (
      user.role !== 'PATIENT' ||
      user.status !== 'ACTIVE' ||
      user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE'
    ) {
      return 'ACCOUNT_INELIGIBLE';
    }
    if (user.email || user.emailVerifiedAt || this.passwordHashes.has(id)) {
      return 'CREDENTIALS_ALREADY_CONFIGURED';
    }
    if (this.hasPartnerAccount(id)) return 'PARTNER_MEMBER';

    const normalizedEmail = normalizeEmailAddress(email);
    if (!normalizedEmail) {
      throw new ValidationError('Email address is required.');
    }
    const existingUserId = this.usersByEmail.get(normalizedEmail);
    if (existingUserId && existingUserId !== id) {
      throw new ConflictError('An account with this email address already exists.');
    }

    user.email = normalizedEmail;
    user.emailVerifiedAt = null;
    this.usersByEmail.set(normalizedEmail, id);
    this.passwordHashes.set(id, passwordHash);
    user.updatedAt = new Date();
    return 'SET';
  }

  async isPartnerAccount(id: string): Promise<boolean> {
    return this.hasPartnerAccount(id);
  }

  private hasPartnerAccount(id: string): boolean {
    return (
      this.activePartnerMembers.has(id) ||
      this.pendingPartnerInvitations.has(id)
    );
  }

  setPartnerMemberForTesting(id: string, active: boolean): void {
    if (active) this.activePartnerMembers.add(id);
    else this.activePartnerMembers.delete(id);
  }

  setPartnerInvitationPendingForTesting(id: string, pending: boolean): void {
    if (pending) this.pendingPartnerInvitations.add(id);
    else this.pendingPartnerInvitations.delete(id);
  }

  setEmailPasswordEligibilityForTesting(
    id: string,
    eligibility: EmailPasswordEligibility
  ): void {
    const user = this.usersById.get(id);
    if (!user) throw new Error('Cannot set eligibility for a missing user.');
    user.emailPasswordEligibility = eligibility;
  }

  setPasswordHashForReset(id: string, passwordHash: string): boolean {
    const user = this.usersById.get(id);
    if (
      !user ||
      user.role !== 'PATIENT' ||
      user.status !== 'ACTIVE' ||
      !user.email ||
      user.emailPasswordEligibility !== 'NEW_PATIENT_ELIGIBLE' ||
      !this.passwordHashes.has(id) ||
      this.hasPartnerAccount(id)
    ) {
      return false;
    }
    this.passwordHashes.set(id, passwordHash);
    user.updatedAt = new Date();
    return true;
  }

  isPasswordHashCurrentForSession(
    id: string,
    expectedPasswordHash: string
  ): boolean {
    const user = this.usersById.get(id);
    return Boolean(
      user &&
        user.role === 'PATIENT' &&
        user.status === 'ACTIVE' &&
        user.emailPasswordEligibility === 'NEW_PATIENT_ELIGIBLE' &&
        user.email &&
        this.passwordHashes.get(id) === expectedPasswordHash &&
        !this.hasPartnerAccount(id)
    );
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
    this.usersByEmail.clear();
    this.passwordHashes.clear();
    this.activePartnerMembers.clear();
    this.pendingPartnerInvitations.clear();
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

  async update(userId: string, data: {
    firstName: string;
    lastName: string;
    dob?: Date | null;
    gender?: string | null;
    emergencyContact?: string | null;
    preferredLanguage?: PreferredLanguage;
  }): Promise<PatientProfile> {
    const existing = this.profilesByUserId.get(userId);
    if (!existing) {
      throw new Error('Patient profile could not be found.');
    }
    const updated: PatientProfile = {
      ...existing,
      firstName: data.firstName,
      lastName: data.lastName,
      dob: data.dob === undefined ? existing.dob : data.dob,
      gender: data.gender === undefined ? existing.gender : data.gender,
      emergencyContact:
        data.emergencyContact === undefined
          ? existing.emergencyContact
          : data.emergencyContact,
      preferredLanguage:
        data.preferredLanguage || existing.preferredLanguage,
      updatedAt: new Date(),
    };
    this.profilesByUserId.set(userId, updated);
    return { ...updated };
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
    const now = new Date();
    const profile: PatientProfile = {
      id: crypto.randomUUID(),
      userId: data.userId,
      firstName: data.firstName,
      lastName: data.lastName,
      dob: data.dob ?? null,
      gender: data.gender ?? null,
      emergencyContact: data.emergencyContact ?? null,
      clinicMrn: null,
      preferredLanguage: data.preferredLanguage || 'en',
      linkingStatus: 'UNLINKED',
      createdAt: now,
      updatedAt: now,
    };

    this.profilesByUserId.set(profile.userId, profile);
    return { ...profile };
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
    const existing = this.profilesByUserId.get(data.userId);
    if (existing) return { ...existing };
    return this.create(data);
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

  async findLatestActiveChallenge(
    phone: string,
    purpose: OtpPurpose
  ): Promise<OtpChallenge | null> {
    const now = Date.now();
    const challenge = [...this.challenges.values()]
      .filter(
        (candidate) =>
          candidate.phone === phone &&
          candidate.purpose === purpose &&
          candidate.consumedAt === null &&
          candidate.expiresAt.getTime() > now &&
          candidate.attemptsCount < candidate.maxAttempts
      )
      .sort((left, right) => right.createdAt.getTime() - left.createdAt.getTime())[0];

    return challenge ? { ...challenge } : null;
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

    const now = Date.now();
    const oneHourAgo = now - 60 * 60 * 1000;
    const challenges = [...this.challenges.values()];
    if (
      data.ipAddress &&
      challenges.filter(
        (challenge) =>
          challenge.ipAddress === data.ipAddress &&
          challenge.createdAt.getTime() >= oneHourAgo
      ).length >= maxRequestsPerHourPerIp
    ) {
      return {
        challenge: null,
        created: false,
        retryAfterSeconds: 0,
        rateLimit: 'ip',
      };
    }
    if (
      challenges.filter(
        (challenge) =>
          challenge.phone === data.phone &&
          challenge.createdAt.getTime() >= oneHourAgo
      ).length >= maxRequestsPerHourPerPhone
    ) {
      return {
        challenge: null,
        created: false,
        retryAfterSeconds: 0,
        rateLimit: 'phone',
      };
    }

    const latest = challenges
      .filter(
        (challenge) =>
          challenge.phone === data.phone &&
          challenge.purpose === data.purpose
      )
      .sort(
        (left, right) =>
          right.createdAt.getTime() - left.createdAt.getTime()
      )[0];

    if (latest) {
      const retryAfterSeconds = Math.ceil(
        (latest.createdAt.getTime() + resendCooldownSeconds * 1000 - now) /
          1000
      );
      if (retryAfterSeconds > 0) {
        const canResume =
          latest.consumedAt === null &&
          latest.expiresAt.getTime() > now &&
          latest.attemptsCount < latest.maxAttempts;
        return {
          challenge: canResume ? { ...latest } : null,
          created: false,
          retryAfterSeconds,
        };
      }
    }

    const invalidatedAt = new Date(now);
    for (const challenge of this.challenges.values()) {
      if (
        challenge.phone === data.phone &&
        challenge.purpose === data.purpose &&
        challenge.consumedAt === null
      ) {
        challenge.consumedAt = invalidatedAt;
      }
    }
    const challengeData = createChallenge();
    const challenge = await this.create({
      ...data,
      ...challengeData,
      createdAt: new Date(now),
    });
    return {
      challenge,
      created: true,
      retryAfterSeconds: resendCooldownSeconds,
    };
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

  // Test helper
  clear(): void {
    this.challenges.clear();
  }
}

/**
 * [DEVELOPMENT / TEST ONLY] In-memory email challenge repository.
 */
export class MockEmailOtpRepository implements IEmailOtpRepository {
  private challenges: Map<string, EmailOtpChallenge> = new Map();

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockEmailOtpRepository cannot be used in production environments.');
    }
  }

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
    const challenge = this.buildChallenge(data);
    this.challenges.set(challenge.id, challenge);
    return { ...challenge };
  }

  async replaceActiveChallenge(
    data: Parameters<IEmailOtpRepository['create']>[0],
    resendCooldownSeconds?: number,
    rateLimits?: {
      maxRequestsPerHourPerEmail: number;
      maxRequestsPerHourPerIp: number;
    }
  ): Promise<EmailOtpChallenge> {
    const challenge = this.buildChallenge(data);
    if (
      resendCooldownSeconds !== undefined &&
      (!Number.isInteger(resendCooldownSeconds) || resendCooldownSeconds < 1)
    ) {
      throw new ValidationError('Resend cooldown must be greater than zero.');
    }

    const now = new Date();
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

      const oneHourAgo = now.getTime() - 60 * 60 * 1000;
      const requests = [...this.challenges.values()].filter(
        (previous) =>
          previous.purpose === challenge.purpose &&
          previous.createdAt.getTime() >= oneHourAgo
      );
      const emailRequests = requests.filter(
        (previous) => previous.email === challenge.email
      );
      const ipRequests = data.ipAddress
        ? requests.filter((previous) => previous.ipAddress === data.ipAddress)
        : [];
      const rateLimitScope =
        emailRequests.length >= rateLimits.maxRequestsPerHourPerEmail
          ? 'email'
          : data.ipAddress &&
              ipRequests.length >= rateLimits.maxRequestsPerHourPerIp
            ? 'ip'
            : undefined;
      if (rateLimitScope) {
        const limitedRequests =
          rateLimitScope === 'email' ? emailRequests : ipRequests;
        const oldestRequest = limitedRequests.reduce<Date | null>(
          (oldest, request) =>
            !oldest || request.createdAt < oldest
              ? request.createdAt
              : oldest,
          null
        );
        const retryAfterSeconds = oldestRequest
          ? Math.max(
              1,
              3600 -
                Math.floor((now.getTime() - oldestRequest.getTime()) / 1000)
            )
          : 3600;
        throw new AppError(
          'Too many email test codes were requested. Try again later.',
          429,
          'EMAIL_OTP_RATE_LIMITED',
          { scope: rateLimitScope, retryAfterSeconds }
        );
      }
    }

    if (resendCooldownSeconds !== undefined) {
      let lastResendAfter: Date | null = null;
      for (const previous of this.challenges.values()) {
        if (
          previous.email === challenge.email &&
          previous.purpose === challenge.purpose &&
          (!lastResendAfter || previous.resendAfter > lastResendAfter)
        ) {
          lastResendAfter = previous.resendAfter;
        }
      }
      const retryAfterSeconds = lastResendAfter
        ? Math.ceil((lastResendAfter.getTime() - now.getTime()) / 1000)
        : 0;
      if (retryAfterSeconds > 0) {
        throw new AppError(
          'Please wait before requesting another verification code.',
          429,
          'EMAIL_OTP_COOLDOWN_ACTIVE',
          { retryAfterSeconds }
        );
      }
    }

    for (const previous of this.challenges.values()) {
      if (
        previous.email === challenge.email &&
        previous.purpose === challenge.purpose &&
        previous.consumedAt === null
      ) {
        previous.consumedAt = now;
      }
    }
    this.challenges.set(challenge.id, challenge);
    return { ...challenge };
  }

  private buildChallenge(
    data: Parameters<IEmailOtpRepository['create']>[0]
  ): EmailOtpChallenge {
    const email = normalizeEmailAddress(data.email);
    if (!email) {
      throw new ValidationError('Email address is required.');
    }
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

    const challenge: EmailOtpChallenge = {
      id: crypto.randomUUID(),
      userId: data.userId ?? null,
      email,
      otpHash: data.otpHash,
      purpose: data.purpose,
      attemptsCount: 0,
      maxAttempts: data.maxAttempts ?? 3,
      expiresAt: new Date(data.expiresAt),
      resendAfter: new Date(data.resendAfter),
      consumedAt: null,
      ipAddress: data.ipAddress,
      createdAt: new Date(),
    };

    return challenge;
  }

  expireChallengeForTesting(id: string): void {
    const challenge = this.challenges.get(id);
    if (challenge) {
      challenge.expiresAt = new Date(Date.now() - 1000);
    }
  }

  async findActiveChallenge(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<EmailOtpChallenge | null> {
    const challenge = this.challenges.get(id);
    if (!challenge || !this.isActive(challenge)) return null;
    if (
      challenge.email !== normalizeEmailAddress(email) ||
      challenge.purpose !== purpose ||
      challenge.userId !== (userId ?? null)
    ) {
      return null;
    }
    return { ...challenge };
  }

  async incrementAttempts(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<number> {
    const challenge = this.challenges.get(id);
    if (
      !challenge ||
      !this.isActive(challenge) ||
      challenge.email !== normalizeEmailAddress(email) ||
      challenge.purpose !== purpose ||
      challenge.userId !== (userId ?? null)
    ) {
      return 0;
    }
    challenge.attemptsCount += 1;
    return challenge.attemptsCount;
  }

  async consume(
    id: string,
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<boolean> {
    const challenge = this.challenges.get(id);
    if (
      !challenge ||
      !this.isActive(challenge) ||
      challenge.email !== normalizeEmailAddress(email) ||
      challenge.purpose !== purpose ||
      challenge.userId !== (userId ?? null)
    ) {
      return false;
    }
    challenge.consumedAt = new Date();
    return true;
  }

  async getLastResendAfter(
    email: string,
    purpose: EmailOtpPurpose,
    userId?: string | null
  ): Promise<Date | null> {
    const normalizedEmail = normalizeEmailAddress(email);
    let latest: Date | null = null;
    for (const challenge of this.challenges.values()) {
      if (
        challenge.email === normalizedEmail &&
        challenge.purpose === purpose &&
        challenge.userId === (userId ?? null) &&
        (!latest || challenge.resendAfter > latest)
      ) {
        latest = challenge.resendAfter;
      }
    }
    return latest ? new Date(latest) : null;
  }

  private isActive(challenge: EmailOtpChallenge): boolean {
    return (
      challenge.consumedAt === null &&
      challenge.expiresAt.getTime() > Date.now() &&
      challenge.attemptsCount < challenge.maxAttempts
    );
  }

  clear(): void {
    this.challenges.clear();
  }
}

/**
 * [DEVELOPMENT / TEST ONLY] In-memory password reset grant repository.
 */
export class MockPasswordResetGrantRepository
  implements IPasswordResetGrantRepository
{
  private grantsByHash: Map<string, PasswordResetGrant> = new Map();

  constructor(
    private readonly userRepo: MockUserRepository,
    private readonly refreshTokenRepo: MockRefreshTokenRepository
  ) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MockPasswordResetGrantRepository cannot be used in production environments.');
    }
  }

  async create(data: {
    userId: string;
    grantHash: string;
    expiresAt: Date;
  }): Promise<PasswordResetGrant> {
    if (!data.grantHash) {
      throw new ValidationError('Password reset grant hash is required.');
    }
    if (this.grantsByHash.has(data.grantHash)) {
      throw new ConflictError('Password reset grant already exists.');
    }

    const grant: PasswordResetGrant = {
      id: crypto.randomUUID(),
      userId: data.userId,
      grantHash: data.grantHash,
      expiresAt: new Date(data.expiresAt),
      consumedAt: null,
      createdAt: new Date(),
    };
    this.grantsByHash.set(grant.grantHash, grant);
    return { ...grant };
  }

  async findActiveByHash(grantHash: string): Promise<PasswordResetGrant | null> {
    const grant = this.grantsByHash.get(grantHash);
    if (
      !grant ||
      grant.consumedAt !== null ||
      grant.expiresAt.getTime() <= Date.now()
    ) {
      return null;
    }
    return { ...grant };
  }

  async consume(grantHash: string): Promise<boolean> {
    const grant = this.grantsByHash.get(grantHash);
    if (
      !grant ||
      grant.consumedAt !== null ||
      grant.expiresAt.getTime() <= Date.now()
    ) {
      return false;
    }
    grant.consumedAt = new Date();
    return true;
  }

  async completePasswordReset(
    grantHash: string,
    passwordHash: string
  ): Promise<boolean> {
    if (!passwordHash) {
      throw new ValidationError('Password hash is required.');
    }

    const grant = this.grantsByHash.get(grantHash);
    if (
      !grant ||
      grant.consumedAt !== null ||
      grant.expiresAt.getTime() <= Date.now() ||
      !this.userRepo.setPasswordHashForReset(grant.userId, passwordHash)
    ) {
      return false;
    }

    this.refreshTokenRepo.revokeAllForUserSync(grant.userId);
    const consumedAt = new Date();
    for (const userGrant of this.grantsByHash.values()) {
      if (userGrant.userId === grant.userId && userGrant.consumedAt === null) {
        userGrant.consumedAt = consumedAt;
      }
    }
    return true;
  }

  clear(): void {
    this.grantsByHash.clear();
  }
}

/**
 * [DEVELOPMENT / TEST ONLY] In-memory fixed-window password login counters.
 */
export class MockPasswordLoginRateLimitRepository
  implements IPasswordLoginRateLimitRepository
{
  private readonly buckets = new Map<
    string,
    { windowStartedAt: number; attempts: number }
  >();

  constructor() {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'MockPasswordLoginRateLimitRepository cannot be used in production environments.'
      );
    }
  }

  async recordAttempt(
    emailBucketHash: string,
    ipBucketHash?: string
  ): Promise<{ emailAttempts: number; ipAttempts: number | null }> {
    this.validateBucketHash(emailBucketHash);
    if (ipBucketHash) this.validateBucketHash(ipBucketHash);
    const now = Date.now();
    const emailAttempts = this.incrementBucket('EMAIL', emailBucketHash, now);
    const ipAttempts = ipBucketHash
      ? this.incrementBucket('IP', ipBucketHash, now)
      : null;
    return { emailAttempts, ipAttempts };
  }

  private incrementBucket(
    type: 'EMAIL' | 'IP',
    hash: string,
    now: number
  ): number {
    const key = `${type}:${hash}`;
    const bucket = this.buckets.get(key);
    if (!bucket || bucket.windowStartedAt <= now - 60 * 60 * 1000) {
      this.buckets.set(key, { windowStartedAt: now, attempts: 1 });
      return 1;
    }
    bucket.attempts += 1;
    return bucket.attempts;
  }

  private validateBucketHash(hash: string): void {
    if (!/^[a-f0-9]{64}$/.test(hash)) {
      throw new ValidationError('Login rate-limit bucket hash is invalid.');
    }
  }

  clear(): void {
    this.buckets.clear();
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

  constructor(private readonly userRepo?: MockUserRepository) {
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
    expectedPasswordHash?: string;
  }): Promise<RefreshToken> {
    if (
      data.expectedPasswordHash !== undefined &&
      (!this.userRepo ||
        !this.userRepo.isPasswordHashCurrentForSession(
          data.userId,
          data.expectedPasswordHash
        ))
    ) {
      throw new AppError(
        'Email or password is incorrect.',
        401,
        'EMAIL_PASSWORD_INVALID_CREDENTIALS'
      );
    }

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
    this.revokeAllForUserSync(userId);
  }

  revokeAllForUserSync(userId: string): void {
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
