// ============================================================
// Supabase Edge Function: /delete-account
// WAI Life Assistant — Full account wipe (DPDP Act compliance)
// ============================================================
//
// Flow:
//   1. Caller must send their Supabase JWT in the Authorization header.
//   2. We verify the JWT and extract the user's UID.
//   3. We call delete_my_account() RPC (soft-deletes all user data).
//   4. We call auth.admin.deleteUser(uid) to remove the auth record.
//   5. Return { success: true }.
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
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Verify caller JWT ─────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Missing Authorization header" }, 401);
    }
    const callerToken = authHeader.replace("Bearer ", "");

    // Admin client (service role) — used for privileged ops.
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    // User client scoped to the caller's token — used for RPC (RLS applies).
    const userClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: { Authorization: `Bearer ${callerToken}` } },
    });

    // Resolve the UID from the token.
    const { data: { user }, error: userErr } = await admin.auth.getUser(callerToken);
    if (userErr || !user) {
      return json({ error: "Invalid or expired token" }, 401);
    }
    const uid = user.id;

    // ── 2. Soft-delete all user data via RPC ─────────────────────────────
    const { error: rpcErr } = await userClient.rpc("delete_my_account");
    if (rpcErr) {
      console.error("[delete-account] RPC error:", rpcErr);
      return json({ error: `Data deletion failed: ${rpcErr.message}` }, 500);
    }

    // ── 3. Delete the auth.users record ──────────────────────────────────
    const { error: deleteErr } = await admin.auth.admin.deleteUser(uid);
    if (deleteErr) {
      console.error("[delete-account] Auth delete error:", deleteErr);
      return json({ error: `Auth deletion failed: ${deleteErr.message}` }, 500);
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
