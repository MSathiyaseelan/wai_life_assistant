-- ============================================================
-- 127_unify_family_member_consent.sql
--
-- Found two inconsistent paths for adding a family member:
--   1. Dashboard Settings "Invite" (send_family_invite) — creates a
--      family_invites row; the person only joins after they explicitly
--      call accept_family_invite. Proper consent.
--   2. Edit Family "Add Member" (add_family_member) — if the phone
--      matched an existing WAI account, that account was inserted into
--      family_members immediately, with zero consent. A silent variant
--      of the same gap also existed via bootstrap_new_user's
--      claim-pending-slots step (auto-linking a placeholder row on
--      signup, again with no accept step).
--
-- This migration unifies on invite+accept: add_family_member now only
-- creates a direct family_members row for phones that DON'T match any
-- existing account (a true placeholder — no one to ask consent from).
-- If the phone DOES match an existing account, it creates a
-- family_invites row + notification instead (same as send_family_invite)
-- and does NOT touch family_members — that only happens once the
-- invited user calls accept_family_invite themselves.
--
-- bootstrap_new_user's claim-pending-slots step is removed for the same
-- reason: silently linking a new signup into a family they were only
-- ever added to by phone (never invited-and-accepted) bypassed consent
-- exactly like the direct-add case did. Existing placeholder
-- family_members rows (phone set, user_id NULL) now simply stay
-- unlinked until the family admin sends them a real invite.
-- ============================================================

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
SET search_path TO 'public'
AS $$
DECLARE
  v_uid              UUID := auth.uid();
  v_member_id        UUID;
  v_linked_uid       UUID;
  v_wallet_id        UUID;
  v_limits           plan_limits;
  v_max_members      INTEGER;
  v_current_count    INTEGER;
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
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Only admins can add members';
  END IF;

  SELECT id INTO v_wallet_id
    FROM wallets
   WHERE family_id = p_family_id
   LIMIT 1;

  v_limits := get_plan_limits(v_wallet_id);

  SELECT COALESCE(ws.family_member_limit, v_limits.family_max_members)
    INTO v_max_members
    FROM wallet_subscriptions ws
   WHERE ws.wallet_id = v_wallet_id
   LIMIT 1;

  IF v_max_members IS NULL THEN
    v_max_members := v_limits.family_max_members;
  END IF;

  IF v_max_members = 0 THEN
    RAISE EXCEPTION 'Family groups require a Family plan. Upgrade to add members.'
      USING ERRCODE = 'P0001';
  END IF;

  IF v_max_members > 0 THEN
    SELECT COUNT(*) INTO v_current_count
      FROM family_members
     WHERE family_id = p_family_id
       AND deleted_at IS NULL;

    IF v_current_count >= v_max_members THEN
      RAISE EXCEPTION 'Family member limit reached. Your plan allows up to % members.', v_max_members
        USING ERRCODE = 'P0001';
    END IF;
  END IF;

  IF p_phone IS NOT NULL THEN
    SELECT id INTO v_linked_uid
      FROM profiles
     WHERE phone_last10(phone) = phone_last10(p_phone)
     LIMIT 1;
  END IF;

  -- Phone matches a real, existing account — require their consent via a
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
      'invited',    true,
      'invite_id',  v_invite_id,
      'token',      v_token
    );
  END IF;

  -- No matching account — a true placeholder, nothing to consent to yet.
  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation, phone)
  VALUES (p_family_id, NULL, p_name, p_emoji, p_role, p_relation, p_phone)
  RETURNING id INTO v_member_id;

  RETURN json_build_object('invited', false, 'member_id', v_member_id);
END;
$$;

-- ── bootstrap_new_user — remove the silent claim-on-signup step ─────────────
CREATE OR REPLACE FUNCTION bootstrap_new_user(
  p_name  TEXT DEFAULT '',
  p_emoji TEXT DEFAULT '👤'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_email      TEXT;
  v_phone      TEXT;
  v_wallet_id  UUID;
BEGIN
  SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

  IF v_email ~ '^phone_\d+@waiapp\.internal$' THEN
    v_phone := '+' || (regexp_match(v_email, '^phone_(\d+)@waiapp\.internal$'))[1];
  END IF;

  INSERT INTO profiles (id, name, emoji, phone, onboarded)
  VALUES (
    v_uid,
    p_name,
    p_emoji,
    v_phone,
    FALSE
  )
  ON CONFLICT (id) DO UPDATE
    SET name      = CASE WHEN profiles.name  <> '' THEN profiles.name  ELSE EXCLUDED.name  END,
        emoji     = CASE WHEN profiles.emoji <> '👤' THEN profiles.emoji ELSE EXCLUDED.emoji END,
        phone     = COALESCE(profiles.phone, EXCLUDED.phone),
        updated_at = NOW();

  IF NOT EXISTS (
    SELECT 1 FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE
  ) THEN
    INSERT INTO wallets (owner_id, name, emoji, is_personal)
    VALUES (v_uid, 'Personal', '👤', TRUE)
    RETURNING id INTO v_wallet_id;
  ELSE
    SELECT id INTO v_wallet_id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE LIMIT 1;
  END IF;

  RETURN json_build_object(
    'profile_id', v_uid,
    'wallet_id',  v_wallet_id
  );
END;
$$;
