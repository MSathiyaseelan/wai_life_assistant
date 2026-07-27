-- ============================================================
-- 126_fix_delete_account_fk_cascades.sql
--
-- Found while cleaning up a duplicate dev account: deleting a user via
-- `DELETE FROM auth.users` (what delete-account/index.ts's
-- admin.auth.admin.deleteUser() does under the hood) failed with
-- "violates foreign key constraint ai_parse_logs_user_id_fkey" — that FK
-- (and several others on personal, user-owned data) had no ON DELETE
-- action at all, unlike every other user-owned table which cascades.
--
-- This means the app's own "Delete Account" feature (DPDP Act
-- compliance requirement) would fail outright for any real user who has
-- ever used AI bill/SMS parsing or the Functions (event planning)
-- module — a real production bug, not just a dev-cleanup inconvenience.
-- ============================================================

ALTER TABLE ai_parse_logs
  DROP CONSTRAINT ai_parse_logs_user_id_fkey,
  ADD CONSTRAINT ai_parse_logs_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE function_bridal_essentials
  DROP CONSTRAINT function_bridal_essentials_user_id_fkey,
  ADD CONSTRAINT function_bridal_essentials_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE function_clothing_families
  DROP CONSTRAINT function_clothing_families_user_id_fkey,
  ADD CONSTRAINT function_clothing_families_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE function_participants
  DROP CONSTRAINT function_participants_user_id_fkey,
  ADD CONSTRAINT function_participants_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- function_plan_messages / function_plan_vendors are dev-only WIP tables
-- (not yet applied to every environment) — guard so this migration stays
-- safe to run wherever they don't exist yet.
DO $$
BEGIN
  IF to_regclass('public.function_plan_messages') IS NOT NULL THEN
    ALTER TABLE function_plan_messages
      DROP CONSTRAINT function_plan_messages_user_id_fkey,
      ADD CONSTRAINT function_plan_messages_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;

  IF to_regclass('public.function_plan_vendors') IS NOT NULL THEN
    ALTER TABLE function_plan_vendors
      DROP CONSTRAINT function_plan_vendors_user_id_fkey,
      ADD CONSTRAINT function_plan_vendors_user_id_fkey
        FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END;
$$;

ALTER TABLE function_return_gifts
  DROP CONSTRAINT function_return_gifts_user_id_fkey,
  ADD CONSTRAINT function_return_gifts_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

-- family_invites references profiles, not auth.users directly — an
-- invite sent by or to a deleted account no longer means anything, so
-- cascade these too rather than leaving them orphaned/blocking.
ALTER TABLE family_invites
  DROP CONSTRAINT family_invites_invited_by_id_fkey,
  ADD CONSTRAINT family_invites_invited_by_id_fkey
    FOREIGN KEY (invited_by_id) REFERENCES profiles(id) ON DELETE CASCADE;

ALTER TABLE family_invites
  DROP CONSTRAINT family_invites_invited_user_id_fkey,
  ADD CONSTRAINT family_invites_invited_user_id_fkey
    FOREIGN KEY (invited_user_id) REFERENCES profiles(id) ON DELETE SET NULL;
