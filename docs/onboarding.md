# Developer Onboarding Guide

Welcome to WAI. This guide gets you from zero to running the app locally in one session.

---

## What is WAI?

**WAI** (*We Are Indian*) is a Flutter mobile app for Indian household management. Five tabs:

| Tab | Purpose |
|---|---|
| Dashboard | AI assistant, overview cards |
| Wallet | Expenses, income, splits, lending |
| Pantry | Meal planning, grocery basket, recipe box |
| PlanIt | Tasks, reminders, special days, wish list, functions tracker |
| MyLife | Lifestyle tracking (V2 — hidden) |

Data is personal or shared via **family wallets** — household members see each other's activity in real time.

**Key Indian-specific feature:** MOI (மொய்) — the South Indian tradition of cash gifts at functions (weddings, housewarmings). WAI tracks what you received and what you owe in return. See [features/functions.md](features/functions.md).

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | `^3.10.3` | `flutter.dev/install` |
| Dart | bundled with Flutter | — |
| Android Studio or VS Code | latest | for IDE support |
| Supabase CLI | latest | `npm install -g supabase` |
| Node.js | `^18` | for Supabase CLI |

Verify your setup:
```bash
flutter doctor
supabase --version
```

---

## Step 1: Clone and Install

```bash
git clone <repo-url>
cd wai_life_assistant
flutter pub get
```

---

## Step 2: Configure Firebase

Firebase is required for push notifications. If you're only doing backend/logic work, you can skip this — the app boots gracefully without Firebase.

```bash
# If you want push notifications:
flutter pub global activate flutterfire_cli
flutterfire configure
# This downloads google-services.json and GoogleService-Info.plist
```

If you skip Firebase, the app will log "FCM disabled" at startup and continue without push.

---

## Step 3: Connect to Supabase

The Supabase URL and anonymous key are already hardcoded in `lib/core/supabase/supabase_config.dart` — **no .env file is needed** for the Flutter client.

```bash
# Link CLI to the project
supabase login
supabase link --project-ref oeclczbamrnouuzooitx

# Apply all 41 migrations + AI prompt seeds
supabase db push
```

---

## Step 4: Set Edge Function Secrets

```bash
supabase secrets set GEMINI_API_KEY=<get-from-aistudio.google.com>
supabase secrets set MSG91_AUTH_KEY=<get-from-msg91.com>
supabase secrets set MSG91_TEMPLATE_ID=<your-dlt-flow-id>
supabase secrets set WAI_INTERNAL_AUTH_PASS=<any-strong-password>
supabase secrets set FCM_SERVICE_ACCOUNT='<json-from-firebase-service-account>'
```

You can skip secrets for services you don't need:
- Skip `GEMINI_*` → AI parsing returns "Setup incomplete" messages
- Skip `MSG91_*` → phone login won't work (use `AuthCoordinator.bypassVerify()` in dev)
- Skip `FCM_SERVICE_ACCOUNT` → push notifications disabled

---

## Step 5: Deploy Edge Functions

```bash
supabase functions deploy parse
supabase functions deploy send-otp
supabase functions deploy verify-otp
supabase functions deploy send-notification
```

---

## Step 6: Run the App

```bash
# Default (dev environment)
flutter run

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

The app will start on the login screen. It requires a real Indian phone number to receive an OTP via MSG91.

### Dev bypass (no OTP needed)

`AuthCoordinator.bypassVerify()` signs in anonymously without OTP. You can call this from a debug button on the login screen to skip the SMS step during development.

> Remove this before production release.

---

## Codebase Tour

```
lib/
├── core/                    ← Services, utilities, navigation
│   ├── env/                 ← EnvironmentConfig (dev/qa/uat/prod)
│   ├── navigation/          ← ErrorTrackingObserver
│   ├── services/            ← ErrorLogger, AIParser, FCM, Network
│   ├── supabase/            ← SupabaseConfig (URL + anonKey)
│   └── utils/               ← SafeExecutor
│
├── features/
│   ├── wallet/              ← Transactions, NLP, SMS, splits
│   │   └── README.md        ← Developer guide for Wallet
│   ├── pantry/              ← Meals, grocery, recipes, bill scan
│   ├── planit/              ← Tasks, reminders, special days, functions
│   └── dashboard/           ← AI assistant, overview widgets
│
├── shared/
│   └── widgets/
│       └── error_boundary.dart   ← Widget subtree error isolation
│
├── app_bootstrap.dart       ← Service initialization sequence
└── main.dart                ← Error zones, runApp

