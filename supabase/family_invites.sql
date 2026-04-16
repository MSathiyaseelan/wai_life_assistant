-- ─────────────────────────────────────────────────────────────────────────────
-- Family Invites — run this in Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Table
CREATE TABLE IF NOT EXISTS family_invites (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id       UUID        NOT NULL REFERENCES families(id) ON DELETE CASCADE,
  invited_by_id   UUID        NOT NULL REFERENCES profiles(id),
  invited_phone   TEXT,
  invited_user_id UUID        REFERENCES profiles(id),
  token           TEXT        NOT NULL UNIQUE
                              DEFAULT upper(substring(replace(gen_random_uuid()::text,'-','') FROM 1 FOR 8)),
  role            TEXT        NOT NULL DEFAULT 'member',
  status          TEXT        NOT NULL DEFAULT 'pending', -- pending | accepted | declined | expired
  expires_at      TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE family_invites ENABLE ROW LEVEL SECURITY;

-- Inviter can see their sent invites
CREATE POLICY "inviter_select" ON family_invites
  FOR SELECT USING (invited_by_id = auth.uid());

-- Invited user can see and update their invites
CREATE POLICY "invitee_select" ON family_invites
  FOR SELECT USING (invited_user_id = auth.uid());

CREATE POLICY "invitee_update" ON family_invites
  FOR UPDATE USING (invited_user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. RPC: send_family_invite
--    Creates an invite record and, if the phone maps to an existing WAI user,
--    inserts an in-app notification for them.
-- ─────────────────────────────────────────────────────────────────────────────
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
  -- Strip spaces, dashes, parentheses from phone
  v_phone_normalized := regexp_replace(p_phone, '[\s\-\(\)]', '', 'g');

  -- Inviter profile
  SELECT name, emoji INTO v_inviter_name, v_inviter_emoji
  FROM profiles WHERE id = v_uid;

  -- Family info
  SELECT name, emoji INTO v_family_name, v_family_emoji
  FROM families WHERE id = p_family_id;

  -- Look up invited user by matching the last 10 digits of the phone number.
  -- This normalises across formats: 9876543210 / +919876543210 / 919876543210
  SELECT id INTO v_invited_uid
  FROM profiles
  WHERE phone IS NOT NULL
    AND right(regexp_replace(phone, '[^0-9]', '', 'g'), 10)
        = right(regexp_replace(v_phone_normalized, '[^0-9]', '', 'g'), 10)
  LIMIT 1;

  -- Create invite
  INSERT INTO family_invites (family_id, invited_by_id, invited_phone, invited_user_id, role)
  VALUES (p_family_id, v_uid, p_phone, v_invited_uid, p_role)
  RETURNING id, token INTO v_invite_id, v_token;

  -- If user exists in WAI, push in-app notification
  IF v_invited_uid IS NOT NULL THEN
    INSERT INTO notifications
      (user_id, family_id, tx_id, actor_id, actor_name, actor_emoji,
       tx_type, tx_category, tx_amount, tx_title)
    VALUES
      (v_invited_uid, p_family_id, v_invite_id::text, v_uid,
       v_inviter_name, v_family_emoji,
       'invite', 'Family Invite', 0, v_family_name);
  END IF;

  RETURN json_build_object(
    'invite_id',   v_invite_id,
    'token',       v_token,
    'user_found',  v_invited_uid IS NOT NULL
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RPC: create_invite_link
--    Generates a tokenised invite (no specific phone) for sharing.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION create_invite_link(
  p_family_id UUID,
  p_role      TEXT DEFAULT 'member'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invite_id UUID;
  v_token     TEXT;
BEGIN
  INSERT INTO family_invites (family_id, invited_by_id, role)
  VALUES (p_family_id, auth.uid(), p_role)
  RETURNING id, token INTO v_invite_id, v_token;

  RETURN json_build_object('invite_id', v_invite_id, 'token', v_token);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. RPC: accept_family_invite
--    Accepts the invite, adds the current user to family_members.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION accept_family_invite(p_invite_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

  -- Add to family (idempotent)
  INSERT INTO family_members (family_id, user_id, name, emoji, role, phone)
  VALUES (v_invite.family_id, v_uid, v_name, v_emoji, v_invite.role, v_phone)
  ON CONFLICT (family_id, user_id) DO NOTHING;

  -- Mark invite accepted
  UPDATE family_invites SET status = 'accepted' WHERE id = p_invite_id;

  -- Mark notification read
  UPDATE notifications
  SET is_read = TRUE
  WHERE tx_id = p_invite_id::text
    AND tx_type = 'invite'
    AND user_id = v_uid;

  RETURN TRUE;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. RPC: decline_family_invite
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION decline_family_invite(p_invite_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

  UPDATE notifications
  SET is_read = TRUE
  WHERE tx_id = p_invite_id::text
    AND tx_type = 'invite'
    AND user_id = v_uid;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. RPC: join_family_by_token
--    Lets any WAI user join a family using the invite code.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION join_family_by_token(p_token TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_invite family_invites%ROWTYPE;
  v_name   TEXT;
  v_emoji  TEXT;
  v_phone  TEXT;
  v_family_name TEXT;
BEGIN
  SELECT * INTO v_invite
  FROM family_invites
  WHERE token = upper(p_token)
    AND status = 'pending'
    AND expires_at > NOW();

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'reason', 'Invalid or expired code');
  END IF;

  SELECT name, emoji, phone INTO v_name, v_emoji, v_phone
  FROM profiles WHERE id = v_uid;

  SELECT name INTO v_family_name FROM families WHERE id = v_invite.family_id;

  INSERT INTO family_members (family_id, user_id, name, emoji, role, phone)
  VALUES (v_invite.family_id, v_uid, v_name, v_emoji, v_invite.role, v_phone)
  ON CONFLICT (family_id, user_id) DO NOTHING;

  UPDATE family_invites SET status = 'accepted', invited_user_id = v_uid
  WHERE id = v_invite.id;

  RETURN json_build_object('success', true, 'family_name', v_family_name);
END;
$$;
