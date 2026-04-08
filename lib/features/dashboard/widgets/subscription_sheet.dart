import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUBSCRIPTION SHEET
// Current plan · Features comparison · Upgrade/Manage · Cancel
// ─────────────────────────────────────────────────────────────────────────────

class SubscriptionSheet extends StatefulWidget {
  final bool isDark;
  final String currentPlan; // 'Free' | 'Plus' | 'Family'

  const SubscriptionSheet({
    super.key,
    required this.isDark,
    required this.currentPlan,
  });

  @override
  State<SubscriptionSheet> createState() => _SubscriptionSheetState();
}

class _SubscriptionSheetState extends State<SubscriptionSheet> {
  /// 'monthly' | 'yearly'
  String _billingCycle = 'yearly';

  // ── colours ────────────────────────────────────────────────────────────────
  Color get _bg   => widget.isDark ? AppColors.cardDark  : AppColors.cardLight;
  Color get _surf => widget.isDark ? AppColors.surfDark  : const Color(0xFFEDEEF5);
  Color get _tc   => widget.isDark ? AppColors.textDark  : AppColors.textLight;
  Color get _sub  => widget.isDark ? AppColors.subDark   : AppColors.subLight;
  Color get _div  => widget.isDark
      ? Colors.white.withAlpha(18)
      : Colors.black.withAlpha(18);

  bool get _isFree   => widget.currentPlan == 'Free';
  bool get _isPlus   => widget.currentPlan == 'Plus';
  bool get _isFamily => widget.currentPlan == 'Family';

  // ── plan accent colours ────────────────────────────────────────────────────
  static const _freeColor   = Color(0xFF8E8EA0);
  static const _plusColor   = Color(0xFFD97706);
  static const _familyColor = Color(0xFF6C63FF);

  Color get _planColor => _isPlus
      ? _plusColor
      : _isFamily
          ? _familyColor
          : _freeColor;

  String get _planEmoji => _isPlus ? '⭐' : _isFamily ? '👨‍👩‍👧' : '🆓';

