import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'wallet_transaction_header.dart';
import 'wallet_transaction_formfields.dart';
import 'package:wai_life_assistant/core/theme/app_spacing.dart';
import 'package:wai_life_assistant/data/models/wallet/WalletTransaction.dart';

class WalletTransactionContent extends StatefulWidget {
  final WalletType walletType;
  final WalletAction action;

  const WalletTransactionContent({
    super.key,
    required this.walletType,
    required this.action,
  });

  @override
  State<WalletTransactionContent> createState() =>
      _WalletTransactionContentState();
}

class _WalletTransactionContentState extends State<WalletTransactionContent> {
  final _amountController = TextEditingController();
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedCategory;

  @override
  void dispose() {
    _amountController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Header(widget.walletType, widget.action),

          const SizedBox(height: AppSpacing.gapM),

          WalletFormFields(
            walletType: widget.walletType,
            amountController: _amountController,
            purposeController: _purposeController,
            notesController: _notesController,
            selectedCategory: _selectedCategory,
            onCategoryChanged: (value) {
              setState(() => _selectedCategory = value);
            },
          ),

          const SizedBox(height: AppSpacing.gapL),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSubmit,
              child: const Text('Submit'),
            ),
          ),

          const SizedBox(height: AppSpacing.gapM),
        ],
      ),
    );
  }

  void _onSubmit() {
    if (_amountController.text.isEmpty || _purposeController.text.isEmpty) {
      return;
    }

    final transaction = WalletTransaction(
      walletType: widget.walletType,
      action: widget.action,
      amount: double.parse(_amountController.text),
      purpose: _purposeController.text,
      category: _selectedCategory,
      notes: _notesController.text,
    );

    Navigator.pop(context, transaction); // ✅ return data
  }
}

// class WalletTransactionContent extends StatelessWidget {
//   final WalletType walletType;
//   final WalletAction action;

//   const WalletTransactionContent({
//     required this.walletType,
//     required this.action,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final textTheme = Theme.of(context).textTheme;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Header(walletType, action),

//         const SizedBox(height: AppSpacing.gapM),

//         WalletFormFields(walletType),

//         const SizedBox(height: AppSpacing.gapL),

//         SizedBox(
//           width: double.infinity,
//           child: ElevatedButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Submit'),
//             //child: Text(action == WalletAction.increment ? 'Add' : 'Remove'),
//           ),
//         ),
//       ],
//     );
//   }
// }
