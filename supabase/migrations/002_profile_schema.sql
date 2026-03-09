-- ============================================================
--  WAI Life Assistant — Profile & Family Selection Schema
--  Extends 001_wallet_schema.sql
--  Run this in: Supabase Dashboard → SQL Editor
-- ============================================================


-- ══════════════════════════════════════════════════════════════
--  ADDITIONAL PROFILE COLUMNS
--  (profiles base table is created in 001_wallet_schema.sql)
-- ══════════════════════════════════════════════════════════════
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS display_name  TEXT,
  ADD COLUMN IF NOT EXISTS relation_self TEXT DEFAULT 'Self',
  ADD COLUMN IF NOT EXISTS onboarded     BOOLEAN NOT NULL DEFAULT FALSE;
-- onboarded = TRUE after user completes profile setup & personal wallet is created


-- ══════════════════════════════════════════════════════════════
--  ADDITIONAL FAMILY COLUMNS
-- ══════════════════════════════════════════════════════════════
ALTER TABLE families
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE;


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: bootstrap_new_user
--  Creates the personal wallet + profile row in one call.
--  Call this once from the app right after OTP sign-in succeeds.
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
  v_wallet_id  UUID;
  v_profile    JSON;
BEGIN
  -- 1. Upsert profile
  INSERT INTO profiles (id, name, emoji, phone, onboarded)
  VALUES (
    v_uid,
    p_name,
    p_emoji,
    (SELECT phone FROM auth.users WHERE id = v_uid),
    TRUE
  )
  ON CONFLICT (id) DO UPDATE
    SET name      = EXCLUDED.name,
        emoji     = EXCLUDED.emoji,
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


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: create_family_with_wallet
--  Creates family + member row for creator + family wallet atomically.
-- ══════════════════════════════════════════════════════════════
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
  v_uid       UUID := auth.uid();
  v_family_id UUID;
  v_wallet_id UUID;
  v_profile   RECORD;
BEGIN
  -- 1. Insert family
  INSERT INTO families (name, emoji, color_index, description, created_by)
  VALUES (p_name, p_emoji, p_color_index, p_description, v_uid)
  RETURNING id INTO v_family_id;

  -- 2. Add creator as admin member
  SELECT name, emoji INTO v_profile FROM profiles WHERE id = v_uid;
  INSERT INTO family_members (family_id, user_id, name, emoji, role, relation)
  VALUES (v_family_id, v_uid, COALESCE(v_profile.name,'Me'), COALESCE(v_profile.emoji,'👤'), 'admin', 'Self');

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


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: update_family
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION update_family(
  p_family_id   UUID,
  p_name        TEXT,
  p_emoji       TEXT,
  p_color_index INTEGER DEFAULT 0,
  p_description TEXT    DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Only admin can update
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can update family details';
  END IF;

  UPDATE families
  SET name        = p_name,
      emoji       = p_emoji,
      color_index = p_color_index,
      description = p_description
  WHERE id = p_family_id;

  -- Keep wallet name/emoji in sync
  UPDATE wallets
  SET name  = p_name,
      emoji = p_emoji,
      gradient_index = p_color_index,
      updated_at = NOW()
  WHERE family_id = p_family_id;
END;
$$;


-- ══════════════════════════════════════════════════════════════
--  FUNCTION: delete_family
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION delete_family(p_family_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM family_members
    WHERE family_id = p_family_id AND user_id = auth.uid() AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Only admins can delete a family';
  END IF;

  -- Cascades to family_members, wallets, transactions, split_groups
  DELETE FROM families WHERE id = p_family_id;
END;
$$;


-- ══════════════════════════════════════════════════════════════
--  VIEW: my_profile_with_families
--  Returns the current user's profile + all families they belong to
--  with each family's member list. Used to seed FamilySwitcherSheet.
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW my_profile_with_families AS
SELECT
  p.id              AS profile_id,
  p.name,
  p.emoji,
  p.phone,
  p.onboarded,
  w.id              AS personal_wallet_id,
  w.cash_in, w.cash_out, w.online_in, w.online_out,
  (w.cash_in + w.online_in - w.cash_out - w.online_out) AS personal_balance,
  -- Families as JSON array
  COALESCE(
    (
      SELECT json_agg(
        json_build_object(
          'family_id',    f.id,
          'name',         f.name,
          'emoji',        f.emoji,
          'color_index',  f.color_index,
          'description',  f.description,
          'my_role',      fm_me.role,
          'wallet_id',    fw.id,
          'balance',      fw.cash_in + fw.online_in - fw.cash_out - fw.online_out,
          'members',      (
            SELECT json_agg(
              json_build_object(
                'id',       fm2.id,
                'user_id',  fm2.user_id,
                'name',     fm2.name,
                'emoji',    fm2.emoji,
                'role',     fm2.role,
                'relation', fm2.relation,
                'phone',    fm2.phone
              )
            ) FROM family_members fm2 WHERE fm2.family_id = f.id
          )
        )
      )
      FROM families f
      JOIN family_members fm_me ON fm_me.family_id = f.id AND fm_me.user_id = p.id
      LEFT JOIN wallets fw ON fw.family_id = f.id
      WHERE f.is_archived = FALSE
    ),
    '[]'::json
  ) AS families
FROM profiles p
LEFT JOIN wallets w ON w.owner_id = p.id AND w.is_personal = TRUE
WHERE p.id = auth.uid();
