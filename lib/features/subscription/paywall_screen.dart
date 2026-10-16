import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/subscription/revenuecat_config.dart';
import '../../data/models/subscription/subscription_models.dart';
import '../../data/services/profile_service.dart';
import '../../data/services/subscription_service.dart';
import '../AppStateNotifier.dart';

/// Upgrade-plan paywall for a family's wallet. Only the family admin can
/// actually purchase — members can still see plans/pricing, with an
/// explanatory banner instead of purchase buttons.
class PaywallScreen extends StatefulWidget {
  final bool isAdmin;
  final String familyName;
  final String walletId;

  const PaywallScreen({
    super.key,
    required this.isAdmin,
    required this.familyName,
    required this.walletId,
  });

  static Future<void> show(
    BuildContext context, {
    required bool isAdmin,
    required String familyName,
    required String walletId,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaywallScreen(isAdmin: isAdmin, familyName: familyName, walletId: walletId),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

// Same tier colours as SubscriptionSheet's comparison table.
const _plusColor = Color(0xFFD97706);
const _proColor = Color(0xFF6C63FF);

/// One purchasable option as shown on screen. Built from the RevenueCat
/// packages whose identifiers follow the default offering's
/// `<tier>_<period>` scheme (plus_monthly, pro_yearly, …); anything else
/// falls back to a generic option named after its store title.
class _PlanOption {
  final Package package;
  final String name;
  final String emoji;
  final String tagline;
  final Color color;
  final bool yearly;
  final SubscriptionPlanData? limits;

  const _PlanOption({
    required this.package,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.color,
    required this.yearly,
    this.limits,
  });
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _loading = true;
  Offerings? _offerings;
  List<SubscriptionPlanData> _plans = const [];
  String? _activeProductId;
  Package? _purchasingPackage;
  bool _restoring = false;
  String? _error;

  bool _yearly = true;
  Package? _selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!RevenueCatConfig.isConfigured) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // Plan limits only feed the highlight rows, and the active product only
    // marks "Current plan" — neither is allowed to block showing the plans.
    final results = await Future.wait<Object?>([
      SubscriptionService.instance.getOfferings(),
      ProfileService.instance
          .fetchSubscriptionPlans()
          .then<List<SubscriptionPlanData>?>((p) => p)
          .catchError((_) => null),
      SubscriptionService.instance.activeProductId(),
    ]);
    if (!mounted) return;
    final offerings = results[0] as Offerings?;
    setState(() {
      _offerings = offerings;
      _plans = (results[1] as List<SubscriptionPlanData>?) ?? const [];
      _activeProductId = results[2] as String?;
      _loading = false;
      if (offerings == null) _error = 'Could not load plans. Please try again.';
    });
  }

  List<Package> get _packages =>
      _offerings?.current?.availablePackages ??
      _offerings?.all.values.expand((o) => o.availablePackages).toList() ??
      const [];

  SubscriptionPlanData? _limitsFor(String planKey) =>
      _plans.where((p) => p.planKey == planKey).firstOrNull;

  List<_PlanOption> get _options {
    final packages = _packages;
    final tiered = <_PlanOption>[];
    for (final tier in const ['plus', 'pro']) {
      for (final yearly in const [false, true]) {
        final pkg = packages
            .where((p) => p.identifier == '${tier}_${yearly ? 'yearly' : 'monthly'}')
            .firstOrNull;
        if (pkg == null) continue;
        final isPro = tier == 'pro';
        tiered.add(_PlanOption(
          package: pkg,
          name: isPro ? 'Family Pro' : 'Family Plus',
          emoji: isPro ? '👑' : '👨‍👩‍👧',
          tagline: isPro
              ? 'Everything, with the highest limits'
              : 'The essentials for your household',
          color: isPro ? _proColor : _plusColor,
          yearly: yearly,
          limits: _limitsFor(isPro ? 'family_pro' : 'family_plus'),
        ));
      }
    }
    if (tiered.isNotEmpty) return tiered;
    return packages
        .map((p) => _PlanOption(
              package: p,
              name: _cleanTitle(p.storeProduct.title),
              emoji: '💎',
              tagline: p.storeProduct.description,
              color: AppColors.primary,
              yearly: p.packageType == PackageType.annual,
            ))
        .toList();
  }

  /// Both billing periods exist, so the Monthly/Yearly toggle is meaningful.
  bool _hasBothPeriods(List<_PlanOption> options) =>
      options.any((o) => o.yearly) && options.any((o) => !o.yearly);

  List<_PlanOption> _visible(List<_PlanOption> options) =>
      _hasBothPeriods(options)
          ? options.where((o) => o.yearly == _yearly).toList()
          : options;

  /// Yearly saving vs. paying monthly for the same tier, as a whole
  /// percentage — the best across tiers, for the toggle's badge.
  int? _yearlySavingPercent(List<_PlanOption> options) {
    int? best;
    for (final y in options.where((o) => o.yearly)) {
      final m = options
          .where((o) => !o.yearly && o.name == y.name)
          .firstOrNull;
      if (m == null) continue;
      final fullYear = m.package.storeProduct.price * 12;
      if (fullYear <= 0) continue;
      final pct = ((1 - y.package.storeProduct.price / fullYear) * 100).floor();
      if (pct > 0 && (best == null || pct > best)) best = pct;
    }
    return best;
  }

  bool _isCurrent(Package p) =>
      _activeProductId != null &&
      _baseProductId(_activeProductId!) ==
          _baseProductId(p.storeProduct.identifier);

  Future<void> _purchase(Package package) async {
    if (!widget.isAdmin || _purchasingPackage != null) return;
    setState(() => _purchasingPackage = package);
    try {
      // If the admin already has an active plan (e.g. upgrading Plus → Pro
      // or downgrading Pro → Plus), pass its product id so Google Play
      // replaces/prorates it instead of stacking a second parallel
      // subscription — see purchasePackage()'s doc comment.
      final oldProductId = await SubscriptionService.instance.activeProductId();
      final info = await SubscriptionService.instance.purchasePackage(
        package,
        walletId: widget.walletId,
        oldProductIdentifier: oldProductId != package.storeProduct.identifier
            ? oldProductId
            : null,
      );
      if (!mounted) return;
      if (info != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Payment confirmed! Your plan updates within a few seconds "
              "as RevenueCat notifies us — pull to refresh if it hasn't yet.",
            ),
          ),
        );
        // Best-effort reconciliation — the actual plan update happens via
        // the revenuecat-webhook edge function, which may not have finished
        // processing yet. This just refreshes local state in case it has.
        AppStateScope.read(context).reload();
        Navigator.pop(context);
      }
      // info == null means the user cancelled — no message needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SubscriptionService.friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _purchasingPackage = null);
    }
  }

  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      final info = await SubscriptionService.instance.restorePurchases();
      if (!mounted) return;
      final hasEntitlement = info?.entitlements.active.isNotEmpty == true;
      if (hasEntitlement) AppStateScope.read(context).reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasEntitlement
                ? 'Purchases restored!'
                : 'No previous purchases found for this account.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(SubscriptionService.friendlyErrorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF4F5FF);
    final card = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final tc = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub = isDark ? Colors.white54 : const Color(0xFF64748B);

    final options = _options;
    final visible = _visible(options);
    // Keep the selection on screen when the period toggles: fall back to the
    // same tier in the other period, then to the last (highest) visible tier.
    _PlanOption? selected = visible
        .where((o) => o.package == _selected)
        .firstOrNull;
    if (selected == null && visible.isNotEmpty) {
      final prevName = options
          .where((o) => o.package == _selected)
          .firstOrNull
          ?.name;
      selected = visible.where((o) => o.name == prevName).firstOrNull ??
          visible.where((o) => !_isCurrent(o.package)).lastOrNull ??
          visible.last;
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tc,
        title: const Text(
          'Upgrade Plan',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: _loading || selected == null
          ? null
          : _CheckoutBar(
              option: selected,
              card: card,
              sub: sub,
              isAdmin: widget.isAdmin,
              isCurrent: _isCurrent(selected.package),
              purchasing: _purchasingPackage == selected.package,
              restoring: _restoring,
              onPurchase: () => _purchase(selected!.package),
              onRestore: _restore,
            ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !RevenueCatConfig.isConfigured || options.isEmpty
                ? _EmptyState(sub: sub, error: _error)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      Text(
                        widget.familyName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Nunito',
                          color: sub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a plan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          color: tc,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'One plan covers everyone in your family.',
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w600,
                          color: sub,
                        ),
                      ),
                      const SizedBox(height: 18),

                      if (!widget.isAdmin) ...[
                        _AdminOnlyNotice(tc: tc),
                        const SizedBox(height: 16),
                      ],

                      if (_hasBothPeriods(options)) ...[
                        _PeriodToggle(
                          yearly: _yearly,
                          savingPercent: _yearlySavingPercent(options),
                          card: card,
                          sub: sub,
                          onChanged: (v) => setState(() => _yearly = v),
                        ),
                        const SizedBox(height: 16),
                      ],

                      ...visible.map((o) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlanCard(
                              option: o,
                              selected: o.package == selected?.package,
                              isCurrent: _isCurrent(o.package),
                              card: card,
                              tc: tc,
                              sub: sub,
                              onTap: () =>
                                  setState(() => _selected = o.package),
                            ),
                          )),
                    ],
                  ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Play Store product titles carry the app's listing name in brackets —
