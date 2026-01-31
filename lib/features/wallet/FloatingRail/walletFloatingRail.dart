import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
import '../featurelistdata.dart';
import 'package:flutter/services.dart';

class WalletFloatingRail extends StatefulWidget {
  const WalletFloatingRail({super.key});

  @override
  State<WalletFloatingRail> createState() => _WalletFloatingRailState();
}

class _WalletFloatingRailState extends State<WalletFloatingRail> {
  bool showUpi = false;
  bool showCash = false;

  void _toggleUpi() {
    HapticFeedback.lightImpact();
    setState(() {
      showUpi = !showUpi;
      showCash = false;
    });
  }

  void _toggleCash() {
    HapticFeedback.lightImpact();
    setState(() {
      showCash = !showCash;
      showUpi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showUpi) ...[
            _miniRailAction(
              icon: Icons.add,
              onTap: () => showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.upi,
                action: WalletAction.increment,
              ),
            ),
            const SizedBox(height: 12),
          ],

          _railAction(
            icon: Icons.account_balance_wallet_outlined,
            label: 'UPI',
            onTap: _toggleUpi,
          ),

          if (showUpi) ...[
            const SizedBox(height: 12),
            _miniRailAction(
              icon: Icons.remove,
              onTap: () => showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.upi,
                action: WalletAction.decrement,
              ),
            ),
          ],

          const SizedBox(height: 24),

          if (showCash) ...[
            _miniRailAction(
              icon: Icons.add,
              onTap: () => showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.cash,
                action: WalletAction.increment,
              ),
            ),
            const SizedBox(height: 12),
          ],

          _railAction(
            icon: Icons.payments_outlined,
            label: 'Cash',
            onTap: _toggleCash,
          ),

          if (showCash) ...[
            const SizedBox(height: 12),
            _miniRailAction(
              icon: Icons.remove,
              onTap: () => showWalletTransactionBottomSheet(
                context: context,
                walletType: WalletType.cash,
                action: WalletAction.decrement,
              ),
            ),
          ],

          const SizedBox(height: 28),

          _railAction(
            icon: Icons.more_vert,
            label: '',
            onTap: () => showFeaturesBottomSheet(
              context: context,
              features: featuresByTab[1] ?? [],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _railAction({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Column(
      children: [
        AnimatedScale(
          scale: 1.0,
          duration: const Duration(milliseconds: 120),
          child: Icon(
            icon,
            size: 30,
            color: Colors.blue,
          ), //color: Colors.white),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.blue, //Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _miniRailAction({required IconData icon, required VoidCallback onTap}) {
  return GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      onTap();
    },
    child: Icon(icon, size: 26, color: Colors.blue), //Colors.white),
  );
}

// Widget _mainAction({
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return _glassRailButton(
//     size: 56,
//     iconSize: 26,
//     icon: icon,
//     label: label,
//     onTap: onTap,
//   );
// }

// Widget _miniAction({
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return _glassRailButton(
//     size: 44,
//     iconSize: 22,
//     icon: icon,
//     label: label,
//     onTap: onTap,
//   );
// }

// Widget _glassRailButton({
//   required double size,
//   required double iconSize,
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return GestureDetector(
//     onTap: onTap,
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(size / 2),
//           child: BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
//             child: Container(
//               width: size,
//               height: size,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.18),
//                 border: Border.all(color: Colors.white.withOpacity(0.35)),
//                 boxShadow: const [
//                   BoxShadow(
//                     blurRadius: 12,
//                     color: Colors.black26,
//                     offset: Offset(0, 6),
//                   ),
//                 ],
//               ),
//               child: Icon(icon, size: iconSize, color: Colors.white),
//             ),
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w500,
//             color: Colors.white,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// Widget _railButton({
//   required double size,
//   required double iconSize,
//   required IconData icon,
//   required String label,
//   required VoidCallback onTap,
// }) {
//   return GestureDetector(
//     onTap: onTap,
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         ClipRRect(
//           borderRadius: BorderRadius.circular(size / 2),
//           child: BackdropFilter(
//             filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
//             child: Container(
//               width: size,
//               height: size,
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.18),
//                 shape: BoxShape.circle,
//                 border: Border.all(color: Colors.white.withOpacity(0.35)),
//               ),
//               child: Icon(icon, size: iconSize, color: Colors.white),
//             ),
//           ),
//         ),
//         const SizedBox(height: 4),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             fontWeight: FontWeight.w500,
//             color: Colors.white,
//           ),
//         ),
//       ],
//     ),
//   );
// }
