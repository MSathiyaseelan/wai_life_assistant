import 'package:flutter/material.dart';

// ── AI monthly-limit snackbar helper ─────────────────────────────────────────
// AIParser._friendlyError() maps the backend's "Monthly AI usage limit
// reached" (429) response to a fixed string containing "AI limit". Every
// screen that calls AIParser.parseText should surface that specific message
// via a SnackBar instead of silently falling back to local parsing.

bool isAiLimitError(String? error) => error != null && error.contains('AI limit');

void maybeShowAiLimitSnackbar(BuildContext context, String? error) {
  if (!isAiLimitError(error)) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error!),
      duration: const Duration(seconds: 4),
      backgroundColor: Colors.orange.shade700,
    ),
  );
}