/// "Family Pro (Yearly) (RiyasHome: AI Family Organizer)" — strip it.
String _cleanTitle(String title) =>
    title.replaceFirst(RegExp(r'\s*\([^()]*\)\s*$'), '').trim();

/// Google Play ids come as "product:base-plan" from some APIs and bare
/// "product" from others; compare on the product part only.
String _baseProductId(String id) => id.split(':').first;

/// "₹1,999.00" → "₹1,999"; keeps real decimals like "$4.99".
String _trimZeroDecimals(String price) =>
    price.replaceFirst(RegExp(r'[.,]00(?=\D*$)'), '');

String _perMonth(StoreProduct p) {
  final fmt = NumberFormat.simpleCurrency(
    name: p.currencyCode,
    decimalDigits: 0,
  );
  return fmt.format(p.price / 12);
}

String _limit(int v, String unit) =>
    v == -1 ? 'Unlimited $unit' : '$v $unit';

List<String> _highlights(SubscriptionPlanData d) => [
      if (d.familyMaxMembers != 0)
        d.familyMaxMembers == -1
            ? 'Unlimited family members'
            : 'Up to ${d.familyMaxMembers} family members',
      _limit(d.aiAssistantCallsMonth, 'AI assistant chats / month'),
      _limit(d.aiParserCallsMonth, 'AI quick entries / month'),
      _limit(d.walletTransactionsMonth, 'transactions / month'),
      if (d.pantryMealWeeksAhead != 0)
        d.pantryMealWeeksAhead == -1
            ? 'Plan meals any number of weeks ahead'
            : 'Plan meals ${d.pantryMealWeeksAhead} '
                '${d.pantryMealWeeksAhead == 1 ? 'week' : 'weeks'} ahead',
    ];

