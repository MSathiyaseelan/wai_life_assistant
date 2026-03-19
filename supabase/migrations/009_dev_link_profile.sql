-- ─────────────────────────────────────────────────────────────────────────────
-- 009_dev_link_profile.sql
-- Dev-bypass helper: find an existing profile by phone and migrate all its
-- data (wallets → transactions → reminders, families, etc.) to the current
-- auth user.  Called once per login when using the email-bypass flow so that
-- data created under a previous anonymous/email session is not lost.
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION dev_link_profile_by_phone(p_phone TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_uid  UUID := auth.uid();
  v_old_uid  UUID;
  v_old_name TEXT;
  v_old_emoji TEXT;
BEGIN
  -- Try exact match first, then strip leading + or country code (91)
  SELECT id, name, emoji INTO v_old_uid, v_old_name, v_old_emoji
  FROM profiles
  WHERE phone IN (
    p_phone,
    regexp_replace(p_phone, '^\+?91', ''),   -- strip +91 or 91
    '+91' || regexp_replace(p_phone, '^\+?91', '')  -- ensure +91 prefix
  )
    AND id <> v_new_uid
  LIMIT 1;

  IF v_old_uid IS NULL THEN
    -- No other user has this phone — just stamp phone on current profile
    UPDATE profiles SET phone = p_phone WHERE id = v_new_uid;
    RETURN FALSE;
  END IF;

  -- ── Migrate all data from v_old_uid → v_new_uid ─────────────────────────

  -- 1. Delete the empty personal wallet bootstrap just created for the new user,
  --    so we don't end up with two personal wallets after the migration below.
  DELETE FROM wallets WHERE owner_id = v_new_uid AND is_personal = TRUE;

  -- 2. Move old user's wallets (personal + any family wallets) to new user
  UPDATE wallets SET owner_id = v_new_uid WHERE owner_id = v_old_uid;

  -- 3. Transactions
  UPDATE transactions SET user_id = v_new_uid WHERE user_id = v_old_uid;

  -- 4. Families created by old user
  UPDATE families SET created_by = v_new_uid WHERE created_by = v_old_uid;

  -- 5. Family membership rows
  UPDATE family_members SET user_id = v_new_uid WHERE user_id = v_old_uid;

  -- 6. Split groups
  UPDATE split_groups SET created_by = v_new_uid WHERE created_by = v_old_uid;

  -- 7. Split participants
  UPDATE split_participants SET user_id = v_new_uid WHERE user_id = v_old_uid;

  -- 8. Copy profile display data to the new user's profile
  UPDATE profiles
  SET name      = COALESCE(NULLIF(v_old_name,  ''),   name),
      emoji     = COALESCE(NULLIF(v_old_emoji, '👤'), emoji),
      phone     = p_phone,
      onboarded = TRUE,
      updated_at = NOW()
  WHERE id = v_new_uid;

  -- 9. Delete old profile (safe: data already re-parented above)
  DELETE FROM profiles WHERE id = v_old_uid;

  RETURN TRUE;
END;
$$;
