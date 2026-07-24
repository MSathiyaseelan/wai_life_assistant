// ============================================================
// Supabase Edge Function: /change-phone
// WAI Life Assistant — Change the phone number on an existing account
// ============================================================
//
// Unlike /firebase-verify (which signs into whichever Supabase account
// owns the phone_${digits}@waiapp.internal email — creating one if none
// exists, i.e. a LOGIN), this updates the CALLER's own already-logged-in
// account to a new phone number. Re-using /firebase-verify for this would
// be wrong — verifying a new number there would sign the user into a
// different (or brand-new) Supabase account instead of renaming theirs.
//
// Flow:
//   1. Client already has a Supabase session (Authorization header) and
//      has separately completed Firebase Phone Auth OTP for the NEW
//      number, producing a Firebase ID token for that number.
//   2. Verify the Supabase JWT → resolve the caller's uid.
//   3. Verify the Firebase ID token (same JWKS check as firebase-verify)
//      → extract the verified new phone number.
//   4. Refuse if that number's internal email already belongs to a
//      DIFFERENT account (can't take over someone else's number).
//   5. admin.updateUserById(uid, { email: new_internal_email }) — changes
//      the auth identity in place, same uid, same data, just a new phone.
//   6. Update profiles.phone to match.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_PROJECT_ID  = Deno.env.get("FIREBASE_PROJECT_ID") ?? "waiapp-4edaf";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ── JWT helpers (same as firebase-verify) ──────────────────────────────────

function base64urlDecode(str: string): Uint8Array {
  const base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  const padded  = base64.padEnd(base64.length + (4 - (base64.length % 4)) % 4, "=");
  const binary  = atob(padded);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

interface FirebaseClaims {
  sub: string;
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  phone_number?: string;
  firebase?: { identities?: { phone?: string[] } };
}

async function verifyFirebaseIdToken(idToken: string): Promise<FirebaseClaims> {
  const parts = idToken.split(".");
  if (parts.length !== 3) throw new Error("Malformed JWT");

  const [headerB64, payloadB64, sigB64] = parts;

  const header  = JSON.parse(new TextDecoder().decode(base64urlDecode(headerB64)));
  const payload = JSON.parse(new TextDecoder().decode(base64urlDecode(payloadB64))) as FirebaseClaims;

  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now)         throw new Error("Token expired");
  if (payload.iat > now + 60)    throw new Error("Token issued in the future");
  if (payload.aud !== FIREBASE_PROJECT_ID)
    throw new Error(`Wrong audience: ${payload.aud}`);
  if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`)
    throw new Error(`Wrong issuer: ${payload.iss}`);

  const jwksRes = await fetch(FIREBASE_JWKS_URL);
  if (!jwksRes.ok) throw new Error("Failed to fetch Firebase public keys");
  const { keys } = await jwksRes.json() as { keys: JsonWebKey[] };
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error(`No matching public key for kid=${header.kid}`);

  const pubKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );

  const signingInput = new TextEncoder().encode(`${headerB64}.${payloadB64}`);
  const signature    = base64urlDecode(sigB64);

  const valid = await crypto.subtle.verify(
    { name: "RSASSA-PKCS1-v1_5" },
    pubKey,
    signature,
    signingInput,
  );
  if (!valid) throw new Error("Invalid token signature");

  return payload;
}

function normalisePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  return digits.startsWith("91") ? digits : `91${digits}`;
}

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── 1. Resolve caller from their Supabase session ──────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return errorResponse(401, "Missing Authorization header");
    }
    const callerToken = authHeader.replace("Bearer ", "");
    const { data: { user: caller }, error: callerErr } =
      await supabaseAdmin.auth.getUser(callerToken);
    if (callerErr || !caller) {
      return errorResponse(401, "Invalid or expired session");
    }

    // ── 2. Verify the new-phone Firebase ID token ───────────────────────────
    const body = await req.json() as { id_token?: string };
    if (!body?.id_token) return errorResponse(400, "id_token is required");

    const claims = await verifyFirebaseIdToken(body.id_token);
    const newPhone = claims.phone_number ?? claims.firebase?.identities?.phone?.[0];
    if (!newPhone) return errorResponse(400, "Phone number not found in Firebase token");

    const digits = normalisePhone(newPhone);
    const newEmail = `phone_${digits}@waiapp.internal`;

    // ── 3. Rename the caller's own account to the new number ───────────────
    // auth.users.email is unique-constrained, so if this number already
    // belongs to a different account, updateUserById fails on that
    // constraint rather than silently overwriting it — no separate
    // pre-check needed (listUsers() is paginated and wouldn't reliably
    // find a match once the user base grows past one page anyway).
    const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(
      caller.id,
      { email: newEmail, email_confirm: true },
    );
    if (updateErr) {
      console.error("[change-phone] updateUserById failed:", updateErr);
      const isDuplicate = /already|duplicate|exists/i.test(updateErr.message);
      return errorResponse(
        isDuplicate ? 409 : 500,
        isDuplicate
          ? "This number is already linked to another account"
          : `Failed to update account: ${updateErr.message}`,
      );
    }

    // ── 5. Keep profiles.phone in sync for display purposes ────────────────
    const { error: profileErr } = await supabaseAdmin
      .from("profiles")
      .update({ phone: newPhone })
      .eq("id", caller.id);
    if (profileErr) {
      console.error("[change-phone] profiles update failed:", profileErr);
      // Auth identity already changed successfully — don't fail the whole
      // request over the display-copy update; the client can retry syncing
      // profiles.phone separately if needed.
    }

    return new Response(JSON.stringify({ success: true, phone: newPhone }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[change-phone] error:", message);
    const status = message.includes("expired") ||
                   message.includes("Invalid") ||
                   message.includes("Wrong audience") ||
                   message.includes("Wrong issuer") ||
                   message.includes("Malformed") ? 401 : 500;
    return errorResponse(status, message);
  }
});
