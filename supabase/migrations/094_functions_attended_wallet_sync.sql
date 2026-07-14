-- ═══════════════════════════════════════════════════════════════════════════
-- 094_functions_attended_wallet_sync.sql
--
-- Adds wallet_tx_id to functions_attended so FunctionsService can auto-create
-- a matching Wallet expense (in the user's Personal wallet) the first time a
-- gift amount is recorded on an attended function, without ever creating a
-- duplicate on subsequent edits — the app checks this column before syncing.
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE functions_attended
  ADD COLUMN IF NOT EXISTS wallet_tx_id UUID REFERENCES transactions(id) ON DELETE SET NULL;
