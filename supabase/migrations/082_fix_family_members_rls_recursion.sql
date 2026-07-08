-- ─────────────────────────────────────────────────────────────────────────────
-- 082_fix_family_members_rls_recursion.sql
-- family_members' own RLS policies (001_wallet_schema.sql) query
-- family_members from inside a policy ON family_members — a raw
-- self-referencing subquery, which Postgres cannot evaluate and fails
-- immediately with:
--   ERROR: infinite recursion detected in policy for relation "family_members"
--
-- This doesn't just break direct queries against family_members — ANY table
-- whose policy checks family membership via a raw subquery (not wrapped in a
-- SECURITY DEFINER helper) transitively triggers this, including wallets
-- ("wallets: family members" / "wallets: family admin manage") and families.
-- Because Postgres evaluates every permissive policy on INSERT (combined via
-- OR), even a *personal* wallet insert was hitting this through the
-- family-wallet policy's subquery into family_members.
--
-- Fix: mirror the wallet_accessible() pattern already used elsewhere
-- (003_pantry_schema.sql) — a SECURITY DEFINER helper bypasses RLS on the
-- table it queries internally, breaking the recursive cycle. This is the
-- single root-cause fix; wallets/families' own policies don't need to change
-- since they'll now succeed once family_members itself resolves cleanly.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION is_family_member(wid_family_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = wid_family_id AND user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION is_family_admin(wid_family_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = wid_family_id AND user_id = auth.uid() AND role = 'admin'
  );
$$;

DROP POLICY IF EXISTS "family_members: members can view" ON family_members;
CREATE POLICY "family_members: members can view" ON family_members
  FOR SELECT USING (is_family_member(family_id));

DROP POLICY IF EXISTS "family_members: admin can manage" ON family_members;
CREATE POLICY "family_members: admin can manage" ON family_members
  FOR ALL USING (is_family_admin(family_id));
