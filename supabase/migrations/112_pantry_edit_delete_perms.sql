-- ============================================================
-- 112_pantry_edit_delete_perms.sql
--
-- Same gap class as fixed in Wallet
-- (110_wallet_transaction_edit_delete_perms.sql): families.perm_edit /
-- perm_delete were never honored for recipes / meal_entries /
-- member_food_prefs. Their UPDATE+DELETE policies only ever allowed the
-- creator or a wallet admin, even when perm_edit/perm_delete =
-- 'any_member' (the default) — no other member could touch someone
-- else's entry, which doesn't match what "any_member" is supposed to
-- mean. (These policies predate 033_family_permissions.sql, which added
-- the columns.)
--
-- Fix: the creator can always manage their own entry (unchanged —
-- nobody's complained about that and taking it away would be a
-- regression); beyond that, access is gated by wallet_can_edit() /
-- wallet_can_delete() (the SECURITY DEFINER helpers introduced in 110)
-- — a wallet admin is always allowed, any other member only when
-- perm_edit/perm_delete = 'any_member'.
--
-- grocery_items UPDATE is deliberately left unconditional (NOT gated
-- here) — marking items in-stock/to-buy, adjusting quantity while
-- cooking, and "mark bought" are routine shared shopping-list
-- housekeeping, not content edits; gating them would block normal
-- day-to-day use of a shared basket under an admin_only edit setting.
-- Only grocery_items DELETE (removing an item from the list entirely)
-- gets the same creator/wallet_can_delete gate as the other tables.
-- ============================================================

-- ── recipes ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "recipes: creator or admin update" ON recipes;
CREATE POLICY "recipes: creator or admin update" ON recipes
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_can_edit(wallet_id)
  );

DROP POLICY IF EXISTS "recipes: creator or admin delete" ON recipes;
CREATE POLICY "recipes: creator or admin delete" ON recipes
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_can_delete(wallet_id)
  );

-- ── meal_entries ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "meal_entries: creator or admin update" ON meal_entries;
CREATE POLICY "meal_entries: creator or admin update" ON meal_entries
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_can_edit(wallet_id)
  );

DROP POLICY IF EXISTS "meal_entries: creator or admin delete" ON meal_entries;
CREATE POLICY "meal_entries: creator or admin delete" ON meal_entries
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_can_delete(wallet_id)
  );

-- ── grocery_items ──────────────────────────────────────────────────────
-- UPDATE intentionally left unconditional — see note above.
DROP POLICY IF EXISTS "grocery_items: creator or admin delete" ON grocery_items;
CREATE POLICY "grocery_items: creator or admin delete" ON grocery_items
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_can_delete(wallet_id)
  );

-- ── member_food_prefs ────────────────────────────────────────────────────
DROP POLICY IF EXISTS "food_prefs: own or admin update" ON member_food_prefs;
CREATE POLICY "food_prefs: own or admin update" ON member_food_prefs
  FOR UPDATE USING (
    created_by = auth.uid() OR wallet_can_edit(wallet_id)
  );

DROP POLICY IF EXISTS "food_prefs: own or admin delete" ON member_food_prefs;
CREATE POLICY "food_prefs: own or admin delete" ON member_food_prefs
  FOR DELETE USING (
    created_by = auth.uid() OR wallet_can_delete(wallet_id)
  );
