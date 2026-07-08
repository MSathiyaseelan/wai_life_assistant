-- ─────────────────────────────────────────────────────────────────────────────
-- 081_fix_handle_new_user_search_path.sql
-- handle_new_user() (001_wallet_schema.sql) is SECURITY DEFINER but never set
-- an explicit search_path and referenced `profiles` unqualified. GoTrue's own
-- database role doesn't have `public` in its default search_path, so the
-- AFTER INSERT ON auth.users trigger failed with:
--   ERROR: relation "profiles" does not exist (SQLSTATE 42P01)
-- ...even though public.profiles obviously exists — every admin-created user
-- (and therefore every real OTP/Firebase signup) was failing outright.
-- Fix: schema-qualify the table and pin search_path on the function itself.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, phone)
  VALUES (NEW.id, NEW.phone)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
