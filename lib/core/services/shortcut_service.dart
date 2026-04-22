import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SHORTCUT SERVICE
// ValueNotifier bridge between BottomNavScreen (which initialises QuickActions
// and receives the callback) and the feature screen that should react to it.
//
// Usage:
//   BottomNavScreen: ShortcutService.pending.value = ShortcutService.pasteBankSms;
//   DashboardScreen: ShortcutService.pending.addListener(_onShortcut);
// ─────────────────────────────────────────────────────────────────────────────

class ShortcutService {
  ShortcutService._();

  /// Shortcut type constant — must match the [ShortcutItem.type] in BottomNavScreen.
  static const pasteBankSms = 'paste_bank_sms';

  /// Set by BottomNavScreen when a shortcut fires; consumed (cleared) by the
  /// target screen so subsequent listeners don't re-fire.
  static final pending = ValueNotifier<String?>(null);
}
