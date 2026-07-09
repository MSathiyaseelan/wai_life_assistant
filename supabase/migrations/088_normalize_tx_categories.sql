-- ─────────────────────────────────────────────────────────────────────────────
-- 088_normalize_tx_categories.sql
-- Transaction categories had no single source of truth: chat quick-add,
-- bank SMS import, the NLP parser, and the manual edit sheet each wrote raw
-- strings straight to transactions.category with no shared validation, and
-- user_tx_categories' UNIQUE(user_id, name, tx_type) is an exact-string
-- match — so "Food", "food", and "🍕 Food" could all exist as distinct
-- category rows/values.
--
-- This adds a normalized_name column used for case-insensitive matching at
-- the application layer (WalletService.resolveCategoryName, wired into the
-- single addTransaction()/updateTransaction() choke point that every write
-- path already goes through). Deliberately forward-only: this does NOT
-- rewrite existing transactions.category or wallet_budgets.category values,
-- and does NOT add a hard UNIQUE constraint on normalized_name (some users
-- may already have pre-existing case-duplicate rows; a hard constraint
-- would fail this migration for them). New writes are normalized going
-- forward; old data is untouched until edited.
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE user_tx_categories ADD COLUMN IF NOT EXISTS normalized_name TEXT;

UPDATE user_tx_categories
SET normalized_name = lower(trim(regexp_replace(name, '[^\w\s]', '', 'g')))
WHERE normalized_name IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_tx_categories_normalized
  ON user_tx_categories(user_id, tx_type, normalized_name);
