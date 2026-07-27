-- ============================================================
-- 121_fix_family_switcher_deleted_members.sql
--
-- Reported: "unable to add/delete family member" — removing a member
-- appeared to silently fail, and re-adding looked like it created a
-- duplicate/broken state.
--
-- Root cause: my_profile_with_families' embedded `members` json_agg never
-- filtered out soft-deleted rows (family_members.deleted_at). The DB write
-- for removeMember() was succeeding the whole time — confirmed on real QA
-- data (deleted_at correctly set) — but the switcher/settings UI reads
-- this view, so removed members never actually disappeared from the list.
--
-- Also adding the same deleted_at guard to the fm_me join, so a user whose
-- own membership was soft-deleted (left the family) stops seeing that
-- family in their switcher at all.
-- ============================================================

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
          'phone',    fm2.phone
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
