-- ============================================================
-- 148_food_prefs_own_member_edit.sql
--
-- member_food_prefs UPDATE/DELETE policies gate on created_by = auth.uid()
-- OR wallet_can_edit/delete(wallet_id) (admin, or family perm_edit =
-- 'any_member'). But the row's created_by is whoever first saved it —
-- often an admin setting up the whole family's prefs at once — not
-- necessarily the member the row is about. A non-admin member trying to
-- edit their OWN food prefs (member_id = auth.uid()) then fails RLS unless
-- perm_edit happens to be 'any_member', even though the client's Family
-- Food Guide UI already treats "own record" as editable
-- (isAdmin || m.id == currentUserId).
--
-- Add member_id = auth.uid() as an explicit OR branch so a member can
-- always manage their own record, independent of who created it.
-- ============================================================

DROP POLICY IF EXISTS "food_prefs: own or admin update" ON member_food_prefs;
CREATE POLICY "food_prefs: own or admin update" ON member_food_prefs
  FOR UPDATE
  USING (
    created_by = auth.uid()
    OR member_id = auth.uid()::text
    OR wallet_can_edit(wallet_id)
  );

DROP POLICY IF EXISTS "food_prefs: own or admin delete" ON member_food_prefs;
CREATE POLICY "food_prefs: own or admin delete" ON member_food_prefs
  FOR DELETE
  USING (
    created_by = auth.uid()
    OR member_id = auth.uid()::text
    OR wallet_can_delete(wallet_id)
  );
