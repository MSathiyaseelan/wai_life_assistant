# Deployment

---

## Overview

WAI has two deployment surfaces:
1. **Flutter app** — Android APK/AAB and iOS IPA
2. **Supabase edge functions** — deployed via Supabase CLI

There are no CI/CD pipelines configured. Deployments are manual.

---

## Environment Selection

Each environment is a **separate Supabase project** (separate database, auth users, edge functions, secrets) and, on Android, a **separate app** via product flavors (`dev`/`qa`/`uat` get an `applicationIdSuffix` so they install side-by-side; `prod` keeps the bare `com.wai.lifeassistant`).

The build environment is set at **compile time** by combining `--flavor` (Android package selection) with `--dart-define-from-file=env/<name>.json` (which Supabase project + `ENV` string to bake in). The real credential files (`env/dev.json`, `env/qa.json`, `env/uat.json`, `env/prod.json`) are gitignored — copy them from the committed `env/<name>.json.example` templates and fill in the real Supabase URL/anon key for that environment.

| ENV | App name | Debug banner | Logging | Use case |
|---|---|---|---|---|
| `dev` (default) | Life Assistant DEV | Shown | On | Local development |
| `qa` | Life Assistant QA | Shown | On | QA testing |
| `uat` | Life Assistant UAT | Shown | On | UAT sign-off |
| `prod` | Life Assistant | Hidden | Off | Production release |

```bash
# Development run
flutter run --flavor dev --dart-define-from-file=env/dev.json

# QA build
flutter build apk --flavor qa --dart-define-from-file=env/qa.json

# Production release build
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json --release
```

> `SupabaseConfig` (`lib/core/supabase/supabase_config.dart`) reads `SUPABASE_URL`/`SUPABASE_ANON_KEY` via `String.fromEnvironment`, falling back to the original dev project if no define file is passed — so a bare `flutter run` still works, but always prefer passing `--dart-define-from-file` explicitly to avoid ambiguity about which backend you're pointed at.

---

## New Environment Setup Checklist

Follow this in order whenever standing up a new environment (QA, UAT, or a future one). Each step below has caused a real, silent failure at some point — do not skip any of them.

- [ ] **Create the Supabase project** in the dashboard. Note its project ref (from the URL or Project Settings → General) and its `anon` key (Project Settings → API).
- [ ] **Create the `env/<name>.json` file** by copying `env/<name>.json.example` and filling in the real `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `ENV`. This file is gitignored — it never gets committed.
- [ ] **Push the database schema:**
  ```bash
  supabase link --project-ref <project-ref>
  supabase db push --project-ref <project-ref>
  ```
  A fresh project is empty Postgres — this step creates every table/RLS policy/function. See the [Database Migrations](#database-migrations) gotchas above if this errors partway through.
- [ ] **Deploy every edge function** (all 7 — see [Edge Functions Deployment](#edge-functions-deployment)):
  ```bash
  supabase functions deploy --project-ref <project-ref>
  ```
- [ ] **Set every required secret** for this environment (see the secrets table under [Edge Functions Deployment](#edge-functions-deployment) for the full list and which function needs which). At minimum:
  ```bash
  supabase secrets set GEMINI_API_KEY=<value> --project-ref <project-ref>
  supabase secrets set MSG91_AUTH_KEY=<value> --project-ref <project-ref>
  supabase secrets set MSG91_TEMPLATE_ID=<value> --project-ref <project-ref>
  supabase secrets set WAI_INTERNAL_AUTH_PASS=<new-strong-random-value> --project-ref <project-ref>
  supabase secrets set FCM_SERVICE_ACCOUNT='<firebase-service-account-json>' --project-ref <project-ref>
  ```
  **`WAI_INTERNAL_AUTH_PASS` is not optional** — `firebase-verify` hard-fails at startup without it (no fallback), and skipping this is the easiest step in this whole checklist to miss since nothing about *creating* the project or pushing migrations surfaces the problem; it only shows up later as a 404/500 the first time someone tries to log in.
- [ ] **Register the Android app(s) in Firebase** for this environment's applicationId (`com.wai.lifeassistant.dev` / `.qa` / `.uat`, or the bare `com.wai.lifeassistant` for prod) in the *same* Firebase project — Firebase Console → Project Settings → Add app. Then download `google-services.json` (it bundles **all** registered apps into one file, regardless of which app's download button you click) and replace `android/app/google-services.json`. Skipping this makes the Gradle build hard-fail for that flavor with a "no matching client" error from the Google Services plugin.
- [ ] **Smoke test before handing off:** OTP send + verify, Firebase phone sign-in (if used), and one `parse` call (see [Verifying a deployment](#verifying-a-deployment)).

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
flutter build appbundle --flavor prod --dart-define-from-file=env/prod.json --release

# APK (for direct distribution / testing)
flutter build apk --flavor prod --dart-define-from-file=env/prod.json --release --split-per-abi

# Output locations (flavor name appears in the path):
# AAB: build/app/outputs/bundle/prodRelease/app-prod-release.aab
# APKs: build/app/outputs/apk/prod/release/app-prod-arm64-v8a-release.apk (etc.)
```

