-- ============================================================
-- 135_split_groups_permissions_and_fixes.sql
--
-- Splits (bill-splitting groups) had several gaps found during review:
--
--   1. split_group_transactions / split_shares / split_participants RLS
--      policies were all FOR ALL USING (any linked participant in the
--      group) — no restriction to the expense's own payer or a group
--      admin/creator. Any participant could edit or delete an expense
--      someone else added, directly mark any share "settled" (bypassing
--      the client's admin-only override button, which was UI-only
--      theater with nothing enforcing it server-side), or add/remove/
--      rename other participants.
--
--   2. split_groups itself had the same FOR ALL problem — any
--      participant could rename or delete the whole group, or (once the
--      client gains a "move to wallet" action) reassign its wallet_id.
--
--   3. There was no way to delete a single split expense at all — only
--      add/update existed. Adding deleted_at (soft delete, matching the
--      recycle-bin pattern already used for split_groups itself since
--      migration 085) so a mis-added expense can be removed.
--
--   4. No per-event notification toggle existed for split expenses
--      (notif_wallet_split) — every other Wallet event has one.
--
-- Fix: tier the RLS into per-command policies. SELECT/INSERT stay broad
-- (any participant can view the group and log an expense they paid).
-- UPDATE/DELETE on an expense or its shares is restricted to: the
-- expense's own payer, the specific share's own participant (so they can
-- self-service proof/extension requests), or a group admin/creator
-- override — reusing the existing wallet_admin() helper (003) so a
-- family-wallet split group's admin matches the family's admin, and a
-- personal-wallet split group's sole owner always qualifies.
-- ============================================================

-- ── 1. Soft-delete column for individual split expenses ─────────────────────
ALTER TABLE split_group_transactions ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_sgt_deleted_at ON split_group_transactions (deleted_at) WHERE deleted_at IS NOT NULL;

-- Wire it into the existing recycle-bin purge job (086) alongside
-- split_groups, so soft-deleted expenses actually get hard-deleted after
-- the configured retention window instead of accumulating forever.
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
  DELETE FROM split_group_transactions WHERE deleted_at < v_cutoff;
  DELETE FROM member_food_prefs   WHERE deleted_at < v_cutoff;
END;
$$;

-- ── 2. Notification preference column ────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notif_wallet_split BOOLEAN NOT NULL DEFAULT true;

-- ── 3. Permission helper functions ───────────────────────────────────────────

-- TRUE if auth.uid() created the split group, or is the admin (or
-- personal-wallet owner) of the wallet it belongs to.
CREATE OR REPLACE FUNCTION split_group_can_manage(p_group_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM split_groups sg
    WHERE sg.id = p_group_id
      AND (sg.created_by = auth.uid() OR wallet_admin(sg.wallet_id))
  );
$$;

-- TRUE if auth.uid() is the payer who added this specific expense, or
-- qualifies for split_group_can_manage on its group.
CREATE OR REPLACE FUNCTION split_tx_can_manage(p_tx_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM split_group_transactions sgt
    JOIN split_participants sp ON sp.id = sgt.added_by_id
    WHERE sgt.id = p_tx_id
      AND (sp.user_id = auth.uid() OR split_group_can_manage(sgt.group_id))
  );
$$;

-- TRUE if auth.uid() is the debtor on this specific share, the payer of
-- its expense, or qualifies for split_group_can_manage — covers every
-- legitimate status transition (self-settle, request/grant extension,
-- payer confirms, admin override) while excluding an unrelated
-- third participant in the same group.
CREATE OR REPLACE FUNCTION split_share_can_manage(p_share_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM split_shares ss
    JOIN split_group_transactions sgt ON sgt.id = ss.transaction_id
    JOIN split_participants sp_share ON sp_share.id = ss.participant_id
    JOIN split_participants sp_payer ON sp_payer.id = sgt.added_by_id
    WHERE ss.id = p_share_id
      AND (
        sp_share.user_id = auth.uid()
        OR sp_payer.user_id = auth.uid()
        OR split_group_can_manage(sgt.group_id)
      )
  );
$$;

-- ── 4. split_groups ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "split_groups: participant access" ON split_groups;

CREATE POLICY "split_groups: select" ON split_groups
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM split_participants sp WHERE sp.group_id = split_groups.id AND sp.user_id = auth.uid())
    OR created_by = auth.uid()
  );

CREATE POLICY "split_groups: insert" ON split_groups
  FOR INSERT WITH CHECK (created_by = auth.uid());

-- WITH CHECK on wallet_accessible (not wallet_admin) so a "move to
-- wallet" update is also blocked from landing in a wallet the caller
-- has no access to at all, even though they passed the USING check via
-- being creator/admin of the CURRENT wallet.
CREATE POLICY "split_groups: update" ON split_groups
  FOR UPDATE
  USING (created_by = auth.uid() OR wallet_admin(wallet_id))
  WITH CHECK (wallet_accessible(wallet_id));

CREATE POLICY "split_groups: delete" ON split_groups
  FOR DELETE USING (created_by = auth.uid() OR wallet_admin(wallet_id));

-- ── 5. split_participants ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "split_participants: group members" ON split_participants;

CREATE POLICY "split_participants: select" ON split_participants
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM split_participants sp2 WHERE sp2.group_id = split_participants.group_id AND sp2.user_id = auth.uid())
    OR EXISTS (SELECT 1 FROM split_groups sg WHERE sg.id = split_participants.group_id AND sg.created_by = auth.uid())
  );

CREATE POLICY "split_participants: insert" ON split_participants
  FOR INSERT WITH CHECK (split_group_can_manage(group_id));

CREATE POLICY "split_participants: update" ON split_participants
  FOR UPDATE USING (split_group_can_manage(group_id));

CREATE POLICY "split_participants: delete" ON split_participants
  FOR DELETE USING (split_group_can_manage(group_id));

-- ── 6. split_group_transactions ───────────────────────────────────────────
DROP POLICY IF EXISTS "split_group_tx: group members" ON split_group_transactions;

CREATE POLICY "split_group_tx: select" ON split_group_transactions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM split_participants sp WHERE sp.group_id = split_group_transactions.group_id AND sp.user_id = auth.uid())
  );

CREATE POLICY "split_group_tx: insert" ON split_group_transactions
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM split_participants sp WHERE sp.group_id = split_group_transactions.group_id AND sp.user_id = auth.uid())
  );

CREATE POLICY "split_group_tx: update" ON split_group_transactions
  FOR UPDATE USING (split_tx_can_manage(id));

CREATE POLICY "split_group_tx: delete" ON split_group_transactions
  FOR DELETE USING (split_tx_can_manage(id));

-- ── 7. split_shares ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "split_shares: group members" ON split_shares;

CREATE POLICY "split_shares: select" ON split_shares
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM split_group_transactions sgt
      JOIN split_participants sp ON sp.group_id = sgt.group_id
      WHERE sgt.id = split_shares.transaction_id AND sp.user_id = auth.uid()
    )
  );

CREATE POLICY "split_shares: insert" ON split_shares
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM split_group_transactions sgt
      JOIN split_participants sp ON sp.group_id = sgt.group_id
      WHERE sgt.id = split_shares.transaction_id AND sp.user_id = auth.uid()
    )
  );

CREATE POLICY "split_shares: update" ON split_shares
  FOR UPDATE USING (split_share_can_manage(id));

CREATE POLICY "split_shares: delete" ON split_shares
  FOR DELETE USING (split_tx_can_manage(transaction_id));
