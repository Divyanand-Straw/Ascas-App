-- Migration: 003_align_care_units_approval_state.sql
-- Description: Align care_units approval constraint with approved_at nullability and clean redundant indexes

-- 1. Strengthen care_units approval state constraint
ALTER TABLE care_units
  DROP CONSTRAINT IF EXISTS chk_care_units_approval_state,
  ADD CONSTRAINT chk_care_units_approval_state CHECK (
    (status = 'PENDING_APPROVAL' AND approved_by_clinic = FALSE AND approved_at IS NULL) OR
    (status = 'ACTIVE' AND approved_by_clinic = TRUE AND approved_at IS NOT NULL) OR
    (status IN ('SUSPENDED', 'DISSOLVED'))
  );

-- 2. Drop redundant low-cardinality boolean index
DROP INDEX IF EXISTS idx_care_units_approved;

-- 3. Drop redundant non-unique index on user_id (backed by patient_profiles_user_id_key)
DROP INDEX IF EXISTS idx_patient_profiles_user_id;

