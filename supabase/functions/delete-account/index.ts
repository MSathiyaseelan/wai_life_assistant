// ============================================================
// Supabase Edge Function: /delete-account
// WAI Life Assistant — Full account wipe (DPDP Act compliance)
// ============================================================
//
// Flow:
//   1. Caller sends their Supabase JWT in the Authorization header.
//   2. Verify the JWT and extract the user's UID.
//   3. Call auth.admin.deleteUser(uid) — Postgres CASCADE deletes
//      all user data automatically across every linked table.
//   4. Return { success: true }.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return json("ok", 200);
  }

  try {
    // ── 1. Extract caller JWT ────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Missing Authorization header" }, 401);
    }
    const callerToken = authHeader.replace("Bearer ", "");

    // Admin client — service role key for privileged operations.
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // ── 2. Resolve UID from token ────────────────────────────────────────
    const { data: { user }, error: userErr } = await admin.auth.getUser(callerToken);
    if (userErr || !user) {
      console.error("[delete-account] Token validation failed:", userErr);
      return json({ error: "Invalid or expired token" }, 401);
    }
    const uid = user.id;
    console.log(`[delete-account] Deleting user ${uid}`);

    // ── 3. Delete auth user — CASCADE removes all linked data ────────────
    // profiles → wallets → transactions/wishes/reminders/notes/recipes/…
    // auth.users → wardrobe_items / health_* / item_locator_* / functions_*
    const { error: deleteErr } = await admin.auth.admin.deleteUser(uid);
    if (deleteErr) {
      console.error("[delete-account] deleteUser failed:", deleteErr);
      return json({ error: `Deletion failed: ${deleteErr.message}` }, 500);
    }

    console.log(`[delete-account] User ${uid} deleted successfully.`);
    return json({ success: true });

  } catch (err) {
    console.error("[delete-account] Unexpected error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
