import 'package:flutter/material.dart';
import 'SparkBottomSheet.dart';
import 'package:wai_life_assistant/data/models/wallet/AiIntent.dart';

Future<AiIntent?> showSparkBottomSheet(BuildContext context) {
  return showModalBottomSheet<AiIntent>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SparkBottomSheet(),
  );
}
