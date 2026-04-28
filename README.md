# WAI — Indian Household Management App

WAI (pronounced "why") is a Flutter + Supabase mobile application for Indian households to manage finances, groceries, planning, events, and daily life in one place — with AI-assisted data entry throughout.

---

## Table of Contents

1. [What is WAI](#what-is-wai)
2. [Architecture Overview](#architecture-overview)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Getting Started](#getting-started)
6. [Database Setup](#database-setup)
7. [Deploying Edge Functions](#deploying-edge-functions)
8. [Environment Variables](#environment-variables)
9. [Third-Party Setup](#third-party-setup)
10. [Testing](#testing)
11. [Code Conventions](#code-conventions)
12. [Contributing](#contributing)
13. [Known Issues](#known-issues)

---

## What is WAI

WAI is built for Indian multi-generational households where money, groceries, events, and tasks are shared across family members. The app has five main tabs:

| Tab | What it does |
|---|---|
| **Dashboard** | Home screen with AI assistant, quick stats, notifications, and family settings |
| **Wallet** | Income/expense/lend/borrow tracking, split groups, bill watch, SMS import, reports |
| **Pantry** | Grocery shopping list, meal planning, recipe box, food preferences |
| **PlanIt** | Reminders (Alert Me), tasks, special days, sticky notes, bill watch, wish list |
| **Lifestyle** | My Garage, My Wardrobe, Documents, Devices, Functions Tracker, Around the House |

**Functions Tracker** (inside Lifestyle) is WAI's most culturally specific feature — it manages Indian social events (weddings, naming ceremonies, engagements) including MOI (மொய் / Moi), the South Indian tradition of tracking monetary gifts and the social obligation to return them at the giver's future events.

Every feature has a natural-language or voice entry path: speak or type a description and the AI fills in the form fields.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App (Dart)                    │
│                                                         │
│  Dashboard  Wallet  Pantry  PlanIt  Lifestyle           │
│       │        │       │       │        │               │
│       └────────┴───────┴───────┴────────┘               │
│                        │                                │
│              lib/data/services/  (WalletService,        │
│              PantryService, TaskService, …)             │
│                        │                                │
│              lib/core/services/AIParser                  │
└────────────────────────┬────────────────────────────────┘
                         │  supabase_flutter SDK
                         │  (JWT auth auto-attached)
              ┌──────────▼──────────────────────┐
              │       Supabase Project           │
              │                                 │
              │  ┌─────────┐  ┌──────────────┐  │
              │  │ Postgres │  │ Edge Functions│  │
              │  │   (DB)   │  │  (Deno/TS)   │  │
              │  └────┬─────┘  └──────┬───────┘  │
              │       │               │          │
              │  ┌────▼─────┐  ┌──────▼───────┐  │
              │  │ Realtime  │  │  /parse      │  │
              │  │(notifs)   │  │  /send-otp   │  │
              │  └──────────┘  │  /verify-otp  │  │
              │                │  /send-notif  │  │
              │                └──────┬───────┘  │
              └───────────────────────┼──────────┘
                                      │
              ┌───────────────────────┼──────────┐
              │   External Services   │          │
              │                       │          │
              │  Google Gemini AI ◄───┘          │
              │  (gemini-2.5-flash / 2.0-flash)  │
              │                                  │
              │  MSG91 OTP  (phone auth SMS)      │
              │                                  │
              │  Firebase FCM  (push notifs)      │
              └──────────────────────────────────┘
```

**Key architectural decisions:**

- **Gemini is never called from the Flutter client.** All AI calls go through the `/parse` Supabase edge function, which fetches the active prompt from the DB, injects context, calls Gemini, and returns normalised JSON.
- **Auth is phone-only via MSG91 OTP.** After verification, the edge function creates a Supabase user with a synthetic internal email (`phone_919876543210@waiapp.internal`) so Supabase Auth manages sessions normally without exposing the phone auth flow.
- **Two-layer parsing for all text input.** Local NLP/regex (free, <1 ms) runs first. If confidence is below threshold, it falls back to Gemini. This keeps AI costs low at scale.
- **State management is intentionally simple.** `StatefulWidget` + `setState` for most screens, `Provider` for cross-screen controllers (`TodoController`, `GroceryController`, `SpecialDaysController`, `LifestyleController`). No Riverpod or Bloc.

---

## Tech Stack

| Layer | Technology | Version |
|---|---|---|
| Mobile framework | Flutter / Dart | SDK `^3.10.3` |
| Backend | Supabase (Postgres + Edge Functions + Auth + Storage + Realtime) | `supabase_flutter ^2.0.0` |
| AI | Google Gemini 2.5 Flash (text) / 2.0 Flash (images) | REST API |
| Phone auth | MSG91 SendOTP | v5 API |
| Push notifications | Firebase Cloud Messaging | `firebase_messaging ^15.0.0` |
| Local notifications | flutter_local_notifications | `^18.0.1` |
| Speech-to-text | Device-native STT via `speech_to_text` | `^7.0.0-beta.2` |
| HTTP client | dio (auth/token flow), http (Gemini direct) | `^5.4.3` / `^1.1.0` |
| State management | Provider + StatefulWidget | `^6.0.5` |
| Edge Function runtime | Deno | `deno.land/std@0.177.0` |

**Full Flutter dependency list:** see [pubspec.yaml](pubspec.yaml).

---

## Project Structure

```
wai_life_assistant/
│
├── lib/
│   ├── main.dart                    # Entry point; sets up error handlers + runZonedGuarded
│   ├── app_bootstrap.dart           # Initialises Supabase, Firebase, notifications, network
│   │
│   ├── core/                        # App-wide infrastructure (no feature logic)
│   │   ├── auth/                    # Token refresh, auth service
│   │   ├── env/                     # AppEnvironment enum, EnvironmentConfig, env.dart
│   │   ├── error/                   # ApiException, ApiErrorMapper, UiErrorMessage
│   │   ├── navigation/              # ErrorTrackingObserver (NavigatorObserver)
│   │   ├── services/                # AIParser, FcmService, GeminiService (stub),
│   │   │                            #   NetworkService, NotificationService, ShortcutService
│   │   ├── supabase/                # SupabaseConfig (URL + anonKey)
│   │   ├── theme/                   # AppTheme (light/dark), AppColors
│   │   └── utils/                   # SafeExecutor
│   │
│   ├── data/
│   │   ├── models/                  # Shared data classes (wallet, pantry, planit, lifestyle…)
│   │   └── services/                # Supabase service singletons
│   │                                # WalletService, PantryService, TaskService,
│   │                                # ReminderService, NoteService, FunctionsService,
│   │                                # SpecialDayService, NotificationService, ProfileService,
│   │                                # InviteService, WishService, AppConfigService
│   │
│   ├── features/
│   │   ├── auth/                    # Login, OTP screen, app lock
│   │   ├── dashboard/               # Dashboard screen, AI assistant, settings sheets
│   │   ├── wallet/                  # Wallet screen + AI entry + SMS + splits + reports
│   │   │   └── README.md            # ← detailed wallet feature docs
│   │   ├── pantry/                  # Grocery list, meal plan, recipe box
│   │   ├── planit/                  # Reminders, tasks, special days, notes, bill watch
│   │   └── lifestyle/               # Garage, wardrobe, devices, documents, functions
│   │
│   ├── routes/                      # AppRoutes (named route map)
│   └── shared/
│       ├── widgets/                 # ErrorBoundary, WalletSwitcherPill, EmojiOrImage…
│       └── utils/                   # (shared utilities)
│
├── supabase/
│   ├── functions/
│   │   ├── import_map.json          # Deno import map
│   │   ├── parse/index.ts           # AI text + image parsing (calls Gemini)
│   │   ├── send-otp/index.ts        # Sends OTP via MSG91
│   │   ├── verify-otp/index.ts      # Verifies OTP + creates/signs-in Supabase user
│   │   └── send-notification/index.ts  # Sends FCM push to family members
│   │
│   └── migrations/                  # 41 sequential SQL files (001 → 041)
│
├── android/                         # Android-specific config
├── ios/                             # iOS-specific config
├── docs/                            # Extended feature documentation
│   ├── feature_planit.md
│   ├── ai_integration.md
│   ├── third_party_integrations.md
│   └── error_tracking.md
│
└── pubspec.yaml
```

---

## Getting Started

### Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | ≥ 3.10.3 | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started/install) |
| Dart SDK | bundled with Flutter | — |
| Supabase CLI | latest | `npm install -g supabase` |
| Node.js | ≥ 18 (for Supabase CLI) | [nodejs.org](https://nodejs.org) |
| Android Studio / Xcode | latest stable | For device emulators |
| Git | any | — |

Verify your setup:
```bash
flutter doctor
supabase --version
```

### Environment Setup

**1. Clone the repo**
```bash
git clone <repo-url>
cd wai_life_assistant
```

**2. Install Flutter dependencies**
```bash
flutter pub get
```

**3. Configure Supabase credentials**

The project connects to a single Supabase project. The credentials are hardcoded in `lib/core/supabase/supabase_config.dart` — no `.env` file is needed for the Flutter client.

```dart
// lib/core/supabase/supabase_config.dart  (already populated)
class SupabaseConfig {
  static const String url     = 'https://oeclczbamrnouuzooitx.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

> The `anonKey` is safe to commit — it is a public key. Row Level Security (RLS) enforces per-user data isolation in Postgres.

**4. Link Supabase CLI to the project**
```bash
supabase login
supabase link --project-ref oeclczbamrnouuzooitx
```

**5. Set edge function secrets** (see [Environment Variables](#environment-variables) for values)
```bash
supabase secrets set GEMINI_API_KEY=<your-key>
supabase secrets set MSG91_AUTH_KEY=<your-key>
supabase secrets set MSG91_TEMPLATE_ID=<your-flow-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=<strong-random-password>
supabase secrets set FCM_SERVICE_ACCOUNT='<firebase-service-account-json>'
```

**6. Set up Firebase** (for push notifications)
```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```

This generates `lib/firebase_options.dart` and places `google-services.json` in `android/app/`. Without this step, FCM is disabled but the app still runs.

### Running Dev Build

```bash
flutter run --dart-define=ENV=dev
```

Dev build shows the debug banner and enables verbose logging (`enableLogs: true` in `EnvironmentConfig`).

### Running QA Build

```bash
flutter run --dart-define=ENV=qa
# or build an APK:
flutter build apk --dart-define=ENV=qa
```

### Running Production Build

```bash
# Android
flutter build apk --dart-define=ENV=prod --release
flutter build appbundle --dart-define=ENV=prod --release

# iOS
flutter build ipa --dart-define=ENV=prod --release
```

Production builds: no debug banner, `enableLogs: false`, title shows "Life Assistant" (not "DEV" or "QA").

---

## Database Setup

### Running Migrations

All schema lives in `supabase/migrations/` as numbered SQL files. Run them in order against the Supabase project:

```bash
# Push all pending migrations
supabase db push

# Or run a specific file manually in Supabase Dashboard → SQL Editor
```

**Migration order matters.** Files are numbered `001` → `041`. Always run them sequentially — later migrations reference tables created in earlier ones.

| Range | What it sets up |
|---|---|
| `001` | Profiles, wallets, transactions (core wallet schema) |
| `002` | Extended profile fields |
| `003–005` | Pantry: grocery items, recipes, grocery notes |
| `006` | Bill Watch table |
| `007` | Split group pin |
| `008–013` | PlanIt: reminders, tasks, special days, wishes, notes |
| `014` | App config table |
| `015` | Notes: add type column |
| `016–017` | Functions/events schema, family name field |
| `018` | AI prompt: split expense |
| `019–020` | Split proof images, public storage policy |
| `021` | `returned` transaction type |
| `022–024` | Recipe library, meal status, meal ingredients |
| `025–027` | Feature usage limits (`check_feature_limit()` function) |
| `028–030` | Profile DOB/plan, custom categories, tx title column |
| `031–034` | Family member linking, permissions, soft delete |
| `035` | AI prompt: pantry basket v2 |
| `036` | Notifications table |
| `037` (×2) | Profile default scopes; SMS parse AI prompt |
| `038–039` | Split extension response, meal recipe IDs |
| `040` | Error logs table + indexes |
| `041` | Functions MOI entries |
| `ai_prompts.sql` | Seeds all 21+ base AI prompts (wallet, pantry, planit, mylife, dashboard) |
| `functions_ai_prompts.sql` | Seeds 7 Functions feature AI prompts |

### Seeding Test Data

There is no automated seed script. For local testing:

1. **Create a wallet via the app** — login with a real Indian phone number, MSG91 sends an OTP, the app creates a profile and wallet automatically.

2. **Seed AI prompts** — the prompt tables are seeded by migration files. If you reset the DB, re-run `ai_prompts.sql` and `functions_ai_prompts.sql`:
```bash
# In Supabase Dashboard → SQL Editor, paste and run:
-- supabase/migrations/ai_prompts.sql
-- supabase/migrations/functions_ai_prompts.sql
```

3. **Add test transactions** — use the Wallet Spark sheet or paste this sample bank SMS:
```
Dear Customer, INR 500.00 debited from A/c XX1234 on 17-04-26. Info: SWIGGY. Avl Bal: INR 24500.00
```

---

## Deploying Edge Functions

Four edge functions live in `supabase/functions/`. Deploy all at once or individually:

```bash
# Deploy all
supabase functions deploy

# Deploy individually
supabase functions deploy parse
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy send-notification
```

**Function summary:**

| Function | Trigger | External call |
|---|---|---|
| `parse` | `AIParser.parseText()` / `parseImage()` from Flutter | Google Gemini REST API |
| `send-otp` | Login screen — user enters phone number | MSG91 `/api/v5/otp` |
| `verify-otp` | Login screen — user enters OTP | MSG91 `/api/v5/otp/verify` + Supabase Admin Auth |
| `send-notification` | Called by Flutter after family events | Firebase FCM v1 HTTP API |

After deploying, verify with a quick smoke test:
```bash
curl -X POST https://oeclczbamrnouuzooitx.supabase.co/functions/v1/parse \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"feature":"wallet","sub_feature":"expense","input_type":"text","text":"250 biryani"}'
# Expected: { "success": true, "data": { "amount": 250, "category": "Food", ... } }
```

---

## Environment Variables

### Flutter (`EnvironmentConfig`)

Set at **build time** via `--dart-define=ENV=<value>`. No `.env` file required.

```bash
flutter run --dart-define=ENV=dev    # default
flutter run --dart-define=ENV=qa
flutter run --dart-define=ENV=uat
flutter run --dart-define=ENV=prod
```

What changes per environment (`lib/core/env/environment_config.dart`):

| ENV | App name | Logs | Debug banner |
|---|---|---|---|
| `dev` | Life Assistant DEV | on | yes |
| `qa` | Life Assistant QA | on | yes |
| `uat` | Life Assistant UAT | on | yes |
| `prod` | Life Assistant | off | no |

> `baseUrl` in `EnvironmentConfig` currently uses placeholder domains (`yourdomain.com`). Update these when a REST API layer is added. The Supabase connection uses `SupabaseConfig` directly and is not affected by `baseUrl`.

### Supabase Secrets

Set once via `supabase secrets set`. Available inside edge functions as `Deno.env.get("KEY")`.

| Secret | Used by | Where to get it |
|---|---|---|
| `GEMINI_API_KEY` | `parse` function | [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey) |
| `MSG91_AUTH_KEY` | `send-otp`, `verify-otp` | MSG91 Dashboard → API → Auth Key |
| `MSG91_TEMPLATE_ID` | `send-otp` | MSG91 Dashboard → SMS → OTP → Flow ID |
| `WAI_INTERNAL_AUTH_PASS` | `verify-otp` | Generate any strong random string (never shown to users) |
| `FCM_SERVICE_ACCOUNT` | `send-notification` | Firebase Console → Project Settings → Service Accounts → Generate key (paste full JSON) |
| `SUPABASE_URL` | all functions | **Auto-injected** by Supabase — do not set manually |
| `SUPABASE_SERVICE_ROLE_KEY` | all functions | **Auto-injected** by Supabase — do not set manually |

Check current secrets:
```bash
supabase secrets list
```

---

## Third-Party Setup

### Gemini AI

1. Go to [aistudio.google.com/app/apikey](https://aistudio.google.com/app/apikey)
2. Create an API key (free tier: 15 RPM / 1M tokens/day on 2.5 Flash)
3. Set the secret and redeploy:
```bash
supabase secrets set GEMINI_API_KEY=AIzaSy...
supabase functions deploy parse
```
4. Smoke-test with the curl command above.

Models used: `gemini-2.5-flash` for all text prompts, `gemini-2.0-flash` for image parsing (`pantry/bill_scan` only).

> `lib/core/services/gemini_service.dart` contains a `_apiKey = 'YOUR_GEMINI_API_KEY'` placeholder. This class is a legacy stub — the production AI path is always through the edge function. Do not use `GeminiService` for new features.

### Firebase / FCM

1. Create a project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add Android app — package name: `com.yourcompany.wai_life_assistant`
3. Download `google-services.json` → place in `android/app/`
4. Add iOS app → download `GoogleService-Info.plist` → place in `ios/Runner/`
5. Run FlutterFire to generate `lib/firebase_options.dart`:
```bash
flutter pub global activate flutterfire_cli
flutterfire configure
```
6. Generate a service account key:
   - Firebase Console → Project Settings → Service Accounts → **Generate new private key**
   - Download the JSON file
7. Store in Supabase and redeploy:
```bash
supabase secrets set FCM_SERVICE_ACCOUNT="$(cat firebase-service-account.json)"
supabase functions deploy send-notification
```

> If `firebase_options.dart` contains placeholder values, `app_bootstrap.dart` catches the Firebase init error and disables FCM. The app still starts — push notifications simply don't work until this is configured.

### MSG91

MSG91 is required for phone login. Indian SMS delivery requires DLT registration (TRAI regulation) — budget 3–5 business days for approval.

1. Create account at [msg91.com](https://msg91.com)
2. Complete DLT registration:
   - Register sender ID (e.g. `WAIAPP`)
   - Submit OTP template: `Your WAI OTP is ##OTP##. Valid for 30 minutes. -WAIAPP`
   - Wait for DLT approval
3. In MSG91 Dashboard → SMS → OTP → Create Flow → select your DLT template → copy **Flow ID**
4. Copy your **Auth Key** from MSG91 → API
5. Set secrets and redeploy:
```bash
supabase secrets set MSG91_AUTH_KEY=<auth-key>
supabase secrets set MSG91_TEMPLATE_ID=<flow-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=$(openssl rand -base64 32)
supabase functions deploy send-otp
supabase functions deploy verify-otp
```

---

## Testing

### Running Unit Tests

There are currently no automated test files (`test/` directory does not exist). The testing infrastructure (`flutter_test`, `flutter_lints`) is declared in `pubspec.yaml` but no tests have been written yet.

To bootstrap tests:
```bash
mkdir test
flutter test
```

Recommended first tests (all pure Dart, no mocks needed):

| Class | File | Why high value |
|---|---|---|
| `NlpParser.parse()` | `lib/features/wallet/AI/nlp_parser.dart` | Covers all 6 transaction type detections + amount parsing |
| `SMSRegexParser.tryParse()` | `lib/features/wallet/services/sms_regex_parser.dart` | 10 bank patterns + 3 date formats |
| `CategoryDetector.detect()` | `lib/features/wallet/category_detector.dart` | Income/expense keyword branches |
| `IntentClassifier.classify()` | `lib/features/dashboard/ai_assistant/intent_classifier.dart` | Dashboard AI routing |

### Running Lint

```bash
flutter analyze
```

The project uses `flutter_lints ^6.0.0`. Rules are in `analysis_options.yaml`.

### Manual Testing Checklist

Before merging any Wallet change:
- [ ] Add expense via typed text (NLP path, no AI call)
- [ ] Add expense via voice (speech path)
- [ ] Paste a bank SMS and confirm the pre-fill
- [ ] Add income, lend, and borrow transactions
- [ ] Switch wallets using the family switcher
- [ ] Open reports sheet — verify totals match the transaction list
- [ ] Drag a transaction into a group

---

## Code Conventions

### Folder structure

Code is organised **feature-first**, not layer-first. Everything for a feature lives under `lib/features/<feature>/`. Shared infrastructure lives in `lib/core/`. Data models and service singletons used by multiple features live in `lib/data/`.

### Imports

Use package imports for cross-feature references, relative imports within a feature:
```dart
// Cross-feature (package import)
import 'package:wai_life_assistant/data/services/wallet_service.dart';

// Intra-feature (relative import)
import 'flow_steps.dart';
import '../widgets/tx_tile.dart';
```

### Service calls

All Supabase calls go through service singletons. Never call `Supabase.instance.client` directly from a widget:
```dart
// Good
final txs = await WalletService.instance.fetchTransactions(walletId);

// Not this
final txs = await Supabase.instance.client.from('transactions').select()...
```

### Error handling

Wrap all service calls in `SafeExecutor.run()`:
```dart
final result = await SafeExecutor.run(
  () => WalletService.instance.addTransaction(walletId, tx),
  feature: 'wallet',
  action:  'add_expense',
  extra:   {'amount': tx.amount},
);
```

Use `ErrorBoundary` around widget subtrees that load async data. Full guidance in [docs/error_tracking.md](docs/error_tracking.md).

### AI parsing

Always run local NLP first; fall back to Gemini only when confidence is low:
```dart
final intent = NlpParser.parse(text);
if (intent.confidence >= 0.75) {
  // use intent directly — free, instant
} else {
  final result = await AIParser.parseText(feature: 'wallet', subFeature: 'expense', text: text);
}
```

### Naming

| Thing | Convention | Example |
|---|---|---|
| Classes | `PascalCase` | `WalletScreen`, `TxModel` |
| Files | `snake_case` | `wallet_screen.dart`, `tx_tile.dart` |
| Private fields | `_camelCase` | `_transactions`, `_isLoading` |
| Service singletons | `ClassName.instance` | `WalletService.instance` |
| Private constants | `_kPascalCase` | `_kScanCooldownMs` |

### Comments

Write comments for *why*, not *what*. Never restate what the code already says:
```dart
// Good — explains a non-obvious constraint
// 5-minute cooldown prevents hammering the SMS inbox on every hot-restart.
static const _kScanCooldownMs = 5 * 60 * 1000;
```

---

## Contributing

1. **Branch** off `main`:
   ```bash
   git checkout -b feature/<short-description>
   ```

2. **Keep changes focused.** One PR per feature or fix. Do not mix schema changes, UI changes, and prompt updates in the same PR.

3. **Migrations are append-only.** Never edit an existing migration file — always create a new numbered file. Editing a migration that has already run breaks `supabase db push`.
   ```bash
   touch supabase/migrations/042_your_change.sql
   ```

4. **Update AI prompts by version bump**, not by editing the seeded migration:
   ```sql
   INSERT INTO ai_prompts (feature, sub_feature, input_type, version, prompt)
   VALUES ('wallet', 'expense', 'text', 2, $$ ... $$);
   -- The edge function automatically uses the highest active version.
   ```

5. **Deploy edge functions** after any change to `supabase/functions/`:
   ```bash
   supabase functions deploy <function-name>
   ```

6. **Test on a real Android device** before merging wallet or SMS changes. SMS features are Android-only. The emulator's SMS inbox is empty.

7. **PR checklist:**
   - [ ] `flutter analyze` passes with no new warnings
   - [ ] New DB columns have a migration file
   - [ ] New AI features have a prompt seeded in `ai_prompts`
   - [ ] New service calls wrapped in `SafeExecutor`
   - [ ] No direct `Supabase.instance.client` calls in widget files

---

## Known Issues

**SMS auto-scan is disabled.**
`READ_SMS` permission is commented out in `AndroidManifest.xml` and the initialization is commented out in `app_bootstrap.dart`, pending Google Play SMS policy approval. Manual paste in SparkBottomSheet works. To re-enable: uncomment the `<uses-permission>` line in the manifest and the two `SMSParserService` lines in `app_bootstrap.dart`.

**`SplitSparkBottomSheet` is a stub.**
`lib/features/wallet/AI/SplitSparkBottomSheet.dart` has all logic commented out. Split creation goes through `SplitGroupSheet` directly. Do not wire up `SplitSparkBottomSheet` until it is implemented.

**`handleAiIntent.dart` is a stub.**
`lib/features/wallet/AI/handleAiIntent.dart` has empty case branches. The intent dispatch system was superseded by `IntentConfirmSheet`. This file can be safely deleted once the import is cleaned up.

**`GeminiService` has a placeholder API key.**
`lib/core/services/gemini_service.dart` contains `_apiKey = 'YOUR_GEMINI_API_KEY'`. This class is not used in any production flow. The real Gemini path is the `/parse` edge function.

**`EnvironmentConfig.baseUrl` uses placeholder domains.**
The `baseUrl` values (`yourdomain.com`) are placeholders for a future REST API layer. They are consumed only by `AuthService.refreshAccessToken()`, which is not in the active auth flow.

**No automated tests.**
The `test/` directory does not exist. Regression testing is entirely manual. See [Testing](#testing) for recommended first tests.

**Notification channel settings are immutable after first install.**
Android channels (`wai_alarms`, `wai_family_channel`, `wai_sms_channel`) have sound and importance locked after creation. To change them during development, uninstall the app from the device before re-running.

**Firebase silently disabled if `firebase_options.dart` is a placeholder.**
Running without `flutterfire configure` means FCM is disabled at runtime (caught silently in `app_bootstrap.dart`). Push notifications do not work until `flutterfire configure` is run and the resulting files are committed.

---

## Documentation

| Document | Contents |
|---|---|
| [docs/ai_integration.md](docs/ai_integration.md) | All 28 AI prompts, edge function architecture, context injection, cost analysis |
| [docs/feature_planit.md](docs/feature_planit.md) | PlanIt tab: reminders, tasks, special days, notes, Functions/MOI system |
| [docs/third_party_integrations.md](docs/third_party_integrations.md) | Supabase, Gemini, FCM, MSG91, speech-to-text, SMS parsing — setup and reference |
| [docs/error_tracking.md](docs/error_tracking.md) | ErrorLogger, SafeExecutor, ErrorBoundary, SQL triage queries, weekly metrics |
| [lib/features/wallet/README.md](lib/features/wallet/README.md) | Wallet feature deep-dive: data flow, file guide, adding a transaction type, common issues |

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.


## To find emulators
flutter emulators
flutter emulators --launch <emulator_id>

## From Terminal to run the app
flutter run
D:\Personal\ToDo\Projects\Repos\wai_life_assistant\lib> flutter run

For Environment change
Dev --> flutter run -t lib/main_dev.dart
Prod --> flutter run -t lib/main_prod.dart

Release build:
flutter build apk -t lib/main_prod.dart
flutter build appbundle -t lib/main_prod.dart

## API Usage Example
final apiUrl = '${envConfig.baseUrl}/auth/login';

## Logging
Button Click
onTap: () {
  AppLogger.d("Health feature tapped");
}

API Logging Example
try {
  AppLogger.i("Calling login API");
  // API call
} catch (e, s) {
  AppLogger.e(
    "Login failed",
    error: e,
    stackTrace: s,
  );
}


Network Logging (Optional but Powerful)
If using Dio, add interceptor:
dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      AppLogger.d("REQUEST → ${options.method} ${options.path}");
      handler.next(options);
    },
    onResponse: (response, handler) {
      AppLogger.i("RESPONSE → ${response.statusCode}");
      handler.next(response);
    },
    onError: (e, handler) {
      AppLogger.e(
        "API ERROR",
        error: e,
        stackTrace: e.stackTrace,
      );
      handler.next(e);
    },
  ),
);


## Dio
Example: Calling API from UI
final authRepo = AuthRepository();

onPressed: () async {
  try {
    await authRepo.login(email, password);
  } catch (e) {
    // show snackbar / dialog
  }
};
