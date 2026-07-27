-- ============================================================
-- 122_fix_family_invite_tx_id_type_mismatch.sql
--
-- The family-invites feature (table + RPCs, source: supabase/family_invites.sql)
-- was only ever applied ad hoc to the dev project, never tracked as a
-- migration and never applied to QA at all — confirmed missing entirely
-- on the real QA project. This migration brings the full feature in as a
-- tracked, idempotent migration for both environments (safe no-op on dev,
-- where the table/policies already exist).
--
-- Also folds in the accept/decline tx_id type fix from 122 directly
-- (notifications.tx_id is uuid — no ::text cast needed).
-- ============================================================

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

DROP POLICY IF EXISTS "inviter_select" ON family_invites;
CREATE POLICY "inviter_select" ON family_invites
  FOR SELECT USING (invited_by_id = auth.uid());

DROP POLICY IF EXISTS "invitee_select" ON family_invites;
CREATE POLICY "invitee_select" ON family_invites
  FOR SELECT USING (invited_user_id = auth.uid());

DROP POLICY IF EXISTS "invitee_update" ON family_invites;
CREATE POLICY "invitee_update" ON family_invites
  FOR UPDATE USING (invited_user_id = auth.uid());

-- ── send_family_invite ───────────────────────────────────────────────────────
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
    'invite_id',   v_invite_id,
    'token',       v_token,
    'user_found',  v_invited_uid IS NOT NULL
  );
END;
$$;

-- ── create_invite_link ───────────────────────────────────────────────────────
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

-- ── accept_family_invite (tx_id is uuid — no ::text cast) ────────────────────
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

  INSERT INTO family_members (family_id, user_id, name, emoji, role, phone)
  VALUES (v_invite.family_id, v_uid, v_name, v_emoji, v_invite.role, v_phone)
  ON CONFLICT (family_id, user_id) DO NOTHING;

  UPDATE family_invites SET status = 'accepted' WHERE id = p_invite_id;

  UPDATE notifications
  SET is_read = TRUE
  WHERE tx_id = p_invite_id
    AND tx_type = 'invite'
    AND user_id = v_uid;

  RETURN TRUE;
END;
$$;

-- ── decline_family_invite (tx_id is uuid — no ::text cast) ───────────────────
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
  WHERE tx_id = p_invite_id
    AND tx_type = 'invite'
    AND user_id = v_uid;
END;
$$;

-- ── join_family_by_token ──────────────────────────────────────────────────────
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
