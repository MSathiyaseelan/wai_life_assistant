-- ============================================================
-- 128_delete_invite_notifications_on_resolve.sql
--
-- Reported: notifications can't be cleared, and declining an invite
-- doesn't make it disappear. Root cause: nothing ever deleted
-- notification rows — accept/decline only set is_read = true, and
-- fetchAll() returns read rows too, so a realtime-triggered refresh
-- while the sheet is open brought the "cleared" invite right back.
--
-- Client now calls NotificationService.dismiss()/clearAll() (real
-- deletes) after resolving an invite. Mirroring that server-side too, so
-- the notification is actually gone regardless of whether the client-side
-- dismiss call succeeds.
-- ============================================================

CREATE OR REPLACE FUNCTION accept_family_invite(p_invite_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_invite    family_invites%ROWTYPE;
  v_name      TEXT;
  v_emoji     TEXT;
  v_phone     TEXT;
BEGIN
  SELECT * INTO v_invite
  FROM family_invites
  WHERE id = p_invite_id
    AND status = 'pending'
    AND expires_at > NOW()
    AND (
      invited_user_id = v_uid
      OR right(regexp_replace(invited_phone, '[^0-9]', '', 'g'), 10)
         = right(regexp_replace((SELECT phone FROM profiles WHERE id = v_uid), '[^0-9]', '', 'g'), 10)
    );

  IF NOT FOUND THEN RETURN FALSE; END IF;

  SELECT name, emoji, phone INTO v_name, v_emoji, v_phone
  FROM profiles WHERE id = v_uid;

  INSERT INTO family_members (family_id, user_id, name, emoji, role, phone)
  VALUES (v_invite.family_id, v_uid, v_name, v_emoji, v_invite.role, v_phone)
  ON CONFLICT (family_id, user_id) DO NOTHING;

  UPDATE family_invites SET status = 'accepted' WHERE id = p_invite_id;

  DELETE FROM notifications
  WHERE tx_id = p_invite_id
    AND tx_type = 'invite'
    AND user_id = v_uid;

  RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION decline_family_invite(p_invite_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE v_uid UUID := auth.uid();
BEGIN
  UPDATE family_invites SET status = 'declined'
  WHERE id = p_invite_id
    AND (
      invited_user_id = v_uid
      OR right(regexp_replace(invited_phone, '[^0-9]', '', 'g'), 10)
         = right(regexp_replace((SELECT phone FROM profiles WHERE id = v_uid), '[^0-9]', '', 'g'), 10)
    );

  DELETE FROM notifications
  WHERE tx_id = p_invite_id
    AND tx_type = 'invite'
    AND user_id = v_uid;
END;
$$;
