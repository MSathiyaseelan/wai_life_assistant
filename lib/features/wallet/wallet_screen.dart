import 'package:flutter/material.dart';
import 'package:wai_life_assistant/features/wallet/one.dart';
import 'package:wai_life_assistant/features/wallet/two.dart';
import 'package:wai_life_assistant/shared/horizontal_calendar.dart';
import 'package:wai_life_assistant/shared/widgets/loggedinuser.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("WAI")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // rows, columns, widgets
              Row(
                children: [
                  OneScreen(),
                  const SizedBox(height: 16),
                  TwoScreen(),
                ],
              ),
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
