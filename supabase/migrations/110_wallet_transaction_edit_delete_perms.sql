-- ============================================================
-- 110_wallet_transaction_edit_delete_perms.sql
--
-- families.perm_edit / perm_delete (033_family_permissions.sql) were
-- exposed to the client (FamilyModel.canEdit/canDelete) but never
-- enforced anywhere — not in the UI, and not in RLS. The old
-- "transactions: wallet access" policy was FOR ALL, so any wallet
-- member could edit/delete any transaction in a shared wallet
-- regardless of the family's "Admin only" setting.
--
-- Splits that single FOR ALL policy into per-command policies, adding
-- perm_edit/perm_delete checks (bypassed for admins and personal-wallet
-- owners) to UPDATE/DELETE while leaving SELECT/INSERT unchanged.
-- ============================================================

-- Returns TRUE if auth.uid() may edit transactions in wallet [wid] —
-- always true for the personal-wallet owner or a family admin;
-- for other family members, only when perm_edit = 'any_member'.
CREATE OR REPLACE FUNCTION wallet_can_edit(wid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    wallet_admin(wid)
    OR (
      wallet_accessible(wid)
      AND EXISTS (
        SELECT 1 FROM wallets w
        JOIN families f ON f.id = w.family_id
        WHERE w.id = wid AND f.perm_edit = 'any_member'
      )
    );
$$;

-- Same as wallet_can_edit but for perm_delete.
CREATE OR REPLACE FUNCTION wallet_can_delete(wid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT
    wallet_admin(wid)
    OR (
      wallet_accessible(wid)
      AND EXISTS (
        SELECT 1 FROM wallets w
        JOIN families f ON f.id = w.family_id
        WHERE w.id = wid AND f.perm_delete = 'any_member'
      )
    );
$$;

DROP POLICY IF EXISTS "transactions: wallet access" ON transactions;

CREATE POLICY "transactions: select" ON transactions
  FOR SELECT USING (wallet_accessible(wallet_id));

CREATE POLICY "transactions: insert" ON transactions
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

-- 'request'-type rows get an exception: accepting/rejecting a payment
-- request (status update) is a response to a request addressed to you,
-- not an edit of someone else's entry, so it isn't gated by perm_edit —
-- any wallet member can respond, same as before this migration.
CREATE POLICY "transactions: update" ON transactions
  FOR UPDATE USING (
    wallet_can_edit(wallet_id)
    OR (type = 'request' AND wallet_accessible(wallet_id))
  );

CREATE POLICY "transactions: delete" ON transactions
  FOR DELETE USING (wallet_can_delete(wallet_id));
