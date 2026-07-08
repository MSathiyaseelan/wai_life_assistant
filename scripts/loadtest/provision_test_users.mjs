// Provisions N throwaway auth users + a personal wallet each, directly via the
// Supabase Admin API — no OTP/SMS involved, so this costs nothing and sends
// no real messages. Writes the resulting session tokens to test_users.json,
// which artillery-config.yml reads to drive the load test.
//
// Usage:
//   SUPABASE_URL=https://<qa-ref>.supabase.co \
//   SUPABASE_ANON_KEY=<qa-anon-key> \
//   SUPABASE_SERVICE_ROLE_KEY=<qa-service-role-key> \
//   TEST_USER_COUNT=50 \
//   node provision_test_users.mjs

import { createClient } from "@supabase/supabase-js";
import { writeFileSync } from "node:fs";
import { randomUUID } from "node:crypto";

const SUPABASE_URL = process.env.SUPABASE_URL;
const ANON_KEY = process.env.SUPABASE_ANON_KEY;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const COUNT = parseInt(process.env.TEST_USER_COUNT ?? "50", 10);

if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
  console.error(
    "Missing env vars. Required: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY"
  );
  process.exit(1);
}

// Guard rail: refuse to run against what looks like a prod URL saved in
// env/prod.json, so a copy-pasted env var can't accidentally point here.
if (process.env.SUPABASE_URL_IS_PROD === "true") {
  console.error("Refusing to run: SUPABASE_URL_IS_PROD=true. Load tests must never target prod.");
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});
const anon = createClient(SUPABASE_URL, ANON_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// Sanity-check the service-role key before looping COUNT times on a key
// that's wrong — listUsers() is a cheap, harmless admin-only call.
const { error: keyCheckErr } = await admin.auth.admin.listUsers({ page: 1, perPage: 1 });
if (keyCheckErr) {
  console.error(
    `SUPABASE_SERVICE_ROLE_KEY check failed (status=${keyCheckErr.status}): ${keyCheckErr.message || "(empty message — key is very likely wrong, or you passed the anon key here instead)"}`
  );
  process.exit(1);
}
console.log("Service-role key OK.");

const runId = Date.now();
const password = `LoadTest-${randomUUID()}`; // shared, disposable — deleted at cleanup
const users = [];

console.log(`Provisioning ${COUNT} load-test users against ${SUPABASE_URL} ...`);

for (let i = 0; i < COUNT; i++) {
  const email = `loadtest_${runId}_${i}@waiapp.internal`;

  const { data: created, error: createErr } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { loadtest: true, run_id: runId },
  });
  if (createErr) {
    console.error(
      `[${i}] createUser failed: status=${createErr.status} code=${createErr.code} message=${createErr.message || "(empty)"}`
    );
    if (i === 0) {
      // First failure only — dump everything, since an empty message usually
      // means the service-role key itself is wrong/missing.
      console.error("Full error object:", JSON.stringify(createErr, null, 2));
      console.error(
        `SUPABASE_URL=${SUPABASE_URL}\nSERVICE_ROLE_KEY starts with: ${SERVICE_ROLE_KEY?.slice(0, 12)}... (length ${SERVICE_ROLE_KEY?.length})`
      );
    }
    continue;
  }
  const userId = created.user.id;

  const { data: signIn, error: signInErr } = await anon.auth.signInWithPassword({
    email,
    password,
  });
  if (signInErr || !signIn.session) {
    console.error(`[${i}] signIn failed:`, signInErr?.message);
    continue;
  }

  // Personal wallet, created via the user's own token so it goes through
  // normal RLS the same way the app would (not a service-role bypass).
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${signIn.session.access_token}` } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: wallet, error: walletErr } = await userClient
    .from("wallets")
    .insert({
      owner_id: userId,
      name: "Load Test Wallet",
      emoji: "🧪",
      is_personal: true,
    })
    .select()
    .single();
  if (walletErr) {
    console.error(`[${i}] wallet insert failed:`, walletErr.message);
    continue;
  }

  users.push({
    userId,
    email,
    walletId: wallet.id,
    accessToken: signIn.session.access_token,
  });

  if ((i + 1) % 10 === 0) console.log(`  ${i + 1}/${COUNT} provisioned`);
}

writeFileSync(
  new URL("./test_users.json", import.meta.url),
  JSON.stringify({ runId, supabaseUrl: SUPABASE_URL, users }, null, 2)
);

console.log(`Done. ${users.length}/${COUNT} users provisioned → test_users.json`);
console.log(`Run ID: ${runId} (needed for cleanup_test_data.mjs)`);
