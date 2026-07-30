import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';
import 'package:wai_life_assistant/core/services/notification_prefs.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FamilyNotificationTrigger
// Fire-and-forget: calls the send-notification edge function after any
// family action. Never throws — notification failure must not break the UI.
//
// Usage:
//   FamilyNotificationTrigger.notify(
//     eventType: 'wallet.expense_added',
//     familyId:  currentFamilyId,
//     eventData: {'member_name': name, 'amount': '500', 'category': 'Food'},
//   );
// ─────────────────────────────────────────────────────────────────────────────

class FamilyNotificationTrigger {
  FamilyNotificationTrigger._();

  static final _supabase = Supabase.instance.client;

  static void notify({
    required String eventType,
    required String familyId,
    required Map<String, dynamic> eventData,
    // Sends only to this user instead of every family_members row — needed
    // for invites, since the invitee isn't a member of familyId yet.
    String? targetUserId,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (familyId.isEmpty) return;
    // "All Notifications" master switch — this is the single choke point
    // every family push notification routes through, so gating it here
    // covers wallet/functions/etc. uniformly instead of needing the check
    // repeated at every call site.
    if (!NotificationPrefs.instance.masterOn) return;

    // Fire and forget — never await, never block the UI. Note: the edge
    // function resolves "who's triggering this" from the caller's own
    // session (the Authorization header supabase_flutter attaches
    // automatically), not from a client-supplied field — it also verifies
    // the caller is actually a member of familyId before sending anything.
    _supabase.functions.invoke(
      'send-notification',
      body: {
        'event_type': eventType,
        'family_id': familyId,
        'event_data': eventData,
        if (targetUserId != null) 'target_user_id': targetUserId,
      },
    ).then((_) {
      debugPrint('[FCM] notified: $eventType');
    }).catchError((e, stack) {
      ErrorLogger.log(e, stackTrace: stack, action: 'family_notification_trigger');
    });
  }
}
