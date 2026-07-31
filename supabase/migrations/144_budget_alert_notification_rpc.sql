-- ============================================================
-- 144_budget_alert_notification_rpc.sql
--
-- WalletService.checkAndAlertBudgets does a raw client INSERT into
-- notifications for each family member when a budget crosses 80%/100%.
-- Same problem as the split reminder case (143): 072_rls_security_fixes.sql
-- removed the blanket INSERT policy on notifications, so this insert has
-- been silently failing under RLS ever since — every member's insert
-- throws, checkAndAlertBudgets's own "anySucceeded" fallback notices and
-- releases the alert-month claim so it retries next time, but it never
-- actually succeeds, so budget threshold alerts have never really been
-- delivered to family members.
--
-- Adds a narrow SECURITY DEFINER RPC for this case, scoped to family
-- membership (unlike the split reminder RPC, a budget always belongs to
-- one wallet's family — no personal-wallet or non-family-participant case
-- to account for here).
-- ============================================================

CREATE OR REPLACE FUNCTION send_budget_alert_notification(
  p_recipient_user_id  UUID,
  p_family_id          UUID,
  p_category           TEXT,
  p_amount             NUMERIC,
  p_title              TEXT,
  p_actor_emoji         TEXT
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Not a member of this family';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = p_recipient_user_id
  ) THEN
    RAISE EXCEPTION 'Recipient is not a member of this family';
  END IF;

  -- actor_id intentionally left NULL — a budget alert is system-generated,
  -- not attributed to whichever member's expense happened to trigger the
  -- threshold check (matches the original raw-insert behavior).
  INSERT INTO notifications (
    user_id, family_id, actor_name, actor_emoji,
    tx_type, tx_category, tx_amount, tx_title, is_read
  ) VALUES (
    p_recipient_user_id, p_family_id, 'Budget Alert', p_actor_emoji,
    'budget_alert', p_category, p_amount, p_title, FALSE
  );
END;
$$;
