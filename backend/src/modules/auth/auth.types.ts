/**
 * Authentication module domain types and interfaces.
 */

export type UserRole = 'PATIENT';

export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'PENDING_VERIFICATION';

export type OtpPurpose =
  | 'LOGIN'
  | 'REGISTRATION'
  | 'EXISTING_PATIENT'
  | 'LINKED_MEMBER';

export type EmailPasswordEligibility =
  | 'IDENTITY_REQUIRED'
  | 'NEW_PATIENT_ELIGIBLE'
  | 'PARTNER_INELIGIBLE';

export type EmailOtpPurpose =
  | 'ACCOUNT_ACTIVATION'
  | 'PASSWORD_RESET'
  | 'EMAIL_CHANGE'
  | 'DEVELOPER_EMAIL_TEST';

export type PreferredLanguage = 'en' | 'ta';

export type LinkingStatus =
  | 'SUBMITTED'
  | 'VERIFICATION_PENDING'
  | 'LINKED'
  | 'ACTION_REQUIRED'
  | 'UNLINKED';

export interface User {
  id: string;
  phone: string;
  email: string | null;
  emailVerifiedAt: Date | null;
  role: UserRole;
  status: UserStatus;
  emailPasswordEligibility: EmailPasswordEligibility;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserCredentials {
  user: User;
  passwordHash: string | null;
}

export const normalizeEmailAddress = (email: string): string =>
  email.trim().toLowerCase();

export interface PatientProfile {
  id: string;
  userId: string;
  firstName: string;
  lastName: string;
  dob?: Date | null;
  gender?: string | null;
  emergencyContact?: string | null;
  clinicMrn?: string | null;
  preferredLanguage: PreferredLanguage;
  linkingStatus: LinkingStatus;
  createdAt: Date;
  updatedAt: Date;
}

export const serializeDateOfBirth = (
  dateOfBirth: Date | null | undefined
): string | null => {
  if (!dateOfBirth || !Number.isFinite(dateOfBirth.getTime())) return null;
  return dateOfBirth.toISOString().slice(0, 10);
};

export interface OtpChallenge {
  id: string;
  phone: string;
  otpHash: string;
  purpose: OtpPurpose;
  attemptsCount: number;
  maxAttempts: number;
  expiresAt: Date;
  consumedAt?: Date | null;
  ipAddress?: string;
  createdAt: Date;
}

export interface EmailOtpChallenge {
  id: string;
  userId: string | null;
  email: string;
  otpHash: string;
  purpose: EmailOtpPurpose;
  attemptsCount: number;
  maxAttempts: number;
  expiresAt: Date;
  resendAfter: Date;
  consumedAt: Date | null;
  ipAddress?: string;
  createdAt: Date;
}

export interface PasswordResetGrant {
  id: string;
  userId: string;
  grantHash: string;
  expiresAt: Date;
  consumedAt: Date | null;
  createdAt: Date;
}

export interface RefreshToken {
  id: string;
  userId: string;
  tokenHash: string;
  deviceInfo?: string;
  ipAddress?: string;
  expiresAt: Date;
  revokedAt?: Date | null;
  createdAt: Date;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  expiresIn: number; // in seconds, e.g. 900 (15 min)
}

export interface AuthSession {
  user: {
    id: string;
    phone: string;
    email: string | null;
    role: UserRole;
    status: UserStatus;
  };
  profile?: {
    id: string;
    userId: string;
    firstName: string;
    lastName: string;
    dob?: string | null;
    gender?: string | null;
    emergencyContact?: string | null;
    clinicMrn?: string | null;
    preferredLanguage: PreferredLanguage;
    linkingStatus: LinkingStatus;
  } | null;
  tokens: AuthTokens;
  isNewUser: boolean;
  hasCompletedProfile: boolean;
}

export interface TokenPayload {
  sub: string;
  phone: string;
  role: UserRole;
  status: UserStatus;
  profileId?: string | null;
  hasCompletedProfile: boolean;
  tokenType: 'access';
  iat?: number;
  exp?: number;
}
