ALTER TABLE users
  ADD COLUMN phone_verified_at TIMESTAMPTZ;

ALTER TABLE patient_profiles
  ADD COLUMN emergency_contact VARCHAR(20),
  ADD CONSTRAINT chk_patient_profiles_emergency_contact_format
    CHECK (
      emergency_contact IS NULL OR
      emergency_contact ~ '^[+][1-9][0-9]{9,14}$'
    );
