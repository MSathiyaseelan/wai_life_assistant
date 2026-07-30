-- ============================================================
-- 137_split_participants_phone_linking.sql
--
-- Creating a split group never linked participants to a real account —
-- WalletService.createSplitGroup inserted every non-"me" participant with
-- user_id = NULL unconditionally, no phone lookup at all (unlike
-- add_family_member, which has matched by phone since day one). Since
-- "split_groups: select" / "split_participants: select" RLS both require
-- a participant row's user_id = auth.uid() to see the group, a
-- participant added by phone could NEVER see a split group they were
-- added to, even with an exact-matching WAI account — the group was only
-- ever visible to its creator.
--
-- Two fixes, covering both orderings:
--   1. match_profile_ids_by_phone() — a new RPC the client calls at
--      group-creation time to resolve participant phones to existing
--      accounts (same phone_last10() matching as add_family_member,
--      migration 120).
--   2. bootstrap_new_user — claims any pre-existing split_participants
--      rows matching the new signup's phone, same as it already does for
--      family_members, covering someone added to a split group *before*
--      they ever created a WAI account.
-- ============================================================

-- Returns each requested phone alongside the matching profile id, if any
-- (last-10-digits comparison — see phone_last10(), migration 120). Only
-- exposes the id, not the rest of the profile row, to the caller.
CREATE OR REPLACE FUNCTION match_profile_ids_by_phone(p_phones TEXT[])
RETURNS TABLE(phone TEXT, user_id UUID)
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT ph.phone, p.id
  FROM unnest(p_phones) AS ph(phone)
  LEFT JOIN profiles p ON phone_last10(p.phone) = phone_last10(ph.phone)
                       AND ph.phone IS NOT NULL;
$$;

-- ── bootstrap_new_user — also claim pending split_participants rows ─────────
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
  v_splits_claimed INT := 0;
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

    UPDATE split_participants
    SET user_id = v_uid
    WHERE user_id IS NULL
      AND is_me = FALSE
      AND phone_last10(phone) = phone_last10(v_phone);
    GET DIAGNOSTICS v_splits_claimed = ROW_COUNT;
  END IF;

  RETURN json_build_object(
    'profile_id',      v_uid,
    'wallet_id',       v_wallet_id,
    'families_joined', v_claimed,
    'split_groups_joined', v_splits_claimed
  );
END;
$$;

-- ── One-time reconciliation for split groups already created ────────────────
UPDATE split_participants sp
SET user_id = p.id
FROM profiles p
WHERE sp.user_id IS NULL
  AND sp.is_me = FALSE
  AND sp.phone IS NOT NULL
  AND phone_last10(p.phone) = phone_last10(sp.phone);
