# Performance

---

## Overview

Key performance considerations for WAI across client rendering, database queries, AI parsing, and feature limits.

---

## Client Performance

### IndexedStack (Tab Persistence)

`AppShell` uses `IndexedStack` rather than building/destroying tabs on navigation. All 5 screens are kept alive in memory. This means:

- **Pro:** Tab switches are instant — no rebuild, no data re-fetch
- **Con:** Memory footprint is higher. All tabs are initialized on first load.

If memory is a concern, switching to `AutomaticKeepAliveClientMixin` on individual screens would allow selectively keeping only active tabs alive.

### Wallet Scope Switch

When the user switches between personal and family wallet, every active screen re-fetches its data. This is one network round-trip per visible tab. Tabs that haven't been opened yet don't fetch until first navigation.

### `mealChangeSignal` / `changeSignal` Pattern

Rather than prop-drilling callbacks, WAI uses `ValueNotifier<int>` counters that increment on any write. Screens `addListener` to these notifiers and call `setState` to trigger a re-fetch. This keeps write/read decoupled.

```dart
// Write side (anywhere in the pantry feature):
mealChangeSignal.value++;

// Read side (PantryScreen):
@override void initState() {
  super.initState();
  mealChangeSignal.addListener(_onMealChange);
}
void _onMealChange() => setState(() {});
```

---

## Database Query Performance

### Key Indexes

Most frequent query patterns and their supporting indexes:

| Query | Index | Table |
|---|---|---|
| Latest transactions for a wallet | `(wallet_id)`, `(date DESC)` | `transactions` |
| Unread notifications for a user | `(user_id, created_at DESC)` | `notifications` |
| Grocery items by category | `(wallet_id, category)` | `grocery_items` |
| Items expiring soon | `(expiry_date) WHERE expiry_date IS NOT NULL` | `grocery_items` |
| Error triage | `(severity, created_at DESC)` | `error_logs` |
| Tasks by status | `(wallet_id)`, `(status)` | `tasks` |

**Known gap:** No composite `(wallet_id, date DESC)` index on `transactions`. Two separate indexes exist. A composite would be more efficient for the common timeline query:

```sql
CREATE INDEX IF NOT EXISTS idx_transactions_wallet_date
  ON transactions(wallet_id, date DESC);
```

### N+1 Query Risk

The PlanIt hub loads all 6 module summaries in one `initState`. Each module makes an independent Supabase query. In personal view, this becomes `6 modules × (1 personal + N family wallets)` queries. For a user with 2 family wallets, that's 18 parallel queries on every PlanIt screen load.

**Mitigated by:** the `_loadedKey` check — queries only fire when the wallet set changes, not on every rebuild.

**Future improvement:** consolidate module summary queries into a single RPC function.

### Realtime Channel Cost

One Realtime channel is subscribed per active user (`notifications:${uid}`). Supabase Free tier supports 200 concurrent Realtime connections. At that scale, consider moving to polling or batching notifications.

---

## AI Parsing Performance

### Latency Breakdown

Typical parse latency from user tap to result displayed:

| Step | Typical duration |
|---|---|
| Local NLP (Layer 1) | < 1ms |
| Supabase edge function cold start | 500–3000ms (first call after idle) |
| Supabase edge function warm | 50–200ms |
| Gemini API call | 800–2500ms |
| Total (warm, with Gemini) | ~1000–2500ms |

The edge function cold start is the most noticeable latency. Consider using [Supabase Edge Function keep-alive](https://supabase.com/docs/guides/functions) in production.

### Local NLP as Latency Guard

For the Wallet feature, `NlpParser` runs synchronously before any API call. If confidence ≥ 0.75, the Gemini call is skipped entirely. Approximately 60–70% of expense entries are handled locally.

---

## Feature Limits

### Bill Scan Quota

| Tier | Limit | Enforcement |
|---|---|---|
| Free | 3 scans/month | `check_feature_limit()` RPC + `feature_usage` table |

The limit is controlled server-side in `feature_limits` — no app update needed to change it:

```sql
UPDATE feature_limits SET monthly_limit = 5 WHERE feature = 'bill_scan';
```

`check_feature_limit()` is an atomic UPSERT + check — it increments the counter and returns `TRUE/FALSE` in one query. The increment happens **before** the Gemini API call. If the call fails, the quota is still consumed (no rollback).

### Family Group Limit

```sql
-- In app_config table:
SELECT value FROM app_config WHERE key = 'max_family_groups';  -- default: '1'
```

`AppStateNotifier.maxFamilyGroups` reads this value on startup. The "Create Family" button is disabled when the user has reached the limit.

---

## Image Size Recommendations

For bill scan, the client sends the full image from `image_picker`. Gemini 2.0 Flash handles images up to 20MB. However, large images increase:
- Edge function memory usage
- Gemini input token cost
- Upload time on slow connections

**Recommendation (not yet implemented):** compress images to max 1024px on the shorter side before encoding to base64. Expected savings: 60–80% reduction in payload size with negligible quality loss for receipt text.

---

## Notification Feed Performance

The `notifications` table has a partial index on `(user_id, is_read) WHERE is_read = FALSE`. The unread badge count query uses this:

```dart
final count = await _db
    .from('notifications')
    .select('id', const FetchOptions(count: CountOption.exact, head: true))
    .eq('user_id', uid)
    .eq('is_read', false);
```

When a user has many historical notifications, `is_read = true` rows are excluded from this index entirely, keeping the query fast.

**Maintenance:** consider a periodic job to archive `notifications` older than 90 days.

---

## Related Documentation

- [Database Schema](../database.md) — index definitions per table
- [Deployment](deployment.md) — build and release optimizations
- [Error Tracking](error-tracking.md) — monitoring performance regressions
