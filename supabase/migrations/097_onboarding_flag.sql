-- ═══════════════════════════════════════════════════════════════════════════
-- 097_onboarding_flag.sql
--
-- profiles.onboarded existed but bootstrap_new_user always forced it to TRUE
-- immediately on signup, so it never actually gated anything. Repurposing it
-- to drive the new onboarding-slides screen: new profiles now start
-- un-onboarded, and the app sets it TRUE once the user finishes (or skips)
-- the onboarding slides, via the new mark_onboarded RPC.
-- ═══════════════════════════════════════════════════════════════════════════

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
  -- 1. Upsert profile — preserve existing name/emoji/onboarded on re-login
  INSERT INTO profiles (id, name, emoji, phone, onboarded)
  VALUES (
    v_uid,
    p_name,
    p_emoji,
    (SELECT phone FROM auth.users WHERE id = v_uid),
    FALSE
  )
  ON CONFLICT (id) DO UPDATE
    SET name      = CASE WHEN profiles.name  <> '' THEN profiles.name  ELSE EXCLUDED.name  END,
        emoji     = CASE WHEN profiles.emoji <> '👤' THEN profiles.emoji ELSE EXCLUDED.emoji END,
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


CREATE OR REPLACE FUNCTION mark_onboarded()
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
AS $$
  UPDATE profiles SET onboarded = TRUE, updated_at = NOW() WHERE id = auth.uid();
$$;
