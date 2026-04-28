# Error Tracking

> Supersedes `docs/error_tracking.md` (flat file).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         ERROR SOURCES                           │
│                                                                 │
│  Source 1              Source 2             Source 3            │
│  FlutterError.onError  runZonedGuarded      ErrorBoundary       │
│  (widget build,        (uncaught async,     (widget subtree     │
│   rendering errors)     isolate errors)      catch block)       │
│                          Source 4                               │
│                          SafeExecutor.run()                     │
│                          (explicit DB/API calls)                │
└──────────────────────────────┬──────────────────────────────────┘
                               │  all four sources call
                               ▼
                    ┌──────────────────────┐
                    │    ErrorLogger.log() │
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
                    │  table, status:'new')│
                    └──────────────────────┘
```

`ErrorTrackingObserver` is a `NavigatorObserver` that keeps `ErrorLogger._screen` and `_feature` current via `ErrorLogger.setScreen()` on every route push/pop/replace. It's not an error source itself, but ensures every error has the right context.

---

## Error Capture Sources

### Source 1: Flutter Framework Errors

```dart
// lib/main.dart
FlutterError.onError = (FlutterErrorDetails details) {
  ErrorLogger.log(
    details.exception,
    stackTrace: details.stack,
    severity:   details.silent ? ErrorSeverity.warning : ErrorSeverity.error,
    action:     'flutter_framework_error',
    extra: { 'library': details.library, 'silent': details.silent },
  );
  if (kDebugMode) FlutterError.presentError(details);
};
```

Catches: widget build exceptions, layout/rendering errors, `setState()` after `dispose()`.

### Source 2: Unhandled Async Errors

```dart
// lib/main.dart
runZonedGuarded(
  () async { WidgetsFlutterBinding.ensureInitialized(); await bootstrapApp(env); },
  (error, stackTrace) {
    ErrorLogger.log(error, stackTrace: stackTrace,
      severity: ErrorSeverity.critical,  // uncaught = always critical
      action:   'unhandled_async_error');
  },
);
```

These are always `critical` — uncaught errors mean the app state may be corrupted.

### Source 3: Widget Subtree Errors (ErrorBoundary)

```dart
// lib/shared/widgets/error_boundary.dart
void markErrored(dynamic error, {StackTrace? stackTrace}) {
  ErrorLogger.log(error, stackTrace: stackTrace,
    severity: ErrorSeverity.error,
    action:   'boundary_catch',
    extra:    {'feature': widget.feature},
  );
  if (mounted) setState(() { _hasError = true; });
}
```

Usage from a catch block:
```dart
try {
  await loadHeavyData();
} catch (e, st) {
  ErrorBoundary.of(context)?.markErrored(e, stackTrace: st);
}
```

### Source 4: SafeExecutor / Direct Logging

```dart
// Pattern 1: Save with silent fallback (most common)
final saved = await SafeExecutor.run(
  () => WalletService.instance.addTransaction(walletId, tx),
  feature: 'wallet', action: 'add_expense',
  extra:   {'amount': tx.amount, 'category': tx.category},
);
if (saved == null) showSnackBar('Failed to save expense.');

// Pattern 2: Load with empty fallback
final tasks = await SafeExecutor.run(
  () => TaskService.instance.fetchTasks(walletId),
  feature: 'planit', action: 'fetch_tasks',
  fallback: <Map<String, dynamic>>[],
) ?? [];

