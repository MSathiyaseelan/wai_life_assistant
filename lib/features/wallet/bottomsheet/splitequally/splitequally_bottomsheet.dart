import 'package:flutter/material.dart';
import 'splitequally_bottomsheet_content.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitGroup.dart';

Future<SplitGroup?> showNewSplitBottomSheet(BuildContext context) {
  return showModalBottomSheet<SplitGroup>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: const SplitEquallyFormContent(),
      );
    },
  );
}
