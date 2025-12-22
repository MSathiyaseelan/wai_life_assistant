import 'package:flutter/material.dart';
import '../wallet/counterchip.dart';
// import '../wallet/transactionbottomsheet.dart';
import '../../navigation/featuresbottomsheet.dart';
import '../wallet/featurelistdata.dart';

class WalletChipBar extends StatelessWidget {
  const WalletChipBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            CounterChip(
              label: 'UPI',
              onIncrement: () => {
                //openTransactionBottomSheet(context),
                debugPrint('UPI +'),
              },
              onDecrement: () => debugPrint('UPI -'),
            ),

            CounterChip(
              label: 'Cash',
              onIncrement: () => debugPrint('Cash +'),
              onDecrement: () => debugPrint('Cash -'),
            ),

            ActionChip(
              label: const Text('Features'),
              elevation: 0,
              pressElevation: 0,
              onPressed: () {
                showFeaturesBottomSheet(context, featuresByTab[1] ?? []);
                debugPrint('Clicked: Features');
              },
            ),
          ],
        ),
      ),
    );
  }
}
