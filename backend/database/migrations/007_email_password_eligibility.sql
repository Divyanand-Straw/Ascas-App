-- Migration: 007_email_password_eligibility.sql
-- Description: Persist fail-closed eligibility for email/password credentials.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS email_password_eligibility VARCHAR(32) NOT NULL
    DEFAULT 'IDENTITY_REQUIRED';

ALTER TABLE users
  ADD CONSTRAINT chk_users_email_password_eligibility
    CHECK (
      email_password_eligibility IN (
        'IDENTITY_REQUIRED',
        'NEW_PATIENT_ELIGIBLE',
        'PARTNER_INELIGIBLE'
      )
    );
