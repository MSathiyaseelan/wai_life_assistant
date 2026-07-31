-- ============================================================
-- 146_split_group_notification_deeplink.sql
--
-- Adding someone as a split participant (createSplitGroup /
-- addSplitParticipants) never notified them at all — and if the group's
-- wallet belongs to a family they're not a member of, they have no wallet
-- switcher entry that would ever surface it either. That participant had
-- no way to discover or open a group they're legitimately part of.
--
-- 1. Adds related_group_id to notifications so split-related notifications
--    (reminder, extension, and the new "added you" case) can deep-link
--    back to the group, regardless of whose wallet it lives on.
-- 2. Updates the reminder/extension RPCs (143, 145) to set it.
-- 3. Adds send_split_added_notification for the "added you" case.
-- ============================================================

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS related_group_id UUID REFERENCES split_groups(id) ON DELETE SET NULL;

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
    tx_type, tx_category, tx_amount, tx_title, is_read, related_group_id
  ) VALUES (
    p_recipient_user_id, p_family_id, auth.uid(), p_actor_name, p_actor_emoji,
    'split_reminder', p_group_name, p_amount,
    'Payment reminder for "' || p_group_name || '"', FALSE, p_group_id
  );
END;
$$;

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
    tx_type, tx_category, tx_amount, tx_title, is_read, related_group_id
  ) VALUES (
    p_recipient_user_id, p_family_id, auth.uid(), p_actor_name, p_actor_emoji,
    'split_extension', p_group_name, p_amount,
    'Extension requested for "' || p_group_name || '"', FALSE, p_group_id
  );
END;
$$;

-- Sent once when a linked WAI account is added as a split participant
-- (createSplitGroup or addSplitParticipants), so they find out the group
-- exists at all. family_id may be null here (a personal-wallet split) —
-- notifications.family_id is NOT NULL, so this case is skipped
-- client-side rather than passing a fabricated value.
CREATE OR REPLACE FUNCTION send_split_added_notification(
  p_group_id           UUID,
  p_recipient_user_id  UUID,
  p_family_id          UUID,
  p_actor_name         TEXT,
  p_actor_emoji        TEXT,
  p_group_name         TEXT
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
    tx_type, tx_category, tx_amount, tx_title, is_read, related_group_id
  ) VALUES (
    p_recipient_user_id, p_family_id, auth.uid(), p_actor_name, p_actor_emoji,
    'split_added_you', p_group_name, 0,
    p_actor_name || ' added you to "' || p_group_name || '"', FALSE, p_group_id
  );
END;
$$;
