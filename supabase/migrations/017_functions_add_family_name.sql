-- ============================================================
--  Add family_name to functions_upcoming and functions_attended
--  Also add person_name to functions_attended (to match upcoming)
-- ============================================================

ALTER TABLE functions_upcoming
  ADD COLUMN IF NOT EXISTS family_name TEXT;

ALTER TABLE functions_attended
  ADD COLUMN IF NOT EXISTS person_name TEXT,
  ADD COLUMN IF NOT EXISTS family_name TEXT;
