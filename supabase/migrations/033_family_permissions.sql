-- ============================================================
--  Migration 033 — Family Permissions
--  Adds configurable perm_invite / perm_edit / perm_delete
--  columns to the families table and refreshes the
--  my_profile_with_families view to expose them.
-- ============================================================

ALTER TABLE families
  ADD COLUMN IF NOT EXISTS perm_invite TEXT NOT NULL DEFAULT 'admin_only'
    CHECK (perm_invite IN ('admin_only', 'any_member')),
  ADD COLUMN IF NOT EXISTS perm_edit   TEXT NOT NULL DEFAULT 'any_member'
    CHECK (perm_edit   IN ('admin_only', 'any_member')),
  ADD COLUMN IF NOT EXISTS perm_delete TEXT NOT NULL DEFAULT 'admin_only'
    CHECK (perm_delete IN ('admin_only', 'any_member'));

-- ── Refresh view to expose the new columns ───────────────────
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
          'perm_invite',  f.perm_invite,
          'perm_edit',    f.perm_edit,
          'perm_delete',  f.perm_delete,
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
