-- Migration: 006_email_password_login_rate_limits.sql
-- Description: Adds persistent fixed-window counters for email/password login throttling

CREATE TABLE IF NOT EXISTS password_login_rate_limits (
  bucket_type VARCHAR(8) NOT NULL
    CHECK (bucket_type IN ('EMAIL', 'IP')),
  bucket_hash CHAR(64) NOT NULL
    CHECK (bucket_hash ~ '^[a-f0-9]{64}$'),
  window_started_at TIMESTAMPTZ NOT NULL,
  attempts_count INT NOT NULL
    CHECK (attempts_count > 0),
  PRIMARY KEY (bucket_type, bucket_hash)
);

CREATE INDEX IF NOT EXISTS idx_password_login_rate_limits_window_started
  ON password_login_rate_limits(window_started_at);
