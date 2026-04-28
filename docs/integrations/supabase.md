# Supabase Integration

---

## Purpose

Supabase is the core backend platform. It provides five services simultaneously:

| Service | What WAI uses it for |
|---|---|
| **Auth** | JWT sessions — accounts created by the `verify-otp` edge function, not native Supabase phone auth |
| **Database** | All application data (41 tables) with RLS on every table |
| **Storage** | Bill/receipt images (pantry bill scan), wardrobe photos |
| **Edge Functions** | `parse`, `send-otp`, `verify-otp`, `send-notification` — all server-side logic |
| **Realtime** | Live push of notification inserts to connected clients |

---

## Project Reference

```
Project ref: oeclczbamrnouuzooitx
URL: https://oeclczbamrnouuzooitx.supabase.co
```

---

## Authentication Method

The Flutter client uses **anonymous key + JWT**. The `anonKey` is a public JWT that grants access within RLS policies. No service role key is ever shipped to the client.

```dart
// lib/core/supabase/supabase_config.dart
class SupabaseConfig {
  static const String url     = 'https://oeclczbamrnouuzooitx.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

> The `anonKey` is safe to commit. RLS policies enforce per-user isolation server-side.

---

## Initialization

```dart
// lib/app_bootstrap.dart
await Supabase.initialize(
  url:     SupabaseConfig.url,
  anonKey: SupabaseConfig.anonKey,
);

// All subsequent access uses the singleton:
final _db = Supabase.instance.client;
```

---

## Edge Functions

Four edge functions deployed at `https://oeclczbamrnouuzooitx.supabase.co/functions/v1/`:

| Function | Purpose |
|---|---|
| `parse` | AI parsing via Gemini — all text and image requests |
| `send-otp` | Sends OTP via MSG91 |
| `verify-otp` | Verifies OTP with MSG91, creates/signs in user |
| `send-notification` | Sends FCM push notifications to family members |

### Invoking from Flutter

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
// Authorization: Bearer <user-JWT> added automatically by supabase_flutter
```

### Edge Function Secrets

All secrets are stored as Supabase edge function environment variables:

| Secret | Service | Set manually? |
|---|---|---|
| `GEMINI_API_KEY` | Google Gemini | Yes |
| `MSG91_AUTH_KEY` | MSG91 | Yes |
| `MSG91_TEMPLATE_ID` | MSG91 | Yes |
| `WAI_INTERNAL_AUTH_PASS` | Internal auth | Yes |
| `FCM_SERVICE_ACCOUNT` | Firebase FCM | Yes |
| `SUPABASE_URL` | Supabase | Auto-injected |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Admin | Auto-injected |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available inside edge functions — do not set them manually.

```bash
supabase secrets list   # view current secrets
```

---

## Realtime Subscription

Used for in-app notification feed:

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

---

## Error Handling

- **Network offline:** `NetworkService` monitors `connectivity_plus`. Screens reload on reconnect. Supabase calls throw; screens show empty states.
- **FunctionException:** `AIParser._invoke()` catches it, returns `AIParseResult.error(message)`. Never re-throws to UI.
- **Auth expiry:** `supabase_flutter` handles JWT refresh automatically.

---

## Free Tier Limits

| Tier | Free | Pro ($25/mo) |
|---|---|---|
| Database rows | 500 MB | 8 GB |
| Edge Function invocations | 500K/mo | 2M/mo |
| Realtime connections | 200 concurrent | 500 concurrent |
| Storage | 1 GB | 100 GB |
| Auth MAU | 50,000 | 100,000 |

At 1,000 MAU with ~5 AI calls/day: ~150K edge function invocations/month — within free tier.

---

## Setup Steps (New Developer)

```bash
# 1. Install Supabase CLI
npm install -g supabase

# 2. Login
supabase login

# 3. Link to project
supabase link --project-ref oeclczbamrnouuzooitx

# 4. Run migrations (creates all tables, RLS, seed prompts)
supabase db push

# 5. Set secrets
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

# 7. No client code changes needed — SupabaseConfig.dart has the real URL/key
```

---

## Related Documentation

- [Database Schema](../database.md) — all 41 tables with RLS policies
- [Gemini AI](gemini.md) — the `parse` edge function
- [MSG91](msg91.md) — the `send-otp` and `verify-otp` functions
- [Firebase FCM](firebase.md) — the `send-notification` function
