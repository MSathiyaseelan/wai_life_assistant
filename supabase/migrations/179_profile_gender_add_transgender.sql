-- ============================================================
--  WAI Life Assistant — Profile: add "transgender" as a gender option
-- ============================================================

ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_gender_check;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_gender_check
  CHECK (gender IS NULL OR gender IN ('male', 'female', 'transgender', 'other'));
