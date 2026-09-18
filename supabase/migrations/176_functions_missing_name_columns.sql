-- ─────────────────────────────────────────────────────────────────────────────
-- 176_functions_missing_name_columns.sql
-- Same class of bug as 175 (functions_my.icon): the Dart models send fields
-- the tables never actually had columns for.
--
-- functions_upcoming.family_name — UpcomingFunction.toJson() sends it
-- whenever familyName is set, failing every time with PGRST204 (confirmed
-- in error_logs, 8 occurrences on 2026-09-16).
--
-- functions_attended.person_name / family_name — AttendedFunction.toJson()
-- sends both whenever set, but this hasn't surfaced in error_logs yet
-- (nobody has specified a person/family name on an attended function so
-- far) — it would fail identically the first time someone does.
--
-- functions_my.is_planned — FunctionModel.toJson() sends this UNCONDITIONALLY
-- on every save (unlike the others above, which are conditional). 175 only
-- added the missing `icon` column; this one was hiding behind it — every
-- "Our Functions" save would have failed again on this column the very
-- next attempt, with a fresh confusing error.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE functions_upcoming ADD COLUMN IF NOT EXISTS family_name TEXT;
ALTER TABLE functions_attended ADD COLUMN IF NOT EXISTS person_name TEXT;
ALTER TABLE functions_attended ADD COLUMN IF NOT EXISTS family_name TEXT;
ALTER TABLE functions_my       ADD COLUMN IF NOT EXISTS is_planned BOOLEAN NOT NULL DEFAULT false;
