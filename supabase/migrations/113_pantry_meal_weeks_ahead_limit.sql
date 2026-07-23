-- ============================================================
-- 113_pantry_meal_weeks_ahead_limit.sql
--
-- plan_limits.pantry_meal_weeks_ahead caps how far in the future a meal
-- can be planned. It was only enforced client-side — pantry_screen.dart
-- passes it into WeekCalendarStrip.maxWeeksAhead to restrict which
-- dates are selectable in the picker — but addMealEntry/updateMealEntry
-- accepted any date with no matching server-side check, so a direct API
-- call (or any future code path that skips the calendar widget) could
-- plan meals arbitrarily far ahead regardless of plan.
--
-- Fix: a BEFORE INSERT OR UPDATE trigger on meal_entries that mirrors
-- the client's own lookup exactly — get_plan_limits(NEW.wallet_id),
-- same function/argument the client calls via get_plan_limits RPC in
-- _loadPlanLimits() — and rejects the row if its date is further out
-- than that many weeks from today. -1 means unlimited, same convention
-- as every other limit in plan_limits.
-- ============================================================

CREATE OR REPLACE FUNCTION public.enforce_meal_weeks_ahead()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  limits plan_limits;
BEGIN
  limits := get_plan_limits(NEW.wallet_id);

  IF limits.pantry_meal_weeks_ahead != -1
     AND NEW.date > CURRENT_DATE + (limits.pantry_meal_weeks_ahead * 7) THEN
    RAISE EXCEPTION 'Meal date is beyond your plan''s %-week planning limit', limits.pantry_meal_weeks_ahead
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_enforce_meal_weeks_ahead ON meal_entries;
CREATE TRIGGER trg_enforce_meal_weeks_ahead
  BEFORE INSERT OR UPDATE ON meal_entries
  FOR EACH ROW EXECUTE FUNCTION enforce_meal_weeks_ahead();
