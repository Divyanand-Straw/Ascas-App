/**
 * Authentication module domain types and interfaces.
 */

export type UserRole = 'PATIENT';

export type UserStatus = 'ACTIVE' | 'SUSPENDED' | 'PENDING_VERIFICATION';

export type OtpPurpose = 'LOGIN' | 'REGISTRATION' | 'LINKED_MEMBER';

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
  role: UserRole;
  status: UserStatus;
  createdAt: Date;
  updatedAt: Date;
}

export interface PatientProfile {
  id: string;
  userId: string;
  firstName: string;
  lastName: string;
  dob?: Date | null;
  gender?: string | null;
  clinicMrn?: string | null;
  preferredLanguage: PreferredLanguage;
  linkingStatus: LinkingStatus;
  createdAt: Date;
  updatedAt: Date;
}

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
    role: UserRole;
    status: UserStatus;
  };
  profile?: {
    id: string;
    firstName: string;
    lastName: string;
    dob?: string | null;
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
