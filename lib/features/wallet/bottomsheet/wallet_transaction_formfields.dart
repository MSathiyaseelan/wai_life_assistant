import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'wallet_transaction_upifields.dart';
import 'wallet_transaction_cashfields.dart';

class WalletFormFields extends StatelessWidget {
  final WalletType walletType;

  const WalletFormFields(this.walletType);

  @override
  Widget build(BuildContext context) {
    switch (walletType) {
      case WalletType.upi:
        return const UpiFields();

      case WalletType.cash:
        return const CashFields();
    }
  }
}
