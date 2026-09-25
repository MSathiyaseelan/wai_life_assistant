-- ============================================================
-- 198_fix_delete_my_account_missing_user_id.sql
--
-- delete_my_account() (latest: 189) filtered five tables on a user_id
-- column they don't have — verified against prod's
-- information_schema — so "Delete my account" always failed with
--   column "user_id" does not exist
-- and, being one transaction, deleted nothing. Same bug class as 154.
--
--   recipes, meal_entries      → have created_by, not user_id
--   notes, reminders, wishes   → only wallet_id; resolve the caller's
--                                rows via their personal wallet(s), as
--                                154 did for bills / wallet_budgets.
--                                Family-wallet notes/reminders/wishes are
--                                shared content with no author column,
--                                so they stay with the family.
--
-- Everything else is unchanged from 189.
-- ============================================================

CREATE OR REPLACE FUNCTION delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid  UUID := auth.uid();
  v_now  TIMESTAMPTZ := NOW();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- ── Wallet / finance ────────────────────────────────────────────────────
  UPDATE tx_groups SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  UPDATE bills SET deleted_at = v_now
  WHERE deleted_at IS NULL
    AND wallet_id IN (SELECT id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE);

  UPDATE wallet_budgets SET deleted_at = v_now
  WHERE deleted_at IS NULL
    AND wallet_id IN (SELECT id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE);

  -- ── PlanIt ──────────────────────────────────────────────────────────────
  -- No user_id column — scoped by the caller's personal wallet(s).
  UPDATE wishes SET deleted_at = v_now
  WHERE deleted_at IS NULL
    AND wallet_id IN (SELECT id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE);

  UPDATE reminders SET deleted_at = v_now
  WHERE deleted_at IS NULL
    AND wallet_id IN (SELECT id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE);

  UPDATE notes SET deleted_at = v_now
  WHERE deleted_at IS NULL
    AND wallet_id IN (SELECT id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE);

  -- ── Lifestyle ────────────────────────────────────────────────────────────
  UPDATE wardrobe_items      SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE wardrobe_outfit_logs SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_medications  SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_doctors      SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_documents    SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_appointments SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_vitals       SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_vaccinations SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_insurance    SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Item Locator ─────────────────────────────────────────────────────────
  UPDATE item_locator_containers SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE item_locator_items      SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Functions (events) ──────────────────────────────────────────────────
  UPDATE functions_my      SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE functions_upcoming SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE functions_attended SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  -- Sub-tables: soft-delete rows under user-owned functions
  UPDATE function_participants
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_moi_entries
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_clothing_families
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_bridal_essentials
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_return_gifts
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_dishes
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);

  -- ── Pantry ───────────────────────────────────────────────────────────────
  -- recipes / meal_entries record the author in created_by, not user_id.
  UPDATE recipes      SET deleted_at = v_now WHERE created_by = v_uid AND deleted_at IS NULL;
  UPDATE meal_entries SET deleted_at = v_now WHERE created_by = v_uid AND deleted_at IS NULL;
  UPDATE meal_reactions SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Family ───────────────────────────────────────────────────────────────
  UPDATE family_members SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Profile (hard-delete — no soft-delete column on profiles) ────────────
  DELETE FROM profiles WHERE id = v_uid;
END;
$$;

REVOKE ALL ON FUNCTION delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_my_account() TO authenticated;
