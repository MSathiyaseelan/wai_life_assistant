// ─────────────────────────────────────────────────────────────────────────────
// Subscription models — mirrors subscription_plans + plan_limits tables
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionPlanData {
  final String planKey;       // 'personal_free' | 'family_plus' | 'family_pro'
  final String name;
  final double priceMonthly;
  final double priceYearly;

  // ── Family ──────────────────────────────────────────────────────────────────
  final int familyMaxMembers;

  // ── AI ──────────────────────────────────────────────────────────────────────
  final int aiParserCallsMonth;
  final int aiAssistantCallsMonth;

  // ── Wallet ──────────────────────────────────────────────────────────────────
  final int walletTransactionsMonth;
  final int walletSplitGroupsMonth;
  final int walletBillWatchMax;
  final int walletCustomCategoriesMax;

  // ── Pantry ──────────────────────────────────────────────────────────────────
  final int pantryMealWeeksAhead;
  final int pantryRecipesMax;

  // ── Functions ───────────────────────────────────────────────────────────────
  final int functionsUpcomingMax;
  final int functionsMyMax;

  // ── Item Locator ────────────────────────────────────────────────────────────
  final int itemLocatorContainersMax;
  final int itemLocatorItemsMax;

  // ── Wardrobe ────────────────────────────────────────────────────────────────
  final int wardrobeItemsMax;
  final int wardrobeOutfitLogMonths;

  // ── Health ──────────────────────────────────────────────────────────────────
  final int healthMedicationsMax;
  final int healthAppointmentsMax;
  final int healthVitalLogsMonth;

  // ── PlanIt ──────────────────────────────────────────────────────────────────
  final int planItTasksMax;
  final int planItRemindersMax;
  final int planItSpecialDaysMax;

  // ── Notifications ────────────────────────────────────────────────────────────
  final bool notifPushEnabled;
  final bool notifCustomAlerts;

  const SubscriptionPlanData({
    required this.planKey,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.familyMaxMembers,
    required this.aiParserCallsMonth,
    required this.aiAssistantCallsMonth,
    required this.walletTransactionsMonth,
    required this.walletSplitGroupsMonth,
    required this.walletBillWatchMax,
    required this.walletCustomCategoriesMax,
    required this.pantryMealWeeksAhead,
    required this.pantryRecipesMax,
    required this.functionsUpcomingMax,
    required this.functionsMyMax,
    required this.itemLocatorContainersMax,
    required this.itemLocatorItemsMax,
    required this.wardrobeItemsMax,
    required this.wardrobeOutfitLogMonths,
    required this.healthMedicationsMax,
    required this.healthAppointmentsMax,
    required this.healthVitalLogsMonth,
    required this.planItTasksMax,
    required this.planItRemindersMax,
    required this.planItSpecialDaysMax,
    required this.notifPushEnabled,
    required this.notifCustomAlerts,
  });

  factory SubscriptionPlanData.fromRow(Map<String, dynamic> row) {
    final lim = row['plan_limits'] as Map<String, dynamic>? ?? {};
    int i(String k, [int def = 0]) => (lim[k] as num?)?.toInt() ?? def;
    bool b(String k) => lim[k] as bool? ?? false;

    return SubscriptionPlanData(
      planKey:      row['plan_key']      as String,
      name:         row['name']          as String,
      priceMonthly: (row['price_monthly'] as num?)?.toDouble() ?? 0,
      priceYearly:  (row['price_yearly']  as num?)?.toDouble() ?? 0,

      familyMaxMembers:          i('family_max_members'),
      aiParserCallsMonth:        i('ai_parser_calls_month',     30),
      aiAssistantCallsMonth:     i('ai_assistant_calls_month',  20),
      walletTransactionsMonth:   i('wallet_transactions_month', 100),
      walletSplitGroupsMonth:    i('wallet_split_groups_month', 3),
      walletBillWatchMax:        i('wallet_bill_watch_max',     5),
      walletCustomCategoriesMax: i('wallet_custom_categories_max', 10),
      pantryMealWeeksAhead:      i('pantry_meal_weeks_ahead',   1),
      pantryRecipesMax:          i('pantry_recipes_max',        10),
      functionsUpcomingMax:      i('functions_upcoming_max',    15),
      functionsMyMax:            i('functions_my_max',          5),
      itemLocatorContainersMax:  i('item_locator_containers_max', 5),
      itemLocatorItemsMax:       i('item_locator_items_max',    50),
      wardrobeItemsMax:          i('wardrobe_items_max',        30),
      wardrobeOutfitLogMonths:   i('wardrobe_outfit_log_months',1),
      healthMedicationsMax:      i('health_medications_max',    15),
      healthAppointmentsMax:     i('health_appointments_max',   20),
      healthVitalLogsMonth:      i('health_vital_logs_month',   60),
      planItTasksMax:            i('planit_tasks_max',          50),
      planItRemindersMax:        i('planit_reminders_max',      30),
      planItSpecialDaysMax:      i('planit_special_days_max',   30),
      notifPushEnabled:          b('notif_push_enabled'),
      notifCustomAlerts:         b('notif_custom_alerts'),
    );
  }

  /// Returns a human-readable display string for a numeric limit.
  /// -1 → '∞', 0 → '—', anything else → the number.
  static String limitLabel(int value) {
    if (value == -1) return '∞';
    if (value == 0)  return '—';
    return '$value';
  }

  /// Formats weeks/months with a unit suffix, respecting -1 = ∞.
  static String weeksLabel(int value) {
    if (value == -1) return '∞';
    return value == 1 ? '1 wk' : '$value wks';
  }

  static String monthsLabel(int value) {
    if (value == -1) return '∞';
    return value == 1 ? '1 mo' : '$value mo';
  }

  static String boolLabel(bool value) => value ? '✓' : '✗';
}
