-- Migration 108: Add PlanIt limits to the shared feature-limit resolver.
--
-- plan_limits.planit_tasks_max (50), planit_reminders_max (30),
-- planit_notes_max (20), planit_special_days_max (30), planit_wishlist_max
-- (25) have existed since 054_subscription_system.sql but were never
-- enforced anywhere. All five are standing counts (like pantry_recipes_max)
-- — deleting one frees a slot for another.

CREATE OR REPLACE FUNCTION public.resolve_feature_scope(
  p_user_id uuid,
  p_feature text,
  OUT best_limit integer,
  OUT best_wallet_id uuid
)
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $function$
DECLARE
  personal_limits plan_limits;
  wallet_limits    plan_limits;
  fam_limit        INTEGER;
  fam_wallet       RECORD;
BEGIN
  best_wallet_id := NULL;
  personal_limits := get_plan_limits(NULL);

  best_limit := CASE p_feature
    WHEN 'ai_parser'              THEN personal_limits.ai_parser_calls_month
    WHEN 'ai_assistant'           THEN personal_limits.ai_assistant_calls_month
    WHEN 'bill_scan'              THEN personal_limits.ai_parser_calls_month
    WHEN 'wallet_transaction'     THEN personal_limits.wallet_transactions_month
    WHEN 'split_group'            THEN personal_limits.wallet_split_groups_month
    WHEN 'custom_category'        THEN personal_limits.wallet_custom_categories_max
    WHEN 'saved_recipe'           THEN personal_limits.pantry_recipes_max
    WHEN 'my_function'            THEN personal_limits.functions_my_max
    WHEN 'upcoming_function'      THEN personal_limits.functions_upcoming_max
    WHEN 'attended_function'      THEN personal_limits.functions_attended_max
    WHEN 'item_locator_container' THEN personal_limits.item_locator_containers_max
    WHEN 'item_locator_item'      THEN personal_limits.item_locator_items_max
    WHEN 'wardrobe_item'          THEN personal_limits.wardrobe_items_max
    WHEN 'wardrobe_outfit_history' THEN personal_limits.wardrobe_outfit_log_months
    WHEN 'health_medication'      THEN personal_limits.health_medications_max
    WHEN 'health_appointment'     THEN personal_limits.health_appointments_max
    WHEN 'health_vital_log'       THEN personal_limits.health_vital_logs_month
    WHEN 'health_vaccine'         THEN personal_limits.health_vaccines_max
    WHEN 'health_doctor'          THEN personal_limits.health_doctors_max
    WHEN 'health_insurance'       THEN personal_limits.health_insurance_max
    WHEN 'health_document'        THEN personal_limits.health_documents_max
    WHEN 'planit_task'            THEN personal_limits.planit_tasks_max
    WHEN 'planit_reminder'        THEN personal_limits.planit_reminders_max
    WHEN 'planit_note'            THEN personal_limits.planit_notes_max
    WHEN 'planit_special_day'     THEN personal_limits.planit_special_days_max
    WHEN 'planit_wishlist'        THEN personal_limits.planit_wishlist_max
    ELSE 10
  END;

  -- -1 already means unlimited on the personal plan; nothing can beat that.
  IF best_limit != -1 THEN
    FOR fam_wallet IN
      SELECT w.id AS wallet_id
        FROM family_members fm
        JOIN wallets w ON w.family_id = fm.family_id
       WHERE fm.user_id = p_user_id
         AND fm.deleted_at IS NULL
    LOOP
      wallet_limits := get_plan_limits(fam_wallet.wallet_id);
      fam_limit := CASE p_feature
        WHEN 'ai_parser'              THEN wallet_limits.ai_parser_calls_month
        WHEN 'ai_assistant'           THEN wallet_limits.ai_assistant_calls_month
        WHEN 'bill_scan'              THEN wallet_limits.ai_parser_calls_month
        WHEN 'wallet_transaction'     THEN wallet_limits.wallet_transactions_month
        WHEN 'split_group'            THEN wallet_limits.wallet_split_groups_month
        WHEN 'custom_category'        THEN wallet_limits.wallet_custom_categories_max
        WHEN 'saved_recipe'           THEN wallet_limits.pantry_recipes_max
        WHEN 'my_function'            THEN wallet_limits.functions_my_max
        WHEN 'upcoming_function'      THEN wallet_limits.functions_upcoming_max
        WHEN 'attended_function'      THEN wallet_limits.functions_attended_max
        WHEN 'item_locator_container' THEN wallet_limits.item_locator_containers_max
        WHEN 'item_locator_item'      THEN wallet_limits.item_locator_items_max
        WHEN 'wardrobe_item'          THEN wallet_limits.wardrobe_items_max
        WHEN 'wardrobe_outfit_history' THEN wallet_limits.wardrobe_outfit_log_months
        WHEN 'health_medication'      THEN wallet_limits.health_medications_max
        WHEN 'health_appointment'     THEN wallet_limits.health_appointments_max
        WHEN 'health_vital_log'       THEN wallet_limits.health_vital_logs_month
        WHEN 'health_vaccine'         THEN wallet_limits.health_vaccines_max
        WHEN 'health_doctor'          THEN wallet_limits.health_doctors_max
        WHEN 'health_insurance'       THEN wallet_limits.health_insurance_max
        WHEN 'health_document'        THEN wallet_limits.health_documents_max
        WHEN 'planit_task'            THEN wallet_limits.planit_tasks_max
        WHEN 'planit_reminder'        THEN wallet_limits.planit_reminders_max
        WHEN 'planit_note'            THEN wallet_limits.planit_notes_max
        WHEN 'planit_special_day'     THEN wallet_limits.planit_special_days_max
        WHEN 'planit_wishlist'        THEN wallet_limits.planit_wishlist_max
        ELSE 10
      END;

      IF fam_limit = -1 THEN
        best_limit := -1;
        best_wallet_id := fam_wallet.wallet_id;
        EXIT;
      ELSIF fam_limit > best_limit THEN
        best_limit := fam_limit;
        best_wallet_id := fam_wallet.wallet_id;
      END IF;
    END LOOP;
  END IF;
END;
$function$;
