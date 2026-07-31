-- ============================================================
-- 145_split_extension_notification_rpc.sql
--
-- "Request Extension" only posted a group chat message — the payer had no
-- push or in-app notification telling them a debtor asked for more time,
-- unlike adding a new expense (which does notify via wallet.split_added).
--
-- Adds a second SECURITY DEFINER RPC alongside 143's
-- send_split_reminder_notification, same participant-scoped authorization
-- (both caller and recipient must be participants of the group — split
-- participants aren't necessarily all in the same family).
-- ============================================================

CREATE OR REPLACE FUNCTION send_split_extension_notification(
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
    'split_extension', p_group_name, p_amount,
    'Extension requested for "' || p_group_name || '"', FALSE
  );
END;
$$;
