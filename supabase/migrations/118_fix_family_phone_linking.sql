-- ============================================================
-- 118_fix_family_phone_linking.sql
--
-- Three related bugs, reported after creating a real family group:
--   1. The admin's own family_members row never had `phone` filled in.
--   2. A member added by phone (who already has an account) ended up with
--      user_id = NULL instead of being linked.
--   3. As a direct consequence of #2, that member never saw the family at
--      all — my_profile_with_families (033) joins on
--      family_members.user_id = auth.uid(), so a NULL user_id can never
--      match anyone.
--
-- Root cause investigation found the real problem is one level deeper:
-- profiles.phone itself is NULL for accounts created through the current
-- Firebase-verify login flow. bootstrap_new_user has always tried to read
-- the phone from `auth.users.phone`, but this app's auth model (Firebase
-- Phone Auth -> a synthetic phone_<digits>@waiapp.internal Supabase user,
-- see firebase-verify/index.ts) never populates that column — the phone
-- only ever lives in the synthetic email. So `auth.users.phone` has been
-- NULL for every user created this way, profiles.phone was NULL as a
-- result, and add_family_member's (already-correct) phone-matching lookup
-- had nothing to match against even for existing accounts.
--
-- Separately: bootstrap_new_user used to also claim pending family_members
-- rows (phone matches, user_id IS NULL) added *before* someone signed up —
-- that logic was added in 031_fix_family_member_linking.sql, then silently
-- dropped when 064_fix_bootstrap_new_user.sql rewrote the function for an
-- unrelated owner_id/user_id fix, and was never restored (097 is based on
-- the 064 version). Restoring it here.
--
-- This migration:
--   A. One-time backfill: derive profiles.phone from auth.users.email for
--      every row where it's currently NULL (fixes existing accounts, not
--      just future signups).
--   B. One-time reconciliation: claim any existing family_members rows
--      with user_id IS NULL whose phone now matches a profile (fixes the
--      user's just-created family immediately, no re-invite needed).
--   C. bootstrap_new_user: derive phone from auth.users.email going
--      forward (the actually-reliable source), and restore the
--      claim-pending-slots step.
--   D. create_family_with_wallet: admin's own family_members row now
--      carries their phone too.
-- ============================================================

-- ── A. Backfill profiles.phone from the synthetic email ─────────────────────
-- Email is always phone_<digits>@waiapp.internal (see firebase-verify/
-- index.ts normalisePhone()) for every account created via this flow.
-- profiles.phone is UNIQUE — skip any row whose derived phone is already
-- claimed by a DIFFERENT profile (can happen when the same real phone
-- number has both a legacy dev_*/MSG91-era account and a newer
-- phone_*@waiapp.internal account; reconciling/merging those is a separate,
-- deliberately out-of-scope concern from this migration).
UPDATE profiles p
SET phone = derived.phone
FROM (
  SELECT u.id, '+' || (regexp_match(u.email, '^phone_(\d+)@waiapp\.internal$'))[1] AS phone
  FROM auth.users u
  WHERE u.email ~ '^phone_\d+@waiapp\.internal$'
) AS derived
WHERE p.id = derived.id
  AND p.phone IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM profiles other
    WHERE other.phone = derived.phone AND other.id <> p.id
  );

-- ── B. Reconcile existing unlinked family_members rows ───────────────────────
UPDATE family_members fm
SET user_id = p.id
FROM profiles p
WHERE fm.user_id IS NULL
  AND fm.phone IS NOT NULL
  AND p.phone IN (
    fm.phone,
    regexp_replace(fm.phone, '^\+?91', ''),
    '+91' || regexp_replace(fm.phone, '^\+?91', '')
  );

-- ── C. bootstrap_new_user — fix phone source, restore claim step ────────────
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

  -- Derive the verified phone from the synthetic email
  -- (phone_<digits>@waiapp.internal) — auth.users.phone is never populated
  -- by this app's Firebase-based login, so it can't be used as the source.
  IF v_email ~ '^phone_\d+@waiapp\.internal$' THEN
    v_phone := '+' || (regexp_match(v_email, '^phone_(\d+)@waiapp\.internal$'))[1];
  END IF;

  -- 1. Upsert profile — preserve existing name/emoji/onboarded on re-login
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

  -- 3. Claim any pending family_members slots that match this user's phone
  --    (added by another user, by phone, before this account existed).
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
    'profile_id',      v_uid,
    'wallet_id',       v_wallet_id,
    'families_joined', v_claimed
  );
END;
$$;

-- ── D. create_family_with_wallet — carry the admin's own phone ──────────────
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
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Authentication required'
      USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(p.plan, 'personal_free')
    INTO v_plan_key
    FROM profiles p
   WHERE p.id = v_uid;

  SELECT pl.*
    INTO v_limits
    FROM plan_limits pl
    JOIN subscription_plans sp ON sp.id = pl.plan_id
   WHERE sp.plan_key = COALESCE(v_plan_key, 'personal_free');

  IF v_limits.family_max_members = 0 THEN
    RAISE EXCEPTION 'Family groups require a Family plan. Upgrade to create a group.'
      USING ERRCODE = 'P0001';
  END IF;

  -- 1. Insert family
  INSERT INTO families (name, emoji, color_index, description, created_by)
  VALUES (p_name, p_emoji, p_color_index, p_description, v_uid)
  RETURNING id INTO v_family_id;

  -- 2. Add creator as admin member — now carries their phone too, matching
  --    every other family_members row (previously omitted entirely).
  SELECT name, emoji, phone INTO v_profile FROM profiles WHERE id = v_uid;
  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation, phone)
  VALUES (v_family_id, v_uid, COALESCE(v_profile.name, 'Me'), COALESCE(v_profile.emoji, '👤'), 'admin', 'Self', v_profile.phone);

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
