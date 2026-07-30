-- ============================================================
-- 139_wallet_transactions_creator_or_admin.sql
--
-- Wallet transactions were gated by wallet_can_edit()/wallet_can_delete(),
-- which fall back to the family's perm_edit/perm_delete "Any member"
-- setting (perm_edit defaults to 'any_member'). That let any family
-- member edit or delete anyone else's transaction, not just their own —
-- unlike Pantry/PlanIt, which already gate on `created_by = auth.uid()`
-- in addition to the wallet_can_edit/delete check.
--
-- Wallet money entries are more sensitive than a pantry note or a planned
-- task, so this drops the perm_edit/perm_delete "Any member" bypass for
-- transactions specifically and replaces it with a flat creator-or-admin
-- rule. Pantry/PlanIt/MyHub keep using wallet_can_edit/wallet_can_delete
-- unchanged — this migration only touches the "transactions" policies.
-- ============================================================

DROP POLICY IF EXISTS "transactions: update" ON transactions;
DROP POLICY IF EXISTS "transactions: delete" ON transactions;

-- 'request'-type rows keep their exception: accepting/rejecting a payment
-- request is a response to a request addressed to you, not an edit of
-- someone else's entry, so any wallet member may still update its status.
CREATE POLICY "transactions: update" ON transactions
  FOR UPDATE USING (
    user_id = auth.uid()
    OR wallet_admin(wallet_id)
    OR (type = 'request' AND wallet_accessible(wallet_id))
  );

CREATE POLICY "transactions: delete" ON transactions
  FOR DELETE USING (
    user_id = auth.uid()
    OR wallet_admin(wallet_id)
  );
