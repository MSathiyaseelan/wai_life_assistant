import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'wallet_transaction_header.dart';
import 'wallet_transaction_formfields.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';

class WalletTransactionContent extends StatelessWidget {
  final WalletType walletType;
  final WalletAction action;

  const WalletTransactionContent({
    required this.walletType,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Header(walletType, action),

        const SizedBox(height: AppSpacing.gapM),

        WalletFormFields(walletType),

        const SizedBox(height: AppSpacing.gapL),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(action == WalletAction.increment ? 'Add' : 'Remove'),
          ),
        ),
      ],
    );
  }
}
