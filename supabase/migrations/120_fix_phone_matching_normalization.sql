-- ============================================================
-- 120_fix_phone_matching_normalization.sql
--
-- 118/119 fixed profiles.phone and did a one-time family_members
-- reconciliation, but the matching logic used everywhere
-- (add_family_member, bootstrap_new_user's claim step, and 118's own
-- backfill) is wrong for a whole class of real numbers:
--
--   regexp_replace(phone, '^\+?91', '')
--
-- strips a leading "91" assuming it's always a country code — but a bare
-- 10-digit Indian mobile number that itself *starts* with the digits 9-1
-- (e.g. 9176024340, a real and common prefix block) gets incorrectly
-- truncated to 8 digits instead of having "+91" added to it. Confirmed on
-- real QA data: a family member added with phone "9176024340" never
-- linked to her account (profiles.phone "+919176024340") because none of
-- the 3 candidates the old logic generated ever equalled the real value.
--
-- Fix: stop trying to detect/strip a country-code prefix at all. Just
-- compare the last 10 digits of both numbers — that's the actual
-- national number regardless of how a "+91"/"91" prefix was or wasn't
-- present, and can't misfire on numbers that happen to start with 9-1.
-- ============================================================

CREATE OR REPLACE FUNCTION phone_last10(p_phone TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(RIGHT(regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g'), 10), '');
$$;

-- ── One-time reconciliation with the corrected matching ──────────────────────
UPDATE family_members fm
SET user_id = p.id
FROM profiles p
WHERE fm.user_id IS NULL
  AND fm.phone IS NOT NULL
  AND phone_last10(p.phone) = phone_last10(fm.phone);

UPDATE family_members fm
SET phone = p.phone
FROM profiles p
WHERE fm.user_id = p.id
  AND fm.phone IS NULL
  AND p.phone IS NOT NULL;

-- ── add_family_member — corrected phone lookup ───────────────────────────────
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
  v_uid           UUID := auth.uid();
  v_member_id     UUID;
  v_linked_uid    UUID;
  v_wallet_id     UUID;
  v_limits        plan_limits;
  v_max_members   INTEGER;
  v_current_count INTEGER;
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

  -- Link to an existing registered user if their phone matches
  -- (last-10-digits comparison — see phone_last10() above).
  IF p_phone IS NOT NULL THEN
    SELECT id INTO v_linked_uid
      FROM profiles
     WHERE phone_last10(phone) = phone_last10(p_phone)
     LIMIT 1;
  END IF;

  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation, phone)
  VALUES (p_family_id, v_linked_uid, p_name, p_emoji, p_role, p_relation, p_phone)
  RETURNING id INTO v_member_id;

  RETURN json_build_object('member_id', v_member_id, 'linked_user_id', v_linked_uid);
END;
$$;

-- ── bootstrap_new_user — corrected claim-pending-slots matching ─────────────
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
  v_claimed    INT := 0;
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

  -- Claim any pending family_members slots that match this user's phone
  -- (last-10-digits comparison — see phone_last10() above).
  IF v_phone IS NOT NULL AND v_phone <> '' THEN
    UPDATE family_members
    SET user_id = v_uid
    WHERE user_id IS NULL
      AND phone_last10(phone) = phone_last10(v_phone);
    GET DIAGNOSTICS v_claimed = ROW_COUNT;
  END IF;

  RETURN json_build_object(
    'profile_id',      v_uid,
    'wallet_id',       v_wallet_id,
    'families_joined', v_claimed
  );
END;
$$;
