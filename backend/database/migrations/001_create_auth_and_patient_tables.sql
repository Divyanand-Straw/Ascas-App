-- Migration: 001_create_auth_and_patient_tables.sql
-- Description: Creates initial authentication and patient profile infrastructure
-- Target Tables: users, patient_profiles, refresh_tokens

-- 1. Helper trigger function for automatically updating updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. USERS TABLE
-- Handles authentication identity.
-- No required password field because mobile OTP is the confirmed authentication mechanism.
-- Role is constrained to PATIENT for this patient-facing mobile backend.
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) NOT NULL UNIQUE,
  status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION')),
  role VARCHAR(50) NOT NULL DEFAULT 'PATIENT' CHECK (role = 'PATIENT'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- Auto-update trigger for users
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 3. PATIENT PROFILES TABLE
-- Keeps patient profile details strictly separate from authentication credentials.
-- User relationship is indexed without a rigid UNIQUE constraint on user_id,
-- preserving flexibility until partner/spouse account cardinality is confirmed.
-- Clinic MRN is nullable until clinic verification.
CREATE TABLE IF NOT EXISTS patient_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  dob DATE,
  gender VARCHAR(20),
  clinic_mrn VARCHAR(100) UNIQUE,
  preferred_language VARCHAR(10) NOT NULL DEFAULT 'en' CHECK (preferred_language IN ('en', 'ta')),
  linking_status VARCHAR(50) NOT NULL DEFAULT 'SUBMITTED' 
    CHECK (linking_status IN ('SUBMITTED', 'VERIFICATION_PENDING', 'LINKED', 'ACTION_REQUIRED', 'UNLINKED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for patient_profiles
CREATE INDEX IF NOT EXISTS idx_patient_profiles_user_id ON patient_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_patient_profiles_clinic_mrn ON patient_profiles(clinic_mrn);
CREATE INDEX IF NOT EXISTS idx_patient_profiles_linking_status ON patient_profiles(linking_status);
CREATE INDEX IF NOT EXISTS idx_patient_profiles_language ON patient_profiles(preferred_language);

-- Auto-update trigger for patient_profiles
DROP TRIGGER IF EXISTS trg_patient_profiles_updated_at ON patient_profiles;
CREATE TRIGGER trg_patient_profiles_updated_at
BEFORE UPDATE ON patient_profiles
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- 4. REFRESH TOKENS TABLE
-- Secure session storage; stores cryptographic hash of token (never plaintext).
-- Supports immediate session revocation (via revoked_at timestamp) and device metadata.
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  device_info VARCHAR(255),
  ip_address VARCHAR(45),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for refresh_tokens
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked_at ON refresh_tokens(revoked_at);

