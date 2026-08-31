import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wai_life_assistant/core/config/feature_flags.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';
import 'package:wai_life_assistant/data/models/subscription/subscription_models.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'package:wai_life_assistant/data/services/profile_service.dart';
import 'package:wai_life_assistant/data/services/subscription_service.dart';
import 'package:wai_life_assistant/features/AppStateNotifier.dart';
import 'package:wai_life_assistant/features/subscription/paywall_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUBSCRIPTION SHEET
// Reflects the subscription_plans + plan_limits DB tables (migration 054/060)
// Tiers: personal_free | family_plus | family_pro
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionSheet extends StatefulWidget {
  final bool isDark;
  final String currentPlan; // 'personal_free' | 'family_plus' | 'family_pro'

  const SubscriptionSheet({
    super.key,
    required this.isDark,
    required this.currentPlan,
  });

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  String _billingCycle = 'monthly';
  List<SubscriptionPlanData>? _plans;
  bool _loading = true;
  bool _hasError = false;
  Offerings? _offerings;

  // ── colours ────────────────────────────────────────────────────────────────
  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _surf => widget.isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;
  Color get _div  => widget.isDark
      ? Colors.white.withAlpha(18)
      : Colors.black.withAlpha(18);

  bool get _isFree => widget.currentPlan == 'personal_free';
  bool get _isPlus => widget.currentPlan == 'family_plus';
  bool get _isPro  => widget.currentPlan == 'family_pro';

  static const _personalColor = Color(0xFF8E8EA0);
  static const _plusColor     = Color(0xFFD97706);
  static const _proColor      = Color(0xFF6C63FF);

  Color get _planColor =>
      _isPro ? _proColor : _isPlus ? _plusColor : _personalColor;

  String get _planEmoji =>
      _isPro ? '👑' : _isPlus ? '👨‍👩‍👧' : '👤';

  String get _planName =>
      _isPro ? 'Family Pro' : _isPlus ? 'Family Plus' : 'Personal';

  SubscriptionPlanData? get _personal =>
      _plans?.where((p) => p.planKey == 'personal_free').firstOrNull ??
      _plans?.firstOrNull;
  SubscriptionPlanData? get _plus =>
      _plans?.where((p) => p.planKey == 'family_plus').firstOrNull;
  SubscriptionPlanData? get _pro =>
      _plans?.where((p) => p.planKey == 'family_pro').firstOrNull;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadOfferings();
  }

  Future<void> _loadPlans() async {
    setState(() => _hasError = false);
    try {
      final plans = await ProfileService.instance.fetchSubscriptionPlans();
      if (mounted) setState(() { _plans = plans; _loading = false; });
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'load_subscription_plans');
      if (mounted) setState(() { _loading = false; _hasError = true; });
    }
  }

  /// Live RevenueCat/Play Store pricing — the single source of truth for
  /// what a plan actually costs. subscription_plans.price_monthly/yearly
  /// (used in [_upgradeTile] as a fallback) is a manually-maintained
  /// display mirror that can drift from real Play Console prices; this
  /// keeps that from being the primary source. Fetched separately from
  /// [_loadPlans] (non-blocking, best-effort) so a slow/failed store
  /// fetch doesn't hold up rendering the feature comparison table.
  Future<void> _loadOfferings() async {
    final offerings = await SubscriptionService.instance.getOfferings();
    if (mounted) setState(() => _offerings = offerings);
  }

  /// The store's formatted price string (e.g. "₹149.00") for [planKey]'s
  /// [period] ('monthly' or 'yearly') package — matches the package
  /// identifiers set up in RevenueCat's default offering (plus_monthly,
  /// plus_yearly, pro_monthly, pro_yearly). Null when offerings haven't
  /// loaded yet or the package isn't found, so callers can fall back to
  /// the DB price.
  String? _livePrice(String planKey, String period) {
    final packages = _offerings?.current?.availablePackages;
    if (packages == null) return null;
    final tier = planKey == 'family_plus' ? 'plus' : 'pro';
    final pkg = packages
        .where((p) => p.identifier == '${tier}_$period')
        .firstOrNull;
    return pkg?.storeProduct.priceString;
  }

  // ── feature rows definition ────────────────────────────────────────────────
  // Each entry: label, emoji, and a function that extracts the value from a plan.
  // Using L = SubscriptionPlanData.limitLabel for convenience.

  List<({String name, String emoji, String personal, String plus, String pro})>
      _buildRows() {
    final p  = _personal;
    final pl = _plus;
    final pr = _pro;
    if (p == null) return [];

    String lim(int v) => SubscriptionPlanData.limitLabel(v);
    String wks(int v) => SubscriptionPlanData.weeksLabel(v);
    String mo(int v)  => SubscriptionPlanData.monthsLabel(v);
    String bl(bool v) => SubscriptionPlanData.boolLabel(v);

    // For family members: personal shows '—', others show 'Up to N'
    String members(int v) => v == 0 ? '—' : 'Up to $v';

    return [
      // ── Family ────────────────────────────────────────────────────────────
      (name: 'Family members',       emoji: '👨‍👩‍👧',
       personal: members(p.familyMaxMembers),
       plus: pl != null ? members(pl.familyMaxMembers) : '—',
       pro:  pr != null ? members(pr.familyMaxMembers) : '—'),
      // ── AI ────────────────────────────────────────────────────────────────
      (name: 'AI parser / month',    emoji: '🤖',
       personal: lim(p.aiParserCallsMonth),
       plus: pl != null ? lim(pl.aiParserCallsMonth) : '—',
       pro:  pr != null ? lim(pr.aiParserCallsMonth) : '—'),
      (name: 'AI assistant / month', emoji: '💬',
       personal: lim(p.aiAssistantCallsMonth),
       plus: pl != null ? lim(pl.aiAssistantCallsMonth) : '—',
       pro:  pr != null ? lim(pr.aiAssistantCallsMonth) : '—'),
      // ── Wallet ────────────────────────────────────────────────────────────
      (name: 'Transactions / month', emoji: '💳',
       personal: lim(p.walletTransactionsMonth),
       plus: pl != null ? lim(pl.walletTransactionsMonth) : '—',
       pro:  pr != null ? lim(pr.walletTransactionsMonth) : '—'),
      (name: 'Split groups / month', emoji: '🤝',
       personal: lim(p.walletSplitGroupsMonth),
       plus: pl != null ? lim(pl.walletSplitGroupsMonth) : '—',
       pro:  pr != null ? lim(pr.walletSplitGroupsMonth) : '—'),
      (name: 'Custom categories',    emoji: '🏷️',
       personal: lim(p.walletCustomCategoriesMax),
       plus: pl != null ? lim(pl.walletCustomCategoriesMax) : '—',
       pro:  pr != null ? lim(pr.walletCustomCategoriesMax) : '—'),
      // ── Pantry ────────────────────────────────────────────────────────────
      (name: 'Meal plan weeks ahead',emoji: '🍽️',
       personal: wks(p.pantryMealWeeksAhead),
       plus: pl != null ? wks(pl.pantryMealWeeksAhead) : '—',
       pro:  pr != null ? wks(pr.pantryMealWeeksAhead) : '—'),
      (name: 'Saved recipes',        emoji: '📖',
       personal: lim(p.pantryRecipesMax),
       plus: pl != null ? lim(pl.pantryRecipesMax) : '—',
       pro:  pr != null ? lim(pr.pantryRecipesMax) : '—'),
      // ── Functions ─────────────────────────────────────────────────────────
      (name: 'Upcoming functions',   emoji: '🎉',
       personal: lim(p.functionsUpcomingMax),
       plus: pl != null ? lim(pl.functionsUpcomingMax) : '—',
       pro:  pr != null ? lim(pr.functionsUpcomingMax) : '—'),
      (name: 'Attended functions',   emoji: '🎁',
       personal: lim(p.functionsAttendedMax),
       plus: pl != null ? lim(pl.functionsAttendedMax) : '—',
       pro:  pr != null ? lim(pr.functionsAttendedMax) : '—'),
      (name: 'My functions',         emoji: '🎊',
       personal: lim(p.functionsMyMax),
       plus: pl != null ? lim(pl.functionsMyMax) : '—',
       pro:  pr != null ? lim(pr.functionsMyMax) : '—'),
      // ── Item Locator ──────────────────────────────────────────────────────
      (name: 'Item Locator containers', emoji: '📦',
       personal: lim(p.itemLocatorContainersMax),
       plus: pl != null ? lim(pl.itemLocatorContainersMax) : '—',
       pro:  pr != null ? lim(pr.itemLocatorContainersMax) : '—'),
      (name: 'Item Locator items',   emoji: '🔍',
       personal: lim(p.itemLocatorItemsMax),
       plus: pl != null ? lim(pl.itemLocatorItemsMax) : '—',
       pro:  pr != null ? lim(pr.itemLocatorItemsMax) : '—'),
      // ── Wardrobe ──────────────────────────────────────────────────────────
      (name: 'Wardrobe items',       emoji: '👗',
       personal: lim(p.wardrobeItemsMax),
       plus: pl != null ? lim(pl.wardrobeItemsMax) : '—',
       pro:  pr != null ? lim(pr.wardrobeItemsMax) : '—'),
      (name: 'Outfit log history',   emoji: '📅',
       personal: mo(p.wardrobeOutfitLogMonths),
       plus: pl != null ? mo(pl.wardrobeOutfitLogMonths) : '—',
       pro:  pr != null ? mo(pr.wardrobeOutfitLogMonths) : '—'),
      // ── Health (hidden entirely when the Health Space feature itself is
      // disabled — see FeatureFlags.healthSpaceEnabled) ─────────────────────
      if (FeatureFlags.healthSpaceEnabled) ...[
        (name: 'Medications',          emoji: '💊',
         personal: lim(p.healthMedicationsMax),
         plus: pl != null ? lim(pl.healthMedicationsMax) : '—',
         pro:  pr != null ? lim(pr.healthMedicationsMax) : '—'),
        (name: 'Appointments',         emoji: '🏥',
         personal: lim(p.healthAppointmentsMax),
         plus: pl != null ? lim(pl.healthAppointmentsMax) : '—',
         pro:  pr != null ? lim(pr.healthAppointmentsMax) : '—'),
        (name: 'Vital logs / month',   emoji: '❤️',
         personal: lim(p.healthVitalLogsMonth),
         plus: pl != null ? lim(pl.healthVitalLogsMonth) : '—',
         pro:  pr != null ? lim(pr.healthVitalLogsMonth) : '—'),
        (name: 'Vaccinations',         emoji: '💉',
         personal: lim(p.healthVaccinesMax),
         plus: pl != null ? lim(pl.healthVaccinesMax) : '—',
         pro:  pr != null ? lim(pr.healthVaccinesMax) : '—'),
        (name: 'Doctors',              emoji: '🩺',
         personal: lim(p.healthDoctorsMax),
         plus: pl != null ? lim(pl.healthDoctorsMax) : '—',
         pro:  pr != null ? lim(pr.healthDoctorsMax) : '—'),
        (name: 'Insurance policies',   emoji: '🛡️',
         personal: lim(p.healthInsuranceMax),
         plus: pl != null ? lim(pl.healthInsuranceMax) : '—',
         pro:  pr != null ? lim(pr.healthInsuranceMax) : '—'),
        (name: 'Documents',            emoji: '📄',
         personal: lim(p.healthDocumentsMax),
         plus: pl != null ? lim(pl.healthDocumentsMax) : '—',
         pro:  pr != null ? lim(pr.healthDocumentsMax) : '—'),
      ],
      // ── PlanIt ────────────────────────────────────────────────────────────
      (name: 'Tasks',                emoji: '✅',
       personal: lim(p.planItTasksMax),
       plus: pl != null ? lim(pl.planItTasksMax) : '—',
       pro:  pr != null ? lim(pr.planItTasksMax) : '—'),
      (name: 'Reminders',            emoji: '🔔',
       personal: lim(p.planItRemindersMax),
       plus: pl != null ? lim(pl.planItRemindersMax) : '—',
       pro:  pr != null ? lim(pr.planItRemindersMax) : '—'),
      (name: 'Notes',                emoji: '📝',
       personal: lim(p.planItNotesMax),
       plus: pl != null ? lim(pl.planItNotesMax) : '—',
       pro:  pr != null ? lim(pr.planItNotesMax) : '—'),
      (name: 'Special days',         emoji: '🎂',
       personal: lim(p.planItSpecialDaysMax),
       plus: pl != null ? lim(pl.planItSpecialDaysMax) : '—',
       pro:  pr != null ? lim(pr.planItSpecialDaysMax) : '—'),
      (name: 'Wish list',            emoji: '🎁',
       personal: lim(p.planItWishlistMax),
       plus: pl != null ? lim(pl.planItWishlistMax) : '—',
       pro:  pr != null ? lim(pr.planItWishlistMax) : '—'),
      // ── Notifications ─────────────────────────────────────────────────────
      (name: 'Push notifications',   emoji: '📲',
       personal: bl(p.notifPushEnabled),
       plus: pl != null ? bl(pl.notifPushEnabled) : '—',
       pro:  pr != null ? bl(pr.notifPushEnabled) : '—'),
      (name: 'Custom alerts',        emoji: '🔔',
       personal: bl(p.notifCustomAlerts),
       plus: pl != null ? bl(pl.notifCustomAlerts) : '—',
       pro:  pr != null ? bl(pr.notifCustomAlerts) : '—'),
    ];
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _handle(),
          _header(context),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _planColor))
                : (_hasError || _plans == null || _plans!.isEmpty)
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Couldn\'t load plans',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    color: _tc)),
                            const SizedBox(height: 4),
                            Text('Check your connection and try again.',
                                style: TextStyle(
                                    fontSize: 12, fontFamily: 'Nunito', color: _sub)),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                setState(() => _loading = true);
                                _loadPlans();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    children: [
                      _currentPlanCard(),
                      const SizedBox(height: 20),
                      _featuresTable(),
                      if (!_isPro) ...[
                        const SizedBox(height: 20),
                        _upgradeSection(context),
                      ],
                      if (!_isFree) ...[
                        const SizedBox(height: 20),
                        _manageSection(context),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── handle + header ────────────────────────────────────────────────────────

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: _sub.withAlpha(80),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
        child: Row(
          children: [
            Text('💳  Subscription',
                style: TextStyle(
                    fontSize: 17,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    color: _tc)),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.close_rounded, color: _sub, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  // ── Current plan card ──────────────────────────────────────────────────────

  Widget _currentPlanCard() {
    final gradient = _isPro
        ? const [Color(0xFF6C63FF), Color(0xFF3D35CC)]
        : _isPlus
            ? const [Color(0xFFD97706), Color(0xFFB45309)]
            : const [Color(0xFF8E8EA0), Color(0xFF6E6E90)];

    final subtitle = _isFree
        ? 'Personal account · Upgrade to unlock family features'
        : _isPlus
            ? 'Family plan · Up to ${_plus?.familyMaxMembers ?? 6} members'
            : 'Premium family plan · Up to ${_pro?.familyMaxMembers ?? 15} members';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(_planEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RiyasHome $_planName',
                  style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'Nunito',
                      color: Colors.white70),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _isFree ? 'FREE' : 'ACTIVE',
              style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Features comparison table ──────────────────────────────────────────────

  Widget _featuresTable() {
    final rows = _buildRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Plan comparison',
              style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: _tc)),
        ),
        Container(
          decoration: BoxDecoration(
              color: _surf, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              _tableHeader(),
              Divider(height: 1, color: _div),
              ...rows.asMap().entries.map((e) => Column(
                    children: [
                      if (e.key > 0) Divider(height: 1, color: _div, indent: 16),
                      _featureRow(e.value),
                    ],
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text('Feature',
                  style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w800,
                      color: _sub)),
            ),
            _planHeaderCell('Personal', _isFree,  _personalColor),
            _planHeaderCell('Plus',     _isPlus,  _plusColor),
            _planHeaderCell('Pro',      _isPro,   _proColor),
          ],
        ),
      );

  Widget _planHeaderCell(String label, bool active, Color color) => SizedBox(
        width: 58,
        child: Column(
          children: [
            if (active)
              Container(
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('CURRENT',
                    style: TextStyle(
                        fontSize: 7,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        color: color)),
              ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: active ? color : _sub),
            ),
          ],
        ),
      );

  Widget _featureRow(
      ({String name, String emoji, String personal, String plus, String pro}) f) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(f.emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(f.name,
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    color: _tc)),
          ),
          _valueCell(f.personal, _isFree,  _personalColor),
          _valueCell(f.plus,     _isPlus,  _plusColor),
          _valueCell(f.pro,      _isPro,   _proColor),
        ],
      ),
    );
  }

  Widget _valueCell(String value, bool isCurrent, Color color) {
    final isDash = value == '—';
    final isNo   = value == '✗';
    final displayColor = isDash || isNo
        ? _sub.withAlpha(80)
        : isCurrent
            ? color
            : color.withAlpha(120);

    return SizedBox(
      width: 58,
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontSize: (value == '✓' || value == '✗') ? 14 : 11,
            fontFamily: 'Nunito',
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w600,
            color: displayColor,
          ),
        ),
      ),
    );
  }

  // ── Upgrade section ────────────────────────────────────────────────────────

  Widget _upgradeSection(BuildContext context) {
    if (_isFree) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Upgrade your plan',
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    color: _tc)),
          ),
          if (_plus != null)
            _upgradeTile(context, plan: _plus!,
                emoji: '👨‍👩‍👧', color: _plusColor),
          if (_plus != null && _pro != null) const SizedBox(height: 10),
          if (_pro != null)
            _upgradeTile(context, plan: _pro!,
                emoji: '👑', color: _proColor),
        ],
      );
    }
    // Plus → offer Pro
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Upgrade to Family Pro',
              style: TextStyle(
                  fontSize: 13,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900,
                  color: _tc)),
        ),
        if (_pro != null)
          _upgradeTile(context, plan: _pro!, emoji: '👑', color: _proColor),
      ],
    );
  }

  Widget _upgradeTile(
    BuildContext context, {
    required SubscriptionPlanData plan,
    required String emoji,
    required Color color,
  }) {
    final title       = plan.planKey == 'family_plus' ? 'Family Plus' : 'Family Pro';
    final memberCount = plan.familyMaxMembers;
    final aiCalls     = SubscriptionPlanData.limitLabel(plan.aiParserCallsMonth);
    final txCount     = SubscriptionPlanData.limitLabel(plan.walletTransactionsMonth);
    final description = 'Up to $memberCount members · $txCount tx/mo · $aiCalls AI calls';

    final monthlyPrice = _livePrice(plan.planKey, 'monthly') ??
        (plan.priceMonthly > 0
            ? '${AppPrefs.cs}${plan.priceMonthly.toStringAsFixed(0)}'
            : 'TBD');
    final yearlyPrice = _livePrice(plan.planKey, 'yearly') ??
        (plan.priceYearly > 0
            ? '${AppPrefs.cs}${plan.priceYearly.toStringAsFixed(0)}'
            : 'TBD');

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RiyasHome $title',
                          style: TextStyle(
                              fontSize: 14,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w900,
                              color: color)),
                      Text(description,
                          style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Nunito',
                              color: _sub)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                Text(
                  _billingCycle == 'monthly' ? monthlyPrice : yearlyPrice,
                  style: TextStyle(
                      fontSize: 26,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: color),
                ),
                Text(
                  _billingCycle == 'monthly' ? '/mo' : '/yr',
                  style: TextStyle(fontSize: 13, fontFamily: 'Nunito', color: _sub),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                      color: _surf, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: ['monthly', 'yearly'].map((cycle) {
                      final active = _billingCycle == cycle;
                      return GestureDetector(
                        onTap: () => setState(() => _billingCycle = cycle),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? color : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            cycle == 'monthly' ? 'Monthly' : 'Yearly',
                            style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : _sub),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _goToPaywall(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Upgrade to WAI $title',
                  style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Manage subscription ────────────────────────────────────────────────────

  Widget _manageSection(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text('Manage Subscription',
                style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    color: _tc)),
          ),
          Container(
            decoration: BoxDecoration(
                color: _surf, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _manageRow(context,
                    icon: Icons.credit_card_rounded,
                    title: 'Payment & Billing',
                    subtitle: 'Update payment method · View invoices',
                    color: _planColor,
                    onTap: () => _openPlayStoreSubscriptions(context),
                    roundTop: true),
                Divider(height: 1, color: _div, indent: 56),
                _manageRow(context,
                    icon: Icons.swap_horiz_rounded,
                    title: 'Change Plan',
                    subtitle: _isPro
                        ? 'Downgrade to Family Plus'
                        : 'Upgrade to Family Pro',
                    color: _planColor,
                    onTap: () => _goToPaywall(context)),
                Divider(height: 1, color: _div, indent: 56),
                _manageRow(context,
                    icon: Icons.cancel_outlined,
                    title: 'Cancel Subscription',
                    subtitle: 'You\'ll keep access until period ends',
                    color: AppColors.expense,
                    onTap: () => _confirmCancel(context),
                    roundBottom: true),
              ],
            ),
          ),
        ],
      );

  Widget _manageRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool roundTop = false,
    bool roundBottom = false,
  }) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: roundTop ? const Radius.circular(16) : Radius.zero,
          bottom: roundBottom ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 13,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w800,
                            color: color == AppColors.expense ? color : _tc)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            color: _sub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: _sub),
            ],
          ),
        ),
      );

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Opens Google Play's own subscription management page — updating a
  /// payment method, viewing invoices, and cancelling all happen there,
  /// not through any RevenueCat/Play Billing API our app could call
  /// in-app. https://play.google.com/store/account/subscriptions
  Future<void> _openPlayStoreSubscriptions(BuildContext context) async {
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?package=com.wai.lifeassistant',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('launchUrl returned false');
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'subscription_open_play_billing');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store.')),
      );
    }
  }

  /// Routes to the real purchase flow (PaywallScreen) for the family the
  /// user already belongs to. Family Plus/Pro subscriptions attach to a
  /// family wallet, so a user with no family yet has nothing to attach one
  /// to — direct them to create one first instead of a false "coming soon".
  void _goToPaywall(BuildContext context) {
    // AppStateScope.of() throws (uncaught, since its guard is an assert
    // stripped from release builds) if no AppStateScope ancestor is found
    // — seen once in production immediately after Play Store force-restarted
    // the app mid-session to apply an update, a narrow timing window before
    // the tree had fully settled. Not reproducible under normal conditions,
    // but this turns that hard crash into a retryable message instead.
    final List<FamilyModel> families;
    try {
      families = AppStateScope.of(context).families;
    } catch (e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'go_to_paywall_app_state');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
      return;
    }
    if (families.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create a family first — Family plans attach to a family wallet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final FamilyModel family = families.first;
    final walletId = family.walletId;
    if (walletId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This family has no wallet yet — try again in a moment.')),
      );
      return;
    }
    PaywallScreen.show(context, isAdmin: family.isAdmin, familyName: family.name, walletId: walletId);
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      // Named (not discarded with `_`) so the action buttons below can pop
      // this dialog specifically via its own context — popping with the
      // outer SubscriptionSheet context instead was closing whichever
      // route the shared Navigator considered "current" at the time,
      // which could be the subscription bottom sheet itself rather than
      // just this dialog.
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Subscription?',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc)),
        content: Text(
          'You\'ll be taken to Google Play to cancel. You\'ll keep your WAI '
          '$_planName benefits until the end of your current billing period — '
          'after that, your account reverts to Personal (Free).',
          style: TextStyle(fontFamily: 'Nunito', fontSize: 13, color: _sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Keep Plan',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: _planColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _openPlayStoreSubscriptions(context);
            },
            child: const Text('Continue to Google Play',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: AppColors.expense)),
          ),
        ],
      ),
    );
  }
}
