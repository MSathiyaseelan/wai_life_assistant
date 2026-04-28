# Section 5: Third-Party Integrations

> **Note on speech-to-text:** The user spec requested "Google Cloud Speech-to-Text" but the implementation
> uses the Flutter `speech_to_text` package, which delegates to the device's native STT engine (Android
> `SpeechRecognizer` / iOS `SFSpeechRecognizer`). No Cloud STT API key or billing is involved. Section 5.5
> documents the actual system.

---

## Table of Contents

1. [Supabase](#51-supabase)
2. [Google Gemini AI](#52-google-gemini-ai)
3. [Firebase Cloud Messaging (FCM)](#53-firebase-cloud-messaging-fcm)
4. [MSG91 SendOTP](#54-msg91-sendotp)
5. [Device Speech-to-Text (speech_to_text)](#55-device-speech-to-text)
6. [SMS Parsing (Bank SMS Auto-Detection)](#56-sms-parsing)

---

## 5.1 Supabase

### Purpose

Supabase is the core backend platform. It provides five services used simultaneously:

| Service | What WAI uses it for |
|---|---|
| **Auth** | Manages user sessions (JWT tokens, refresh) — accounts are created by the `verify-otp` edge function, not native Supabase phone auth |
| **Database** | All application data: wallets, transactions, tasks, reminders, groceries, functions/MOI, notifications, AI logs, FCM tokens |
| **Storage** | Bill/receipt images (pantry bill scan), wardrobe photos |
| **Edge Functions** | `parse`, `send-otp`, `verify-otp`, `send-notification` — all server-side logic |
| **Realtime** | Live push of notification inserts to connected clients |

### Authentication Method

The client uses **anonymous key + JWT**. The `anonKey` is a public JWT that grants access within Row Level Security (RLS) policies. No service role key is ever shipped to the client.

```dart
// lib/core/supabase/supabase_config.dart
class SupabaseConfig {
  static const String url     = 'https://oeclczbamrnouuzooitx.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

> The `anonKey` is safe to ship in client code. It is not a secret — RLS policies enforce per-user isolation.

### Environment Configuration

There are **no per-environment Supabase URLs** in the current setup. A single project is used across dev/QA/prod. The `EnvironmentConfig` (`lib/core/env/environment_config.dart`) tracks the app name, base URL, and log verbosity but does not gate Supabase credentials.

```dart
// lib/core/env/environment_config.dart
static EnvironmentConfig fromEnv(String env) {
  switch (env) {
    case 'prod':
      return EnvironmentConfig(
        environment: AppEnvironment.prod,
        appName:     'Life Assistant',
        baseUrl:     'https://api.yourdomain.com',
        enableLogs:  false,
      );
    // 'dev' (default), 'qa', 'uat' also defined
  }
}
```

The ENV is set at build time via `--dart-define`:
```bash
flutter run --dart-define=ENV=prod
flutter build apk --dart-define=ENV=prod
```

### Initialization

Supabase is initialized once in `app_bootstrap.dart` before `runApp`:

```dart
await Supabase.initialize(
  url:     SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
);
```

All subsequent access uses the singleton:
```dart
final _db = Supabase.instance.client;
```

### What Triggers Calls

| Trigger | Service | Example |
|---|---|---|
| App start | Auth | Session restore |
| Every tab load | Database | `_db.from('transactions').select(...)` |
| User creates data | Database | Insert task, expense, reminder |
| Family action | Edge Function | `send-notification` triggered with `event_type` |
| AI parse request | Edge Function | `_db.functions.invoke('parse', body: {...})` |
| App start (if Firebase ready) | Database | `user_fcm_tokens` upsert |
| Notification tapped | Realtime | `notifications:$uid` channel fires |

### Edge Function Invocation (via supabase_flutter)

```dart
// lib/core/services/ai_parser.dart
final response = await Supabase.instance.client.functions.invoke(
  'parse',
  body: {
    'feature':     feature,
    'sub_feature': subFeature,
    'input_type':  inputType,
    'text':        text,
    'context':     _buildContext(context),
  },
);
```

The `Authorization: Bearer <user-JWT>` header is added automatically by `supabase_flutter`.

### Realtime Subscription

```dart
// lib/data/services/notification_service.dart
_channel = _db
    .channel('notifications:$uid')
    .onPostgresChanges(
      event:  PostgresChangeEvent.insert,
      schema: 'public',
      table:  'notifications',
      filter: PostgresChangeFilter(
        type:   PostgresChangeFilterType.eq,
        column: 'user_id',
        value:  uid,
      ),
      callback: (_) => changeSignal.value++,
    )
    .subscribe();
```

### Error Handling and Fallback

- **Network offline:** `NetworkService` (`lib/core/services/network_service.dart`) monitors `connectivity_plus`. Screens listen to `isOnline` and reload on reconnect. Supabase calls will throw; screens show empty states or cached data.
- **FunctionException from edge function:** `AIParser._invoke()` catches `FunctionException`, extracts the error message, and returns `AIParseResult.error(message)`. Never re-throws to the UI.
- **DB errors:** individual service classes (`TaskService`, `PantryService`, etc.) let errors propagate up to the screen where they are shown as snackbars.
- **Auth expiry:** `supabase_flutter` handles JWT refresh automatically using the stored refresh token.

### Cost and Rate Limits

| Tier | Free | Pro ($25/mo) |
|---|---|---|
| Database rows | 500 MB | 8 GB |
| Edge Function invocations | 500K/mo | 2M/mo |
| Realtime connections | 200 concurrent | 500 concurrent |
| Storage | 1 GB | 100 GB |
| Auth MAU | 50,000 | 100,000 |

WAI's heaviest usage is edge function invocations (one per AI parse + one per family notification). At 1,000 MAU with ~5 AI calls/day, estimated ~150K/mo — within the free tier.

### Setup Steps for New Developer

```bash
# 1. Install Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Link to project
supabase link --project-ref oeclczbamrnouuzooitx

# 4. Run migrations (creates all tables, RLS, and seed prompts)
supabase db push

# 5. Set edge function secrets (see Section 5.2, 5.3, 5.4 for values)
supabase secrets set GEMINI_API_KEY=<your-key>
supabase secrets set MSG91_AUTH_KEY=<your-key>
supabase secrets set MSG91_TEMPLATE_ID=<your-template-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=<strong-password>
supabase secrets set FCM_SERVICE_ACCOUNT='<json-content>'

# 6. Deploy edge functions
supabase functions deploy parse
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy send-notification

# 7. No client code changes needed — SupabaseConfig.dart has the real project URL/key
```

---

## 5.2 Google Gemini AI

### Purpose

All AI parsing in WAI is handled by Google Gemini. It converts natural-language text and images into structured JSON for every feature: expense parsing, receipt scanning, task creation, grocery detection, event planning, bank SMS parsing, and the dashboard AI assistant.

### Architecture

Gemini is **never called directly from the Flutter client**. All calls go through the `parse` Supabase edge function, which handles prompt loading, context injection, and response normalisation. The client calls `AIParser.parseText()` or `AIParser.parseImage()`, which invoke the `parse` edge function via `supabase_flutter`.

```
Flutter client
    ↓  supabase_flutter.functions.invoke('parse', body)
Supabase Edge Function (/parse)
    ↓  fetch(geminiUrl + '?key=' + GEMINI_API_KEY)
Google Gemini REST API
    ↓  JSON response
Edge function normalises + returns
    ↓
AIParseResult { success, data, confidence, needsReview, meta }
```

There is also a legacy `GeminiService` (`lib/core/services/gemini_service.dart`) that calls Gemini directly via REST. It contains a placeholder `_apiKey = 'YOUR_GEMINI_API_KEY'` and a guard that returns a setup message if the key is not set. This class is a scaffold — the production path is always through the edge function.

### Models Used

| Model | Used for | Config |
|---|---|---|
| `gemini-2.5-flash` | All text parsing (28+ prompts) | `temperature: 0.1`, `maxOutputTokens: 2048`, `responseMimeType: application/json` |
| `gemini-2.0-flash` | Image parsing (`pantry/bill_scan` only) | Same generation config, no `responseMimeType` (image+JSON causes 422 on some models) |

### Authentication Method

**API key** passed as a query parameter:
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=GEMINI_API_KEY
```

The key is stored as a Supabase edge function secret (`GEMINI_API_KEY`) and is never shipped to the client.

### Environment Configuration

All environments use the same Gemini API key (stored in Supabase secrets). There is no dev/prod key split in the current setup. To rotate:
```bash
supabase secrets set GEMINI_API_KEY=<new-key>
supabase functions deploy parse
```

### What Triggers Calls

Every `AIParser.parseText()` or `AIParser.parseImage()` call in the client triggers one Gemini call via the edge function. Common triggers:

| Feature | Trigger | sub_feature |
|---|---|---|
| Wallet | User types/speaks an expense description | `expense` |
| Wallet | User photographs a receipt | `receipt` |
| Wallet | User pastes a bank SMS | `sms_parse` |
| Pantry | User photographs a grocery bill | `bill_scan` |
| Pantry | User types a meal or basket description | `meal`, `basket` |
| PlanIt | User types a reminder or task | `reminder`, `task` |
| Functions | User types function/MOI details | `my_function`, `received_gift`, etc. |
| Dashboard | User asks the AI assistant | `ai_assistant` |

### Request Format (Edge Function POST /parse)

```json
{
  "feature":     "wallet",
  "sub_feature": "expense",
  "input_type":  "text",
  "text":        "250 for lunch at Saravana Bhavan",
  "context": {
    "today":         "2026-04-28",
    "day_of_week":   "Monday",
    "current_month": "April 2026",
    "currency":      "INR",
    "categories":    ["Food", "Transport", "Shopping", "Health", "Other"]
  }
}
```

For images:
```json
{
  "feature":          "pantry",
  "sub_feature":      "bill_scan",
  "input_type":       "image",
  "image_base64":     "<base64-encoded JPEG>",
  "image_mime_type":  "image/jpeg",
  "context":          { "today": "2026-04-28", "currency": "INR" }
}
```

### Response Format

```json
{
  "success":      true,
  "feature":      "wallet",
  "sub_feature":  "expense",
  "input_type":   "text",
  "data": {
    "amount":      250,
    "category":    "Food",
    "title":       "Lunch at Saravana Bhavan",
    "type":        "expense",
    "date":        "2026-04-28",
    "confidence":  0.94
  },
  "confidence":   0.94,
  "needs_review": false,
  "meta": {
    "tokens_used": 312,
    "latency_ms":  1840,
    "prompt_id":   "a1b2c3d4-...",
    "model":       "gemini-2.5-flash"
  }
}
```

### Error Handling and Fallback

| Error | Handling |
|---|---|
| Gemini HTTP error (non-200) | Edge function returns `{ success: false, error: "Gemini API error 429: ..." }` with status 502 |
| Gemini returns invalid JSON | Edge function tries `{...}` extraction; if still fails, returns 422 `"AI returned invalid JSON"` |
| Gemini returns empty candidates | `new Error("Gemini returned empty response")` → 502 |
| Edge function unreachable | `AIParser._invoke()` catches `FunctionException`, returns `AIParseResult.error(...)` |
| `needs_review: true` (confidence < 0.7) | Client shows confirmation sheet before saving — user can correct fields |

SMS parsing has an additional regex fallback layer (see Section 5.6).

### Safety Settings

All four harm categories are set to `BLOCK_NONE` in the edge function. This is intentional — financial/medical text regularly triggers false positives with default settings.

```typescript
safetySettings: [
  { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
]
```

### Cost and Rate Limits

**Gemini 2.5 Flash pricing (as of 2026):**

| Input | Cost |
|---|---|
| Text input | $0.15 / 1M tokens |
| Text output | $0.60 / 1M tokens |
| Image input | $0.075 / 1K images |

**Per-parse estimate:** average prompt ~600 tokens + output ~200 tokens = ~0.18¢ per text parse.

| Scale (MAU) | Parses/month (est.) | Estimated cost |
|---|---|---|
| 100 | 15,000 | ~$0.03 |
| 1,000 | 150,000 | ~$0.27 |
| 10,000 | 1.5M | ~$2.70 |
| 100,000 | 15M | ~$27 |

Rate limits: `gemini-2.5-flash` supports 1,000 RPM / 1M TPM on the paid tier. No throttling expected below 10K MAU.

### Setup Steps for New Developer

```bash
# 1. Get API key from https://aistudio.google.com/app/apikey
# 2. Set in Supabase secrets
supabase secrets set GEMINI_API_KEY=AIzaSy...

# 3. Verify it works
curl -X POST https://oeclczbamrnouuzooitx.supabase.co/functions/v1/parse \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"feature":"wallet","sub_feature":"expense","input_type":"text","text":"100 chai"}'

# Expected: { "success": true, "data": { "amount": 100, "category": "Food", ... } }
```

---

## 5.3 Firebase Cloud Messaging (FCM)

### Purpose

FCM delivers **family event push notifications** to other members' devices. Examples: "Ravi added ₹500 expense", "Priya added Milk to shopping list", "New task assigned to you". These are triggered server-side when one family member performs an action that affects other members.

### Architecture

```
Family member saves data (Flutter)
    ↓  client calls Supabase edge function
/send-notification (Edge Function)
    ↓  look up family_members → user_fcm_tokens
    ↓  obtain FCM OAuth2 token (service account JWT → Google OAuth2 token endpoint)
    ↓  POST https://fcm.googleapis.com/v1/projects/{project_id}/messages:send
FCM → device push notification
    ↓
FcmService._handleTap() → navigate to tab
```

### Authentication Method

FCM v1 HTTP API requires a **short-lived OAuth2 access token**, not a legacy server key. The edge function:
1. Constructs a JWT signed with the service account private key using `RSASSA-PKCS1-v1_5 / SHA-256`
2. Exchanges the JWT for a bearer token via `https://oauth2.googleapis.com/token`
3. Uses the bearer token in `Authorization: Bearer <token>` on the FCM request

The service account JSON is stored as the `FCM_SERVICE_ACCOUNT` Supabase secret. It is never shipped to the client.

### Android Notification Channels

Two channels are registered at app startup (`NotificationService.init()`):

| Channel ID | Name | Importance | Used for |
|---|---|---|---|
| `wai_alarms` | WAI Alarms | MAX (alarm sound + vibration) | Local reminder/bill alerts from `NotificationService.schedule()` |
| `wai_family_channel` | Family Updates | HIGH | FCM push from family members via `FcmService._createFamilyChannel()` |
| `wai_sms_channel` | Bank SMS Alerts | HIGH | SMS detection notifications (currently disabled — see Section 5.6) |

Android channel settings are immutable after first creation. To change sound/importance you must uninstall the app or create a new channel ID.

### FCM Token Lifecycle

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

Token refresh is handled via `_messaging.onTokenRefresh.listen((_) => saveFcmToken())`.

### Notification Templates (send-notification edge function)

The edge function defines 13 typed templates. Callers send `event_type` + `event_data`:

```typescript
// supabase/functions/send-notification/index.ts
const TEMPLATES = {
  "wallet.expense_added":  (d) => ({ title: `💸 ${d.member_name} added expense`,  body: `₹${d.amount} for ${d.category}`,   route: "wallet" }),
  "wallet.income_added":   (d) => ({ title: `💰 ${d.member_name} added income`,   body: `₹${d.amount} — ${d.title}`,        route: "wallet" }),
  "wallet.lend_added":     (d) => ({ title: `🤝 ${d.member_name} lent money`,     body: `₹${d.amount} to ${d.person}`,      route: "wallet" }),
  "wallet.split_added":    (d) => ({ ... }),
  "pantry.meal_added":     (d) => ({ ... }),
  "pantry.basket_item_added": (d) => ({ ... }),
  "pantry.item_finished":  (d) => ({ ... }),
  "pantry.expiry_alert":   (d) => ({ ... }),
  "planit.task_added":     (d) => ({ ... }),
  "planit.task_completed": (d) => ({ ... }),
  "planit.reminder_added": (d) => ({ ... }),
  "planit.special_day_approaching": (d) => ({ ... }),
  "planit.note_added":     (d) => ({ ... }),
  "functions.upcoming_added": (d) => ({ ... }),
};
```

### Request Format (POST /send-notification)

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

### Response Format

```json
{ "sent": 3, "total": 3 }
// or
{ "sent": 0, "reason": "no members" }
// or
{ "sent": 0, "reason": "fcm_auth_failed", "error": "..." }
```

### Notification Tap → Tab Navigation

```dart
// lib/core/services/fcm_service.dart
static int? _routeToTab(String? route) => switch (route) {
  'wallet' => 1,
  'pantry' => 2,
  'planit' => 3,
  _        => null,
};
```

`FcmService.pendingTab` is a `ValueNotifier<int?>` that `BottomNavScreen` listens to.

### Error Handling and Fallback

| Failure | Behaviour |
|---|---|
| Firebase not configured | Bootstrap catches the exception, logs `FCM disabled`, app starts without push |
| FCM token null | `saveFcmToken()` logs and returns — no crash |
| FCM auth token failure | Edge function returns `{ sent: 0, reason: "fcm_auth_failed" }` — no retry |
| No family members found | Returns `{ sent: 0, reason: "no members" }` |
| Individual send failure | `Promise.allSettled` — other recipients still receive their notifications |
| Background message (app killed) | `firebaseMessagingBackgroundHandler` runs in a separate Dart isolate, shows local notification via its own `FlutterLocalNotificationsPlugin` instance |

### Snooze / Stop Actions (Local Alarms Only)

`NotificationService` schedules local alarms (not FCM). When Snooze is tapped:
1. Cancel current notification
2. Reschedule 10 minutes later via `zonedSchedule`
3. Update `reminders.due_date/due_time/snoozed` in Supabase

Stop action cancels the notification only, no DB change.

### Cost and Rate Limits

FCM is **free** (no message limits, no per-message cost). Service account tokens expire after 1 hour — the edge function generates a fresh one per request.

### Setup Steps for New Developer

```bash
# 1. Create a Firebase project at https://console.firebase.google.com
# 2. Add Android app (package: com.yourcompany.wai_life_assistant)
#    Download google-services.json → android/app/google-services.json
# 3. Add iOS app → download GoogleService-Info.plist → ios/Runner/
# 4. Run FlutterFire CLI
flutter pub global activate flutterfire_cli
flutterfire configure

# 5. Generate service account key:
#    Firebase Console → Project Settings → Service Accounts → Generate new private key
#    Download the JSON

# 6. Store in Supabase
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"

# 7. Deploy notification function
supabase functions deploy send-notification

# 8. Verify: after logging in on a device, check that user_fcm_tokens has a row
```

---

## 5.4 MSG91 SendOTP

### Purpose

WAI uses **phone number + OTP** as the only sign-in method. MSG91 delivers the 6-digit OTP via SMS to the user's Indian mobile number. After verification, a Supabase session is created using an internal synthetic email — the user never sees or manages a password.

### Authentication Method

**API key in request header** (`authkey: MSG91_AUTH_KEY`). The key is stored as a Supabase secret and passed from the edge function; it is never shipped to the Flutter client.

### Auth Flow

```
Flutter                  Supabase /send-otp         MSG91
  │                             │                      │
  │ POST { phone }              │                      │
  │────────────────────────────>│                      │
  │                             │ POST /api/v5/otp     │
  │                             │─────────────────────>│
  │                             │    { request_id }    │
  │                             │<─────────────────────│
  │   { request_id }            │                      │
  │<────────────────────────────│                      │
  │                             │                  SMS sent
  │                             │                  to user
  │
  │ POST { phone, otp, request_id }
  │────────────────────────────>│  (Supabase /verify-otp)
  │                             │ GET /api/v5/otp/verify
  │                             │─────────────────────>│
  │                             │    { type: "success" }
  │                             │<─────────────────────│
  │                             │
  │                             │ supabaseAdmin.auth.signInWithPassword
  │                             │   (or createUser if new)
  │                             │   email: phone_919876543210@waiapp.internal
  │   { access_token,           │   password: WAI_INTERNAL_AUTH_PASS
  │     refresh_token,          │
  │     user.id }               │
  │<────────────────────────────│
```

### Internal Email Convention

Because MSG91 handles the OTP, Supabase Auth is used with email+password internally. The email is derived from the phone number:

```
phone: +91 98765 43210
→ digits: 919876543210
→ email:  phone_919876543210@waiapp.internal
→ password: WAI_INTERNAL_AUTH_PASS (server-side secret, never sent to client)
```

This ensures the same user always gets the same `auth.uid()` regardless of device.

### OTP Configuration

```typescript
// supabase/functions/send-otp/index.ts
body: JSON.stringify({
  template_id: MSG91_TEMPLATE_ID,  // MSG91 Flow ID
  mobile,                           // e.g. "919876543210"
  otp_length:  6,
  otp_expiry:  30,                  // minutes
})
```

### Request/Response Format

**Send OTP** (`POST /functions/v1/send-otp`):
```json
// Request
{ "phone": "+919876543210" }

// Success
{ "success": true, "request_id": "MSG91-request-id" }

// Error
{ "error": "Invalid phone number" }
```

**Verify OTP** (`POST /functions/v1/verify-otp`):
```json
// Request
{ "phone": "+919876543210", "otp": "123456", "request_id": "MSG91-request-id" }

// Success
{
  "access_token":  "eyJhbGciOi...",
  "refresh_token": "v1.abc...",
  "expires_in":    3600,
  "user":          { "id": "uuid", "phone": "+919876543210" }
}

// Error
{ "error": "Invalid OTP" }
```

### Error Handling and Fallback

| Error | HTTP Status | Behaviour |
|---|---|---|
| MSG91 returns error type | 502 | Returns MSG91's error message to client |
| Invalid/expired OTP | 401 | Returns "Invalid OTP" from MSG91 |
| User creation fails | 500 | Returns "Failed to create user account" |
| Missing phone/otp fields | 400 | Returns field validation error |
| Unexpected MSG91 non-JSON | 502 | Returns "Unexpected response from OTP provider" |

There is no automatic retry on the server side. The client must call `/send-otp` again to get a fresh OTP.

### Cost and Rate Limits

| Item | Cost |
|---|---|
| SMS OTP (Indian numbers) | ~₹0.15–0.25 per OTP (MSG91 DLT pricing) |
| Rate limit | Configurable in MSG91 dashboard; default ~5 OTPs/phone/hour |
| OTP validity | 30 minutes (configured) |

MSG91 requires DLT registration for Indian numbers (TRAI regulation). The `MSG91_TEMPLATE_ID` corresponds to a pre-approved DLT template.

### Setup Steps for New Developer

```
1. Create a MSG91 account at https://msg91.com
2. Complete DLT registration (required for Indian SMS):
   - Register sender ID (e.g. WAIAPP)
   - Submit OTP template for DLT approval (~3–5 business days)
   - Note the DLT-approved template content (e.g. "Your WAI OTP is ##OTP##. Valid for 30 minutes.")
3. In MSG91 dashboard → SMS → OTP → Create Flow
   - Select your DLT template
   - Copy the Flow ID (this is MSG91_TEMPLATE_ID)
4. Copy your Auth Key from MSG91 → API → Auth Key
5. Set Supabase secrets:
```
```bash
supabase secrets set MSG91_AUTH_KEY=<your-auth-key>
supabase secrets set MSG91_TEMPLATE_ID=<your-flow-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=<strong-random-password>
```
```
6. Deploy edge functions:
```
```bash
supabase functions deploy send-otp
supabase functions deploy verify-otp
```
```
7. Test: run the app, enter a real Indian mobile number, verify OTP arrives within 30 seconds.
```

---

## 5.5 Device Speech-to-Text

### Purpose

WAI uses speech input as an alternative to typing for expense entry and grocery basket input. The user taps a microphone button, speaks (e.g. "spent 250 on groceries at Big Bazaar"), and the transcribed text is fed to the AI parser.

### Implementation

Uses the Flutter package [`speech_to_text: ^7.0.0-beta.2`](https://pub.dev/packages/speech_to_text), which delegates to:
- **Android:** `SpeechRecognizer` (uses Google's on-device or cloud STT depending on device)
- **iOS:** `SFSpeechRecognizer` (Apple's native speech framework)

**This is not Google Cloud Speech-to-Text API.** There is no API key, no billing account, and no network call to Google's STT service from WAI's code. The device handles speech recognition natively.

### Usage

```dart
// lib/features/wallet/AI/SparkBottomSheet.dart
final SpeechToText _speech = SpeechToText();

await _speech.listen(
  localeId:       'en_IN',              // Indian English
  listenMode:     ListenMode.dictation,
  partialResults: true,                 // streams partial text while speaking
  pauseFor:       const Duration(seconds: 3),
  listenFor:      const Duration(seconds: 30),
  onResult: (result) {
    setState(() => _spokenText = result.recognizedWords);
    if (result.finalResult) _onSpeechComplete();
  },
);
```

The same pattern is used in:
- `lib/features/wallet/wallet_screen.dart`
- `lib/features/pantry/pantry_screen.dart`

### Language Selection

The voice language is user-configurable in Settings → Language & Voice. The selected locale is stored via `AppPrefs.voiceLanguage`. Currently only `en` (English) is enabled; other Indian languages (Tamil, Hindi, Telugu) show "Coming soon" in the UI.

```dart
// lib/features/dashboard/widgets/language_voice_sheet.dart
final enabled = lang.code == 'en';  // others disabled
```

### Permissions

| Platform | Permission | When requested |
|---|---|---|
| Android | `RECORD_AUDIO` | On first microphone tap (via `permission_handler`) |
| iOS | `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` | On first use |

### Error Handling and Fallback

| Scenario | Behaviour |
|---|---|
| Permission denied | Mic button shows error; user can type instead |
| No speech detected | `listenFor` timeout fires; text field remains empty |
| Device STT unavailable | `_speech.initialize()` returns `false`; mic button is hidden |
| Partial transcription | `partialResults: true` streams text in real time; user can edit before submitting |

After transcription, the text is passed to `AIParser.parseText()` exactly like typed input. There is no separate voice-specific AI prompt — the same text prompts handle both typed and spoken input.

### Cost and Rate Limits

**Free.** Device-native STT. On Android, Google's on-device model handles most recognition without network. No rate limits or API costs.

### Setup Steps for New Developer

```yaml
# pubspec.yaml (already present)
speech_to_text: ^7.0.0-beta.2
permission_handler: ^11.0.1
```

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
```

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>WAI uses the microphone for voice input to add expenses and groceries.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>WAI uses speech recognition to convert your spoken words to text.</string>
```

No API keys or accounts required.

---

## 5.6 SMS Parsing

### Purpose

WAI can detect Indian bank SMS messages and extract transaction details (amount, merchant, type, date) to pre-fill the expense entry form — removing the need for manual data entry. This is the fastest onboarding flow for Wallet.

### Two Approaches

#### Approach 1: Automatic Scan-on-Open (Android only)

The app scans the SMS inbox each time it opens, finds new bank SMS messages since the last scan, and surfaces a confirmation sheet.

> **Currently disabled** in production. The `READ_SMS` permission and the initialization call are commented out in `app_bootstrap.dart` pending Google Play Store approval.

```dart
// lib/app_bootstrap.dart (disabled)
// try { await SMSParserService.initialize(); } catch (e) { ... }
// await SMSParserService.checkPending();
```

To re-enable:
1. Uncomment the two lines in `app_bootstrap.dart`
2. Restore `<uses-permission android:name="android.permission.READ_SMS"/>` in AndroidManifest
3. Complete Google Play's SMS permissions declaration form

#### Approach 2: Manual Paste (active)

The user copies a bank SMS and pastes it into the SparkBottomSheet (Wallet → AI entry). This has no Play Store restrictions and works on both iOS and Android.

```dart
// QuickAction shortcut from home screen
ShortcutService.pasteBankSms = 'paste_bank_sms'
```

### Two-Layer Parse Pipeline

```
Bank SMS text
    │
    ▼
Layer 1: SMSRegexParser.tryParse()
    │
    ├── confidence ≥ 0.80 (isHighConfidence) ──► return result (free, <1ms)
    │
    └── no match or low confidence
            │
            ▼
        Layer 2: AIParser.parseText(feature: 'wallet', subFeature: 'sms_parse')
            │
            ├── success ──► return AI result
            │
            └── AI error ──► return regex result (even if low confidence)
```

### Layer 1: Regex Parser (`SMSRegexParser`)

Handles ~70% of Indian bank SMS formats. 10 pattern functions run in order:

| Pattern | Confidence | Example |
|---|---|---|
| HDFC debit | 0.92 | `INR 500.00 debited from A/c XX1234... Info: SWIGGY` |
| HDFC credit | 0.90 | `INR 75,000.00 credited to your A/c XX7890... by TCS` |
| SBI debit | 0.90 | `A/c no. XX5678 is debited for Rs.1000.00... to RAZORPAY` |
| ICICI debit | 0.88 | `ICICI Bank: Rs.850.00 debited from XX9012...` |
| Axis debit | 0.88 | `Rs.500 debited from Axis Acct XX3456 at DMART` |
| UPI paid | 0.90 | `Rs.500.00 paid to Swiggy India via PhonePe` |
| UPI received | 0.88 | `Rs.500.00 received from Ravi Kumar in your HDFC` |
| Salary credit | 0.92 | `Salary of INR 75,000.00 credited... by TCS LIMITED` |
| Generic debit | 0.65 | Fallback: amount + debited/paid keyword |
| Generic credit | 0.60 | Fallback: amount + credited/received keyword |

Date normalisation handles three Indian formats: `17-03-26`, `17/03/2026`, `17-Mar-26` → always output as `YYYY-MM-DD`.

`isHighConfidence` is `confidence >= 0.80` — patterns 1–8 all qualify; generics (0.60–0.65) do not.

### Layer 2: AI Parser (Gemini via Edge Function)

If Layer 1 fails or has low confidence, the `wallet/sms_parse` prompt is called:

```dart
// lib/features/wallet/services/sms_parser_service.dart
final result = await AIParser.parseText(
  feature:    'wallet',
  subFeature: 'sms_parse',
  text:       body,
  context: {
    'sender': sender,
    'today':  DateTime.now().toIso8601String().split('T')[0],
  },
);
if (result.data?['is_transaction'] != true) return null;
return SMSTransaction.fromJson(result.data!);
```

The AI prompt handles auspicious Indian amounts (₹51, ₹101, ₹501), mixed-script merchant names, and edge cases the regex cannot cover.

### Bank SMS Detector

Used before scanning to filter non-bank SMS:

```dart
// lib/features/wallet/services/sms_parser_service.dart
static bool isBankSMS(String sender, String body) {
  const bankSenders = [
    'hdfcbk', 'icicib', 'sbiinb', 'axisbk', 'kotakb', 'boiind',
    'pnbsms', 'canbnk', 'indbnk', 'yesbnk', 'rblbnk', 'iobsms',
    'scbank', 'federa', 'idbibk', 'paytmb',
    'gpay', 'phonepe', 'paytm', 'bhimupi',
  ];
  if (bankSenders.any((k) => sender.toLowerCase().contains(k))) return true;
  return ['debited', 'credited', 'debit', 'credit', 'withdrawn',
          'inr ', 'rs.', '₹'].any((k) => body.toLowerCase().contains(k));
}
```

### Scan Cooldown and Deduplication

```dart
static const _kScanCooldownMs = 5 * 60 * 1000;  // 5 minutes between scans
static const _kSeenIdsKey     = 'sms_seen_ids';   // SharedPreferences, max 200 IDs
```

On each scan:
1. Check 5-minute cooldown. Skip if too soon.
2. Read inbox, filter to last 48 hours (or since last scan)
3. Filter out seen IDs
4. Filter to bank SMS only
5. Sort newest-first, surface only the most recent
6. Mark all candidates as seen before processing (crash-safe)

### Notification on SMS Detection

When a new bank SMS is found (during auto-scan):
```dart
// Shows local notification on wai_sms_channel
await _showSmsNotification(body);  // title: "🏦 ₹500 spent at Swiggy"
// Also fires ValueNotifier for immediate foreground confirmation
pendingSmsBody.value = body;
```

Cold-start tap (app was killed, user tapped notification):
1. `NotificationService._onBackgroundAction()` writes SMS body to `SharedPreferences('pending_sms_body')`
2. On next app start, `SMSParserService.checkPending()` reads and fires `pendingSmsBody.value`

### `SMSTransaction` Model

```dart
class SMSTransaction {
  final bool   isTransaction;
  final String transactionType;   // 'debit' | 'credit'
  final double amount;
  final String? merchant;
  final String? accountLast4;
  final String? bankName;
  final String  transactionDate;  // YYYY-MM-DD
  final String? category;
  final String? paymentMode;      // 'UPI' | 'POS' | 'ATM' | 'NEFT' | ...
  final double  confidence;       // 0.0–1.0
  final String? referenceNumber;

  bool get isExpense      => transactionType == 'debit';
  bool get isHighConfidence => confidence >= 0.80;
  String get title        => merchant ?? (isExpense ? 'Expense' : 'Income');
}
```

### Error Handling and Fallback

| Scenario | Behaviour |
|---|---|
| READ_SMS permission denied | `initialize()` logs and returns — no crash |
| Inbox read error | Logged, returns empty result |
| No bank SMS found | Silent — no notification, no UI change |
| Layer 1 fails, Layer 2 fails | Returns `null` → UI shows manual entry form |
| Layer 2 returns `is_transaction: false` | Returns `null` — not shown as transaction |

### Cost and Rate Limits

| Component | Cost |
|---|---|
| Regex (Layer 1) | Free, <1ms |
| AI (Layer 2) | ~0.18¢/parse (same Gemini pricing as Section 5.2) |
| SMS inbox read | Free (device API) |

In practice, Layer 1 handles ~70% of parses. AI is only called for ~30% of bank SMS events.

### Setup Steps for New Developer

**To enable auto-scan (after Play Store approval):**

1. `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_SMS"/>
```

2. `lib/app_bootstrap.dart` — uncomment:
```dart
try { await SMSParserService.initialize(); } catch (e) {
  debugPrint('[Bootstrap] SMS init failed: $e');
}
await SMSParserService.checkPending();
```

3. In Google Play Console → App content → Permissions declaration → Justify `READ_SMS` use.

**Manual paste (already active):** No setup required. Available via SparkBottomSheet and the `paste_bank_sms` home screen quick action.

---

## Environment Secret Reference

All secrets are stored as Supabase edge function environment variables. Client code never holds secrets.

| Secret Name | Service | Where set |
|---|---|---|
| `GEMINI_API_KEY` | Google Gemini | Supabase secrets |
| `MSG91_AUTH_KEY` | MSG91 | Supabase secrets |
| `MSG91_TEMPLATE_ID` | MSG91 | Supabase secrets |
| `WAI_INTERNAL_AUTH_PASS` | Supabase Auth (internal) | Supabase secrets |
| `FCM_SERVICE_ACCOUNT` | Firebase FCM | Supabase secrets (JSON string) |
| `SUPABASE_URL` | Supabase | Auto-injected by Supabase runtime |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Admin | Auto-injected by Supabase runtime |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available inside edge functions — you do not set them manually.

To list currently set secrets:
```bash
supabase secrets list
```

---

*Next: Section 6 — API Reference*
