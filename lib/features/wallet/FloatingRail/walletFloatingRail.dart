import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
import '../featurelistdata.dart';
import 'package:flutter/services.dart';

class WalletFloatingRail extends StatelessWidget {
  final bool showCash;
  final bool showUpi;

  final VoidCallback onCashTap;
  final VoidCallback onUpiTap;
  final VoidCallback onCollapse;

  final VoidCallback onCashAdd;
  final VoidCallback onCashRemove;
  final VoidCallback onUpiAdd;
  final VoidCallback onUpiRemove;
  final VoidCallback onMoreTap;
  final VoidCallback onSparkTap;

  const WalletFloatingRail({
    super.key,
    required this.showCash,
    required this.showUpi,
    required this.onCashTap,
    required this.onUpiTap,
    required this.onCollapse,
    required this.onCashAdd,
    required this.onCashRemove,
    required this.onUpiAdd,
    required this.onUpiRemove,
    required this.onMoreTap,
    required this.onSparkTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          //----------- AI ------------
          // Spark AI Button
          _RailAction(
            icon: Icons.auto_awesome_rounded,
            label: 'AI',
            color: Colors.deepPurple,
            onTap: onSparkTap,
          ),
          const SizedBox(height: 28),

          // ---------- CASH ----------
          if (showCash) ...[
            _MiniRailAction(
              icon: Icons.add,
              onTap: () {
                onCollapse();
                onCashAdd();
              },
            ),
            const SizedBox(height: 12),
          ],

          _RailAction(
            icon: Icons.payments_outlined,
            label: 'Cash',
            onTap: () {
              HapticFeedback.lightImpact();
              onCashTap();
            },
          ),

          if (showCash) ...[
            const SizedBox(height: 12),
            _MiniRailAction(
              icon: Icons.remove,
              onTap: () {
                onCollapse();
                onCashRemove();
              },
            ),
          ],

          const SizedBox(height: 24),

          // ---------- UPI ----------
          if (showUpi) ...[
            _MiniRailAction(
              icon: Icons.add,
              onTap: () {
                onCollapse();
                onUpiAdd();
              },
            ),
            const SizedBox(height: 12),
          ],

          _RailAction(
            icon: Icons.account_balance_wallet_outlined,
            label: 'UPI',
            onTap: () {
              HapticFeedback.lightImpact();
              onUpiTap();
            },
          ),

          if (showUpi) ...[
            const SizedBox(height: 12),
            _MiniRailAction(
              icon: Icons.remove,
              onTap: () {
                onCollapse();
                onUpiRemove();
              },
            ),
          ],

          const SizedBox(height: 28),

          // ---------- MORE ----------
          _RailAction(
            icon: Icons.more_vert,
            label: '',
            onTap: () {
              HapticFeedback.lightImpact();
              onMoreTap();
            },
          ),
        ],
      ),
    );
  }
}

/* ---------------- Rail Button ---------------- */

class _RailAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _RailAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 30, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------- Mini + / − Button ---------------- */

class _MiniRailAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniRailAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Icon(icon, size: 26, color: theme.colorScheme.primary),
    );
  }
}

// class WalletFloatingRail extends StatefulWidget {
//   const WalletFloatingRail({super.key});

//   @override
//   State<WalletFloatingRail> createState() => _WalletFloatingRailState();
// }

// class _WalletFloatingRailState extends State<WalletFloatingRail> {
//   bool showUpi = false;
//   bool showCash = false;

//   void _toggleUpi() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       showUpi = !showUpi;
//       showCash = false;
//     });
//   }

//   void _toggleCash() {
//     HapticFeedback.lightImpact();
//     setState(() {
//       showCash = !showCash;
//       showUpi = false;
//     });
//   }

//   void _collapseRail() {
//     if (showCash || showUpi) {
//       setState(() {
//         showCash = false;
//         showUpi = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Positioned(
//       right: 12,
//       bottom: 15,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (showCash) ...[
//             _miniRailAction(
//               icon: Icons.add,
//               onTap: () => showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.cash,
//                 action: WalletAction.increment,
//               ),
//             ),
//             const SizedBox(height: 12),
//           ],

//           _railAction(
//             icon: Icons.payments_outlined,
//             label: 'Cash',
//             onTap: _toggleCash,
//           ),

//           if (showCash) ...[
//             const SizedBox(height: 12),
//             _miniRailAction(
//               icon: Icons.remove,
//               onTap: () => showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.cash,
//                 action: WalletAction.decrement,
//               ),
//             ),
//           ],

//           const SizedBox(height: 24),

//           if (showUpi) ...[
//             _miniRailAction(
//               icon: Icons.add,
//               onTap: () => showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.upi,
//                 action: WalletAction.increment,
//               ),
//             ),
//             const SizedBox(height: 12),
//           ],

//           _railAction(
//             icon: Icons.account_balance_wallet_outlined,
//             label: 'UPI',
//             onTap: _toggleUpi,
//           ),

//           if (showUpi) ...[
//             const SizedBox(height: 12),
//             _miniRailAction(
//               icon: Icons.remove,
//               onTap: () => showWalletTransactionBottomSheet(
//                 context: context,
//                 walletType: WalletType.upi,
//                 action: WalletAction.decrement,
//               ),
//             ),
//           ],

//           const SizedBox(height: 28),

//           _railAction(
//             icon: Icons.more_vert,
//             label: '',
//             onTap: () => showFeaturesBottomSheet(
//               context: context,
//               features: featuresByTab[1] ?? [],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// Widget _railAction({
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return GestureDetector(
//     onTap: onTap,
//     child: Column(
//       children: [
//         AnimatedScale(
//           scale: 1.0,
//           duration: const Duration(milliseconds: 120),
//           child: Icon(
//             icon,
//             size: 30,
//             color: Colors.grey, //Colors.white),
//           ), //color: Colors.white),
//         ),
//         if (label.isNotEmpty) ...[
//           const SizedBox(height: 4),
//           Text(
//             label,
//             style: const TextStyle(
//               color: Colors.grey, //Colors.white,
//               fontSize: 12,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ],
//     ),
//   );
// }

// Widget _miniRailAction({required IconData icon, required VoidCallback onTap}) {
//   return GestureDetector(
//     onTap: () {
//       HapticFeedback.lightImpact();
//       onTap();
//     },
//     child: Icon(icon, size: 26, color: Colors.blue), //Colors.white),
//   );
// }
