abstract final class DbTable {
  // ── Core ───────────────────────────────────────────────────────────────────
  static const String profiles         = 'profiles';
  static const String families         = 'families';
  static const String familyMembers    = 'family_members';
  static const String wallets          = 'wallets';
  static const String appConfig        = 'app_config';
  static const String featureUsage     = 'feature_usage';
  static const String notifications    = 'notifications';
  static const String userFcmTokens   = 'user_fcm_tokens';

  // ── Wallet ─────────────────────────────────────────────────────────────────
  static const String transactions     = 'transactions';
  static const String txGroups         = 'tx_groups';
  static const String userTxCategories = 'user_tx_categories';
  static const String walletBudgets    = 'wallet_budgets';
  static const String bills            = 'bills';

  // ── Split ──────────────────────────────────────────────────────────────────
  static const String splitGroups             = 'split_groups';
  static const String splitParticipants       = 'split_participants';
  static const String splitGroupTransactions  = 'split_group_transactions';
  static const String splitShares             = 'split_shares';
  static const String splitGroupMessages      = 'split_group_messages';

  // ── Pantry ─────────────────────────────────────────────────────────────────
  static const String groceryItems     = 'grocery_items';
  static const String recipes          = 'recipes';
  static const String masterRecipes    = 'master_recipes';
  static const String mealEntries      = 'meal_entries';
  static const String mealReactions    = 'meal_reactions';
  static const String memberFoodPrefs  = 'member_food_prefs';

  // ── PlanIt ─────────────────────────────────────────────────────────────────
  static const String tasks            = 'tasks';
  static const String reminders        = 'reminders';
  static const String specialDays      = 'special_days';
  static const String wishes           = 'wishes';
  static const String notes            = 'notes';

  // ── Health ─────────────────────────────────────────────────────────────────
  static const String healthProfiles      = 'health_profiles';
  static const String healthMedications   = 'health_medications';
  static const String healthDoctors       = 'health_doctors';
  static const String healthDocuments     = 'health_documents';
  static const String healthAppointments  = 'health_appointments';
  static const String healthVitals        = 'health_vitals';
  static const String healthVaccinations  = 'health_vaccinations';
  static const String healthInsurance     = 'health_insurance';

  // ── Lifestyle ──────────────────────────────────────────────────────────────
  static const String wardrobeItems       = 'wardrobe_items';
  static const String wardrobeOutfitLogs  = 'wardrobe_outfit_logs';
  static const String itemLocatorContainers = 'item_locator_containers';
  static const String itemLocatorItems    = 'item_locator_items';

  // ── Functions / Events ─────────────────────────────────────────────────────
  static const String functionsUpcoming         = 'functions_upcoming';
  static const String functionsMy               = 'functions_my';
  static const String functionsAttended         = 'functions_attended';
  static const String functionParticipants      = 'function_participants';
  static const String functionMoiEntries        = 'function_moi_entries';
  static const String functionReturnGifts       = 'function_return_gifts';
  static const String functionClothingFamilies  = 'function_clothing_families';
  static const String functionBridalEssentials  = 'function_bridal_essentials';

  // ── Subscription ───────────────────────────────────────────────────────────
  static const String subscriptionPlans  = 'subscription_plans';

  // ── AI ─────────────────────────────────────────────────────────────────────
  static const String aiPrompts          = 'ai_prompts';
  static const String errorLogs          = 'error_logs';
}
