-- Migration: 002_add_care_units_and_refine_profiles.sql
-- Description: Refines patient_profiles, drops redundant indexes, and implements Care Units for partner sharing
-- Scope: Schema refinements + 3 new tables (care_units, care_unit_members, care_unit_invitations)

-- ============================================================================
-- 1. REFINEMENTS ON EXISTING MIGRATION 001 TABLES
-- ============================================================================

-- A. Enforce strictly 1:1 relationship between User Account and Patient Profile
ALTER TABLE patient_profiles
  ADD CONSTRAINT patient_profiles_user_id_key UNIQUE (user_id);

-- B. Healthcare Compliance & Audit Protection:
-- Medical profiles must never be hard-deleted via CASCADE.
-- Switch foreign key to ON DELETE RESTRICT.
ALTER TABLE patient_profiles
  DROP CONSTRAINT IF EXISTS patient_profiles_user_id_fkey,
  ADD CONSTRAINT patient_profiles_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT;

-- C. Drop redundant non-unique indexes that duplicate backing UNIQUE constraints
-- (UNIQUE constraints in PostgreSQL automatically create backing unique btree indexes)
DROP INDEX IF EXISTS idx_users_phone;
DROP INDEX IF EXISTS idx_patient_profiles_clinic_mrn;
DROP INDEX IF EXISTS idx_refresh_tokens_token_hash;


-- ============================================================================
-- 2. CREATE CARE UNITS TABLE (Shared IVF Treatment Relationship)
-- ============================================================================
CREATE TABLE IF NOT EXISTS care_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(50) NOT NULL UNIQUE,
  name VARCHAR(100),
  clinic_case_id VARCHAR(100) UNIQUE,
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING_APPROVAL'
    CHECK (status IN ('PENDING_APPROVAL', 'ACTIVE', 'SUSPENDED', 'DISSOLVED')),
  approved_by_clinic BOOLEAN NOT NULL DEFAULT FALSE,
  approved_at TIMESTAMPTZ,
  created_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Strict state consistency constraint:
  -- PENDING_APPROVAL: must be unapproved (approved_by_clinic = FALSE and approved_at IS NULL)
  -- ACTIVE: must be approved by clinic (approved_by_clinic = TRUE and approved_at IS NOT NULL)
  -- SUSPENDED / DISSOLVED: allows previously approved or unapproved historical states
  CONSTRAINT chk_care_units_approval_state CHECK (
    (status = 'PENDING_APPROVAL' AND approved_by_clinic = FALSE AND approved_at IS NULL) OR
    (status = 'ACTIVE' AND approved_by_clinic = TRUE AND approved_at IS NOT NULL) OR
    (status IN ('SUSPENDED', 'DISSOLVED'))
  )
);

CREATE INDEX IF NOT EXISTS idx_care_units_status ON care_units(status);
CREATE INDEX IF NOT EXISTS idx_care_units_created_by ON care_units(created_by_user_id);

-- Auto-update trigger for care_units
DROP TRIGGER IF EXISTS trg_care_units_updated_at ON care_units;
CREATE TRIGGER trg_care_units_updated_at
BEFORE UPDATE ON care_units
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================================
-- 3. CREATE CARE UNIT MEMBERS TABLE (User Membership & Authorization Scope)
-- ============================================================================
CREATE TABLE IF NOT EXISTS care_unit_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- RESTRICT: Retain member audit history. Do not cascade deletions of healthcare relationships.
  care_unit_id UUID NOT NULL REFERENCES care_units(id) ON DELETE RESTRICT,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  member_role VARCHAR(50) NOT NULL DEFAULT 'PRIMARY_PATIENT'
    CHECK (member_role IN ('PRIMARY_PATIENT', 'PARTNER', 'LEGAL_GUARDIAN')),
  member_status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE'
    CHECK (member_status IN ('ACTIVE', 'INACTIVE', 'REMOVED')),
  -- 'FULL' scope removed to prevent broad, unmonitored access to sensitive individual medical records
  access_scope VARCHAR(50) NOT NULL DEFAULT 'SHARED_TREATMENT_ONLY'
    CHECK (access_scope IN ('SHARED_TREATMENT_ONLY', 'READ_ONLY')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Standalone foreign key lookup indexes
CREATE INDEX IF NOT EXISTS idx_care_unit_members_unit ON care_unit_members(care_unit_id);
CREATE INDEX IF NOT EXISTS idx_care_unit_members_user ON care_unit_members(user_id);
CREATE INDEX IF NOT EXISTS idx_care_unit_members_status ON care_unit_members(member_status);

-- Partial Unique Index:
-- Supports members leaving and rejoining over time without losing audit history.
-- Guarantees at most ONE 'ACTIVE' membership per (care_unit_id, user_id) at any given moment.
CREATE UNIQUE INDEX IF NOT EXISTS uq_care_unit_members_active
  ON care_unit_members (care_unit_id, user_id)
  WHERE member_status = 'ACTIVE';

-- Auto-update trigger for care_unit_members
DROP TRIGGER IF EXISTS trg_care_unit_members_updated_at ON care_unit_members;
CREATE TRIGGER trg_care_unit_members_updated_at
BEFORE UPDATE ON care_unit_members
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();


-- ============================================================================
-- 4. CREATE CARE UNIT INVITATIONS TABLE (Expiring, Single-Use Partner Tokens)
-- ============================================================================
CREATE TABLE IF NOT EXISTS care_unit_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  -- RESTRICT: Preserve invitation audit trails even if care unit is deactivated
  care_unit_id UUID NOT NULL REFERENCES care_units(id) ON DELETE RESTRICT,
  inviter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  invitee_phone VARCHAR(20) NOT NULL,
  relationship_type VARCHAR(50) NOT NULL DEFAULT 'SPOUSE'
    CHECK (relationship_type IN ('SPOUSE', 'PARTNER')),
  token_hash VARCHAR(255) NOT NULL UNIQUE,
  status VARCHAR(50) NOT NULL DEFAULT 'PENDING'
    CHECK (status IN ('PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED', 'REVOKED')),
  expires_at TIMESTAMPTZ NOT NULL,
  accepted_at TIMESTAMPTZ,
  accepted_by_user_id UUID REFERENCES users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Lifecycle consistency constraint:
  -- ACCEPTED requires both accepted_at and accepted_by_user_id.
  -- Non-accepted states must have these acceptance fields NULL.
  CONSTRAINT chk_invitations_acceptance_state CHECK (
    (status = 'ACCEPTED' AND accepted_at IS NOT NULL AND accepted_by_user_id IS NOT NULL) OR
    (status != 'ACCEPTED' AND accepted_at IS NULL AND accepted_by_user_id IS NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_care_unit_invitations_unit ON care_unit_invitations(care_unit_id);
CREATE INDEX IF NOT EXISTS idx_care_unit_invitations_phone ON care_unit_invitations(invitee_phone);
CREATE INDEX IF NOT EXISTS idx_care_unit_invitations_status ON care_unit_invitations(status);
CREATE INDEX IF NOT EXISTS idx_care_unit_invitations_expires ON care_unit_invitations(expires_at);

-- Partial Unique Index: Prevents multiple active PENDING invitations for the same care_unit and phone
-- Allows historical invitations (EXPIRED, REVOKED, ACCEPTED) while strictly blocking duplicate active invites
CREATE UNIQUE INDEX IF NOT EXISTS uq_care_unit_invitations_active_pending
  ON care_unit_invitations (care_unit_id, invitee_phone)
  WHERE status = 'PENDING';
