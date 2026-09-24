-- ============================================================
-- 196_enforce_family_invite_permissions.sql
--
-- send_family_invite (132) and create_invite_link (122) are SECURITY DEFINER
-- and checked nothing about the caller: not family membership, not the
-- family's "Who can invite members" (families.perm_invite), and not the
-- invite role, which came straight from the client (p_role). Accepting an
-- invite (accept_family_invite / join_family_by_token) inserts the member
-- with that stored role, so:
--   • any member could make an account admin (invite link with
--     p_role = 'admin', then join it),
--   • any member could invite despite perm_invite = 'admin_only' (the app
--     only hid the button),
--   • any signed-in user could add themselves to a family whose id they had.
--
-- Now both require the caller to be an active member of a live family who
-- may invite (admin, or perm_invite = 'any_member' — the app's canInvite),
-- and only admins may issue 'admin' invites. The app always sends 'member',
-- so it is unaffected.
--
-- Also: soft-deleted memberships (family_members.deleted_at, 065) no longer
-- count as admin in is_family_admin() / "families: admin can update" — a
-- removed admin could otherwise keep managing the family.
-- ============================================================

-- ── Shared check ─────────────────────────────────────────────────────────────
-- Raises unless auth.uid() may invite into p_family_id with p_role.
CREATE OR REPLACE FUNCTION assert_can_invite(p_family_id UUID, p_role TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_my_role     TEXT;
  v_perm_invite TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_role IS NULL OR p_role NOT IN ('admin', 'member', 'viewer') THEN
    RAISE EXCEPTION 'Invalid role' USING ERRCODE = '22023';
  END IF;

  SELECT fm.role, f.perm_invite
    INTO v_my_role, v_perm_invite
  FROM family_members fm
  JOIN families f ON f.id = fm.family_id
  WHERE fm.family_id = p_family_id
    AND fm.user_id   = auth.uid()
    AND fm.deleted_at IS NULL
    AND f.deleted_at  IS NULL
  LIMIT 1;

  IF v_my_role IS NULL THEN
    RAISE EXCEPTION 'You are not a member of this family' USING ERRCODE = '42501';
  END IF;

  IF v_my_role <> 'admin' AND COALESCE(v_perm_invite, 'admin_only') <> 'any_member' THEN
    RAISE EXCEPTION 'Only admins can invite members to this family' USING ERRCODE = '42501';
  END IF;

  IF p_role = 'admin' AND v_my_role <> 'admin' THEN
    RAISE EXCEPTION 'Only admins can invite admins' USING ERRCODE = '42501';
  END IF;
END;
$$;

-- Internal helper — only the invite functions (running as owner) call it.
REVOKE ALL ON FUNCTION assert_can_invite(UUID, TEXT) FROM PUBLIC, anon, authenticated;

-- ── send_family_invite (was 132) — unchanged apart from the check ───────────
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
  PERFORM assert_can_invite(p_family_id, p_role);

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

-- ── create_invite_link (was 122) — unchanged apart from the check ───────────
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
  PERFORM assert_can_invite(p_family_id, p_role);

  INSERT INTO family_invites (family_id, invited_by_id, role)
  VALUES (p_family_id, auth.uid(), p_role)
  RETURNING id, token INTO v_invite_id, v_token;

  RETURN json_build_object('invite_id', v_invite_id, 'token', v_token);
END;
$$;

-- ── Removed (soft-deleted) admins are no longer admins ──────────────────────
-- CREATE OR REPLACE can't rename a parameter, and the parameter name differs
-- between databases (082 has wid_family_id; some have p_family_id). DROP
-- isn't an option either — RLS policies depend on this function. So keep
-- whatever name exists and reference the argument positionally ($1).
DO $do$
DECLARE
  v_arg TEXT;
BEGIN
  SELECT COALESCE(p.proargnames[1], 'wid_family_id') INTO v_arg
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'is_family_admin'
    AND p.pronargs = 1;

  EXECUTE format($f$
    CREATE OR REPLACE FUNCTION public.is_family_admin(%I UUID)
    RETURNS BOOLEAN
    LANGUAGE sql
    SECURITY DEFINER
    SET search_path = public
    STABLE
    AS $body$
      SELECT EXISTS (
        SELECT 1 FROM family_members
        WHERE family_id = $1 AND user_id = auth.uid() AND role = 'admin'
          AND deleted_at IS NULL
      );
    $body$
  $f$, COALESCE(v_arg, 'wid_family_id'));
END
$do$;

DROP POLICY IF EXISTS "families: admin can update" ON families;
CREATE POLICY "families: admin can update" ON families
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = families.id
        AND fm.user_id = auth.uid()
        AND fm.role = 'admin'
        AND fm.deleted_at IS NULL
    )
  );

-- ── Cancel pending invites the new rules would have refused ─────────────────
-- An admin invite whose inviter isn't a current admin of that family, or any
-- invite whose inviter was never an active member of it. Accepted invites
-- are left alone — review those separately (see the query in the PR notes).
UPDATE family_invites fi
SET status = 'expired'
WHERE fi.status = 'pending'
  AND (
    (fi.role = 'admin' AND NOT EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = fi.family_id AND fm.user_id = fi.invited_by_id
        AND fm.role = 'admin' AND fm.deleted_at IS NULL))
    OR NOT EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = fi.family_id AND fm.user_id = fi.invited_by_id
        AND fm.deleted_at IS NULL)
  );
