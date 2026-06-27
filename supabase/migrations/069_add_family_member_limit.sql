-- ============================================================
-- 069_add_family_member_limit.sql
--
-- Replaces add_family_member() with a version that enforces
-- the family member cap defined by the wallet's subscription plan.
--
-- Logic:
--   1. Look up the family wallet → get plan limits via get_plan_limits().
--   2. Resolve effective limit:
--        wallet_subscriptions.family_member_limit if set (per-wallet override),
--        else plan_limits.family_max_members.
--   3. Count current non-deleted members in the family.
--   4. Raise P0001 if count >= limit (0 = no family plan; -1 = unlimited).
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

  -- 0  = personal plan (not a family plan)
  -- -1 = unlimited
  -- >0 = hard cap
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
