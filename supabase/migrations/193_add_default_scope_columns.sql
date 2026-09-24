-- ============================================================
-- 193_add_default_scope_columns.sql
--
-- ProfileService.updateDefaultScopes() writes wallet_scope, pantry_scope
-- and planit_scope alongside hub_scope (129_add_hub_scope.sql), but no
-- migration ever created those three columns — so on any database where
-- they weren't added by hand (PROD), the whole profiles update failed with
-- "column does not exist" and the Default Scope sheet showed "Saved on this
-- device, but failed to sync to your account". Worse, the dashboard's
-- profile sync then read the missing columns as null and reset the local
-- choice back to 'personal'.
--
-- IF NOT EXISTS keeps this a no-op on databases that already have them.
-- ============================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS wallet_scope TEXT NOT NULL DEFAULT 'personal';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS pantry_scope TEXT NOT NULL DEFAULT 'personal';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS planit_scope TEXT NOT NULL DEFAULT 'personal';
