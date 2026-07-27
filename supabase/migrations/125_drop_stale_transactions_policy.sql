-- ============================================================
-- 125_drop_stale_transactions_policy.sql
--
-- Found during a dev-vs-QA schema audit: dev still had the original
-- catch-all "transactions: wallet members can manage" ALL-command policy
-- (any wallet member can edit/delete any transaction) alongside the
-- fine-grained per-command policies introduced in
-- 110_wallet_transaction_edit_delete_perms.sql (creator-or-perm_edit
-- gating). RLS policies are OR'd, so this leftover policy silently
-- bypassed 110's restriction entirely on dev. QA never had this stale
-- policy (it was already clean) — dropping it here to match.
-- ============================================================

DROP POLICY IF EXISTS "transactions: wallet members can manage" ON transactions;
