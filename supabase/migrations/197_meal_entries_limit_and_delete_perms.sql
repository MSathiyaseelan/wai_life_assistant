-- ============================================================
-- 197_meal_entries_limit_and_delete_perms.sql
--
-- Two Meal Map fixes:
--
-- 1. Weeks-ahead limit (113) — the trigger compared against UTC
--    CURRENT_DATE, so for users ahead of UTC (IST) the last allowed day
--    shown by the app was rejected between local midnight and 05:30.
--    It also re-checked the date on EVERY update, so after a plan
--    downgrade a family couldn't even mark an already-planned far-ahead
--    meal as cooked or delete it. Now: one day of timezone slack, and
--    updates are only checked when the date itself changes. The client
--    uses the same rolling rule (today + weeks*7 days).
--
-- 2. Delete permission — meals are soft-deleted (UPDATE deleted_at), so
--    the UPDATE policy (creator OR wallet_can_edit) governed deletes and
--    perm_delete was never consulted. A member with delete-but-not-edit
--    rights had their delete silently dropped by RLS; one with
--    edit-but-not-delete rights could delete anyway. Now the UPDATE policy
--    admits either right, and a trigger requires wallet_can_delete for a
--    deleted_at change (delete / recycle-bin restore) and wallet_can_edit
--    for everything else — the creator is always allowed, as before.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enforce_meal_weeks_ahead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  limits plan_limits;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.date IS NOT DISTINCT FROM OLD.date THEN
    RETURN NEW;
  END IF;

  limits := get_plan_limits(NEW.wallet_id);

  -- +1: CURRENT_DATE is UTC; the user's local "today" can be a day ahead.
  IF limits.pantry_meal_weeks_ahead != -1
     AND NEW.date > CURRENT_DATE + 1 + (limits.pantry_meal_weeks_ahead * 7) THEN
    RAISE EXCEPTION 'Meal date is beyond your plan''s %-week planning limit', limits.pantry_meal_weeks_ahead
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$function$;

DROP POLICY IF EXISTS "meal_entries: creator or admin update" ON meal_entries;
CREATE POLICY "meal_entries: creator or admin update" ON meal_entries
  FOR UPDATE USING (
    created_by = auth.uid()
    OR wallet_can_edit(wallet_id)
    OR wallet_can_delete(wallet_id)
  );

CREATE OR REPLACE FUNCTION public.enforce_meal_entry_update_perms()
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
      RAISE EXCEPTION 'Not allowed to delete meals in this family'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    -- A delete/restore must not smuggle in content edits.
    IF (to_jsonb(NEW) - 'deleted_at' - 'updated_at')
       IS DISTINCT FROM (to_jsonb(OLD) - 'deleted_at' - 'updated_at')
       AND NOT wallet_can_edit(OLD.wallet_id) THEN
      RAISE EXCEPTION 'Not allowed to edit meals in this family'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSIF NOT wallet_can_edit(OLD.wallet_id) THEN
    RAISE EXCEPTION 'Not allowed to edit meals in this family'
      USING ERRCODE = 'insufficient_privilege';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_meal_entry_update_perms ON meal_entries;
CREATE TRIGGER trg_enforce_meal_entry_update_perms
  BEFORE UPDATE ON meal_entries
  FOR EACH ROW EXECUTE FUNCTION enforce_meal_entry_update_perms();