// ── Widgets ──────────────────────────────────────────────────────────────────

class _AdminOnlyNotice extends StatelessWidget {
  final Color tc;
  const _AdminOnlyNotice({required this.tc});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Only the family admin can upgrade the plan. '
                'You can still see what\'s included below.',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: tc,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PeriodToggle extends StatelessWidget {
  final bool yearly;
  final int? savingPercent;
  final Color card, sub;
  final ValueChanged<bool> onChanged;

  const _PeriodToggle({
    required this.yearly,
    required this.savingPercent,
    required this.card,
    required this.sub,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value, {String? badge}) {
      final active = yearly == value;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : sub,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white.withValues(alpha: 0.22)
                          : const Color(0xFF16A34A).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'Nunito',
                        fontWeight: FontWeight.w900,
                        color: active ? Colors.white : const Color(0xFF16A34A),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          segment('Monthly', false),
          segment(
            'Yearly',
            true,
            badge: savingPercent != null ? 'SAVE $savingPercent%' : null,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final _PlanOption option;
  final bool selected;
  final bool isCurrent;
  final Color card, tc, sub;
  final VoidCallback onTap;

  const _PlanCard({
    required this.option,
    required this.selected,
    required this.isCurrent,
    required this.card,
    required this.tc,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final product = option.package.storeProduct;
    final color = option.color;
    final highlights =
        option.limits != null ? _highlights(option.limits!) : const <String>[];

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.18),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (selected ? color : Colors.black)
                  .withValues(alpha: selected ? 0.12 : 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(option.emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              option.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Nunito',
                                color: tc,
                              ),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (option.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          option.tagline,
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            color: sub,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RadioDot(selected: selected, color: color),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _trimZeroDecimals(product.priceString),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Nunito',
                    color: tc,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  option.yearly ? '/ year' : '/ month',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Nunito',
                    color: sub,
                  ),
                ),
                const Spacer(),
                if (option.yearly)
                  Text(
                    'just ${_perMonth(product)}/mo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Nunito',
                      color: color,
                    ),
                  ),
              ],
            ),
            if (highlights.isNotEmpty) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: sub.withValues(alpha: 0.15)),
              const SizedBox(height: 12),
              ...highlights.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            h,
                            style: TextStyle(
                              fontSize: 13,
                              fontFamily: 'Nunito',
                              fontWeight: FontWeight.w600,
                              color: tc,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;
  final Color color;
  const _RadioDot({required this.selected, required this.color});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(
            color: selected ? color : color.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: selected
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      );
}

class _CheckoutBar extends StatelessWidget {
  final _PlanOption option;
  final Color card, sub;
  final bool isAdmin;
  final bool isCurrent;
  final bool purchasing;
  final bool restoring;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  const _CheckoutBar({
    required this.option,
    required this.card,
    required this.sub,
    required this.isAdmin,
    required this.isCurrent,
    required this.purchasing,
    required this.restoring,
    required this.onPurchase,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final price = _trimZeroDecimals(option.package.storeProduct.priceString);
    final label = !isAdmin
        ? 'Only the admin can upgrade'
        : isCurrent
            ? 'This is your current plan'
            : 'Continue with ${option.name} · $price/${option.yearly ? 'yr' : 'mo'}';

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed:
                    isAdmin && !isCurrent && !purchasing ? onPurchase : null,
                style: FilledButton.styleFrom(
                  backgroundColor: option.color,
                  disabledBackgroundColor: option.color.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: purchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Billed through Google Play. Cancel anytime.',
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w600,
                color: sub,
              ),
            ),
            TextButton(
              onPressed: restoring ? null : onRestore,
              child: Text(
                restoring ? 'Restoring…' : 'Restore purchases',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Nunito',
                  color: sub,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Color sub;
  final String? error;
  const _EmptyState({required this.sub, this.error});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🛠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              Text(
                error ?? 'Plans are being set up — check back soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600,
                  color: sub,
                ),
              ),
            ],
          ),
        ),
      );
}
