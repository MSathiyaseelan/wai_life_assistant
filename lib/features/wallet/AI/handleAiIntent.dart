import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/AiIntent.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_transaction_bottom_sheet.dart';
import 'package:wai_life_assistant/features/wallet/bottomsheet/wallet_features_bottomsheet.dart';

void handleAiIntent(BuildContext context, AiIntent intent) {
  switch (intent.type) {
    case AiIntentType.addExpense:
      //_handleExpense(context, intent);
      break;

    case AiIntentType.createGroup:
      //_handleCreateGroup(context, intent);
      break;

    case AiIntentType.lend:
    case AiIntentType.borrow:
      //_handleLendBorrow(context, intent);
      break;

    case AiIntentType.addIncome:
      // Handle add income intent
      break;

    case AiIntentType.requestMoney:
      // Handle request money intent
      break;

    case AiIntentType.addToGroup:
      // Handle add to group intent
      break;
  }
}

// Expense handling (personal vs group)
//void _handleExpense(BuildContext context, AiIntent intent) {
  // if (!groupExists(intent.groupName)) {
  //   _handleCreateGroup(context, intent);
  //   return;
  // }

  // // Group expense
  // if (intent.groupName != null) {
  //   showAddSplitExpenseBottomSheet(
  //     context: context,
  //     groupName: intent.groupName!,
  //     amount: intent.amount,
  //     paidBy: intent.paidBy,
  //     participants: intent.participants,
  //     splitType: intent.splitType,
  //   );
  //   return;
  // }

//   // Personal wallet expense
//   showWalletTransactionBottomSheet(
//     context: context,
//     walletType: intent.paymentMode ?? WalletType.cash,
//     action: WalletAction.decrement,
//     prefillAmount: intent.amount,
//     prefillNote: intent.note,
//   );
// }

// //Group mapping
// void _handleCreateGroup(BuildContext context, AiIntent intent) {
//   showCreateGroupBottomSheet(
//     context: context,
//     initialName: intent.groupName,
//     initialMembers: intent.participants,
//   );
// }

// //Lend / Borrow mapping
// void _handleLendBorrow(BuildContext context, AiIntent intent) {
//   showLendBorrowBottomSheet(
//     context: context,
//     type: intent.type == AiIntentType.lend
//         ? LendBorrowType.lend
//         : LendBorrowType.borrow,
//     person: intent.participants.isNotEmpty ? intent.participants.first : null,
//     amount: intent.amount,
//     note: intent.note,
//   );
// }
