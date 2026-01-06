import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/userlist.dart';
import 'package:wai_life_assistant/shared/calendar/customcalendar.dart';
import 'package:wai_life_assistant/features/wallet/walletsummarycard.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppText.walletTitle,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(flex: 2, child: UsersList()),
                  const SizedBox(width: AppSpacing.gapS),
                  Expanded(flex: 3, child: DayNavigator()),
                ],
              ),

              const SizedBox(height: AppSpacing.gapL),

              Row(children: const [Expanded(child: WalletSummaryCard())]),
            ],
          ),
        ),
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
