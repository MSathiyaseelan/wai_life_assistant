-- ============================================================
-- 129_add_hub_scope.sql
--
-- Default Scope settings covered Wallet/Pantry/PlanIt but not MyHub /
-- FamilyHub — the underlying nav code (bottom_nav_screen.dart) already
-- reads/writes an AppPrefs 'hub_scope' key for it, but nothing persisted
-- it to the profile for cross-device sync since the column never existed.
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS hub_scope TEXT NOT NULL DEFAULT 'personal';
