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
    builder: (_) => SparkBottomSheet(
      walletId: walletId,
      onSave: onSave,
      onOpenFlow: onOpenFlow,
    ),
  );
}
