// Deletes every load-test user, identified by user_metadata.loadtest === true
// (set at creation in provision_test_users.mjs) rather than by reading
// test_users.json — so this still works even if that file was lost/deleted
// after provisioning, and cleans up ALL past load-test runs in one pass, not
// just the most recent one.
//
// auth.users -> profiles -> wallets -> transactions all cascade on delete
// (see supabase/migrations/001_wallet_schema.sql), so deleting the auth user
// is sufficient to remove all data the load test created — nothing else in
// QA is touched.
//
// Usage:
//   SUPABASE_URL=https://<qa-ref>.supabase.co \
//   SUPABASE_SERVICE_ROLE_KEY=<qa-service-role-key> \
//   node cleanup_test_data.mjs

import { createClient } from "@supabase/supabase-js";
import { existsSync, unlinkSync } from "node:fs";

const SUPABASE_URL = process.env.SUPABASE_URL;
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("Missing env vars. Required: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY");
  process.exit(1);
}

const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

console.log(`Scanning ${SUPABASE_URL} for load-test users (user_metadata.loadtest === true) ...`);

const loadtestUsers = [];
const PER_PAGE = 1000;
for (let page = 1; ; page++) {
  const { data, error } = await admin.auth.admin.listUsers({ page, perPage: PER_PAGE });
  if (error) {
    console.error("listUsers failed:", error.status, error.message);
    process.exit(1);
  }
  loadtestUsers.push(...data.users.filter((u) => u.user_metadata?.loadtest === true));
  if (data.users.length < PER_PAGE) break; // last page
}

if (loadtestUsers.length === 0) {
  console.log("No load-test users found — nothing to clean up.");
} else {
  console.log(`Found ${loadtestUsers.length} load-test user(s). Deleting ...`);
  let deleted = 0;
  for (const u of loadtestUsers) {
    const { error } = await admin.auth.admin.deleteUser(u.id);
    if (error) {
      console.error(`  failed to delete ${u.email}:`, error.message);
      continue;
    }
    deleted++;
  }
  console.log(`Done. ${deleted}/${loadtestUsers.length} users deleted (cascaded: profile, wallet, transactions).`);
}

const usersFile = new URL("./test_users.json", import.meta.url);
if (existsSync(usersFile)) {
  unlinkSync(usersFile);
  console.log("Removed test_users.json.");
}
