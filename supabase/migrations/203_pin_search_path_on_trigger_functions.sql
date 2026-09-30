-- ============================================================
-- 203_pin_search_path_on_trigger_functions.sql
--
-- "Delete Account" failed with "Failed to delete account". The
-- delete-account edge function calls auth.admin.deleteUser(), which
-- GoTrue runs as its own database role — and that role doesn't have
-- `public` in its search_path (same root cause as 081, which fixed the
-- signup side).
--
-- Deleting the auth user cascades through profiles → wallets →
-- transactions → …, firing our triggers inside GoTrue's session. Any
-- trigger function without a pinned search_path that names a table
-- unqualified then fails, rolling the whole delete back:
--
--   sync_wallet_balance()    AFTER DELETE ON transactions
--     → UPDATE wallets …     ERROR: relation "wallets" does not exist
--   revoke_admin_top_tier()  AFTER DELETE ON admin_users
--     → UPDATE profiles …    (staff/QA accounts)
--   enforce_meal_weeks_ahead() declares a `plan_limits` variable, which
--     doesn't resolve either.
--
-- So deletion broke for any user with a transaction. 126 didn't catch
-- this because it was verified with DELETE FROM auth.users in the SQL
-- editor, which runs as postgres (public is on its search_path).
--
-- Fix: pin search_path on every trigger function in public that doesn't
-- have one yet, rather than patching the three above one by one — the
-- setting also covers whatever helper functions a trigger calls.
-- `extensions` is included because that is what these functions resolve
-- against today when fired from a normal app request.
-- ============================================================

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS fn
    FROM pg_proc p
    WHERE p.pronamespace = 'public'::regnamespace
      AND p.prorettype = 'trigger'::regtype
      AND NOT EXISTS (
        SELECT 1 FROM unnest(COALESCE(p.proconfig, '{}')) c
        WHERE c LIKE 'search_path=%'
      )
      -- Leave functions that belong to an extension alone.
      AND NOT EXISTS (
        SELECT 1 FROM pg_depend d
        WHERE d.objid = p.oid AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, extensions', r.fn);
  END LOOP;
END $$;
