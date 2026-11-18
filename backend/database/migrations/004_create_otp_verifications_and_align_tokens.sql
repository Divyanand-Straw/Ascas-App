-- Migration: 004_create_otp_verifications_and_align_tokens.sql
-- Description: Add persistent OTP challenges and align refresh_tokens with rotation tracking
-- Scope: 1 new table (otp_verifications) + column alignment on refresh_tokens

-- ============================================================================
-- 1. CREATE OTP VERIFICATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS otp_verifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) NOT NULL,
  otp_hash VARCHAR(64) NOT NULL,
  purpose VARCHAR(32) NOT NULL CHECK (purpose IN ('LOGIN', 'REGISTRATION', 'LINKED_MEMBER')),
  attempts_count INT NOT NULL DEFAULT 0,
  max_attempts INT NOT NULL DEFAULT 3,
  consumed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ NOT NULL,
  ip_address VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance and lookup speed
CREATE INDEX IF NOT EXISTS idx_otp_verifications_phone_purpose ON otp_verifications(phone, purpose);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_expires_at ON otp_verifications(expires_at);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_created_at ON otp_verifications(created_at);
CREATE INDEX IF NOT EXISTS idx_otp_verifications_ip ON otp_verifications(ip_address);


-- ============================================================================
-- 2. ALIGN REFRESH TOKENS WITH ROTATION TRACKING
-- ============================================================================
ALTER TABLE refresh_tokens
  ADD COLUMN IF NOT EXISTS replaced_by_token_id UUID REFERENCES refresh_tokens(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_replaced_by ON refresh_tokens(replaced_by_token_id);
