import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wai_life_assistant/core/services/error_logger.dart';

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
    // Exactly one of familyId / splitGroupId must be set — a split group's
    // wallet doesn't have to belong to a family (e.g. splitting with a
    // friend on your personal wallet), so family membership isn't always
    // the right thing to authorize against server-side.
    String? familyId,
    String? splitGroupId,
    required Map<String, dynamic> eventData,
    // Sends only to this user instead of every family_members row — needed
    // for invites, since the invitee isn't a member of familyId yet, and
    // always required when using splitGroupId (there's no "all members" list).
    String? targetUserId,
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if ((familyId == null || familyId.isEmpty) &&
        (splitGroupId == null || splitGroupId.isEmpty)) {
      return;
    }

    // No local NotificationPrefs gate here — every notification toggle
    // (master switch and per-event) is a promise about what each RECIPIENT
    // wants, not what this sending device wants, so it's checked server-side
    // in the edge function against each recipient's own profiles row.

    // Fire and forget — never await, never block the UI. Note: the edge
    // function resolves "who's triggering this" from the caller's own
    // session (the Authorization header supabase_flutter attaches
    // automatically), not from a client-supplied field — it also verifies
    // the caller is actually a member of familyId (or a participant of
    // splitGroupId) before sending anything.
    _supabase.functions.invoke(
      'send-notification',
      body: {
        'event_type': eventType,
        if (familyId != null) 'family_id': familyId,
        if (splitGroupId != null) 'split_group_id': splitGroupId,
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
