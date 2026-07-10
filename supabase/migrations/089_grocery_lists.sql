-- ─────────────────────────────────────────────────────────────────────────────
-- 089_grocery_lists.sql
-- Grocery Lists — persist "Create List" snapshots from the Pantry To Buy tab
-- as history, and let items be linked back to the list they were bought
-- from. Mirrors the tx_groups pattern (032_tx_groups.sql): a lightweight
-- group table + a nullable FK column on the existing item table, rather
-- than a separate snapshot copy — so marking an item bought from a list
-- view is the same underlying grocery_items update used everywhere else
-- (in_stock=true, to_buy=false), and it's instantly reflected in the live
-- In Stock / To Buy tabs too.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS grocery_lists (
  id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id  UUID        NOT NULL REFERENCES wallets(id)  ON DELETE CASCADE,
  created_by UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  name       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_grocery_lists_wallet ON grocery_lists(wallet_id);
CREATE INDEX IF NOT EXISTS idx_grocery_lists_deleted_at ON grocery_lists(deleted_at) WHERE deleted_at IS NOT NULL;

ALTER TABLE grocery_lists ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "grocery_lists: wallet members read" ON grocery_lists;
CREATE POLICY "grocery_lists: wallet members read" ON grocery_lists
  FOR SELECT USING (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "grocery_lists: wallet members insert" ON grocery_lists;
CREATE POLICY "grocery_lists: wallet members insert" ON grocery_lists
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id) AND created_by = auth.uid());

DROP POLICY IF EXISTS "grocery_lists: wallet members update" ON grocery_lists;
CREATE POLICY "grocery_lists: wallet members update" ON grocery_lists
  FOR UPDATE USING (wallet_accessible(wallet_id));

-- Link grocery_items → the list they were added to (nullable; SET NULL if
-- the list is later hard-purged so the item itself isn't affected).
ALTER TABLE grocery_items
  ADD COLUMN IF NOT EXISTS list_id UUID REFERENCES grocery_lists(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_grocery_items_list ON grocery_items(list_id);

-- Register in the soft-delete purge job (configurable retention via
-- app_config.recycle_bin_retention_days, see 086_configurable_recycle_bin_retention.sql).
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
  DELETE FROM member_food_prefs   WHERE deleted_at < v_cutoff;
  DELETE FROM grocery_lists       WHERE deleted_at < v_cutoff;
END;
$$;