  // ── feature matrix ─────────────────────────────────────────────────────────
  static const _features = <({
    String name,
    bool free,
    bool plus,
    bool family,
  })>[
    (name: 'Personal wallet',           free: true,  plus: true,  family: true),
    (name: 'Family wallet',             free: false, plus: true,  family: true),
    (name: 'AI expense parser',         free: true,  plus: true,  family: true),
    (name: 'Advanced AI suggestions',   free: false, plus: true,  family: true),
    (name: 'Unlimited transactions',    free: false, plus: true,  family: true),
    (name: 'Pantry & meal planner',     free: true,  plus: true,  family: true),
    (name: 'PlanIt (tasks & reminders)',free: true,  plus: true,  family: true),
    (name: 'Split expenses',            free: false, plus: true,  family: true),
    (name: 'Family shared access',      free: false, plus: false, family: true),
    (name: 'Up to 6 family members',    free: false, plus: false, family: true),
    (name: 'Export data (PDF/Excel)',   free: false, plus: true,  family: true),
    (name: 'Priority support',          free: false, plus: true,  family: true),
  ];

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
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                _currentPlanCard(),
                const SizedBox(height: 20),
                _featuresTable(),
                if (_isFree || _isPlus) ...[
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

  // ── components ─────────────────────────────────────────────────────────────

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
    final gradient = _isPlus
        ? const [Color(0xFFD97706), Color(0xFFB45309)]
        : _isFamily
            ? const [Color(0xFF6C63FF), Color(0xFF3D35CC)]
            : const [Color(0xFF8E8EA0), Color(0xFF6E6E90)];

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
                  'WAI ${widget.currentPlan}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontFamily: 'Nunito',
                      fontWeight: FontWeight.w900,
                      color: Colors.white),
                ),
                Text(
                  _isFree
                      ? 'Basic features · Upgrade to unlock more'
                      : _isPlus
                          ? 'All features unlocked'
                          : 'Full family access · All features',
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
              // Header row
              _tableHeader(),
              Divider(height: 1, color: _div),
              // Feature rows
              ..._features.asMap().entries.map((e) => Column(
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
            _planHeaderCell('Free',   _isFree,   _freeColor),
            _planHeaderCell('Plus',   _isPlus,   _plusColor),
            _planHeaderCell('Family', _isFamily, _familyColor),
          ],
        ),
      );

  Widget _planHeaderCell(String label, bool active, Color color) => Container(
        width: 52,
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
              fontSize: 11,
              fontFamily: 'Nunito',
              fontWeight: FontWeight.w900,
              color: active ? color : _sub),
        ),
      );

  Widget _featureRow(
      ({String name, bool free, bool plus, bool family}) f) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(f.name,
                style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w600,
                    color: _tc)),
          ),
          _checkCell(f.free,   _freeColor,   _isFree),
          _checkCell(f.plus,   _plusColor,   _isPlus),
          _checkCell(f.family, _familyColor, _isFamily),
        ],
      ),
    );
  }

  Widget _checkCell(bool has, Color color, bool highlight) => SizedBox(
        width: 52,
        child: Center(
          child: has
              ? Icon(Icons.check_circle_rounded,
                  size: 18,
                  color: highlight ? color : color.withAlpha(100))
              : Icon(Icons.remove_rounded,
                  size: 16, color: _sub.withAlpha(80)),
        ),
      );

  // ── Upgrade section (Free → Plus, Plus → Family) ───────────────────────────

  Widget _upgradeSection(BuildContext context) {
    final targetPlan = _isFree ? 'Plus' : 'Family';
    final targetColor = _isFree ? _plusColor : _familyColor;
    final monthlyPrice = _isFree ? '₹99' : '₹199';
    final yearlyPrice  = _isFree ? '₹799' : '₹1,599';
    final yearlySaving = _isFree ? '33%' : '33%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            _isFree ? 'Upgrade to WAI Plus' : 'Upgrade to Family',
            style: TextStyle(
                fontSize: 13,
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc),
          ),
        ),

        // Billing toggle
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: _surf, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: ['monthly', 'yearly'].map((cycle) {
              final active = _billingCycle == cycle;
              final label  = cycle == 'monthly' ? 'Monthly' : 'Yearly';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _billingCycle = cycle),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? targetColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(label,
                            style: TextStyle(
                                fontSize: 13,
                                fontFamily: 'Nunito',
                                fontWeight: FontWeight.w800,
                                color: active ? Colors.white : _tc)),
                        if (cycle == 'yearly' && !active) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C897).withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Save 33%',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF00C897))),
                          ),
                        ],
                        if (cycle == 'yearly' && active) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(40),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Save $yearlySaving',
                                style: const TextStyle(
                                    fontSize: 9,
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Price card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: targetColor.withAlpha(15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: targetColor.withAlpha(60)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _billingCycle == 'monthly' ? monthlyPrice : yearlyPrice,
                style: TextStyle(
                    fontSize: 32,
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w900,
                    color: targetColor),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _billingCycle == 'monthly' ? '/month' : '/year',
                  style: TextStyle(
                      fontSize: 14,
                      fontFamily: 'Nunito',
                      color: _sub),
                ),
              ),
              const Spacer(),
              if (_billingCycle == 'yearly')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'vs $monthlyPrice×12',
                      style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          color: _sub,
                          decoration: TextDecoration.lineThrough),
                    ),
                    Text(
                      'Save $yearlySaving',
                      style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'Nunito',
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF00C897)),
                    ),
                  ],
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // CTA button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _onUpgrade(context, targetPlan),
            style: ElevatedButton.styleFrom(
              backgroundColor: targetColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'Upgrade to WAI $targetPlan',
              style: const TextStyle(
                  fontSize: 15,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }

  // ── Manage subscription (active plans) ────────────────────────────────────

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
                InkWell(
                  onTap: () => _showComingSoon(context, 'Manage subscription'),
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _planColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.credit_card_rounded,
                              size: 18, color: _planColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Payment & Billing',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w800,
                                      color: _tc)),
                              Text('Update payment method',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: _sub)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            size: 20, color: _sub),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: _div, indent: 56),
                InkWell(
                  onTap: () => _confirmCancel(context),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.expense.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.cancel_outlined,
                              size: 18, color: AppColors.expense),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Cancel Subscription',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'Nunito',
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.expense)),
                              Text('You\'ll keep access until period ends',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'Nunito',
                                      color: _sub)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 20, color: AppColors.expense),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ── actions ────────────────────────────────────────────────────────────────

  void _onUpgrade(BuildContext context, String plan) {
    _showComingSoon(context, 'Upgrade to WAI $plan');
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — payment integration coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Cancel Subscription?',
            style: TextStyle(
                fontFamily: 'Nunito',
                fontWeight: FontWeight.w900,
                color: _tc)),
        content: Text(
          'You\'ll keep your ${widget.currentPlan} benefits until the end of your current billing period. After that, your account will revert to Free.',
          style: TextStyle(
              fontFamily: 'Nunito', fontSize: 13, color: _sub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Plan',
                style: TextStyle(
                    fontFamily: 'Nunito',
                    fontWeight: FontWeight.w800,
                    color: _planColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showComingSoon(context, 'Cancel subscription');
            },
            child: const Text('Cancel Subscription',
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
