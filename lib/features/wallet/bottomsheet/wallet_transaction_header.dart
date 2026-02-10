import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';

class Header extends StatelessWidget {
  final WalletType walletType;
  final WalletAction action;

  const Header(this.walletType, this.action);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text(
        //   action == WalletAction.increment ? 'Add Amount' : 'Remove Amount',
        //   style: textTheme.titleMedium,
        // ),
        const SizedBox(height: 4),
        Text(
          walletType == WalletType.upi ? 'UPI Wallet' : 'Cash Wallet',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }
}