supabase/
├── functions/               ← Edge functions (Deno/TypeScript)
│   ├── parse/               ← AI parsing via Gemini
│   ├── send-otp/            ← MSG91 OTP delivery
│   ├── verify-otp/          ← MSG91 OTP verification + session creation
│   └── send-notification/   ← FCM push notifications
└── migrations/              ← 001–041 SQL migrations + seed files
```

---

## Key Concepts to Understand First

### 1. Wallet Scoping (Personal vs Family)

Every screen receives a `walletId` prop from `AppShell`. When the user switches wallets via the pill widget, `AppStateNotifier.switchWallet()` fires, `AppStateScope` rebuilds, and every screen re-fetches with the new wallet ID.

Each tab has a saved scope preference (`AppPrefs.walletScope`, `.pantryScope`, `.planItScope`).

See [architecture.md → Personal vs Family Toggle](architecture.md).

### 2. Two-Layer AI Parsing

Every AI parse tries a local NLP parser first (free, <1ms). Only if confidence is below threshold does it call Gemini via the `parse` edge function.

See [ai/smart-parser.md](ai/smart-parser.md).

### 3. RLS is the Security Gate

The `anonKey` in `SupabaseConfig` is public — that's intentional. Security comes from Row Level Security on every Supabase table. The client never accesses data it doesn't own.

### 4. No Automated Tests

The `test/` directory does not exist. There are no widget tests, unit tests, or integration tests. Test manually in the running app.

---

## Common First-Week Tasks

### "I want to add a field to transactions"

1. Write a migration: `supabase/migrations/042_transactions_add_field.sql`
2. `supabase db push`
3. Update `WalletTransaction` model (`lib/features/wallet/models/wallet_transaction.dart`)
4. Update `WalletService` query to include the field
5. Update the relevant form sheet to show the field

See [features/wallet.md → Adding a New Transaction Type](features/wallet.md) for a step-by-step guide.

### "I want to change how an AI prompt works"

No code change needed:
1. Go to Supabase Dashboard → Table Editor → `ai_prompts`
2. Find the row with `feature='wallet'`, `sub_feature='expense'`
3. INSERT a new row with `version = current + 1`, updated `prompt_text`

See [ai/prompts-reference.md → Adding or Updating a Prompt](ai/prompts-reference.md).

### "I want to add a new notification event"

1. Add a new template to `supabase/functions/send-notification/index.ts`
2. `supabase functions deploy send-notification`
3. Call `supabase.functions.invoke('send-notification', body: {...})` from the client when the event occurs

See [integrations/firebase.md → Notification Templates](integrations/firebase.md).

### "I want to debug a production error"

1. Go to Supabase Dashboard → SQL Editor → project `oeclczbamrnouuzooitx`
2. Run the daily triage query in [operations/error-tracking.md](operations/error-tracking.md)

---

## Environment Secrets Summary

| Secret | Required for | Where to get |
|---|---|---|
| `GEMINI_API_KEY` | AI parsing | aistudio.google.com |
| `MSG91_AUTH_KEY` | Phone OTP | msg91.com dashboard |
| `MSG91_TEMPLATE_ID` | Phone OTP | msg91.com → SMS → OTP Flow |
| `WAI_INTERNAL_AUTH_PASS` | User auth | generate any strong password |
| `FCM_SERVICE_ACCOUNT` | Push notifications | Firebase Console → Service Accounts |

---

## Documentation Index

- [Architecture](architecture.md) — system diagram, state management, auth flow
- [Database Schema](database.md) — all 41 tables, RLS, migrations
- [Wallet Feature](features/wallet.md) — transactions, NLP, SMS
- [Pantry Feature](features/pantry.md) — meals, basket, bill scan
- [PlanIt Feature](features/planit.md) — tasks, reminders, wish list
- [Functions Tracker](features/functions.md) — MOI system
- [Supabase](integrations/supabase.md) — backend platform setup
- [Gemini AI](integrations/gemini.md) — AI API details
- [Firebase FCM](integrations/firebase.md) — push notifications
- [MSG91](integrations/msg91.md) — phone OTP
- [Smart Parser](ai/smart-parser.md) — two-layer NLP architecture
- [Prompts Reference](ai/prompts-reference.md) — all 28 AI prompts
- [Error Tracking](operations/error-tracking.md) — debugging production issues
- [Deployment](operations/deployment.md) — releasing to stores
