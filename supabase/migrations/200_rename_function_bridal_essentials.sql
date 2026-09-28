-- ============================================================
-- 200_rename_function_bridal_essentials.sql
--
-- The "Bridal Essentials" tab is now a generic "Essentials" tab usable
-- for any function (not just weddings). Renames the backing table
-- function_bridal_essentials → function_essentials, along with its
-- index, constraints and RLS policies.
--
-- PL/pgSQL bodies are not rewritten by ALTER TABLE ... RENAME, so
-- purge_old_deleted_records() (latest: 189) and delete_my_account()
-- (latest: 198) are recreated with the new name. Both are otherwise
-- unchanged.
--
-- Older app builds still query function_bridal_essentials, so a
-- security_invoker view with that name is left behind (simple single-
-- table view → auto-updatable, RLS of the base table applies). Drop it
-- once those builds are no longer in use.
-- ============================================================

ALTER TABLE function_bridal_essentials RENAME TO function_essentials;

ALTER INDEX IF EXISTS idx_function_bridal_essentials_deleted_at
  RENAME TO idx_function_essentials_deleted_at;

-- Constraints (pkey, fkeys) keep their old auto-generated names — rename them.
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.function_essentials'::regclass
      AND conname LIKE 'function_bridal_essentials%'
  LOOP
    EXECUTE format('ALTER TABLE function_essentials RENAME CONSTRAINT %I TO %I',
                   r.conname, replace(r.conname, 'function_bridal_essentials', 'function_essentials'));
  END LOOP;

  FOR r IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'function_essentials'
      AND policyname LIKE 'function_bridal_essentials%'
  LOOP
    EXECUTE format('ALTER POLICY %I ON function_essentials RENAME TO %I',
                   r.policyname, replace(r.policyname, 'function_bridal_essentials', 'function_essentials'));
  END LOOP;
END $$;

-- ── Backward-compat view for older app builds ───────────────────────────────
CREATE VIEW function_bridal_essentials
  WITH (security_invoker = true)
  AS SELECT * FROM function_essentials;

GRANT SELECT, INSERT, UPDATE, DELETE ON function_bridal_essentials TO authenticated;

-- ── Recycle-bin purge job (latest version, from 189) ────────────────────────
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

-- ── delete_my_account() (latest version, from 198) ──────────────────────────
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
