-- Migration 106: Add 'wardrobe_item' / 'wardrobe_outfit_history' to the
-- shared feature-limit resolver.
--
-- plan_limits.wardrobe_items_max (30) and wardrobe_outfit_log_months (1) have
-- existed since 054_subscription_system.sql but were never enforced.
-- wardrobe_item is a standing count cap (like pantry_recipes_max). Outfit
-- logs have no delete method and are a permanent daily record, so
-- wardrobe_outfit_history is instead a view-window limit — how many months
-- back fetchOutfitLogs returns, not a write-side restriction.

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
