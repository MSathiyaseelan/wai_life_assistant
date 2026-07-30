-- ============================================================
-- 132_invite_returns_target_user.sql
--
-- Family invites (send_family_invite / add_family_member's invite branch)
-- only ever inserted a passive row into `notifications` — no real FCM push
-- was ever triggered, so the invited person had no way to know an invite
-- existed until they happened to open the app and check the bell icon.
--
-- Actually sending a push requires the Flutter client to call the
-- send-notification edge function with the invited person's user_id right
-- after the RPC succeeds. Both RPCs already resolve the matching account
-- into a local uid variable (v_invited_uid / v_linked_uid) — this migration
-- just also returns it in the response json so the client has something to
-- target.
-- ============================================================

CREATE OR REPLACE FUNCTION send_family_invite(
  p_family_id   UUID,
  p_phone       TEXT,
  p_role        TEXT DEFAULT 'member'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid              UUID := auth.uid();
  v_inviter_name     TEXT;
  v_inviter_emoji    TEXT;
  v_family_name      TEXT;
  v_family_emoji     TEXT;
  v_invited_uid      UUID;
  v_invite_id        UUID;
  v_token            TEXT;
  v_phone_normalized TEXT;
BEGIN
  v_phone_normalized := regexp_replace(p_phone, '[\s\-\(\)]', '', 'g');

  SELECT name, emoji INTO v_inviter_name, v_inviter_emoji
  FROM profiles WHERE id = v_uid;

  SELECT name, emoji INTO v_family_name, v_family_emoji
  FROM families WHERE id = p_family_id;

  SELECT id INTO v_invited_uid
  FROM profiles
  WHERE phone IS NOT NULL
    AND right(regexp_replace(phone, '[^0-9]', '', 'g'), 10)
        = right(regexp_replace(v_phone_normalized, '[^0-9]', '', 'g'), 10)
  LIMIT 1;

  INSERT INTO family_invites (family_id, invited_by_id, invited_phone, invited_user_id, role)
  VALUES (p_family_id, v_uid, p_phone, v_invited_uid, p_role)
  RETURNING id, token INTO v_invite_id, v_token;

  IF v_invited_uid IS NOT NULL THEN
    BEGIN
      INSERT INTO notifications
        (user_id, family_id, tx_id, actor_id, actor_name, actor_emoji,
         tx_type, tx_category, tx_amount, tx_title)
      VALUES
        (v_invited_uid, p_family_id, v_invite_id, v_uid,
         v_inviter_name, v_family_emoji,
         'invite', 'Family Invite', 0, v_family_name);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;
  END IF;

  RETURN json_build_object(
    'invite_id',       v_invite_id,
    'token',           v_token,
    'user_found',      v_invited_uid IS NOT NULL,
    'invited_user_id', v_invited_uid,
    'inviter_name',    v_inviter_name,
    'family_name',     v_family_name
  );
END;
$$;

-- ── add_family_member — same, for the invite branch (migration 127) ─────────
CREATE OR REPLACE FUNCTION add_family_member(
  p_family_id UUID,
  p_name      TEXT,
  p_emoji     TEXT    DEFAULT '👤',
  p_role      TEXT    DEFAULT 'member',
  p_relation  TEXT    DEFAULT NULL,
  p_phone     TEXT    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid              UUID := auth.uid();
  v_member_id        UUID;
  v_linked_uid       UUID;
  v_phone_normalized TEXT;
  v_invite_id        UUID;
  v_token            TEXT;
  v_inviter_name     TEXT;
  v_inviter_emoji    TEXT;
  v_family_name      TEXT;
  v_family_emoji     TEXT;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
      AND user_id   = v_uid
      AND role      = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only the family admin can add members';
  END IF;

  IF p_phone IS NOT NULL AND length(trim(p_phone)) > 0 THEN
    v_phone_normalized := regexp_replace(p_phone, '[\s\-\(\)]', '', 'g');
    SELECT id INTO v_linked_uid
    FROM profiles
    WHERE phone IS NOT NULL
      AND right(regexp_replace(phone, '[^0-9]', '', 'g'), 10)
          = right(regexp_replace(v_phone_normalized, '[^0-9]', '', 'g'), 10)
    LIMIT 1;
  END IF;

  -- Matches an existing account — route through invite+accept, same as a
  -- normal invite instead of adding them directly.
  IF v_linked_uid IS NOT NULL THEN
    SELECT name, emoji INTO v_inviter_name, v_inviter_emoji FROM profiles WHERE id = v_uid;
    SELECT name, emoji INTO v_family_name, v_family_emoji FROM families WHERE id = p_family_id;

    INSERT INTO family_invites (family_id, invited_by_id, invited_phone, invited_user_id, role)
    VALUES (p_family_id, v_uid, p_phone, v_linked_uid, p_role)
    RETURNING id, token INTO v_invite_id, v_token;

    BEGIN
      INSERT INTO notifications
        (user_id, family_id, tx_id, actor_id, actor_name, actor_emoji,
         tx_type, tx_category, tx_amount, tx_title)
      VALUES
        (v_linked_uid, p_family_id, v_invite_id, v_uid,
         v_inviter_name, v_family_emoji,
         'invite', 'Family Invite', 0, v_family_name);
    EXCEPTION WHEN OTHERS THEN
      NULL;
    END;

    RETURN json_build_object(
      'invited',         true,
      'invite_id',       v_invite_id,
      'token',           v_token,
      'invited_user_id', v_linked_uid,
      'inviter_name',    v_inviter_name,
      'family_name',     v_family_name
    );
  END IF;

  -- No matching account — a true placeholder, nothing to consent to yet.
  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation, phone)
  VALUES (p_family_id, NULL, p_name, p_emoji, p_role, p_relation, p_phone)
  RETURNING id INTO v_member_id;

  RETURN json_build_object('invited', false, 'member_id', v_member_id);
END;
$$;
