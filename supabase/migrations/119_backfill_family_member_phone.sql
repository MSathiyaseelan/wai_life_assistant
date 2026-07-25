-- ============================================================
-- 119_backfill_family_member_phone.sql
--
-- 118_fix_family_phone_linking.sql fixed create_family_with_wallet to carry
-- the admin's phone into family_members going forward, and backfilled
-- profiles.phone for existing accounts — but it didn't retroactively fill
-- in family_members.phone for rows that were already linked (user_id set)
-- before that fix existed. Confirmed still NULL on real data after 118 ran.
-- ============================================================

UPDATE family_members fm
SET phone = p.phone
FROM profiles p
WHERE fm.user_id = p.id
  AND fm.phone IS NULL
  AND p.phone IS NOT NULL;
