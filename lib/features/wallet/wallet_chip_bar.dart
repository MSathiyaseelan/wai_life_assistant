import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import '../wallet/counterchip.dart';
import '../../navigation/featuresbottomsheet.dart';
import '../wallet/featurelistdata.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';

class WalletChipBar extends StatelessWidget {
  const WalletChipBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: AppSpacing.walletChipBarPadding,
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Wrap(
          spacing: AppSpacing.walletChipSpacing,
          runSpacing: AppSpacing.walletChipSpacing,
          children: [
            CounterChip(
              label: AppText.walletChipUpi,
              onIncrement: () => {debugPrint('UPI +')},
              onDecrement: () => debugPrint('UPI -'),
            ),

            CounterChip(
              label: AppText.walletChipCash,
              onIncrement: () => debugPrint('Cash +'),
              onDecrement: () => debugPrint('Cash -'),
            ),

            ActionChip(
              label: Text(
                AppText.walletChipFeatures,
                style: Theme.of(context).textTheme.labelLarge,
              ),
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
