-- ================================================================
-- WAI Life Assistant — Migration 079
--
-- Closes two server-side subscription gaps:
--
-- 1. create_family_with_wallet — personal_free users (family_max_members=0)
--    could bypass the UI paywall and call this RPC directly. Now raises P0001
--    if the calling user's plan does not allow family groups.
--
-- 2. add_family_member — family_max_members=0 was silently skipping the
--    limit check (the old IF > 0 guard treated 0 as "no limit" rather than
--    "blocked"). Now treats 0 as "family plan not active".
-- ================================================================


-- ── 1. create_family_with_wallet — add plan gate ─────────────────────────────

CREATE OR REPLACE FUNCTION create_family_with_wallet(
  p_name          TEXT,
  p_emoji         TEXT,
  p_color_index   INTEGER DEFAULT 0,
  p_description   TEXT    DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_uid        UUID := auth.uid();
  v_family_id  UUID;
  v_wallet_id  UUID;
  v_profile    RECORD;
  v_plan_key   TEXT;
  v_limits     plan_limits;
BEGIN
  -- Require authentication
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = 'P0001';
  END IF;

  -- Look up the calling user's plan
  SELECT COALESCE(p.plan, 'personal_free')
    INTO v_plan_key
    FROM profiles p
   WHERE p.id = v_uid;

  -- Resolve plan limits (personal scope — no wallet yet)
  SELECT pl.*
    INTO v_limits
    FROM plan_limits pl
    JOIN subscription_plans sp ON sp.id = pl.plan_id
   WHERE sp.plan_key = COALESCE(v_plan_key, 'personal_free');

  -- family_max_members = 0 means this plan has no family group entitlement
  IF v_limits.family_max_members = 0 THEN
    RAISE EXCEPTION 'Family groups require a Family plan. Upgrade to create a group.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 1. Insert family
  INSERT INTO families (name, emoji, color_index, description, created_by)
  VALUES (p_name, p_emoji, p_color_index, p_description, v_uid)
  RETURNING id INTO v_family_id;

  -- 2. Add creator as admin member
  SELECT name, emoji INTO v_profile FROM profiles WHERE id = v_uid;
  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation)
  VALUES (v_family_id, v_uid, COALESCE(v_profile.name, 'Me'), COALESCE(v_profile.emoji, '👤'), 'admin', 'Self');

  -- 3. Create linked family wallet
  INSERT INTO wallets (family_id, name, emoji, is_personal, gradient_index)
  VALUES (v_family_id, p_name, p_emoji, FALSE, p_color_index)
  RETURNING id INTO v_wallet_id;

  RETURN json_build_object(
    'family_id', v_family_id,
    'wallet_id', v_wallet_id
  );
END;
$$;


-- ── 2. add_family_member — fix zero-members-allowed bypass ───────────────────

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
  -- Only admins can add members
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id
      AND user_id   = v_uid
      AND role      = 'admin'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Only admins can add members';
  END IF;

  -- Find the family wallet to determine the subscription plan
  SELECT id INTO v_wallet_id
    FROM wallets
   WHERE family_id = p_family_id
   LIMIT 1;

  -- Get base plan limits for this wallet
  v_limits := get_plan_limits(v_wallet_id);

  -- Prefer per-wallet override (family_member_limit), fall back to plan default
  SELECT COALESCE(ws.family_member_limit, v_limits.family_max_members)
    INTO v_max_members
    FROM wallet_subscriptions ws
   WHERE ws.wallet_id = v_wallet_id
   LIMIT 1;

  -- If no subscription row exists, use plan default
  IF v_max_members IS NULL THEN
    v_max_members := v_limits.family_max_members;
  END IF;

  -- 0  = personal plan — family members not allowed on this plan
  -- -1 = unlimited (pro tier)
  -- >0 = hard cap
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
