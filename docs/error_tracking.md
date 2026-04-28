# Section 6: Error Tracking Documentation

---

## Table of Contents

1. [Architecture Overview](#61-architecture-overview)
2. [Error Capture Sources](#62-error-capture-sources)
3. [Severity Levels](#63-severity-levels)
4. [ErrorLogger API](#64-errorlogger-api)
5. [SafeExecutor Usage Patterns](#65-safeexecutor-usage-patterns)
6. [ErrorBoundary for Widget Trees](#66-errorboundary-for-widget-trees)
7. [Database Schema](#67-database-schema)
8. [Reviewing Errors in Supabase Dashboard](#68-reviewing-errors-in-supabase-dashboard)
9. [SQL Queries for Error Analysis](#69-sql-queries-for-error-analysis)
10. [Workflow: From New to Fixed](#610-workflow-from-new-to-fixed)
11. [Weekly Metrics to Monitor](#611-weekly-metrics-to-monitor)

---

## 6.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         ERROR SOURCES                           │
│                                                                 │
│  Source 1              Source 2             Source 3            │
│  FlutterError.onError  runZonedGuarded      ErrorBoundary       │
│  (widget build,        (uncaught async,     (widget subtree     │
│   rendering,           isolate errors)       catch block)       │
│   layout errors)                                                │
│                          Source 4                               │
│                          SafeExecutor.run()                     │
│                          (explicit DB/API calls)                │
└──────────────────────────────┬──────────────────────────────────┘
                               │  all four sources call
                               ▼
                    ┌──────────────────────┐
                    │    ErrorLogger.log() │
                    │                      │
                    │  enriches with:      │
                    │  • screen_name       │
                    │  • feature           │
                    │  • device model/OS   │
                    │  • app version       │
                    │  • was_online        │
                    │  • user_id           │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  error_logs (Supabase│
                    │  table)              │
                    │  status: 'new'       │
                    └──────────────────────┘
```

All four capture sources ultimately call the same `ErrorLogger.log()` method. The logger enriches every error with screen, device, and user context before persisting to the `error_logs` Supabase table. If the insert itself fails (e.g. offline, auth error), `ErrorLogger` falls back to `debugPrint` — it never throws.

---

## 6.2 Error Capture Sources

### Source 1: Flutter Framework Errors (`FlutterError.onError`)

Set in `main()` before `WidgetsFlutterBinding.ensureInitialized()`. Catches:
- Widget build exceptions
- Layout and rendering errors
- `setState()` called after `dispose()`

```dart
// lib/main.dart
FlutterError.onError = (FlutterErrorDetails details) {
  ErrorLogger.log(
    details.exception,
    stackTrace: details.stack,
    severity:   details.silent ? ErrorSeverity.warning : ErrorSeverity.error,
    action:     'flutter_framework_error',
    extra: {
      'library':  details.library,
      'context':  details.context?.toString(),
      'silent':   details.silent,
      'is_debug': kDebugMode,
    },
  );
  if (kDebugMode) FlutterError.presentError(details);  // still shows red screen in debug
};
```

**Why before `ensureInitialized`:** Flutter may throw during binding setup. Setting the handler first guarantees those errors are captured.

---

### Source 2: Unhandled Async / Isolate Errors (`runZonedGuarded`)

Wraps all of `bootstrapApp()` and `runApp()`. Catches:
- Uncaught `Future` errors not handled by `try/catch`
- Dart isolate errors
- Errors in `Timer` callbacks

```dart
// lib/main.dart
runZonedGuarded(
  () async {
    WidgetsFlutterBinding.ensureInitialized();
    await bootstrapApp(env);
  },
  (error, stackTrace) {
    ErrorLogger.log(
      error,
      stackTrace: stackTrace,
      severity:   ErrorSeverity.critical,  // uncaught = always critical
      action:     'unhandled_async_error',
    );
  },
);
```

These errors are always logged as `critical` because by definition no code handled them — the app state is potentially corrupted.

---

### Source 3: Widget Subtree Errors (`ErrorBoundary`)

`ErrorBoundary` wraps a widget subtree. When a child throws during a catch block, the boundary:
1. Logs via `ErrorLogger` with `action: 'boundary_catch'`
2. Replaces the subtree with a fallback UI
3. Does **not** crash the rest of the screen

```dart
// lib/shared/widgets/error_boundary.dart
void markErrored(dynamic error, {StackTrace? stackTrace}) {
  ErrorLogger.log(
    error,
    stackTrace: stackTrace,
    severity:   ErrorSeverity.error,
    action:     'boundary_catch',
    extra:      {'feature': widget.feature},
  );
  if (mounted) setState(() { _hasError = true; _lastError = error; });
}
```

Callers trigger the boundary from a catch block:
```dart
try {
  await loadHeavyData();
} catch (e, st) {
  ErrorBoundary.of(context)?.markErrored(e, stackTrace: st);
}
```

---

### Source 4: Explicit Instrumentation (`SafeExecutor` / `ErrorLogger.log`)

For operations where you want structured error data, call `SafeExecutor.run()` or `ErrorLogger.log()` directly. This gives the most control — you can attach `feature`, `action`, and arbitrary `extra` data to every error.

See [Section 6.5](#65-safeexecutor-usage-patterns) for detailed usage patterns.

---

### Source 5: Navigation Context (`ErrorTrackingObserver`)

Not an error source itself, but ensures every error carries the correct `screen_name` and `feature`. Registered as a `NavigatorObserver`:

```dart
// lib/main.dart
MaterialApp(
  navigatorObservers: [ErrorTrackingObserver()],
)
```

On every `push`, `pop`, and `replace`, it calls `ErrorLogger.setScreen()`:

```dart
// lib/core/navigation/error_tracking_observer.dart
static const _routeFeature = {
  '/':          'auth',
  '/login':     'auth',
  '/otp':       'auth',
  '/bottomNav': 'home',
  '/dashboard': 'dashboard',
  '/wallet':    'wallet',
  '/pantry':    'pantry',
  '/planit':    'planit',
  '/settings':  'settings',
  '/functions': 'functions',
};
```

Unmapped routes (modal sheets, deep sub-routes) use prefix matching — a route starting with `/wallet` is tagged `wallet` even if not explicitly listed.

---

## 6.3 Severity Levels

```dart
enum ErrorSeverity {
  critical, // app crash, data-loss risk
  error,    // feature broken, user impacted
  warning,  // degraded experience
  info,     // diagnostic context, non-breaking
}
```

| Severity | When to use | Example |
|---|---|---|
| `critical` | App cannot continue. User data may be lost. Requires immediate investigation. | Uncaught async exception (`runZonedGuarded`), bootstrap failure, corruption of wallet state |
| `error` | A feature is broken for this user. They cannot complete their task. | `PostgrestException` saving a transaction, AI parse returning invalid JSON, auth session corrupt |
| `warning` | The feature degraded but the user can continue. No data was lost. | `SocketException` (offline — scan will retry), `TimeoutException` on a non-critical load, FCM token save failed |
| `info` | Diagnostic information only. Not an error. | Feature flag check result, AI parse confidence below threshold (handled gracefully), scan cooldown triggered |

### Practical Decision Guide

```
Did the user lose data or is the app broken for them?
  ├── Yes, and no code caught it at all  →  critical  (runZonedGuarded catches these)
  ├── Yes, but a catch block handled it  →  error
  └── No, app degraded gracefully        →  warning

Is this a network/timeout that will self-resolve?
  └── Yes  →  warning  (not error — don't pollute error dashboards with connectivity noise)

Is this purely informational?
  └── Yes  →  info  (use sparingly — info logs can hide real errors if overused)
```

---

## 6.4 ErrorLogger API

### `ErrorLogger.initialize()`

Call once in `app_bootstrap.dart` after `Supabase.initialize()`. Fetches device model, OS version, and app version once and caches them for all subsequent log calls.

```dart
await ErrorLogger.initialize();
```

### `ErrorLogger.log()` — Full API

```dart
static Future<void> log(
  dynamic error, {
  StackTrace?           stackTrace,
  ErrorSeverity         severity  = ErrorSeverity.error,
  String?               action,      // what the user/system was doing
  String?               familyId,    // wallet UUID if relevant
  String?               appScope,    // 'personal' | 'family'
  Map<String, dynamic>? extra,       // any structured data
})
```

All fields written to `error_logs`:

| DB column | Source | Notes |
|---|---|---|
| `error_type` | `error.runtimeType.toString()` | e.g. `PostgrestException`, `SocketException` |
| `error_message` | `error.toString()` | Full error message |
| `stack_trace` | `stackTrace?.toString()` | Full Dart stack trace |
| `screen_name` | `ErrorLogger._screen` | Set by `ErrorTrackingObserver` |
| `feature` | `ErrorLogger._feature` | Derived from route |
| `action` | caller-provided | e.g. `'add_expense'`, `'sms_parse'` |
| `severity` | caller-provided | `critical/error/warning/info` |
| `user_id` | `Supabase.instance.client.auth.currentUser?.id` | null if not logged in |
| `family_id` | caller-provided | wallet UUID |
| `device_os` | `Platform.isAndroid` | `android` or `ios` |
| `os_version` | `DeviceInfoPlugin` | e.g. `14`, `17.4` |
| `device_model` | `DeviceInfoPlugin` | e.g. `Samsung SM-G991B` |
| `app_version` | `PackageInfo` | e.g. `1.0.0` |
| `build_number` | `PackageInfo` | e.g. `42` |
| `was_online` | `Connectivity().checkConnectivity()` | boolean |
| `extra_data` | caller-provided | JSONB — any structured context |
| `status` | hardcoded `'new'` | review lifecycle field |

### Convenience Methods

```dart
// Critical — no action required (stack trace mandatory)
await ErrorLogger.critical(error, stackTrace: st, action: 'bootstrap_supabase');

// Warning — no stack trace needed for network errors
await ErrorLogger.warning(error, action: 'fcm_token_save');

// Info — string message, extra context
await ErrorLogger.info('SMS scan cooldown active', extra: {'last_scan_ms': lastMs});
```

---

## 6.5 SafeExecutor Usage Patterns

`SafeExecutor.run<T>()` is the recommended way to wrap any `async` operation that touches the database or network. It:
- Catches 5 error types with appropriate severities
- Logs each with structured `feature` + `action` + `extra` context
- Returns `fallback` (default `null`) on error instead of throwing
- Accepts `throwOnError: true` when the caller needs to handle the exception itself

```dart
static Future<T?> run<T>(
  Future<T> Function() operation, {
  required String feature,
  required String action,
  T?     fallback     = null,
  bool   throwOnError = false,
  Map<String, dynamic>? extra,
})
```

### Error Type → Severity Mapping

| Exception type | Logged severity | Rationale |
|---|---|---|
| `PostgrestException` | `error` | DB failure — data not saved/loaded, user impacted |
| `FunctionException` | `error` | Edge function failure — AI or notification broken |
| `SocketException` | `warning` | Network unavailable — expected on mobile, will retry |
| `TimeoutException` | `warning` | Slow network — transient, not a code bug |
| All other exceptions | `error` | Unknown — treat as impactful until proven otherwise |

### Pattern 1: Save with silent fallback (most common)

```dart
// Write operation: log the error, return null, show snackbar to user
final saved = await SafeExecutor.run(
  () => WalletService.instance.addTransaction(walletId, tx),
  feature: 'wallet',
  action:  'add_expense',
  extra:   {'amount': tx.amount, 'category': tx.category},
);

if (saved == null) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Failed to save expense. Please try again.')),
  );
}
```

### Pattern 2: Load with empty fallback

```dart
// Read operation: return empty list instead of crashing the screen
final tasks = await SafeExecutor.run(
  () => TaskService.instance.fetchTasks(walletId),
  feature:  'planit',
  action:   'fetch_tasks',
  fallback: <Map<String, dynamic>>[],
) ?? [];
```

### Pattern 3: AI parse with rethrow

When the caller needs to handle the error differently (e.g. show a specific error message):

```dart
try {
  final result = await SafeExecutor.run(
    () => AIParser.parseText(feature: 'wallet', subFeature: 'expense', text: input),
    feature:      'wallet',
    action:       'ai_parse_expense',
    throwOnError: true,   // re-throws after logging
    extra:        {'input_length': input.length},
  );
  _applyResult(result!);
} catch (e) {
  setState(() => _errorMsg = 'Could not parse. Try typing it manually.');
}
```

### Pattern 4: Non-critical background operation

```dart
// Fire-and-forget logging of a non-critical event — warning severity, no rethrow
await SafeExecutor.run(
  () => FunctionsService.instance.logAttendance(functionId),
  feature: 'functions',
  action:  'log_attendance',
  // fallback null, throwOnError false — default
);
// silently continues even if this fails
```

### Pattern 5: Direct `ErrorLogger.log()` for known error paths

When you have explicit error handling logic but still want the error recorded:

```dart
try {
  await SMSParserService.scanNewMessages();
} catch (e, st) {
  await ErrorLogger.log(
    e,
    stackTrace: st,
    severity:   ErrorSeverity.warning,
    action:     'sms_scan_on_open',
    extra:      {'platform': Platform.operatingSystem},
  );
  // continue — SMS scan failure is non-critical
}
```

### When NOT to use SafeExecutor

- **Validation logic** — `SafeExecutor` is for I/O. Don't wrap form validators or pure computation.
- **Expected empty states** — a query returning 0 rows is not an error; don't wrap it in SafeExecutor.
- **Unit tests** — inject errors directly; SafeExecutor's auto-logging makes test output noisy.

---

## 6.6 ErrorBoundary for Widget Trees

`ErrorBoundary` isolates widget subtrees so a crash in one card does not blank the entire screen.

### Basic Usage

```dart
// Wraps a single card — if it throws, shows default "Something went wrong" fallback
ErrorBoundary(
  feature: 'wallet',
  child: WalletSummaryCard(walletId: walletId),
)
```

### With Custom Fallback

```dart
ErrorBoundary(
  feature:  'pantry',
  fallback: Container(
    padding:    const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        Colors.orange.withAlpha(30),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text('Meal plan temporarily unavailable.'),
  ),
  child: MealMapWidget(),
)
```

### Manual Trigger from Catch Block

```dart
class _MoiTabState extends State<MoiTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadMoiData(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Trigger the boundary instead of showing an error inline
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorBoundary.of(context)?.markErrored(
              snapshot.error,
              stackTrace: snapshot.stackTrace,
            );
          });
          return const SizedBox.shrink();
        }
        return MoiList(data: snapshot.data!);
      },
    );
  }
}
```

### Resetting After Recovery

```dart
// "Try again" button — resets the boundary, retries the child build
ErrorBoundary(
  feature:  'dashboard',
  fallback: ElevatedButton(
    onPressed: () => ErrorBoundary.of(context)?.reset(),
    child: const Text('Retry'),
  ),
  child: AIAssistantWidget(walletId: walletId),
)
```

### Default Fallback UI

When no `fallback` is provided, `_DefaultFallback` renders:
- An outlined error container using `colorScheme.errorContainer`
- "Something went wrong here. The rest of the app is fine."
- A "Try again" button that calls `reset()`

### Placement Guidelines

| Where to place | Reason |
|---|---|
| Around each dashboard card | Isolates AI widget, wallet summary, pantry summary from each other |
| Around tab content in multi-tab screens | A crash in Tab 2 doesn't blank Tab 1 |
| Around heavy FutureBuilder widgets | Network failures render fallback instead of blank |
| **Not** around every small widget | Excessive nesting adds noise to error logs; scope to meaningful sections |

---

## 6.7 Database Schema

```sql
-- supabase/migrations/040_error_logs.sql
CREATE TABLE error_logs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Error details
  error_type      TEXT NOT NULL,
  error_message   TEXT NOT NULL,
  stack_trace     TEXT,

  -- Location
  screen_name     TEXT,
  feature         TEXT,        -- wallet | pantry | planit | functions | dashboard | auth
  action          TEXT,        -- add_expense | fetch_tasks | sms_parse | ...

  -- Severity: critical | error | warning | info
  severity        TEXT DEFAULT 'error',

  -- User context
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  family_id       UUID,
  app_scope       TEXT,        -- personal | family

  -- Device context
  device_os       TEXT,        -- android | ios
  os_version      TEXT,
  device_model    TEXT,
  app_version     TEXT,
  build_number    TEXT,

  -- Additional context
  extra_data      JSONB,

  -- Review workflow
  status          TEXT DEFAULT 'new',   -- new | reviewed | fixed | ignored

  -- Network state at time of error
  was_online      BOOLEAN DEFAULT true,

  created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### Indexes

| Index | Purpose |
|---|---|
| `(severity, created_at DESC)` | Dashboard: filter by severity, newest first |
| `(status, created_at DESC)` | Dashboard: triage queue of `new` errors |
| `(user_id, created_at DESC)` | Support: see all errors for a specific user |
| `(feature, created_at DESC)` | Developer: errors in a specific feature |
| `(created_at DESC)` | General chronological queries |

### RLS Policy

```sql
-- Clients can INSERT (logged-in OR anonymous, so pre-auth errors are captured)
-- No client-facing SELECT — only service role (Supabase dashboard) reads errors
CREATE POLICY "allow_error_insert"
  ON error_logs FOR INSERT
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());
```

Pre-authentication errors (login screen failures, bootstrap errors) are captured with `user_id = NULL`. The policy allows this explicitly.

### Status Lifecycle

```
new  →  reviewed  →  fixed
 └──────────────→  ignored
```

| Status | Meaning |
|---|---|
| `new` | Just arrived, not looked at |
| `reviewed` | Seen and understood, pending fix |
| `fixed` | Root cause addressed in a code change |
| `ignored` | Expected/known noise (e.g. connectivity errors on flaky networks) |

---

## 6.8 Reviewing Errors in Supabase Dashboard

### Accessing the Table

1. Open [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select project `oeclczbamrnouuzooitx`
3. Left sidebar → **Table Editor** → `error_logs`
4. Or: **SQL Editor** (for complex queries)

### Quick Triage View

In Table Editor, set filters:
- `status` = `new`
- `severity` = `critical` or `error`
- Sort by `created_at` descending

This shows unreviewed critical/error entries, newest first — the daily triage queue.

### Reading an Error Row

| Column | What to look for |
|---|---|
| `error_type` | Identifies the exception class — `PostgrestException` (DB issue), `SocketException` (offline), `FunctionException` (edge function) |
| `error_message` | The actual error text |
| `stack_trace` | Full Dart stack — look for your own file names (e.g. `wallet_screen.dart:142`) |
| `screen_name` + `feature` | Narrows down where the user was |
| `action` | What they were trying to do |
| `extra_data` | Structured context — e.g. `{"amount": 500, "category": "Food", "db_code": "23503"}` |
| `was_online` | `false` = network error, likely self-resolving |
| `device_model` + `os_version` | Helps identify device-specific bugs |
| `app_version` + `build_number` | Confirms whether you're looking at a bug that's already fixed in a newer build |
| `user_id` | Cross-reference with `auth.users` if user reported the issue |

---

## 6.9 SQL Queries for Error Analysis

Run these in **Supabase Dashboard → SQL Editor**.

### Daily Triage: New Critical and Error Entries

```sql
SELECT
  id,
  severity,
  feature,
  action,
  error_type,
  LEFT(error_message, 120) AS message,
  screen_name,
  app_version,
  device_os,
  was_online,
  created_at
FROM error_logs
WHERE status   = 'new'
  AND severity IN ('critical', 'error')
ORDER BY
  CASE severity WHEN 'critical' THEN 0 ELSE 1 END,
  created_at DESC
LIMIT 50;
```

### Error Volume by Feature (Last 7 Days)

```sql
SELECT
  feature,
  severity,
  COUNT(*)            AS total,
  COUNT(DISTINCT user_id) AS affected_users
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
  AND severity IN ('critical', 'error')
GROUP BY feature, severity
ORDER BY total DESC;
```

### Top Recurring Error Messages (Deduplication)

```sql
SELECT
  error_type,
  LEFT(error_message, 200)    AS message_prefix,
  feature,
  action,
  COUNT(*)                    AS occurrences,
  COUNT(DISTINCT user_id)     AS affected_users,
  MIN(created_at)             AS first_seen,
  MAX(created_at)             AS last_seen
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
  AND severity IN ('critical', 'error')
GROUP BY error_type, LEFT(error_message, 200), feature, action
ORDER BY occurrences DESC
LIMIT 20;
```

### Errors for a Specific User (Support Investigation)

```sql
SELECT
  severity,
  feature,
  action,
  error_type,
  LEFT(error_message, 200) AS message,
  extra_data,
  app_version,
  device_model,
  was_online,
  created_at
FROM error_logs
WHERE user_id = '<paste-user-uuid>'
ORDER BY created_at DESC
LIMIT 30;
```

### Errors Introduced by a Specific App Version

```sql
SELECT
  feature,
  action,
  error_type,
  LEFT(error_message, 150) AS message,
  COUNT(*)                 AS count
FROM error_logs
WHERE app_version = '1.2.0'
  AND severity IN ('critical', 'error')
GROUP BY feature, action, error_type, LEFT(error_message, 150)
ORDER BY count DESC;
```

### Offline vs Online Error Split

```sql
SELECT
  was_online,
  severity,
  COUNT(*) AS total
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY was_online, severity
ORDER BY was_online DESC, total DESC;
```

High `was_online = false` + `warning` = expected network noise. High `was_online = false` + `error` = app not handling offline state correctly.

### AI Parse Errors (Feature-Specific)

```sql
SELECT
  action,
  LEFT(error_message, 200)  AS message,
  extra_data->>'function_status' AS edge_fn_status,
  COUNT(*)                  AS occurrences
FROM error_logs
WHERE feature   = 'wallet'
  AND action    LIKE '%parse%'
  AND severity  IN ('error', 'critical')
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY action, LEFT(error_message, 200), extra_data->>'function_status'
ORDER BY occurrences DESC;
```

### DB Errors with Postgres Code

```sql
SELECT
  feature,
  action,
  extra_data->>'db_code'    AS pg_error_code,
  extra_data->>'db_hint'    AS pg_hint,
  LEFT(error_message, 200)  AS message,
  COUNT(*)                  AS occurrences
FROM error_logs
WHERE error_type = 'PostgrestException'
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY feature, action, extra_data->>'db_code', extra_data->>'db_hint', LEFT(error_message, 200)
ORDER BY occurrences DESC;
```

Common Postgres error codes to know: `23503` = foreign key violation, `23505` = unique constraint, `42501` = RLS denied, `PGRST116` = `.single()` returned no row.

### Error Rate Trend (Hourly, Last 48h)

```sql
SELECT
  DATE_TRUNC('hour', created_at) AS hour,
  severity,
  COUNT(*)                       AS count
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '48 hours'
  AND severity IN ('critical', 'error')
GROUP BY DATE_TRUNC('hour', created_at), severity
ORDER BY hour DESC;
```

Spike at a particular hour = correlate with a deploy or a notification push.

---

## 6.10 Workflow: From New to Fixed

### Step 1: Triage (daily, 5 minutes)

Run the daily triage query from [Section 6.9](#69-sql-queries-for-error-analysis). Scan for:
- Any `critical` entries → investigate immediately
- Recurring `error` entries (same message, many rows) → add to sprint
- `was_online = false` warnings → bulk-ignore (see below)

### Step 2: Mark as Reviewed

```sql
-- Single error
UPDATE error_logs
SET status = 'reviewed'
WHERE id = 'uuid-of-error';

-- Bulk: all offline warnings older than 7 days
UPDATE error_logs
SET status = 'ignored'
WHERE severity = 'warning'
  AND was_online = false
  AND created_at < NOW() - INTERVAL '7 days';

-- Bulk: all errors from a specific old app version (superseded by fix)
UPDATE error_logs
SET status = 'ignored'
WHERE app_version IN ('1.0.0', '1.0.1')
  AND severity = 'error';
```

### Step 3: Investigate

From the error row, get the key fields:
1. `stack_trace` → find the file and line number in your codebase
2. `action` → know exactly what the user was doing
3. `extra_data` → structured context (amount, category, db_code, etc.)
4. `device_model` + `os_version` → check if it's device-specific
5. `user_id` → if user reported it, query their recent errors

Cross-reference with `ai_parse_logs` for AI-related errors:
```sql
SELECT * FROM ai_parse_logs
WHERE user_id    = '<user-uuid>'
  AND created_at >= '<error-created_at>'::timestamptz - INTERVAL '1 minute'
ORDER BY created_at DESC
LIMIT 5;
```

### Step 4: Fix and Mark as Fixed

After deploying the fix:
```sql
-- Mark a cluster of related errors as fixed
UPDATE error_logs
SET status = 'fixed'
WHERE feature      = 'wallet'
  AND action       = 'add_expense'
  AND error_type   = 'PostgrestException'
  AND app_version  = '1.1.0'
  AND status       = 'reviewed';
```

### Step 5: Verify Fix

After deploying the new version, run the deduplication query filtered to the new version:
```sql
SELECT COUNT(*) FROM error_logs
WHERE feature     = 'wallet'
  AND action      = 'add_expense'
  AND error_type  = 'PostgrestException'
  AND app_version = '1.2.0'  -- new version
  AND created_at >= NOW() - INTERVAL '24 hours';
```

Zero or near-zero count confirms the fix is working.

---

## 6.11 Weekly Metrics to Monitor

Review these every Monday. Copy into a spreadsheet or Supabase View for trending.

### Metric 1: Weekly Error Volume by Severity

```sql
SELECT
  severity,
  COUNT(*)                AS total,
  COUNT(DISTINCT user_id) AS affected_users
FROM error_logs
WHERE created_at >= DATE_TRUNC('week', NOW()) - INTERVAL '1 week'
  AND created_at <  DATE_TRUNC('week', NOW())
GROUP BY severity
ORDER BY CASE severity
  WHEN 'critical' THEN 0 WHEN 'error' THEN 1
  WHEN 'warning'  THEN 2 ELSE 3 END;
```

**Target:** 0 critical. `error` count trending down week-over-week. `warning` dominated by offline/timeout.

---

### Metric 2: Error Rate vs Active Users

```sql
-- Errors per user (error rate proxy)
SELECT
  COUNT(DISTINCT el.user_id)                          AS users_with_errors,
  COUNT(*) FILTER (WHERE severity IN ('critical', 'error')) AS total_errors,
  ROUND(
    COUNT(*) FILTER (WHERE severity IN ('critical', 'error'))::numeric
    / NULLIF(COUNT(DISTINCT el.user_id), 0),
    2
  ) AS errors_per_affected_user
FROM error_logs el
WHERE created_at >= NOW() - INTERVAL '7 days';
```

**Target:** errors per affected user < 3. Spikes indicate a recurring bug hitting the same users repeatedly.

---

### Metric 3: New vs Resolved

```sql
SELECT
  status,
  COUNT(*) AS count
FROM error_logs
WHERE severity IN ('critical', 'error')
GROUP BY status;
```

**Target:** `new` count should decrease or stay flat week-over-week. Growing `new` count = triage backlog building up.

---

### Metric 4: Feature Error Breakdown

```sql
SELECT
  feature,
  COUNT(*) AS errors_this_week
FROM error_logs
WHERE severity  IN ('critical', 'error')
  AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY feature
ORDER BY errors_this_week DESC;
```

**Target:** No single feature > 40% of total errors. A dominant feature signals a systemic bug.

---

### Metric 5: Crash-Free Rate (Critical errors)

```sql
SELECT
  COUNT(DISTINCT user_id)                                              AS users_with_critical,
  -- compare with your total active user count from auth.users
  (SELECT COUNT(*) FROM auth.users
   WHERE last_sign_in_at >= NOW() - INTERVAL '7 days')                AS active_users
FROM error_logs
WHERE severity   = 'critical'
  AND created_at >= NOW() - INTERVAL '7 days';
```

**Target:** crash-free rate > 99.5% (`users_with_critical / active_users < 0.005`).

---

### Metric 6: AI Parse Error Rate

```sql
SELECT
  sub_feature,
  COUNT(*) FILTER (WHERE error IS NOT NULL) AS failed_parses,
  COUNT(*)                                  AS total_parses,
  ROUND(
    COUNT(*) FILTER (WHERE error IS NOT NULL)::numeric
    / NULLIF(COUNT(*), 0) * 100,
    1
  ) AS error_rate_pct
FROM ai_parse_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY sub_feature
ORDER BY failed_parses DESC;
```

**Target:** AI parse error rate < 5% per sub_feature. Higher = prompt regression or Gemini API issue.

---

### Dashboard Snapshot Template

Copy this query weekly for a one-row summary:

```sql
SELECT
  COUNT(*) FILTER (WHERE severity = 'critical' AND status = 'new')         AS open_critical,
  COUNT(*) FILTER (WHERE severity = 'error'    AND status = 'new')         AS open_errors,
  COUNT(*) FILTER (WHERE severity = 'warning'  AND status = 'new')         AS open_warnings,
  COUNT(*) FILTER (WHERE status = 'fixed' AND created_at >= NOW() - INTERVAL '7 days') AS fixed_this_week,
  COUNT(DISTINCT user_id) FILTER (WHERE severity IN ('critical','error'))  AS affected_users
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '7 days';
```

---

*Next: Section 7 — Known Issues and TODOs*
