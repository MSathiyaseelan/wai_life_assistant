-- ============================================================
-- Align profiles.plan values with subscription_plans.plan_key
-- Old: 'Free' | 'Plus' | 'Family'
-- New: 'personal_free' | 'family_plus' | 'family_pro'
-- ============================================================

UPDATE profiles SET plan = 'personal_free' WHERE plan = 'Free';
UPDATE profiles SET plan = 'family_plus'   WHERE plan = 'Plus';
UPDATE profiles SET plan = 'family_pro'    WHERE plan = 'Family';

ALTER TABLE profiles
  ALTER COLUMN plan SET DEFAULT 'personal_free';
