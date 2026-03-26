import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class WalletCardWidget extends StatefulWidget {
  final WalletModel wallet;
  final bool isActive;
  final VoidCallback onTap;

  /// When provided, overrides the wallet's all-time breakdown with period stats.
  final double? periodCashIn;
  final double? periodCashOut;
  final double? periodOnlineIn;
  final double? periodOnlineOut;

  const WalletCardWidget({
    super.key,
    required this.wallet,
    required this.isActive,
    required this.onTap,
    this.periodCashIn,
    this.periodCashOut,
    this.periodOnlineIn,
    this.periodOnlineOut,
  });

  @override
  State<WalletCardWidget> createState() => _WalletCardWidgetState();
}

class _WalletCardWidgetState extends State<WalletCardWidget> {
  // Amounts hidden by default — tap the eye icon to reveal
  bool _hidden = true;

  double get _periodBalance {
    if (widget.periodCashIn != null) {
      final totalIn = (widget.periodCashIn ?? 0) + (widget.periodOnlineIn ?? 0);
      final totalOut = (widget.periodCashOut ?? 0) + (widget.periodOnlineOut ?? 0);
      return totalIn - totalOut;
    }
    return widget.wallet.balance;
  }

  String _fmt(double v) {
    if (_hidden) return '••••';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  String _fmtSmall(double v) {
    if (_hidden) return '••';
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
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
            // ── Balance row with eye toggle ───────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '₹${_fmt(_periodBalance)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Nunito',
                      letterSpacing: -1,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _hidden = !_hidden);
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      _hidden
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
          ],
        ),
      ),
    );
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
                  '₹${fmtFn(inAmt)}',
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
                  '₹${fmtFn(outAmt)}',
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
