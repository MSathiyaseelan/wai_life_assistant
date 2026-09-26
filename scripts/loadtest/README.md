# WAI Load Testing

Load tests the Supabase **database/PostgREST capacity** (wallet, pantry, functions reads
+ a transaction write path) using [Artillery](https://www.artillery.io/), plus a
separately-capped test for the `parse` edge function (calls paid Gemini API).

**⚠️ Never run this against prod.** Target QA (or a throwaway project) only.

## 1. One-time setup

```bash
cd scripts/loadtest
npm install
```

## 2. Provision test users

Creates disposable auth users directly via the Admin API (no OTP/SMS involved — zero
cost, no real messages sent) plus a personal wallet each, and saves their session
tokens to `test_users.json` (gitignored).

```bash
SUPABASE_URL=https://<qa-project-ref>.supabase.co \
SUPABASE_ANON_KEY=<qa-anon-key> \
SUPABASE_SERVICE_ROLE_KEY=<qa-service-role-key> \
TEST_USER_COUNT=50 \
npm run provision
```

Get the service-role key from Supabase Dashboard → Project Settings → API (or the new
"API Keys" → Legacy keys page — same place we used it for the `WAI_INTERNAL_AUTH_PASS`
fix earlier). **Treat it the same way: never commit it, never log it.**

`TEST_USER_COUNT` should be ≥ your test's peak concurrent virtual users (`arrivalRate`
in the config) — each request picks a random provisioned user, so too few users means
they'll collide on the same rows more than real distinct users would.

**Token lifetime:** the access tokens are normal Supabase sessions and expire (default
~1 hour). Provision right before running the test, and keep total test duration under
that window — a run spanning the expiry will start seeing 401s partway through.

## 3. Run the main DB/API capacity test

```bash
SUPABASE_URL=https://<qa-project-ref>.supabase.co \
SUPABASE_ANON_KEY=<qa-anon-key> \
npm run test:api
```

Default profile in `artillery-config.yml`: warms up to 10 req/s over 30s, ramps to 50
req/s over 60s, holds 50 req/s for 2 minutes, cools down. Edit the `phases:` block to
change the target concurrency — `arrivalRate` is virtual users/sec, roughly analogous
to concurrent active app users.

Scenarios (weighted): dashboard load (wallet + transactions, 45%), pantry grocery list
(20%), attended functions list (10%), and a transaction write (25%). All write-path
data is tagged `note: "artillery load test"` for easy identification, and is deleted
automatically by the cleanup step below regardless (cascades from the test user).

The run fails loudly (`ensure` thresholds) if p99 latency exceeds 2s or the error rate
exceeds 1% — that's your answer to "can Supabase handle this load."

## 4. Run the capped edge-function test (optional)

```bash
SUPABASE_URL=https://<qa-project-ref>.supabase.co \
SUPABASE_ANON_KEY=<qa-anon-key> \
npm run test:parse
```

Fires exactly **10** calls to `parse` (Gemini), regardless of the main test's
concurrency — see `parse-loadtest.yml` if you want to raise/lower that fixed count.
`send-otp`/`verify-otp` are intentionally excluded (they send real SMS via MSG91 with
no safe test number) — tell me if you have a dedicated test phone number and want
those added.

## 5. Run the Realtime connection test

Concurrent Realtime connections are usually the first ceiling (Supabase caps them per
plan), so this is the closest thing to a "how many users can be online at once" answer.

```bash
SUPABASE_URL=https://<qa-project-ref>.supabase.co \
SUPABASE_ANON_KEY=<qa-anon-key> \
CONNECTIONS=200 HOLD_SECONDS=300 \
npm run test:realtime
```

Each connection opens the same channels as the app's `RealtimeSyncService.subscribeAll()`
(a `meal_entries` channel per wallet). While connections are held, `PROBE_USERS` users
(default 20) insert a `meal_entries` row every `PROBE_INTERVAL_MS` (default 2000),
and the script measures how long it takes each of that user's connections to receive it.

It prints a status line every 10s, then a per-table channel status table and PASS/FAIL.
It fails when a connection never subscribes, probe delivery is below 99%, delivery
p99 is above 2s, or any channel errors or times out.

- `CONNECTIONS` can be higher than `TEST_USER_COUNT`; users are reused round-robin.
- `RAMP_PER_SEC` (default 20) sets how many connections open per second.
- Step `CONNECTIONS` up across runs (100 → 200 → 500 → …) to find the point where
  connections start being refused. That's your plan's concurrent-user limit.
- One Node process handles a couple of thousand sockets. Past that, run several
  processes in parallel.
- Provision right before running, and keep the run under the ~1h token lifetime.

## 6. Clean up

**Always run this after testing** — deletes every provisioned test user, which
cascades (via FK `ON DELETE CASCADE`) to remove their wallets and all transactions
created during the test. Nothing else in QA is touched.

```bash
SUPABASE_URL=https://<qa-project-ref>.supabase.co \
SUPABASE_SERVICE_ROLE_KEY=<qa-service-role-key> \
npm run cleanup
```

## Reading results

Artillery prints a summary at the end (`http.codes.*`, `http.response_time.*`,
`vusers.failed`). For a saved report:

```bash
npx artillery run artillery-config.yml --output report.json
npx artillery report report.json   # generates an HTML report
```

## What this does and doesn't cover

- **Covers:** Postgres/PostgREST throughput and latency under concurrent load, RLS
  policy overhead at scale, connection pool behavior.
- **Covers (realtime_soak.mjs):** concurrent Realtime connections, channel subscribe
  success per table, and change-delivery latency under load.
- **Doesn't cover:** the Flutter client itself (this hits the API directly, not
  through the app UI), or push notification delivery
  (`send-notification`/`notify-trial-expiry`) — ask if you want those added.
