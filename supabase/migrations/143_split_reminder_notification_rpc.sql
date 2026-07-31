-- ============================================================
-- 143_split_reminder_notification_rpc.sql
--
-- The "Notify in App" split reminder button needs to insert a row into
-- notifications so the recipient sees it in their bell even if the paired
-- FCM push doesn't land. A raw client INSERT can't do that though —
-- 072_rls_security_fixes.sql removed the blanket INSERT policy on
-- notifications specifically to stop any user forging notifications for
-- another account; only the SECURITY DEFINER transaction trigger can
-- insert now.
--
-- Adds a narrow SECURITY DEFINER RPC for this one case instead of
-- reopening that policy. Authorization is scoped to the split group
-- (both caller and recipient must be participants of it) rather than
-- family membership, since a split's participants aren't necessarily all
-- in the same family (you can split with any linked WAI friend).
-- ============================================================

CREATE OR REPLACE FUNCTION send_split_reminder_notification(
  p_group_id           UUID,
  p_recipient_user_id  UUID,
  p_family_id          UUID,
  p_actor_name         TEXT,
  p_actor_emoji        TEXT,
  p_group_name         TEXT,
  p_amount             NUMERIC
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT is_split_group_participant(p_group_id) THEN
    RAISE EXCEPTION 'Not a participant of this split group';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM split_participants
    WHERE group_id = p_group_id AND user_id = p_recipient_user_id
  ) THEN
    RAISE EXCEPTION 'Recipient is not a participant of this split group';
  END IF;

  INSERT INTO notifications (
    user_id, family_id, actor_id, actor_name, actor_emoji,
    tx_type, tx_category, tx_amount, tx_title, is_read
  ) VALUES (
    p_recipient_user_id, p_family_id, auth.uid(), p_actor_name, p_actor_emoji,
    'split_reminder', p_group_name, p_amount,
    'Payment reminder for "' || p_group_name || '"', FALSE
  );
END;
$$;
