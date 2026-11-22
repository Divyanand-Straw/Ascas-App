-- Migration: 010_add_developer_email_test_otp_purpose.sql
-- Description: Adds an account-independent purpose for staging email delivery tests.

ALTER TABLE email_otp_challenges
  DROP CONSTRAINT IF EXISTS email_otp_challenges_purpose_check,
  ADD CONSTRAINT email_otp_challenges_purpose_check
    CHECK (
      purpose IN (
        'ACCOUNT_ACTIVATION',
        'PASSWORD_RESET',
        'EMAIL_CHANGE',
        'DEVELOPER_EMAIL_TEST'
      )
    ),
  DROP CONSTRAINT IF EXISTS chk_email_otp_user_binding,
  ADD CONSTRAINT chk_email_otp_user_binding
    CHECK (
      purpose IN ('PASSWORD_RESET', 'DEVELOPER_EMAIL_TEST')
      OR user_id IS NOT NULL
    );
