import 'package:flutter/material.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import '../wallet/counterchip.dart';
import '../wallet/featurelistdata.dart';
import 'package:wai_life_assistant/core/theme/app_text.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'bottomsheet/wallet_features_bottomsheet.dart';

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
              onIncrement: () => {
                //debugPrint('UPI +')
                showWalletTransactionBottomSheet(
                  context: context,
                  walletType: WalletType.upi,
                  action: WalletAction.increment,
                ),
              },
              onDecrement: () => {
                //debugPrint('UPI -')
                showWalletTransactionBottomSheet(
                  context: context,
                  walletType: WalletType.upi,
                  action: WalletAction.decrement,
                ),
              },
            ),

            CounterChip(
              label: AppText.walletChipCash,
              onIncrement: () => {
                //debugPrint('Cash +'),
                showWalletTransactionBottomSheet(
                  context: context,
                  walletType: WalletType.cash,
                  action: WalletAction.increment,
                ),
              },
              onDecrement: () => {
                debugPrint('Cash -'),
                showWalletTransactionBottomSheet(
                  context: context,
                  walletType: WalletType.cash,
                  action: WalletAction.decrement,
                ),
              },
            ),

            ActionChip(
              label: Text(
                AppText.walletChipFeatures,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              elevation: 0,
              pressElevation: 0,
              onPressed: () {
                showFeaturesBottomSheet(
                  context: context,
                  features: featuresByTab[1] ?? [],
                );
                debugPrint('Clicked: Features');
              },
            ),
          ],
        ),
      ),
    );
  }
}
