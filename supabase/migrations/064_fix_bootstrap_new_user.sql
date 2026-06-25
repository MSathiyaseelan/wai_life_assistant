-- ============================================================
--  Fix: bootstrap_new_user — use owner_id (not user_id) on wallets
--  The wallets table uses owner_id as the personal wallet FK.
-- ============================================================

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
  v_wallet_id  UUID;
  v_profile    JSON;
BEGIN
  -- 1. Upsert profile — preserve existing name/emoji on re-login
  INSERT INTO profiles (id, name, emoji, phone, onboarded)
  VALUES (
    v_uid,
    p_name,
    p_emoji,
    (SELECT phone FROM auth.users WHERE id = v_uid),
    TRUE
  )
  ON CONFLICT (id) DO UPDATE
    SET name      = CASE WHEN profiles.name  <> '' THEN profiles.name  ELSE EXCLUDED.name  END,
        emoji     = CASE WHEN profiles.emoji <> '👤' THEN profiles.emoji ELSE EXCLUDED.emoji END,
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
    SELECT id INTO v_wallet_id FROM wallets WHERE owner_id = v_uid AND is_personal = TRUE LIMIT 1;
  END IF;

  -- 3. Return combined result
  SELECT json_build_object(
    'profile_id', v_uid,
    'wallet_id',  v_wallet_id
  ) INTO v_profile;

  RETURN v_profile;
END;
$$;
