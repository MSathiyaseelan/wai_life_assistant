import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'wallet_transaction_upifields.dart';
import 'wallet_transaction_cashfields.dart';

class WalletFormFields extends StatelessWidget {
  final WalletType walletType;

  final TextEditingController amountController;
  final TextEditingController purposeController;
  final TextEditingController notesController;

  final String? selectedCategory;
  final ValueChanged<String?> onCategoryChanged;

  const WalletFormFields({
    super.key,
    required this.walletType,
    required this.amountController,
    required this.purposeController,
    required this.notesController,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (walletType) {
      case WalletType.upi:
        return UpiFields(
          amountController: amountController,
          purposeController: purposeController,
          notesController: notesController,
          selectedCategory: selectedCategory,
          onCategoryChanged: onCategoryChanged,
        );

      case WalletType.cash:
        return CashFields(
          amountController: amountController,
          purposeController: purposeController,
          notesController: notesController,
          selectedCategory: selectedCategory,
          onCategoryChanged: onCategoryChanged,
        );
    }
  }
}

// class WalletFormFields extends StatelessWidget {
//   final WalletType walletType;

//   const WalletFormFields(this.walletType);

//   @override
//   Widget build(BuildContext context) {
//     switch (walletType) {
//       case WalletType.upi:
//         return const UpiFields();

//       case WalletType.cash:
//         return const CashFields();
//     }
//   }
// }
