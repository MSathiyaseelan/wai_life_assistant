import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';

class WalletCardWidget extends StatelessWidget {
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

  double get _periodBalance {
    if (periodCashIn != null) {
      final totalIn = (periodCashIn ?? 0) + (periodOnlineIn ?? 0);
      final totalOut = (periodCashOut ?? 0) + (periodOnlineOut ?? 0);
      return totalIn - totalOut;
    }
    return wallet.balance;
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        transform: Matrix4.identity()..scale(isActive ? 1.0 : 0.92),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: wallet.gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: wallet.gradient[0].withOpacity(0.5),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Balance ───────────────────────────────────────────────────
            Text(
              '₹${_fmt(_periodBalance)}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'Nunito',
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 6),
            // ── Cash vs Online breakdown ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeColumn(
                      icon: '💵',
                      label: 'Cash',
                      inAmt: periodCashIn ?? wallet.cashIn,
                      outAmt: periodCashOut ?? wallet.cashOut,
                      fmtFn: _fmt,
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white24),
                  Expanded(
                    child: _ModeColumn(
                      icon: '📱',
                      label: 'Online',
                      inAmt: periodOnlineIn ?? wallet.onlineIn,
                      outAmt: periodOnlineOut ?? wallet.onlineOut,
                      fmtFn: _fmt,
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
