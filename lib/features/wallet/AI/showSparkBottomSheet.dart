import 'package:flutter/material.dart';
import 'package:wai_life_assistant/data/models/wallet/wallet_models.dart';
import 'SparkBottomSheet.dart';

Future<void> showSparkBottomSheet(
  BuildContext context, {
  required String walletId,
  required void Function(TxModel tx) onSave,
  required VoidCallback onOpenFlow,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // ScaffoldMessenger + Scaffold so SnackBars shown from within the sheet
    // render inside this modal route instead of bubbling up to the page
    // underneath, where they'd stay hidden behind the sheet.
    builder: (_) => ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SparkBottomSheet(
          walletId: walletId,
          onSave: onSave,
          onOpenFlow: onOpenFlow,
        ),
      ),
    ),
  );
}