// Pattern 3: Rethrow after logging
try {
  final result = await SafeExecutor.run(
    () => AIParser.parseText(feature: 'wallet', subFeature: 'expense', text: input),
    feature: 'wallet', action: 'ai_parse_expense',
    throwOnError: true,
  );
  _applyResult(result!);
} catch (e) {
  setState(() => _errorMsg = 'Could not parse. Try typing manually.');
}
```

`SafeExecutor` exception → severity mapping:

| Exception | Severity | Rationale |
|---|---|---|
| `PostgrestException` | `error` | DB failure — user impacted |
| `FunctionException` | `error` | Edge function broken |
| `SocketException` | `warning` | Network unavailable — will retry |
| `TimeoutException` | `warning` | Slow network — transient |
| All others | `error` | Unknown — treat as impactful |

---

## Severity Levels

```dart
enum ErrorSeverity { critical, error, warning, info }
```

| Severity | When to use |
|---|---|
| `critical` | App cannot continue. User data may be lost. | 
| `error` | Feature broken for this user. They cannot complete their task. |
| `warning` | Feature degraded but user can continue. No data lost. |
| `info` | Diagnostic information only. Not an error. |

**Decision guide:**
```
Is data lost or is the app broken?
  ├── Yes, and no code caught it   →  critical
  ├── Yes, but a catch block handled it  →  error
  └── No, degraded gracefully      →  warning

