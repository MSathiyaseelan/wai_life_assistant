import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/widgets/screen_padding.dart';
import 'wallet_header.dart';
import 'bottomsheet/settings_bottomsheet.dart';
import 'FloatingRail/walletFloatingRail.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';
import 'featurelistdata.dart';
import 'package:flutter/services.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool showCash = false;
  bool showUpi = false;

  void _toggleCash() {
    HapticFeedback.lightImpact();
    setState(() {
      showCash = !showCash;
      showUpi = false;
    });
  }

  void _toggleUpi() {
    HapticFeedback.lightImpact();
    setState(() {
      showUpi = !showUpi;
      showCash = false;
    });
  }

  void _collapseRail() {
    if (showCash || showUpi) {
      setState(() {
        showCash = false;
        showUpi = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppText.walletTitle)),
      body: Stack(
        children: [
          ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(children: [Expanded(child: WalletSummaryCard())]),
              ],
            ),
          ),

          // 👇 THIS is where outside tap handling lives
          if (showCash || showUpi)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _collapseRail,
                child: const SizedBox.expand(),
              ),
            ),

          // Floating rail always on top
          WalletFloatingRail(
            showCash: showCash,
            showUpi: showUpi,
            onCashTap: _toggleCash,
            onUpiTap: _toggleUpi,
            onCollapse: _collapseRail,
            onCashAdd: () => showWalletTransactionBottomSheet(
              context: context,
              walletType: WalletType.cash,
              action: WalletAction.increment,
            ),
            onCashRemove: () => showWalletTransactionBottomSheet(
              context: context,
              walletType: WalletType.cash,
              action: WalletAction.decrement,
            ),
            onUpiAdd: () => showWalletTransactionBottomSheet(
              context: context,
              walletType: WalletType.upi,
              action: WalletAction.increment,
            ),
            onUpiRemove: () => showWalletTransactionBottomSheet(
              context: context,
              walletType: WalletType.upi,
              action: WalletAction.decrement,
            ),
            onMoreTap: () => showFeaturesBottomSheet(
              context: context,
              features: featuresByTab[1] ?? [],
            ),
          ),
        ],
      ),
    );
  }
}

// class WalletScreen extends StatelessWidget {
//   const WalletScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(AppText.walletTitle),
//         // actions: [
//         //   IconButton(
//         //     icon: const Icon(Icons.more_vert),
//         //     onPressed: () {
//         //       showSettingsBottomSheet(context);
//         //     },
//         //   ),
//         // ],
//       ),
//       body: Stack(
//         children: [
//           ScreenPadding(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 //const WalletHeader(),
//                 //const SizedBox(height: AppSpacing.xxs),
//                 Row(children: const [Expanded(child: WalletSummaryCard())]),
//               ],
//             ),
//           ),
//           const WalletFloatingRail(),
//         ],
//       ),
//     );
//   }
// }
