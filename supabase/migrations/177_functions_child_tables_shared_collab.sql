-- ============================================================
--  Functions Module: extend Shared Collaboration to child tables
--
--  091_functions_shared_collab.sql widened functions_my/
--  functions_upcoming from single-owner RLS to wallet_accessible(),
--  so a family member sees a planned function shared on the family
--  wallet. But the 4 tables that hold that function's planning
--  data — function_participants, function_clothing_families,
--  function_bridal_essentials, function_return_gifts — were never
--  touched and still carry their original 0410 "user_own" policy
--  (auth.uid() = user_id), scoped to whichever member happened to
--  add each row.
--
--  Net effect: the function itself shows up for every family
--  member, but anything one member adds under Participants/
--  Clothing Gifts/Bridal Essentials/Return Gift is invisible to
--  everyone else — e.g. a "Clothing Gifts" family entry added by
--  one member never appears for the others, even though they can
--  see the function it belongs to.
--
--  These tables have no wallet_id column of their own (only
--  function_id → functions_my.id), so accessibility is resolved by
--  joining to the parent function's wallet_id.
-- ============================================================

CREATE OR REPLACE FUNCTION function_row_wallet_accessible(fid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM functions_my fm
    WHERE fm.id = fid AND functions_wallet_accessible(fm.wallet_id)
  );
$$;

CREATE OR REPLACE FUNCTION function_row_wallet_admin(fid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM functions_my fm
    WHERE fm.id = fid AND functions_wallet_admin(fm.wallet_id)
  );
$$;

-- ── function_participants ────────────────────────────────────
DROP POLICY IF EXISTS "user_own" ON function_participants;

CREATE POLICY "function_participants: wallet members read" ON function_participants
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_participants: wallet members insert" ON function_participants
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

CREATE POLICY "function_participants: wallet members update" ON function_participants
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_participants: creator or admin delete" ON function_participants
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));

-- ── function_clothing_families ───────────────────────────────
DROP POLICY IF EXISTS "user_own" ON function_clothing_families;

CREATE POLICY "function_clothing_families: wallet members read" ON function_clothing_families
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_clothing_families: wallet members insert" ON function_clothing_families
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

CREATE POLICY "function_clothing_families: wallet members update" ON function_clothing_families
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_clothing_families: creator or admin delete" ON function_clothing_families
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));

-- ── function_bridal_essentials ───────────────────────────────
DROP POLICY IF EXISTS "user_own" ON function_bridal_essentials;

CREATE POLICY "function_bridal_essentials: wallet members read" ON function_bridal_essentials
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_bridal_essentials: wallet members insert" ON function_bridal_essentials
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

CREATE POLICY "function_bridal_essentials: wallet members update" ON function_bridal_essentials
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_bridal_essentials: creator or admin delete" ON function_bridal_essentials
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));

-- ── function_return_gifts ────────────────────────────────────
DROP POLICY IF EXISTS "user_own" ON function_return_gifts;

CREATE POLICY "function_return_gifts: wallet members read" ON function_return_gifts
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_return_gifts: wallet members insert" ON function_return_gifts
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

CREATE POLICY "function_return_gifts: wallet members update" ON function_return_gifts
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_return_gifts: creator or admin delete" ON function_return_gifts
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));