Is this network/timeout (self-resolves)?
  └── Yes  →  warning (not error — don't pollute dashboards with connectivity noise)
```

---

## ErrorBoundary Placement Guidelines

| Where | Reason |
|---|---|
| Around each dashboard card | Isolates AI widget, wallet summary, pantry summary |
| Around tab content in multi-tab screens | Crash in Tab 2 doesn't blank Tab 1 |
| Around heavy FutureBuilder widgets | Network failures show fallback instead of blank |
| **Not** around every small widget | Excessive nesting adds noise to error logs |

---

## Database Schema

```sql
CREATE TABLE error_logs (
  id            UUID  PRIMARY KEY DEFAULT gen_random_uuid(),
  error_type    TEXT  NOT NULL,
  error_message TEXT  NOT NULL,
  stack_trace   TEXT,
  screen_name   TEXT,
  feature       TEXT,
  action        TEXT,
  severity      TEXT  DEFAULT 'error',
  user_id       UUID  REFERENCES auth.users(id) ON DELETE SET NULL,
  family_id     UUID,
  app_scope     TEXT,
  device_os     TEXT,
  os_version    TEXT,
  device_model  TEXT,
  app_version   TEXT,
  build_number  TEXT,
  extra_data    JSONB,
  status        TEXT  DEFAULT 'new',    -- new|reviewed|fixed|ignored
  was_online    BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);
```

**RLS:** INSERT only — `user_id IS NULL OR user_id = auth.uid()`. No client SELECT.

**Status lifecycle:** `new` → `reviewed` → `fixed` (or `ignored`)

---

## Reviewing Errors

1. Open Supabase Dashboard → project `oeclczbamrnouuzooitx` → Table Editor → `error_logs`
2. Filter: `status = new`, `severity = critical OR error`, sort `created_at DESC`

**Key columns to read:**
- `error_type` — e.g. `PostgrestException`, `SocketException`
- `stack_trace` — look for your own file names (e.g. `wallet_screen.dart:142`)
- `action` — what the user was trying to do
- `extra_data` — structured context (`amount`, `category`, `db_code`)
- `was_online` — `false` = likely self-resolving network error
- `app_version` + `build_number` — confirms if the bug is already fixed

---

## SQL Triage Queries

### Daily triage queue

```sql
SELECT id, severity, feature, action, error_type,
  LEFT(error_message, 120) AS message, screen_name, app_version, was_online, created_at
FROM error_logs
WHERE status = 'new' AND severity IN ('critical', 'error')
ORDER BY CASE severity WHEN 'critical' THEN 0 ELSE 1 END, created_at DESC
LIMIT 50;
```

### Error volume by feature (last 7 days)

```sql
SELECT feature, severity, COUNT(*) AS total, COUNT(DISTINCT user_id) AS affected_users
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '7 days' AND severity IN ('critical', 'error')
GROUP BY feature, severity
ORDER BY total DESC;
```

### Top recurring errors

```sql
SELECT error_type, LEFT(error_message, 200) AS message_prefix, feature, action,
  COUNT(*) AS occurrences, COUNT(DISTINCT user_id) AS affected_users,
  MIN(created_at) AS first_seen, MAX(created_at) AS last_seen
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '30 days' AND severity IN ('critical', 'error')
GROUP BY error_type, LEFT(error_message, 200), feature, action
ORDER BY occurrences DESC LIMIT 20;
```

### Errors for a specific user

```sql
SELECT severity, feature, action, error_type, LEFT(error_message, 200) AS message,
  extra_data, app_version, device_model, was_online, created_at
FROM error_logs WHERE user_id = '<paste-user-uuid>'
ORDER BY created_at DESC LIMIT 30;
```

### Offline vs online error split

```sql
SELECT was_online, severity, COUNT(*) AS total
FROM error_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY was_online, severity
ORDER BY was_online DESC, total DESC;
```

High `was_online=false + warning` = expected connectivity noise.
High `was_online=false + error` = app not handling offline state correctly.

---

## Workflow: New → Fixed

### Step 1: Triage (daily, 5 min)

Run the daily triage query. Flag: any `critical` → investigate immediately; recurring `error` → add to sprint; `was_online=false` warnings → bulk-ignore.

### Step 2: Mark reviewed

```sql
UPDATE error_logs SET status = 'reviewed' WHERE id = 'uuid-of-error';

-- Bulk: ignore offline warnings older than 7 days
UPDATE error_logs SET status = 'ignored'
WHERE severity = 'warning' AND was_online = false AND created_at < NOW() - INTERVAL '7 days';
```

### Step 3: Investigate

```
1. stack_trace → find file:line
2. action → know what the user was doing
3. extra_data → structured context (amount, db_code, etc.)
4. device_model + os_version → device-specific bug?
```

Cross-reference AI errors with `ai_parse_logs`:
```sql
SELECT * FROM ai_parse_logs
WHERE user_id = '<user-uuid>' AND created_at >= '<error-time>'::timestamptz - INTERVAL '1 minute'
ORDER BY created_at DESC LIMIT 5;
```

### Step 4: Fix and mark fixed

```sql
UPDATE error_logs SET status = 'fixed'
WHERE feature = 'wallet' AND action = 'add_expense'
  AND error_type = 'PostgrestException' AND app_version = '1.1.0'
  AND status = 'reviewed';
```

### Step 5: Verify fix

```sql
SELECT COUNT(*) FROM error_logs
WHERE feature = 'wallet' AND action = 'add_expense'
  AND error_type = 'PostgrestException'
  AND app_version = '1.2.0'
  AND created_at >= NOW() - INTERVAL '24 hours';
```

---

## Weekly Metrics

Copy these queries every Monday:

```sql
-- 1. Volume by severity
SELECT severity, COUNT(*) AS total, COUNT(DISTINCT user_id) AS affected_users
FROM error_logs
WHERE created_at >= DATE_TRUNC('week', NOW()) - INTERVAL '1 week'
  AND created_at <  DATE_TRUNC('week', NOW())
GROUP BY severity;

-- 2. New vs resolved
SELECT status, COUNT(*) AS count FROM error_logs
WHERE severity IN ('critical', 'error') GROUP BY status;

-- 3. Feature breakdown
SELECT feature, COUNT(*) AS errors_this_week
FROM error_logs
WHERE severity IN ('critical', 'error') AND created_at >= NOW() - INTERVAL '7 days'
GROUP BY feature ORDER BY errors_this_week DESC;

-- 4. AI parse error rate (from ai_parse_logs)
SELECT sub_feature,
  COUNT(*) FILTER (WHERE error IS NOT NULL) AS failed_parses,
  COUNT(*) AS total_parses,
  ROUND(COUNT(*) FILTER (WHERE error IS NOT NULL)::numeric / NULLIF(COUNT(*),0) * 100, 1) AS error_rate_pct
FROM ai_parse_logs
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY sub_feature ORDER BY failed_parses DESC;
```

**Targets:**
- 0 critical open errors
- `error` count trending down week-over-week
- AI parse error rate < 5% per sub_feature
- Crash-free rate > 99.5%
