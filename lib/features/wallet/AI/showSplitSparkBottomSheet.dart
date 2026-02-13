import 'package:flutter/material.dart';
import 'SplitSparkBottomSheet.dart';
import 'package:wai_life_assistant/data/models/wallet/SplitAiIntent.dart';

Future<SplitAiIntent?> showSplitSparkBottomSheet(BuildContext context) {
  return showModalBottomSheet<SplitAiIntent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SplitSparkBottomSheet(),
  );
}
