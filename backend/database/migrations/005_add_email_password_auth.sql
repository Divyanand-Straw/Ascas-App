-- Migration: 005_add_email_password_auth.sql
-- Description: Adds optional email/password credentials and persistent email challenges

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email VARCHAR(320),
  ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

ALTER TABLE users
  ADD CONSTRAINT chk_users_email_normalized
    CHECK (
      email IS NULL OR (
        email <> '' AND email = LOWER(BTRIM(
          email,
          E' \t\n\r\f' || CHR(11) ||
          U&'\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'
        ))
      )
    ),
  ADD CONSTRAINT chk_users_email_verified
    CHECK (email_verified_at IS NULL OR email IS NOT NULL),
  ADD CONSTRAINT chk_users_password_requires_verified_email
    CHECK (password_hash IS NULL OR email_verified_at IS NOT NULL);

CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_unique
  ON users (LOWER(BTRIM(
    email,
    E' \t\n\r\f' || CHR(11) ||
    U&'\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'
  )))
  WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS email_otp_challenges (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  email VARCHAR(320) NOT NULL,
  purpose VARCHAR(32) NOT NULL
    CHECK (purpose IN ('ACCOUNT_ACTIVATION', 'PASSWORD_RESET', 'EMAIL_CHANGE')),
  otp_hash VARCHAR(64) NOT NULL,
  attempts_count INT NOT NULL DEFAULT 0 CHECK (attempts_count >= 0),
  max_attempts INT NOT NULL DEFAULT 3 CHECK (max_attempts > 0),
  expires_at TIMESTAMPTZ NOT NULL,
  resend_after TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  ip_address VARCHAR(45),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_email_otp_email_normalized
    CHECK (
      email <> '' AND email = LOWER(BTRIM(
        email,
        E' \t\n\r\f' || CHR(11) ||
        U&'\00A0\1680\2000\2001\2002\2003\2004\2005\2006\2007\2008\2009\200A\2028\2029\202F\205F\3000\FEFF'
      ))
    ),
  CONSTRAINT chk_email_otp_user_binding
    CHECK (purpose = 'PASSWORD_RESET' OR user_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_email_otp_challenges_email_purpose
  ON email_otp_challenges(email, purpose, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_otp_challenges_user_purpose
  ON email_otp_challenges(user_id, purpose, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_otp_challenges_expires_at
  ON email_otp_challenges(expires_at);
CREATE INDEX IF NOT EXISTS idx_email_otp_challenges_ip
  ON email_otp_challenges(ip_address);

CREATE TABLE IF NOT EXISTS password_reset_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  grant_hash VARCHAR(128) NOT NULL UNIQUE,
  expires_at TIMESTAMPTZ NOT NULL,
  consumed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_grants_user
  ON password_reset_grants(user_id);
CREATE INDEX IF NOT EXISTS idx_password_reset_grants_expires_at
  ON password_reset_grants(expires_at);
