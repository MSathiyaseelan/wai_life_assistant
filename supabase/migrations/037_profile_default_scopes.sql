-- ============================================================
--  WAI Life Assistant — Profile: Default Scope preferences
-- ============================================================

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS wallet_scope TEXT NOT NULL DEFAULT 'personal',
  ADD COLUMN IF NOT EXISTS pantry_scope TEXT NOT NULL DEFAULT 'personal',
  ADD COLUMN IF NOT EXISTS planit_scope TEXT NOT NULL DEFAULT 'personal';
