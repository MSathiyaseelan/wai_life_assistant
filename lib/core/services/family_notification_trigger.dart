import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  }) {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    if (familyId.isEmpty) return;

    // Fire and forget — never await, never block the UI
    _supabase.functions.invoke(
      'send-notification',
      body: {
        'event_type': eventType,
        'family_id': familyId,
        'triggered_by': userId,
        'event_data': eventData,
      },
    ).then((_) {
      debugPrint('[FCM] notified: $eventType');
    }).catchError((e) {
      debugPrint('[FCM] notify error: $e');
    });
  }
}
