-- ============================================================
-- 209_function_gifts_table.sql
--
-- Functions Module: Gold / Silver and Gifts tab persistence.
--
-- Gifts received at a completed function (gold, silver, household,
-- clothing, gift items, gift cards) only ever lived in memory on
-- FunctionModel.gifts and were lost on every reload. Same fix as
-- vendors (208): a backing table following the function_dishes
-- pattern (184) — shared wallet-collaboration RLS (177), soft delete,
-- the row-move guard (206), and the purge / delete_my_account sweeps.
--
-- purge_old_deleted_records() and delete_my_account() are recreated
-- from their latest versions (208) with function_gifts added.
-- ============================================================

CREATE TABLE IF NOT EXISTS function_gifts (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  function_id       UUID          REFERENCES functions_my(id) ON DELETE CASCADE,
  user_id           UUID          REFERENCES auth.users(id) ON DELETE CASCADE,
  guest_name        TEXT          NOT NULL,
  gift_type         TEXT          NOT NULL DEFAULT 'gold',
  guest_place       TEXT,
  phone             TEXT,
  relation          TEXT,
  cash_amount       NUMERIC,
  gold_grams        NUMERIC,
  silver_grams      NUMERIC,
  item_description  TEXT,
  gift_card_value   TEXT,
  notes             TEXT,
  deleted_at        TIMESTAMPTZ,
  created_at        TIMESTAMPTZ   DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_function_gifts_function   ON function_gifts (function_id);
CREATE INDEX IF NOT EXISTS idx_function_gifts_deleted_at ON function_gifts (deleted_at) WHERE deleted_at IS NOT NULL;

ALTER TABLE function_gifts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "function_gifts: wallet members read" ON function_gifts;
CREATE POLICY "function_gifts: wallet members read" ON function_gifts
  FOR SELECT USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

DROP POLICY IF EXISTS "function_gifts: wallet members insert" ON function_gifts;
CREATE POLICY "function_gifts: wallet members insert" ON function_gifts
  FOR INSERT WITH CHECK (auth.uid() = user_id AND (function_row_wallet_accessible(function_id) OR function_id IS NULL));

DROP POLICY IF EXISTS "function_gifts: wallet members update" ON function_gifts;
CREATE POLICY "function_gifts: wallet members update" ON function_gifts
  FOR UPDATE USING (auth.uid() = user_id OR function_row_wallet_accessible(function_id));

DROP POLICY IF EXISTS "function_gifts: creator or admin delete" ON function_gifts;
CREATE POLICY "function_gifts: creator or admin delete" ON function_gifts
  FOR DELETE USING (auth.uid() = user_id OR function_row_wallet_admin(function_id));

-- ── Row-move guard (same as the other function_* tables, from 206) ─────────
DROP TRIGGER IF EXISTS guard_move_function_id ON function_gifts;
CREATE TRIGGER guard_move_function_id
  BEFORE UPDATE OF function_id ON function_gifts
  FOR EACH ROW EXECUTE FUNCTION guard_row_move('function_id', 'function');

-- ── Recycle-bin purge job (latest version, from 208) ────────────────────────
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
  DELETE FROM wardrobe_outfit_logs WHERE deleted_at < v_cutoff;
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
  DELETE FROM function_essentials         WHERE deleted_at < v_cutoff;
  DELETE FROM function_return_gifts       WHERE deleted_at < v_cutoff;
  DELETE FROM function_dishes             WHERE deleted_at < v_cutoff;
  DELETE FROM function_vendors            WHERE deleted_at < v_cutoff;
  DELETE FROM function_gifts              WHERE deleted_at < v_cutoff;
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

-- ── delete_my_account() (latest version, from 208) ──────────────────────────
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
  UPDATE function_essentials
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
  UPDATE function_vendors
    SET deleted_at = v_now
    WHERE deleted_at IS NULL
      AND function_id IN (SELECT id FROM functions_my WHERE user_id = v_uid);
  UPDATE function_gifts
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
