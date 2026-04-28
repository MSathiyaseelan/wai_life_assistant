# Deployment

---

## Overview

WAI has two deployment surfaces:
1. **Flutter app** — Android APK/AAB and iOS IPA
2. **Supabase edge functions** — deployed via Supabase CLI

There are no CI/CD pipelines configured. Deployments are manual.

---

## Environment Selection

The build environment is set at **compile time** via `--dart-define=ENV=<value>`:

| ENV | App name | Debug banner | Logging | Use case |
|---|---|---|---|---|
| `dev` (default) | Life Assistant DEV | Shown | On | Local development |
| `qa` | Life Assistant QA | Shown | On | QA testing |
| `uat` | Life Assistant UAT | Shown | On | UAT sign-off |
| `prod` | Life Assistant | Hidden | Off | Production release |

```bash
# Development run
flutter run

# QA build
flutter build apk --dart-define=ENV=qa

# Production release build
flutter build appbundle --dart-define=ENV=prod --release
```

---

## Android Release Build

### Prerequisites

1. **Keystore file** — `android/keystore/release.jks` (do not commit to git)
2. **`android/key.properties`** (do not commit to git):
```properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=<your-key-alias>
storeFile=../keystore/release.jks
```

3. Verify `android/app/build.gradle` reads `key.properties` for the release signing config.

### Build commands

```bash
# App Bundle (recommended for Play Store)
flutter build appbundle --dart-define=ENV=prod --release

# APK (for direct distribution / testing)
flutter build apk --dart-define=ENV=prod --release --split-per-abi

# Output locations:
# AAB: build/app/outputs/bundle/release/app-release.aab
# APKs: build/app/outputs/apk/release/app-arm64-v8a-release.apk (etc.)
```

### Play Store submission checklist

- [ ] `version` and `versionCode` incremented in `pubspec.yaml`
- [ ] `google-services.json` is present in `android/app/`
- [ ] All debug/dev-only code removed or gated (`kDebugMode` checks)
- [ ] `AuthCoordinator.bypassVerify()` removed or wrapped in `assert(kDebugMode)`
- [ ] SMS permissions declaration submitted (if `READ_SMS` is re-enabled)
- [ ] `dev_link_profile_by_phone` function dropped from production DB

---

## iOS Release Build

### Prerequisites

1. Valid Apple Developer account with App ID configured
2. Distribution certificate and provisioning profile installed in Xcode
3. `ios/Runner/GoogleService-Info.plist` present (from Firebase setup)

### Build commands

```bash
# Build for App Store
flutter build ipa --dart-define=ENV=prod --release

# Output: build/ios/ipa/wai_life_assistant.ipa
```

Upload to App Store Connect via Transporter or Xcode Organizer.

### iOS Info.plist requirements

The following usage descriptions must be set (they already exist but verify before submission):

```xml
<key>NSMicrophoneUsageDescription</key>
<string>WAI uses the microphone for voice input to add expenses and groceries.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>WAI uses speech recognition to convert your spoken words to text.</string>
<key>NSCameraUsageDescription</key>
<string>WAI uses the camera to scan grocery bills.</string>
<key>NSContactsUsageDescription</key>
<string>WAI uses contacts to find people for split expense entries.</string>
<key>NSFaceIDUsageDescription</key>
<string>WAI uses Face ID to protect your financial data.</string>
```

---

## Edge Functions Deployment

Edge functions are in `supabase/functions/`. Deploy one or all:

```bash
# Link to project (once)
supabase link --project-ref oeclczbamrnouuzooitx

# Deploy a single function
supabase functions deploy parse
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy send-notification

# Deploy all functions
supabase functions deploy

# Check deployment status
supabase functions list
```

### Verifying a deployment

After deploying `parse`:
```bash
curl -X POST https://oeclczbamrnouuzooitx.supabase.co/functions/v1/parse \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"feature":"wallet","sub_feature":"expense","input_type":"text","text":"100 chai"}'
```

Expected: `{ "success": true, "data": { "amount": 100, "category": "Food", ... } }`

---

## Database Migrations

```bash
# Apply all pending migrations to linked project
supabase db push

# Generate a new migration
supabase migration new <migration_name>
# Creates: supabase/migrations/YYYYMMDDHHMMSS_<migration_name>.sql
# Edit the file, then:
supabase db push

# Check migration status
supabase migration list
```

**Naming convention used in this project:** `NNN_description.sql` (e.g. `042_add_user_reports.sql`).

---

## Secret Rotation

To rotate a secret (e.g. Gemini API key):

```bash
# Update the secret
supabase secrets set GEMINI_API_KEY=<new-key>

# Re-deploy the affected function (picks up new secret)
supabase functions deploy parse
```

> Rotating `WAI_INTERNAL_AUTH_PASS` requires additionally updating all existing Supabase user passwords to match. Contact the project owner for the migration script.

---

## Pre-Release Security Checklist

| Item | Status | Notes |
|---|---|---|
| `AuthCoordinator.bypassVerify()` removed | ⚠️ Pending | Currently not gated — must remove before production |
| `dev_link_profile_by_phone` dropped from DB | ⚠️ Pending | Migration `009` left in production schema |
| `anonKey` moved to `--dart-define` | ⚠️ Pending | Currently hardcoded in `SupabaseConfig` |
| `notes` table RLS policy verified | ⚠️ Investigate | Policy references `family_members.wallet_id` which doesn't exist |
| No test files | ⚠️ Known | `test/` directory does not exist — no automated tests |

---

## Rollback

### Edge function rollback

Supabase does not support function rollback natively. To revert:

1. Check out the previous version from git
2. `supabase functions deploy <function-name>`

### Database migration rollback

```bash
# Roll back the most recent migration
supabase db reset  # WARNING: drops and recreates the entire DB from scratch
```

For production: write a manual rollback SQL migration (down migration) and apply it via the Supabase SQL editor.

---

## Related Documentation

- [Supabase Integration](../integrations/supabase.md) — edge function secrets and setup
- [Architecture](../architecture.md) — environment configuration details
- [Error Tracking](error-tracking.md) — monitoring after deployments
