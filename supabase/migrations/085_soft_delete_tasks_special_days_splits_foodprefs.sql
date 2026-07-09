-- ─────────────────────────────────────────────────────────────────────────────
-- 085_soft_delete_tasks_special_days_splits_foodprefs.sql
-- Converts four remaining hard-delete tables to the app's standard
-- soft-delete + Recycle Bin pattern (see 065_soft_delete_all.sql):
--   - tasks, special_days: PlanIt siblings of reminders/wishes/notes, which
--     already soft-delete — these two were the only stragglers.
--   - split_groups: cascades to split_participants / split_group_transactions
--     / split_shares via ON DELETE CASCADE. Soft-deleting the group instead
--     of hard-deleting it leaves those children intact until the 30-day
--     purge issues a real DELETE, which still cascades correctly.
--   - member_food_prefs: per-family-member allergy/preference data.
--
-- Also fixes deleteTransaction() moving from hard DELETE to soft delete:
-- transactions already had a deleted_at column (034_soft_delete_family.sql)
-- and fetchTransactions() already filtered on it, but trg_sync_wallet_balance
-- only fired on INSERT/DELETE, not UPDATE — so soft-deleting a transaction
-- would silently stop rolling back the wallet's cash/online totals. Extends
-- the trigger to also fire on UPDATE and treat a deleted_at transition as
-- the equivalent DELETE (rollback) / INSERT (reapply, for restore).
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE tasks              ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE special_days       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE split_groups       ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE member_food_prefs  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_tasks_deleted_at             ON tasks             (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_special_days_deleted_at      ON special_days      (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_split_groups_deleted_at      ON split_groups      (deleted_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_member_food_prefs_deleted_at ON member_food_prefs (deleted_at) WHERE deleted_at IS NOT NULL;

-- Extend the daily purge job (066_schedule_purge_deleted.sql) to also
-- hard-delete these four tables' rows 30 days after soft-delete. Restates
-- the full body from 065_soft_delete_all.sql plus the new tables, since
-- CREATE OR REPLACE FUNCTION requires the complete function body.
CREATE OR REPLACE FUNCTION purge_old_deleted_records()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM wishes               WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM reminders            WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM notes                WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM wardrobe_items       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_medications   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_doctors       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_documents     WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_appointments  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_vitals        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_vaccinations  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM health_insurance     WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM family_members       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_my         WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_upcoming   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM functions_attended   WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_participants       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_moi_entries        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_clothing_families  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_bridal_essentials  WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM function_return_gifts       WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM attended_function_groups    WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM item_locator_containers WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM item_locator_items      WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM tx_groups           WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM bills               WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM wallet_budgets      WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM recipes             WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM meal_entries        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM meal_reactions      WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM tasks               WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM special_days        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM split_groups        WHERE deleted_at < NOW() - INTERVAL '30 days';
  DELETE FROM member_food_prefs   WHERE deleted_at < NOW() - INTERVAL '30 days';
END;
$$;

-- Extend the wallet-balance trigger to also fire on UPDATE, handling
-- deleted_at transitions the same way INSERT/DELETE were already handled.
-- Non-deleted-related field edits (amount/type/pay_mode changes on an
-- otherwise-active transaction) are intentionally left as-is — that's a
-- pre-existing separate behavior, unchanged here.
CREATE OR REPLACE FUNCTION sync_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type IN ('income','borrow') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in  = cash_in  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    ELSIF NEW.type IN ('expense','lend') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out  = cash_out  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.type IN ('income','borrow') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in  = cash_in  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    ELSIF OLD.type IN ('expense','lend') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out  = cash_out  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
      -- Soft-delete: same rollback as a hard DELETE, using OLD values.
      IF OLD.type IN ('income','borrow') THEN
        IF OLD.pay_mode = 'cash' THEN
          UPDATE wallets SET cash_in  = cash_in  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
        ELSIF OLD.pay_mode = 'online' THEN
          UPDATE wallets SET online_in = online_in - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
        END IF;
      ELSIF OLD.type IN ('expense','lend') THEN
        IF OLD.pay_mode = 'cash' THEN
          UPDATE wallets SET cash_out  = cash_out  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
        ELSIF OLD.pay_mode = 'online' THEN
          UPDATE wallets SET online_out = online_out - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
        END IF;
      END IF;
    ELSIF OLD.deleted_at IS NOT NULL AND NEW.deleted_at IS NULL THEN
      -- Restore: same reapply as a fresh INSERT, using NEW values.
      IF NEW.type IN ('income','borrow') THEN
        IF NEW.pay_mode = 'cash' THEN
          UPDATE wallets SET cash_in  = cash_in  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
        ELSIF NEW.pay_mode = 'online' THEN
          UPDATE wallets SET online_in = online_in + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
        END IF;
      ELSIF NEW.type IN ('expense','lend') THEN
        IF NEW.pay_mode = 'cash' THEN
          UPDATE wallets SET cash_out  = cash_out  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
        ELSIF NEW.pay_mode = 'online' THEN
          UPDATE wallets SET online_out = online_out + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
        END IF;
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_wallet_balance ON transactions;
CREATE TRIGGER trg_sync_wallet_balance
  AFTER INSERT OR UPDATE OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION sync_wallet_balance();
