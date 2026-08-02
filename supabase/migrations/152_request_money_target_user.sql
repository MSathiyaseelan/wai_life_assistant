-- ============================================================
-- 152_request_money_target_user.sql
--
-- "Request Money" transactions (type='request') had no way to identify WHO
-- the request targets — 'person' is free text (a typed name / contact
-- name), not a link to a real account. As a result:
--   1. SELECT policy fell back to wallet_accessible(wallet_id), showing
--      every family member every request in the wallet, not just the
--      requestor and the person being asked.
--   2. UPDATE policy had an explicit `(type = 'request' AND
--      wallet_accessible(wallet_id))` carve-out (presumably meant to let
--      the recipient accept/reject) that actually let ANY wallet member
--      edit/accept/reject ANY request, not just the one it's for.
--
-- Adds target_user_id so a request can be scoped to a specific family
-- member's real account (populated by the client once "Person" becomes a
-- family-member picker instead of free text/contacts — see the Dart
-- changes alongside this migration). Existing rows keep target_user_id
-- NULL (no backfill — per-request decision, this data is still test data)
-- so they're visible only to their requestor/admin going forward, not
-- retroactively matched to anyone.
-- ============================================================

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_target_user_id ON transactions(target_user_id);

-- ── select ──────────────────────────────────────────────────────────────
-- Non-request rows keep full wallet visibility. Request rows are visible
-- only to the requestor, the specific target (once linked), or a wallet
-- admin (oversight, consistent with other family-management permissions).
DROP POLICY IF EXISTS "transactions: select" ON transactions;
CREATE POLICY "transactions: select" ON transactions
  FOR SELECT
  USING (
    CASE
      WHEN type = 'request' THEN
        user_id = auth.uid()
        OR target_user_id = auth.uid()
        OR wallet_admin(wallet_id)
      ELSE
        wallet_accessible(wallet_id)
    END
  );

-- ── update ──────────────────────────────────────────────────────────────
-- Replaces the "any wallet member can update any request" carve-out with
-- "only the specific target can respond to/edit their own request".
DROP POLICY IF EXISTS "transactions: update" ON transactions;
CREATE POLICY "transactions: update" ON transactions
  FOR UPDATE
  USING (
    user_id = auth.uid()
    OR wallet_admin(wallet_id)
    OR (type = 'request' AND target_user_id = auth.uid())
  );
