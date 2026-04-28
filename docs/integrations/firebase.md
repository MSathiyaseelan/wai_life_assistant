# Firebase Cloud Messaging (FCM) Integration

---

## Purpose

FCM delivers **family event push notifications** when one family member performs an action affecting other members. Examples:
- "Ravi added ₹500 expense"
- "Priya added Milk to shopping list"
- "New task assigned to you"

---

## Architecture

```
Family member saves data (Flutter)
    ↓  client calls /send-notification edge function
/send-notification (Supabase Edge Function)
    ↓  look up family_members → user_fcm_tokens
    ↓  obtain FCM OAuth2 token (service account JWT → Google OAuth2)
    ↓  POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send
FCM → device push notification
    ↓
FcmService._handleTap() → navigate to tab
```

---

## Authentication Method

FCM v1 HTTP API requires a **short-lived OAuth2 access token**, not a legacy server key.

The `send-notification` edge function:
1. Constructs a JWT signed with service account private key (`RSASSA-PKCS1-v1_5 / SHA-256`)
2. Exchanges the JWT for a bearer token via `https://oauth2.googleapis.com/token`
3. Uses the bearer token in `Authorization: Bearer <token>` on the FCM request

The service account JSON is stored as the `FCM_SERVICE_ACCOUNT` Supabase secret. **Never shipped to the client.**

---

## Android Notification Channels

Two channels registered at app startup (`NotificationService.init()`):

| Channel ID | Name | Importance | Used for |
|---|---|---|---|
| `wai_alarms` | WAI Alarms | MAX | Local reminder/bill alerts from `NotificationService.schedule()` |
| `wai_family_channel` | Family Updates | HIGH | FCM push from family members |
| `wai_sms_channel` | Bank SMS Alerts | HIGH | SMS detection notifications *(disabled)* |

Android channel settings are **immutable after first creation**. To change sound/importance: uninstall the app or create a new channel ID.

---

## FCM Token Lifecycle

```dart
// lib/core/services/fcm_service.dart
static Future<void> saveFcmToken([String? token]) async {
  final fcmToken = token ?? await _messaging.getToken();
  await Supabase.instance.client.from('user_fcm_tokens').upsert(
    {
      'user_id':    userId,
      'fcm_token':  fcmToken,
      'platform':   Platform.isAndroid ? 'android' : 'ios',
      'updated_at': DateTime.now().toIso8601String(),
    },
    onConflict: 'user_id, platform',  // one token per user per platform
  );
}
```

Token refresh: `_messaging.onTokenRefresh.listen((_) => saveFcmToken())`

---

## Notification Templates

The edge function defines 13 typed templates. Callers send `event_type` + `event_data`:

```typescript
const TEMPLATES = {
  "wallet.expense_added":         (d) => ({ title: `💸 ${d.member_name} added expense`,   body: `₹${d.amount} for ${d.category}`, route: "wallet" }),
  "wallet.income_added":          (d) => ({ title: `💰 ${d.member_name} added income`,    body: `₹${d.amount} — ${d.title}`,       route: "wallet" }),
  "wallet.lend_added":            (d) => ({ title: `🤝 ${d.member_name} lent money`,      body: `₹${d.amount} to ${d.person}`,     route: "wallet" }),
  "wallet.split_added":           (d) => ({ ... }),
  "pantry.meal_added":            (d) => ({ ... }),
  "pantry.basket_item_added":     (d) => ({ ... }),
  "pantry.item_finished":         (d) => ({ ... }),
  "pantry.expiry_alert":          (d) => ({ ... }),
  "planit.task_added":            (d) => ({ ... }),
  "planit.task_completed":        (d) => ({ ... }),
  "planit.reminder_added":        (d) => ({ ... }),
  "planit.special_day_approaching": (d) => ({ ... }),
  "planit.note_added":            (d) => ({ ... }),
  "functions.upcoming_added":     (d) => ({ ... }),
};
```

---

## Request Format (POST /send-notification)

```json
{
  "event_type":   "wallet.expense_added",
  "family_id":    "uuid-of-wallet",
  "triggered_by": "uuid-of-acting-user",
  "event_data": {
    "member_name": "Ravi",
    "amount":      "500",
    "category":    "Food"
  }
}
```

**Response:**
```json
{ "sent": 3, "total": 3 }
// or
{ "sent": 0, "reason": "no members" }
```

---

## Notification Tap → Tab Navigation

```dart
// lib/core/services/fcm_service.dart
static int? _routeToTab(String? route) => switch (route) {
  'wallet' => 1,
  'pantry' => 2,
  'planit' => 3,
  _        => null,
};
```

`FcmService.pendingTab` (`ValueNotifier<int?>`) is listened to by `BottomNavScreen`.

---

## Error Handling

| Failure | Behaviour |
|---|---|
| Firebase not configured | Bootstrap catches exception, logs "FCM disabled", app starts without push |
| FCM token null | `saveFcmToken()` logs and returns — no crash |
| FCM auth token failure | Returns `{ sent: 0, reason: "fcm_auth_failed" }` — no retry |
| No family members | Returns `{ sent: 0, reason: "no members" }` |
| Individual send failure | `Promise.allSettled` — other recipients still receive |
| Background message (app killed) | `firebaseMessagingBackgroundHandler` runs in separate Dart isolate |

---

## Cost

FCM is **free** — no message limits, no per-message cost. Service account tokens expire after 1 hour; the edge function generates a fresh one per request.

---

## Setup

```bash
# 1. Create Firebase project at https://console.firebase.google.com
# 2. Add Android app (package: com.yourcompany.wai_life_assistant)
#    Download google-services.json → android/app/google-services.json
# 3. Add iOS app → download GoogleService-Info.plist → ios/Runner/

# 4. Run FlutterFire CLI
flutter pub global activate flutterfire_cli
flutterfire configure

# 5. Generate service account key:
#    Firebase Console → Project Settings → Service Accounts → Generate new private key

# 6. Store in Supabase
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"

# 7. Deploy notification function
supabase functions deploy send-notification

# 8. Verify: after logging in on a device, check user_fcm_tokens has a row
```

---

## Related Documentation

- [Supabase Integration](supabase.md) — edge function deployment
- [Database Schema](../database.md) — `user_fcm_tokens`, `notifications` tables