### Play Store submission checklist

- [ ] `version` and `versionCode` incremented in `pubspec.yaml`
- [ ] `google-services.json` is present in `android/app/` and contains a client entry for `com.wai.lifeassistant` (the `prod` flavor's bare applicationId, no suffix)
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
flutter build ipa --flavor prod --dart-define-from-file=env/prod.json --release

# Output: build/ios/ipa/wai_life_assistant.ipa
```

> iOS flavor schemes/xcconfigs mirroring the Android flavors have not been set up yet (needs Xcode on macOS) — until then, iOS builds only target the default (prod-equivalent) configuration.

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

Seven edge functions live in `supabase/functions/`. Deploy one or all — always pass `--project-ref` explicitly rather than relying on whatever the CLI happens to be linked to, so you don't accidentally deploy to the wrong environment:

```bash
# Deploy a single function
supabase functions deploy parse               --project-ref <project-ref>
supabase functions deploy send-otp            --project-ref <project-ref>
supabase functions deploy verify-otp          --project-ref <project-ref>
supabase functions deploy firebase-verify     --project-ref <project-ref>
supabase functions deploy send-notification   --project-ref <project-ref>
supabase functions deploy delete-account      --project-ref <project-ref>
supabase functions deploy notify-trial-expiry --project-ref <project-ref>

# Deploy all functions at once
supabase functions deploy --project-ref <project-ref>

# Check deployment status
supabase functions list --project-ref <project-ref>
```

| Function | Purpose | Required secrets |
|---|---|---|
| `parse` | AI parsing (Gemini) for all natural-language/image inputs across the app | `GEMINI_API_KEY`, `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\* |
| `send-otp` | Sends OTP via MSG91 for phone login | `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID` |
| `verify-otp` | Verifies MSG91 OTP, signs in/creates the Supabase user | `MSG91_AUTH_KEY`, `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\*, `WAI_INTERNAL_AUTH_PASS` (has a dev fallback, but set it explicitly) |
| `firebase-verify` | Verifies Firebase Phone Auth ID token, signs in/creates the Supabase user | `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\*, `WAI_INTERNAL_AUTH_PASS` **(hard-fails at startup if unset — no fallback)**, `FIREBASE_PROJECT_ID` (has a fallback) |
| `send-notification` | Sends FCM push notifications after family events | `FCM_SERVICE_ACCOUNT`, `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\* |
| `delete-account` | Account deletion flow | `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\* |
| `notify-trial-expiry` | Scheduled job notifying users of trial expiry | `SUPABASE_URL`\*, `SUPABASE_SERVICE_ROLE_KEY`\*, `FCM_SERVICE_ACCOUNT`, `CRON_SECRET` (has a fallback) |

\* `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by Supabase per-project — never set these manually.

> **`WAI_INTERNAL_AUTH_PASS` is used as the literal Supabase Auth password** for every phone-auth user (`phone_<digits>@waiapp.internal`), shared across `verify-otp` and `firebase-verify`. Supabase secrets are project-wide, so setting it once makes both functions agree. It does **not** need to match the value used in other environments — each environment has its own separate `auth.users` table — it just needs to be set once per environment and never changed afterward (rotating it breaks sign-in for existing users on that environment; see [Secret Rotation](#secret-rotation)).

### Verifying a deployment

After deploying `parse` (replace `<project-url>` with the environment's Supabase URL from its `env/<name>.json`):
```bash
curl -X POST https://<project-url>.supabase.co/functions/v1/parse \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"feature":"wallet","sub_feature":"expense","input_type":"text","text":"100 chai"}'
```

Expected: `{ "success": true, "data": { "amount": 100, "category": "Food", ... } }`

---

## Database Migrations

```bash
# Apply all pending migrations to a specific project (always pass --project-ref)
supabase db push --project-ref <project-ref>

# Generate a new migration
supabase migration new <migration_name>
# Creates: supabase/migrations/YYYYMMDDHHMMSS_<migration_name>.sql
# Edit the file, then:
supabase db push --project-ref <project-ref>

# Check migration status for a project
supabase migration list --project-ref <project-ref>
```

**Naming convention used in this project:** `NNN_description.sql` (e.g. `042_add_user_reports.sql`), with a few 4-digit exceptions (`0170`, `0171`, `0410`, `0710`) inserted between existing numbers to fix ordering bugs discovered when pushing to a fresh project — see below.

**Gotchas learned the hard way pushing to a brand-new (QA) project** — none of these show up against an already-provisioned database, only against an empty one:
- **Version prefix must be purely numeric.** The CLI derives a migration's "version" from the leading digit run before the first `_`. A file like `017a_foo.sql` gets silently treated as version `017` (colliding with `017_bar.sql`) and may be skipped or corrupt the remote history. Always use digits only (`0170_foo.sql` is fine, `017a_foo.sql` is not).
- **No duplicate version prefixes.** Two files both starting `037_...` will fail with `duplicate key value violates unique constraint "schema_migrations_pkey"` the second time one applies. `ls supabase/migrations | grep '^037'`-style checks catch this before pushing.
- **All `CREATE POLICY` / `CREATE TRIGGER` statements should be guarded** with `DROP POLICY IF EXISTS` / `DROP TRIGGER IF EXISTS` immediately before them. Without this, any migration that runs twice (e.g. after a `migration repair`, or `--include-all`) fails with `policy already exists`. Every existing migration in this repo now has this guard — keep it for new ones too.
- **Every table your migrations reference must actually be created by a migration.** Several tables (`function_participants`, `function_clothing_families`, `function_bridal_essentials`, `function_return_gifts`, `user_fcm_tokens`) existed on dev only because they were created manually via the Supabase Dashboard SQL Editor, never captured in `supabase/migrations/`. This only surfaces as `relation "..." does not exist` when pushing to a brand-new project. If you add a table via the Dashboard instead of a migration file, **write the migration too** — don't let dev's schema drift ahead of migration history.
- If a new environment's `db push` ever reports `Remote migration versions not found in local migrations directory`, that means the remote bookkeeping table has a version that doesn't match any current local file (usually from a renamed/fixed migration). Recover with:
  ```bash
  supabase link --project-ref <project-ref>
  supabase migration repair --status reverted <version>   # only edits bookkeeping, not data
  supabase db pull
  supabase db push --include-all --project-ref <project-ref>
  ```

---

## Secret Rotation

To rotate a secret (e.g. Gemini API key), per environment:

```bash
# Update the secret
supabase secrets set GEMINI_API_KEY=<new-key> --project-ref <project-ref>

# Re-deploy the affected function (picks up new secret)
supabase functions deploy parse --project-ref <project-ref>
```

> Rotating `WAI_INTERNAL_AUTH_PASS` requires additionally updating all existing Supabase user passwords to match. Contact the project owner for the migration script.

---

## Pre-Release Security Checklist

| Item | Status | Notes |
|---|---|---|
| `AuthCoordinator.bypassVerify()` removed | ⚠️ Pending | Currently not gated — must remove before production |
| `dev_link_profile_by_phone` dropped from DB | ⚠️ Pending | Migration `009` left in production schema |
| `anonKey` moved to `--dart-define` | ✅ Done | `SupabaseConfig` now reads `SUPABASE_URL`/`SUPABASE_ANON_KEY` via `--dart-define-from-file=env/<name>.json`, with the original dev value only as a fallback default |
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
