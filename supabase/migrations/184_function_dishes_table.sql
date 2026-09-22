-- ============================================================
--  Functions Module: Dishes (catering menu) tab
--
--  New tab alongside Clothing Gifts (Planned) / Gifts (Completed)
--  for tracking the catering menu planned/served at a function.
--  Mirrors function_return_gifts in shape and follows the shared
--  wallet-collaboration RLS pattern from 177 directly (no separate
--  single-owner -> shared migration needed since this table is new).
-- ============================================================

CREATE TABLE IF NOT EXISTS function_dishes (
  id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id   UUID          REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id       UUID          REFERENCES auth.users(id) ON DELETE CASCADE,
  dish_name     TEXT          NOT NULL,
  category      TEXT,
  vendor        TEXT,
  notes         TEXT,
  approx_cost   NUMERIC,
  quantity      INTEGER       DEFAULT 1,
  deleted_at    TIMESTAMPTZ,
  created_at    TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_function_dishes_function   ON function_dishes (function_id);
CREATE INDEX IF NOT EXISTS idx_function_dishes_deleted_at ON function_dishes (deleted_at) WHERE deleted_at IS NOT NULL;

ALTER TABLE function_dishes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "function_dishes: wallet members read" ON function_dishes
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_dishes: wallet members insert" ON function_dishes
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

CREATE POLICY "function_dishes: wallet members update" ON function_dishes
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

CREATE POLICY "function_dishes: creator or admin delete" ON function_dishes
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));

-- ── Wire into recycle-bin purge job (latest version, from 135) ──────────────
CREATE OR REPLACE FUNCTION purge_old_deleted_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cutoff TIMESTAMPTZ;
BEGIN
  SELECT NOW() - (COALESCE(
    (SELECT value FROM app_config WHERE key = 'recycle_bin_retention_days'),
    '30'
  ) || ' days')::interval
  INTO v_cutoff;

  DELETE FROM wishes               WHERE deleted_at < v_cutoff;
  DELETE FROM reminders            WHERE deleted_at < v_cutoff;
  DELETE FROM notes                WHERE deleted_at < v_cutoff;
  DELETE FROM wardrobe_items       WHERE deleted_at < v_cutoff;
  DELETE FROM health_medications   WHERE deleted_at < v_cutoff;
  DELETE FROM health_doctors       WHERE deleted_at < v_cutoff;
  DELETE FROM health_documents     WHERE deleted_at < v_cutoff;
  DELETE FROM health_appointments  WHERE deleted_at < v_cutoff;
  DELETE FROM health_vitals        WHERE deleted_at < v_cutoff;
  DELETE FROM health_vaccinations  WHERE deleted_at < v_cutoff;
  DELETE FROM health_insurance     WHERE deleted_at < v_cutoff;
  DELETE FROM family_members       WHERE deleted_at < v_cutoff;
  DELETE FROM functions_my         WHERE deleted_at < v_cutoff;
  DELETE FROM functions_upcoming   WHERE deleted_at < v_cutoff;
  DELETE FROM functions_attended   WHERE deleted_at < v_cutoff;
  DELETE FROM function_participants       WHERE deleted_at < v_cutoff;
  DELETE FROM function_moi_entries        WHERE deleted_at < v_cutoff;
  DELETE FROM function_clothing_families  WHERE deleted_at < v_cutoff;
  DELETE FROM function_bridal_essentials  WHERE deleted_at < v_cutoff;
  DELETE FROM function_return_gifts       WHERE deleted_at < v_cutoff;
  DELETE FROM function_dishes             WHERE deleted_at < v_cutoff;
  DELETE FROM attended_function_groups    WHERE deleted_at < v_cutoff;
  DELETE FROM item_locator_containers WHERE deleted_at < v_cutoff;
  DELETE FROM item_locator_items      WHERE deleted_at < v_cutoff;
  DELETE FROM tx_groups           WHERE deleted_at < v_cutoff;
  DELETE FROM bills               WHERE deleted_at < v_cutoff;
  DELETE FROM wallet_budgets      WHERE deleted_at < v_cutoff;
  DELETE FROM recipes             WHERE deleted_at < v_cutoff;
  DELETE FROM meal_entries        WHERE deleted_at < v_cutoff;
  DELETE FROM meal_reactions      WHERE deleted_at < v_cutoff;
  DELETE FROM tasks               WHERE deleted_at < v_cutoff;
  DELETE FROM special_days        WHERE deleted_at < v_cutoff;
  DELETE FROM split_groups        WHERE deleted_at < v_cutoff;
  DELETE FROM split_group_transactions WHERE deleted_at < v_cutoff;
  DELETE FROM member_food_prefs   WHERE deleted_at < v_cutoff;
END;
$$;

-- ── Wire into delete_my_account() (latest version, from 154) ────────────────
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
  UPDATE function_dishes
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

REVOKE ALL ON FUNCTION delete_my_account() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION delete_my_account() TO authenticated;
