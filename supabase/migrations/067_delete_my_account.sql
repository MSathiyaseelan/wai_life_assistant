-- ============================================================
--  delete_my_account() — soft-deletes every row belonging to the
--  calling user across all 28 soft-deletable tables, then removes
--  the profile row.  The edge function delete-account calls this
--  first, then removes the auth.users record via the admin API.
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
  UPDATE tx_groups      SET deleted_at = v_now WHERE owner_id  = v_uid AND deleted_at IS NULL;
  UPDATE bills          SET deleted_at = v_now WHERE owner_id  = v_uid AND deleted_at IS NULL;
  UPDATE wallet_budgets SET deleted_at = v_now WHERE owner_id  = v_uid AND deleted_at IS NULL;

  -- ── PlanIt ──────────────────────────────────────────────────────────────
  UPDATE wishes    SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE reminders SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE notes     SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Lifestyle ────────────────────────────────────────────────────────────
  UPDATE wardrobe_items     SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_medications SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_doctors     SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_documents   SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_appointments SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_vitals      SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_vaccinations SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE health_insurance   SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

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

  -- ── Pantry ───────────────────────────────────────────────────────────────
  UPDATE recipes     SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE meal_entries SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;
  UPDATE meal_reactions SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Family ───────────────────────────────────────────────────────────────
  UPDATE family_members SET deleted_at = v_now WHERE user_id = v_uid AND deleted_at IS NULL;

  -- ── Profile (hard-delete — no soft-delete column on profiles) ────────────
  DELETE FROM profiles WHERE id = v_uid;
END;
$$;

-- Only the owner (via RLS + SECURITY DEFINER) can call this.
REVOKE ALL ON FUNCTION delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_my_account() TO authenticated;
