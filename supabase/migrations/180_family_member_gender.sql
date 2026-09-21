-- ══════════════════════════════════════════════════════════════
--  Expose gender within the family, like name/emoji already are
--
--  profiles.gender is otherwise private (RLS: id = auth.uid()).
--  Wardrobe's "Family Today" lets you switch between family members
--  and needs each member's gender to filter clothing categories
--  correctly for them — so, following the same denormalize-onto-
--  family_members + sync-trigger pattern as 153_sync_family_member_name,
--  add family_members.gender and keep it in sync with profiles.gender.
-- ══════════════════════════════════════════════════════════════

ALTER TABLE family_members
  ADD COLUMN IF NOT EXISTS gender TEXT;

-- One-time backfill for members already linked to a profile.
UPDATE family_members fm
SET gender = p.gender
FROM profiles p
WHERE fm.user_id = p.id
  AND p.gender IS NOT NULL
  AND fm.gender IS DISTINCT FROM p.gender;

CREATE OR REPLACE FUNCTION sync_family_member_gender()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.gender IS DISTINCT FROM OLD.gender THEN
    UPDATE family_members
    SET gender = NEW.gender
    WHERE user_id = NEW.id
      AND gender IS DISTINCT FROM NEW.gender;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_family_member_gender ON profiles;
CREATE TRIGGER trg_sync_family_member_gender
  AFTER UPDATE OF gender ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_family_member_gender();

-- Surface it through the switcher view (see 121_fix_family_switcher_
-- deleted_members.sql for the previous definition this replaces).
CREATE OR REPLACE VIEW my_profile_with_families AS
SELECT
  p.id AS profile_id,
  p.name,
  p.emoji,
  p.phone,
  p.onboarded,
  w.id AS personal_wallet_id,
  w.cash_in,
  w.cash_out,
  w.online_in,
  w.online_out,
  w.cash_in + w.online_in - w.cash_out - w.online_out AS personal_balance,
  COALESCE((
    SELECT json_agg(json_build_object(
      'family_id',    f.id,
      'name',         f.name,
      'emoji',        f.emoji,
      'color_index',  f.color_index,
      'description',  f.description,
      'my_role',      fm_me.role,
      'perm_invite',  f.perm_invite,
      'perm_edit',    f.perm_edit,
      'perm_delete',  f.perm_delete,
      'wallet_id',    fw.id,
      'balance',      fw.cash_in + fw.online_in - fw.cash_out - fw.online_out,
      'members', (
        SELECT json_agg(json_build_object(
          'id',       fm2.id,
          'user_id',  fm2.user_id,
          'name',     fm2.name,
          'emoji',    fm2.emoji,
          'role',     fm2.role,
          'relation', fm2.relation,
          'phone',    fm2.phone,
          'gender',   fm2.gender
        ))
        FROM family_members fm2
        WHERE fm2.family_id = f.id
          AND fm2.deleted_at IS NULL
      )
    ))
    FROM families f
    JOIN family_members fm_me
      ON fm_me.family_id = f.id
     AND fm_me.user_id   = p.id
     AND fm_me.deleted_at IS NULL
    LEFT JOIN wallets fw ON fw.family_id = f.id
    WHERE f.is_archived = false
  ), '[]'::json) AS families
FROM profiles p
LEFT JOIN wallets w ON w.owner_id = p.id AND w.is_personal = true
WHERE p.id = auth.uid();
