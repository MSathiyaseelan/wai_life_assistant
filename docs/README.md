# WAI Life Assistant — Documentation Index

**WAI** is an Indian household management app built with Flutter and Supabase. This folder contains all technical documentation for the project.

---

## Quick Links

| I want to… | Go to |
|---|---|
| Understand the system | [Architecture](architecture.md) |
| Set up locally (day 1) | [Onboarding](onboarding.md) |
| Work on a feature | [Features →](#features) |
| Configure an integration | [Integrations →](#integrations) |
| Understand AI / parsing | [AI System →](#ai-system) |
| Debug errors in production | [Error Tracking](operations/error-tracking.md) |
| Deploy or release | [Deployment](operations/deployment.md) |
| Review the database schema | [Database](database.md) |

---

## Features

| Document | What it covers |
|---|---|
| [Wallet](features/wallet.md) | Transactions, NLP parser, SMS import, split tracking |
| [Pantry](features/pantry.md) | Inventory, bill scanning, grocery lists, expiry alerts |
| [PlanIt](features/planit.md) | Tasks, events, alarms, shared family to-dos |
| [Functions Tracker](features/functions.md) | MOI (மொய்) gift-obligation system |

---

## Integrations

| Document | Service |
|---|---|
| [Supabase](integrations/supabase.md) | Auth, Postgres, Realtime, Storage, Edge Functions |
| [Gemini AI](integrations/gemini.md) | Text and image parsing via Edge Function |
| [Firebase FCM](integrations/firebase.md) | Push notifications |
| [MSG91](integrations/msg91.md) | OTP-based phone authentication |

---

## AI System

| Document | What it covers |
|---|---|
| [Smart Parser Architecture](ai/smart-parser.md) | Two-layer NLP → Gemini pipeline |
| [Prompts Reference](ai/prompts-reference.md) | All 28 AI prompts, versioning, placeholders |
| [Training Data](ai/training-data.md) | Correction logging, `ai_parse_logs`, future pipeline |

---

## Operations

| Document | What it covers |
|---|---|
| [Error Tracking](operations/error-tracking.md) | Capture, triage, SQL queries, weekly metrics |
| [Performance](operations/performance.md) | Key metrics, image scan limits, Realtime considerations |
| [Deployment](operations/deployment.md) | Android release, iOS, edge functions, secrets |

---

## Other

- [Database Schema](database.md) — full table reference, RLS policies, migration history
- [Architecture](architecture.md) — system diagram, data flow, state management

---

## Existing Flat Docs (legacy)

The following files pre-date this structure and are kept for reference until their content is fully migrated:

- `docs/architecture.md` → superseded by [architecture.md](architecture.md)
- `docs/database_schema.md` → superseded by [database.md](database.md)
- `docs/feature_wallet.md` → superseded by [features/wallet.md](features/wallet.md)
- `docs/feature_pantry.md` → superseded by [features/pantry.md](features/pantry.md)
- `docs/feature_planit.md` → superseded by [features/planit.md](features/planit.md)
- `docs/ai_integration.md` → superseded by [ai/smart-parser.md](ai/smart-parser.md)
- `docs/third_party_integrations.md` → superseded by [integrations/](integrations/)
- `docs/error_tracking.md` → superseded by [operations/error-tracking.md](operations/error-tracking.md)
