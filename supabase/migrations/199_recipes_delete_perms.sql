-- ============================================================
-- 199_recipes_delete_perms.sql
--
-- Same gap 197 fixed for meal_entries: recipes are soft-deleted
-- ("Untag" = UPDATE deleted_at), so the UPDATE policy (creator OR
-- wallet_can_edit) governed deletes and perm_delete was never consulted.
-- A member with delete-but-not-edit rights had an untag silently dropped
-- by RLS; one with edit-but-not-delete rights could untag anyway.
--
-- Fix: the UPDATE policy admits either right, and a trigger requires
-- wallet_can_delete for a deleted_at change (untag / "Add back" /
-- recycle-bin restore) and wallet_can_edit for everything else. The
-- creator is always allowed, as before.
--
-- The trigger function is table-agnostic (any table with created_by,
-- wallet_id, deleted_at) so other soft-deleted tables can reuse it.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enforce_soft_delete_update_perms()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
  -- Server-side jobs (purge, account deletion) run without a user.
  IF auth.uid() IS NULL OR OLD.created_by = auth.uid() THEN
    RETURN NEW;
  END IF;

  IF NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN
    IF NOT wallet_can_delete(OLD.wallet_id) THEN
      RAISE EXCEPTION 'Not allowed to delete % in this family', TG_TABLE_NAME
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    -- A delete/restore must not smuggle in content edits.
    IF (to_jsonb(NEW) - 'deleted_at' - 'updated_at')
       IS DISTINCT FROM (to_jsonb(OLD) - 'deleted_at' - 'updated_at')
       AND NOT wallet_can_edit(OLD.wallet_id) THEN
      RAISE EXCEPTION 'Not allowed to edit % in this family', TG_TABLE_NAME
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSIF NOT wallet_can_edit(OLD.wallet_id) THEN
    RAISE EXCEPTION 'Not allowed to edit % in this family', TG_TABLE_NAME
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$function$;

DROP POLICY IF EXISTS "recipes: creator or admin update" ON recipes;
CREATE POLICY "recipes: creator or admin update" ON recipes
  FOR UPDATE USING (
    created_by = auth.uid()
    OR wallet_can_edit(wallet_id)
    OR wallet_can_delete(wallet_id)
  );

DROP TRIGGER IF EXISTS trg_enforce_recipe_update_perms ON recipes;
CREATE TRIGGER trg_enforce_recipe_update_perms
  BEFORE UPDATE ON recipes
  FOR EACH ROW EXECUTE FUNCTION enforce_soft_delete_update_perms();
