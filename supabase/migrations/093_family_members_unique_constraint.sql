-- ═══════════════════════════════════════════════════════════════════════════
-- 093_family_members_unique_constraint.sql
--
-- Fixes: "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification" (Postgres error 42P10), hit when a user re-joins a family
-- they're already a member of (e.g. an admin re-using their own invite code).
--
-- join_family_by_token and accept_family_invite (supabase/family_invites.sql)
-- both do:
--   INSERT INTO family_members (family_id, user_id, ...)
--   ON CONFLICT (family_id, user_id) DO NOTHING;
-- assuming a unique constraint on (family_id, user_id) — but family_members
-- (001_wallet_schema.sql) only ever got plain, non-unique indexes on
-- family_id and user_id individually. The constraint the ON CONFLICT clause
-- needs was never actually created, so Postgres has no arbiter to match
-- against and raises 42P10 instead of silently no-op'ing.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Dedupe any pre-existing duplicate (family_id, user_id) rows before adding
--    the unique index below (a duplicate would make CREATE UNIQUE INDEX fail).
--    Only real accounts are affected — user_id IS NOT NULL — since pending
--    phone-only invite slots (031_fix_family_member_linking.sql) keep
--    user_id NULL, and NULL is never considered equal to NULL for a unique
--    index, so those are untouched. Keep the earliest row per pair.
DELETE FROM family_members fm
USING family_members dup
WHERE fm.family_id = dup.family_id
  AND fm.user_id = dup.user_id
  AND fm.user_id IS NOT NULL
  AND fm.id <> dup.id
  AND (fm.created_at, fm.id) > (dup.created_at, dup.id);

-- 2. Add the unique index the ON CONFLICT clauses already assume exists.
CREATE UNIQUE INDEX IF NOT EXISTS family_members_family_user_key
  ON family_members (family_id, user_id);
