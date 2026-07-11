import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/core/services/app_prefs.dart';
import 'package:wai_life_assistant/core/utils/amount_format.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class WalletCardWidget extends StatefulWidget {
  final WalletModel wallet;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onReports;
  final VoidCallback? onBudget;

  /// Whether amounts are hidden (•••• mask). Controlled externally so the eye
  /// toggle affects the transaction list as well.
  final bool hidden;
  final VoidCallback onToggleHide;

  /// Budget models that have crossed 80% or 100% of their monthly limit.
  /// When non-empty an alert banner is shown at the bottom of the card.
  final List<BudgetModel> budgetAlerts;

  /// When provided, overrides the wallet's all-time breakdown with period stats.
  final double? periodCashIn;
  final double? periodCashOut;
  final double? periodOnlineIn;
  final double? periodOnlineOut;
  final String? periodLabel;

  const WalletCardWidget({
    super.key,
    required this.wallet,
    required this.isActive,
    required this.onTap,
    required this.hidden,
    required this.onToggleHide,
    this.onReports,
    this.onBudget,
    this.budgetAlerts = const [],
    this.periodCashIn,
    this.periodCashOut,
    this.periodOnlineIn,
    this.periodOnlineOut,
    this.periodLabel,
  });

  @override
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  double get _periodBalance {
    if (widget.periodCashIn != null) {
      final totalIn = (widget.periodCashIn ?? 0) + (widget.periodOnlineIn ?? 0);
      final totalOut = (widget.periodCashOut ?? 0) + (widget.periodOnlineOut ?? 0);
      return totalIn - totalOut;
    }
    return widget.wallet.balance;
  }

  String _fmt(double v) {
    if (widget.hidden) return '••••';
    final large = formatLargeAmount(v);
    if (large != null) return large;
    if (v >= 10000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  String _fmtSmall(double v) {
    if (widget.hidden) return '••';
    final large = formatLargeAmount(v);
    if (large != null) return large;
    if (v >= 10000) {
      final s = (v / 1000).toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
      return '${s}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final alerts   = widget.budgetAlerts;
    final hasAlerts = alerts.isNotEmpty;
    final anyOver   = alerts.any((b) => b.isOver);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        transform: Matrix4.identity()..scale(widget.isActive ? 1.0 : 0.92),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.wallet.gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: widget.wallet.gradient[0].withValues(alpha: 0.5),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Wallet name / emoji header ────────────────────────────────
            Row(
              children: [
                Text(
                  widget.wallet.emoji.startsWith('http') || widget.wallet.emoji.isEmpty
                      ? (widget.wallet.isPersonal ? '👤' : '👨‍👩‍👧')
                      : widget.wallet.emoji,
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.wallet.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Nunito',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ── Balance row with icons ────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppPrefs.cs}${_fmt(_periodBalance)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Nunito',
                          letterSpacing: -1,
                        ),
                      ),
                      if (widget.periodLabel != null)
                        Text(
                          widget.periodLabel!,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Budget icon (before report) ───────────────────────────
                if (widget.onBudget != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onBudget!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 12),
                      child: Icon(
                        Icons.donut_small_rounded,
                        color: hasAlerts
                            ? (anyOver
                                ? const Color(0xFFFF5C7A)
                                : const Color(0xFFFFAA2C))
                            : Colors.white60,
                        size: 20,
                      ),
                    ),
                  ),
                // ── Report icon ───────────────────────────────────────────
                if (widget.onReports != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onReports!();
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 12),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white60,
                        size: 20,
                      ),
                    ),
                  ),
                // ── Eye toggle ────────────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleHide();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      widget.hidden
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // ── Cash vs Online breakdown ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeColumn(
                      icon: '💵',
                      label: 'Cash',
                      inAmt: widget.periodCashIn ?? widget.wallet.cashIn,
                      outAmt: widget.periodCashOut ?? widget.wallet.cashOut,
                      fmtFn: _fmtSmall,
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white24),
                  Expanded(
                    child: _ModeColumn(
                      icon: '📱',
                      label: 'Online',
                      inAmt: widget.periodOnlineIn ?? widget.wallet.onlineIn,
                      outAmt: widget.periodOnlineOut ?? widget.wallet.onlineOut,
                      fmtFn: _fmtSmall,
                    ),
                  ),
                ],
              ),
            ),
            // ── Budget alert banner ───────────────────────────────────────
            if (hasAlerts) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onBudget?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: anyOver
                        ? const Color(0xFFFF5C7A).withValues(alpha: 0.20)
                        : const Color(0xFFFFAA2C).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: anyOver
                          ? const Color(0xFFFF5C7A).withValues(alpha: 0.35)
                          : const Color(0xFFFFAA2C).withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(anyOver ? '🔴' : '🟠',
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _alertSummary(alerts),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Nunito',
                            fontWeight: FontWeight.w700,
                            color: anyOver
                                ? const Color(0xFFFF5C7A)
                                : const Color(0xFFFFAA2C),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: anyOver
                            ? const Color(0xFFFF5C7A)
                            : const Color(0xFFFFAA2C),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _alertSummary(List<BudgetModel> alerts) {
    final over = alerts.where((b) => b.isOver).toList();
    final near = alerts.where((b) => b.isNear).toList();
    if (over.isNotEmpty && near.isNotEmpty) {
      return '${over.map((b) => b.category).join(', ')} over · ${near.map((b) => b.category).join(', ')} near limit';
    }
    if (over.isNotEmpty) {
      return '${over.map((b) => b.category).join(', ')} budget exceeded!';
    }
    return '${near.map((b) => b.category).join(', ')} budget almost full';
  }
}

class _ModeColumn extends StatelessWidget {
  final String icon, label;
  final double inAmt, outAmt;
  final String Function(double) fmtFn;

  const _ModeColumn({
    required this.icon,
    required this.label,
    required this.inAmt,
    required this.outAmt,
    required this.fmtFn,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$icon $label',
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                const Text(
                  'IN',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppPrefs.cs}${fmtFn(inAmt)}',
                  style: const TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
            Column(
              children: [
                const Text(
                  'OUT',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${AppPrefs.cs}${fmtFn(outAmt)}',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Nunito',
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
