-- ─────────────────────────────────────────────────────────────────────────────
-- 031_fix_family_member_linking.sql
--
-- Two fixes:
--
-- 1. add_family_member (was missing from all prior migrations)
--    Inserts a placeholder family_members row with user_id = NULL and the
--    invited member's phone.  SECURITY DEFINER so any member can add.
--
-- 2. bootstrap_new_user (updated)
--    After creating/upserting the profile + personal wallet, scans
--    family_members rows where phone matches the new user's auth phone and
--    user_id IS NULL, then claims them by setting user_id = new uid.
--    This is what causes the family group (and its wallet) to appear for the
--    new user immediately after they sign up.
-- ─────────────────────────────────────────────────────────────────────────────


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: add_family_member
-- ══════════════════════════════════════════════════════════════
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
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_member_id UUID;
  v_linked_uid UUID;
BEGIN
  -- Only admins can add members
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
      AND user_id   = v_uid
      AND role      = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can add members';
  END IF;

  -- Check if a registered user already has this phone — if so, link directly
  IF p_phone IS NOT NULL THEN
    SELECT id INTO v_linked_uid
    FROM profiles
    WHERE phone IN (
      p_phone,
      regexp_replace(p_phone, '^\+?91', ''),
      '+91' || regexp_replace(p_phone, '^\+?91', '')
    )
    LIMIT 1;
  END IF;

  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation, phone)
  VALUES (p_family_id, v_linked_uid, p_name, p_emoji, p_role, p_relation, p_phone)
  RETURNING id INTO v_member_id;

  RETURN json_build_object('member_id', v_member_id, 'linked', v_linked_uid IS NOT NULL);
END;
$$;


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: bootstrap_new_user  (updated to claim pending slots)
-- ══════════════════════════════════════════════════════════════
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
  v_phone      TEXT;
  v_wallet_id  UUID;
  v_claimed    INT  := 0;
BEGIN
  -- Get the verified phone from auth.users
  SELECT phone INTO v_phone FROM auth.users WHERE id = v_uid;

  -- 1. Upsert profile — preserve existing name/emoji on re-login
  INSERT INTO profiles (id, name, emoji, phone, onboarded)
  VALUES (
    v_uid,
    p_name,
    p_emoji,
    v_phone,
    TRUE
  )
  ON CONFLICT (id) DO UPDATE
    SET name      = CASE WHEN profiles.name  <> '' THEN profiles.name  ELSE EXCLUDED.name  END,
        emoji     = CASE WHEN profiles.emoji <> '👤' THEN profiles.emoji ELSE EXCLUDED.emoji END,
        phone     = COALESCE(profiles.phone, EXCLUDED.phone),
        onboarded = TRUE,
        updated_at = NOW();

  -- 2. Create personal wallet only if one doesn't exist yet
  IF NOT EXISTS (
    SELECT 1 FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE
  ) THEN
    INSERT INTO wallets (owner_id, name, emoji, is_personal)
    VALUES (v_uid, 'Personal', '👤', TRUE)
    RETURNING id INTO v_wallet_id;
  ELSE
    SELECT id INTO v_wallet_id
    FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE LIMIT 1;
  END IF;

  -- 3. Claim any pending family_members slots that match this user's phone
  --    (added by another user before this account existed)
  IF v_phone IS NOT NULL AND v_phone <> '' THEN
    UPDATE family_members
    SET user_id = v_uid
    WHERE user_id IS NULL
      AND phone IN (
        v_phone,
        regexp_replace(v_phone, '^\+?91', ''),
        '+91' || regexp_replace(v_phone, '^\+?91', '')
      );
    GET DIAGNOSTICS v_claimed = ROW_COUNT;
  END IF;

  RETURN json_build_object(
    'profile_id',     v_uid,
    'wallet_id',      v_wallet_id,
    'families_joined', v_claimed
  );
END;
$$;
