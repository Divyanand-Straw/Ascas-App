-- Add an independent mobile OTP purpose for the Existing Patient flow.
-- This migration preserves all existing challenge rows and does not run automatically.
ALTER TABLE otp_verifications
  DROP CONSTRAINT IF EXISTS otp_verifications_purpose_check;

ALTER TABLE otp_verifications
  ADD CONSTRAINT otp_verifications_purpose_check
  CHECK (
    purpose IN (
      'LOGIN',
      'REGISTRATION',
      'EXISTING_PATIENT',
      'LINKED_MEMBER'
    )
  );
