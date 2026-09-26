// Realtime capacity test — opens many concurrent app-like Realtime
// connections and measures whether they subscribe, stay up, and deliver
// changes quickly. This is the part artillery-config.yml can't cover, and
// the most likely capacity ceiling (Supabase caps concurrent Realtime
// connections per plan).
//
// Each connection mirrors RealtimeSyncService.subscribeAll() in the app:
// one WebSocket with a meal_entries channel filtered by wallet_id per
// wallet. Provisioned users only have a personal wallet, so that's one
// channel each — a real family member also has one per family wallet.
//
// Latency probes: for PROBE_USERS users, a meal_entries row (dated today)
// is inserted every PROBE_INTERVAL_MS and the time until each of that
// user's connections receives the INSERT is recorded. Probe rows belong to
// the test user and are removed by `npm run cleanup` (ON DELETE CASCADE).
//
// Usage (after `npm run provision`, within the ~1h token lifetime):
//   SUPABASE_URL=https://<qa-ref>.supabase.co \
//   SUPABASE_ANON_KEY=<qa-anon-key> \
//   CONNECTIONS=200 HOLD_SECONDS=300 \
//   node realtime_soak.mjs
//
// CONNECTIONS may exceed the number of provisioned users — users are reused
// round-robin (like one person on two devices). One Node process handles a
// couple of thousand sockets; beyond that, run several processes in parallel.

import { createClient } from "@supabase/supabase-js";
import { readFileSync } from "node:fs";

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !ANON_KEY) {
  console.error("Missing env vars. Required: SUPABASE_URL, SUPABASE_ANON_KEY");
  process.exit(1);
}
if (process.env.SUPABASE_URL_IS_PROD === "true") {
  console.error("Refusing to run: SUPABASE_URL_IS_PROD=true. Load tests must never target prod.");
  process.exit(1);
}

const { users } = JSON.parse(
  readFileSync(new URL("./test_users.json", import.meta.url), "utf-8")
);
if (users.length === 0) {
  console.error("test_users.json has no users — run `npm run provision` first.");
  process.exit(1);
}

const CONNECTIONS = parseInt(process.env.CONNECTIONS ?? String(users.length), 10);
const RAMP_PER_SEC = parseInt(process.env.RAMP_PER_SEC ?? "20", 10);
const HOLD_SECONDS = parseInt(process.env.HOLD_SECONDS ?? "300", 10);
const PROBE_USERS = Math.min(parseInt(process.env.PROBE_USERS ?? "20", 10), users.length);
const PROBE_INTERVAL_MS = parseInt(process.env.PROBE_INTERVAL_MS ?? "2000", 10);
const SUBSCRIBE_TIMEOUT_MS = 15_000;

// ── Metrics ─────────────────────────────────────────────────────────────────

const channelStatus = new Map(); // table -> { SUBSCRIBED, CHANNEL_ERROR, TIMED_OUT, CLOSED }
const channelErrors = new Map(); // table -> first error message seen
const subscribeMs = [];
const latencies = [];
const probes = new Map(); // probeName -> { sentAt, expected, received }
let socketsOpen = 0;
let probesSent = 0;
let probeInsertErrors = 0;

function bump(table, status, err) {
  const s = channelStatus.get(table) ?? {};
  s[status] = (s[status] ?? 0) + 1;
  channelStatus.set(table, s);
  if (err && !channelErrors.has(table)) channelErrors.set(table, String(err?.message ?? err));
}

function pct(arr, p) {
  if (!arr.length) return NaN;
  const s = [...arr].sort((a, b) => a - b);
  return s[Math.min(s.length - 1, Math.floor((p / 100) * s.length))];
}

const fmt = (n) => (Number.isNaN(n) ? "-" : `${Math.round(n)}ms`);

// ── Connections ─────────────────────────────────────────────────────────────

const clients = [];
const listenersByWallet = new Map(); // walletId -> number of connections listening

function openConnection(i) {
  const u = users[i % users.length];
  const client = createClient(SUPABASE_URL, ANON_KEY, {
    accessToken: async () => u.accessToken,
    realtime: { timeout: SUBSCRIBE_TIMEOUT_MS },
  });
  clients.push(client);
  listenersByWallet.set(u.walletId, (listenersByWallet.get(u.walletId) ?? 0) + 1);

  const started = Date.now();
  client
    .channel(`wallet:${u.walletId}:meal_entries:${i}`)
    .on(
      "postgres_changes",
      { event: "*", schema: "public", table: "meal_entries", filter: `wallet_id=eq.${u.walletId}` },
      (payload) => {
        if (payload.eventType !== "INSERT") return;
        const probe = probes.get(payload.new?.name);
        if (!probe) return;
        probe.received++;
        latencies.push(Date.now() - probe.sentAt);
      }
    )
    .subscribe((status, err) => {
      bump("meal_entries", status, err);
      if (status === "SUBSCRIBED") {
        subscribeMs.push(Date.now() - started);
        socketsOpen++;
      }
    });
}

