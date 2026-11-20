-- migration_person_approval.sql
-- Adds publish/approval columns to wanted_persons so admins can hide
-- wanted-person cases from the mobile app the same way they already do for
-- missing_persons. Also adds a case_code index on both tables for faster
-- case-lookup searches in the admin UI.

-- 1) Approval/publish columns on wanted_persons (mirror missing_persons).
ALTER TABLE wanted_persons
  ADD COLUMN IF NOT EXISTS is_approved      BOOLEAN DEFAULT TRUE,
  ADD COLUMN IF NOT EXISTS approved_by      UUID REFERENCES users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS approved_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- 2) Helpful indexes for the admin "Unpublished / Drafts" filters.
CREATE INDEX IF NOT EXISTS idx_wanted_approved ON wanted_persons(is_approved);
CREATE INDEX IF NOT EXISTS idx_missing_case_code ON missing_persons(case_code);
CREATE INDEX IF NOT EXISTS idx_wanted_case_code  ON wanted_persons(case_code);
