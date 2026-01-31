import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/core/widgets/screen_padding.dart';
import 'wallet_header.dart';
import 'bottomsheet/settings_bottomsheet.dart';
import 'FloatingRail/walletFloatingRail.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppText.walletTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showSettingsBottomSheet(context);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          ScreenPadding(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const WalletHeader(),
                const SizedBox(height: AppSpacing.gapS),
                Row(children: const [Expanded(child: WalletSummaryCard())]),
              ],
            ),
          ),
          const WalletFloatingRail(),
        ],
      ),
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("WAI")),
//       body: Padding(
//         padding: const EdgeInsets.all(12),
//         child: Row(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             LoggedInUser(),

//             const SizedBox(width: 12),

//             Expanded(
//               child: HorizontalCalendar(
//                 initialDate: DateTime.now(),
//                 onDateSelected: (date) {
//                   debugPrint("Selected: $date");
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

//Scrollable
// class WalletScreen extends StatelessWidget {
//   const WalletScreen({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: const EdgeInsets.all(AppSpacing.md),
//       children: [
//         HorizontalCalendar(
//           onDateSelected: (_) {},
//         ),
//         const SizedBox(height: AppSpacing.lg),
//         WalletSummaryCard(),
//         const SizedBox(height: AppSpacing.lg),
//         TransactionsList(),
//       ],
//     );
//   }
// }