// ── Probes ──────────────────────────────────────────────────────────────────

const probeClients = users.slice(0, PROBE_USERS).map((u) => ({
  u,
  db: createClient(SUPABASE_URL, ANON_KEY, { accessToken: async () => u.accessToken }),
}));

async function sendProbes() {
  const today = new Date().toISOString().split("T")[0];
  await Promise.all(
    probeClients.map(async ({ u, db }) => {
      const name = `probe:${u.userId}:${Date.now()}:${Math.random().toString(36).slice(2, 8)}`;
      probes.set(name, {
        sentAt: Date.now(),
        expected: listenersByWallet.get(u.walletId) ?? 0,
        received: 0,
      });
      probesSent++;
      const { error } = await db.from("meal_entries").insert({
        wallet_id: u.walletId,
        created_by: u.userId,
        name,
        meal_time: "lunch",
        date: today,
      });
      if (error) {
        probeInsertErrors++;
        if (probeInsertErrors === 1) console.error(`Probe insert failed: ${error.message}`);
        probes.delete(name);
      }
    })
  );
}

function deliveryStats() {
  let expected = 0;
  let received = 0;
  const cutoff = Date.now() - 10_000; // give in-flight probes 10s before counting them
  for (const p of probes.values()) {
    if (p.sentAt > cutoff) continue;
    expected += p.expected;
    received += Math.min(p.received, p.expected);
  }
  return { expected, received, rate: expected ? (received / expected) * 100 : NaN };
}

function statusLine(label) {
  let ok = 0;
  let failed = 0;
  for (const s of channelStatus.values()) {
    ok += s.SUBSCRIBED ?? 0;
    failed += (s.CHANNEL_ERROR ?? 0) + (s.TIMED_OUT ?? 0) + (s.CLOSED ?? 0);
  }
  const d = deliveryStats();
  console.log(
    `[${label}] sockets=${socketsOpen}/${clients.length} channels ok=${ok} failed=${failed} ` +
      `probes=${probesSent} delivered=${Number.isNaN(d.rate) ? "-" : d.rate.toFixed(1) + "%"} ` +
      `latency p50=${fmt(pct(latencies, 50))} p95=${fmt(pct(latencies, 95))} p99=${fmt(pct(latencies, 99))}`
  );
}

// ── Run ─────────────────────────────────────────────────────────────────────

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const startedAt = Date.now();
const elapsed = () => `${Math.round((Date.now() - startedAt) / 1000)}s`;

console.log(
  `Opening ${CONNECTIONS} connections at ${RAMP_PER_SEC}/s against ${SUPABASE_URL}, ` +
    `holding ${HOLD_SECONDS}s, probing ${probeClients.length} users ...`
);

const ticker = setInterval(() => statusLine(elapsed()), 10_000);

for (let i = 0; i < CONNECTIONS; i++) {
  openConnection(i);
  if ((i + 1) % RAMP_PER_SEC === 0) await sleep(1000);
}
await sleep(SUBSCRIBE_TIMEOUT_MS); // let the last batch finish subscribing

const probeTimer = setInterval(sendProbes, PROBE_INTERVAL_MS);
await sleep(HOLD_SECONDS * 1000);
clearInterval(probeTimer);
await sleep(10_000); // drain in-flight probes
clearInterval(ticker);

// ── Report ──────────────────────────────────────────────────────────────────

console.log("\n══ Summary ══");
statusLine("final");
console.log(`Subscribe time p50=${fmt(pct(subscribeMs, 50))} p95=${fmt(pct(subscribeMs, 95))}`);
if (probeInsertErrors) console.log(`Probe inserts failed: ${probeInsertErrors}`);

console.log("\nChannel status:");
const rows = [...channelStatus.keys()].map((table) => {
  const s = channelStatus.get(table);
  return {
    table,
    subscribed: s.SUBSCRIBED ?? 0,
    error: s.CHANNEL_ERROR ?? 0,
    timed_out: s.TIMED_OUT ?? 0,
    closed: s.CLOSED ?? 0,
    first_error: channelErrors.get(table) ?? "",
  };
});
console.table(rows);

const d = deliveryStats();
const p99 = pct(latencies, 99);
const failures = [];
if (socketsOpen < clients.length) failures.push(`${clients.length - socketsOpen} connection(s) never subscribed`);
if (!Number.isNaN(d.rate) && d.rate < 99) failures.push(`probe delivery ${d.rate.toFixed(1)}% < 99%`);
if (p99 > 2000) failures.push(`delivery p99 ${Math.round(p99)}ms > 2000ms`);
if (rows.some((r) => r.error || r.timed_out)) failures.push("some channels failed to subscribe (see table)");

console.log(failures.length ? `\nFAIL: ${failures.join("; ")}` : "\nPASS");

for (const c of clients) await c.removeAllChannels();
process.exit(failures.length ? 1 : 0);
