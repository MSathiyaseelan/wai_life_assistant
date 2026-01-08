import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/enum/wallet_enums.dart';
import 'package:wai_life_assistant/shared/bottom_sheets/app_bottom_sheet.dart';
import 'wallet_transaction_content.dart';

void showWalletTransactionBottomSheet({
  required BuildContext context,
  required WalletType walletType,
  required WalletAction action,
}) {
  showAppBottomSheet(
    context: context,
    child: WalletTransactionContent(walletType: walletType, action: action),
  );
}
