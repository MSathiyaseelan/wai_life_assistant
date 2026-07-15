import 'package:flutter/material.dart';

import 'overlay_toast.dart';

// ── AI monthly-limit toast helper ────────────────────────────────────────────
// AIParser._friendlyError() maps the backend's "Monthly AI usage limit
// reached" (429) response to a fixed string containing "AI limit". Every
// screen that calls AIParser.parseText should surface that specific message
// instead of silently falling back to local parsing.

bool isAiLimitError(String? error) => error != null && error.contains('AI limit');

void maybeShowAiLimitSnackbar(BuildContext context, String? error) {
  if (!isAiLimitError(error)) return;
  showOverlayToast(context, error!, backgroundColor: Colors.orange.shade700);
}
