// ============================================================
// Supabase Edge Function: /firebase-verify
// WAI Life Assistant — Firebase Phone Auth → Supabase Session
// ============================================================
//
// Flow:
//   1. Client signs in via Firebase Phone Auth and gets an ID token.
//   2. Client sends { id_token } to this function.
//   3. We verify the Firebase ID token against Google's public JWKS.
//   4. We extract the verified phone number from the token payload.
//   5. We sign in (or create) the corresponding Supabase user using the
//      same phone_${digits}@waiapp.internal internal-email pattern as
//      the legacy verify-otp function, so existing user rows are reused.
//   6. We return a Supabase session to the client.
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const FIREBASE_PROJECT_ID  = Deno.env.get("FIREBASE_PROJECT_ID") ?? "waiapp-4edaf";
const SUPABASE_URL         = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const INTERNAL_PASS = (() => {
  const v = Deno.env.get("WAI_INTERNAL_AUTH_PASS");
  if (!v) throw new Error("WAI_INTERNAL_AUTH_PASS env var is not set — refusing to start");
  return v;
})();

const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ── JWT helpers ─────────────────────────────────────────────────────────────

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

  // ── 1. Basic claim checks (cheap, before fetching keys) ──────────────────
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now)         throw new Error("Token expired");
  if (payload.iat > now + 60)    throw new Error("Token issued in the future");
  if (payload.aud !== FIREBASE_PROJECT_ID)
    throw new Error(`Wrong audience: ${payload.aud}`);
  if (payload.iss !== `https://securetoken.google.com/${FIREBASE_PROJECT_ID}`)
    throw new Error(`Wrong issuer: ${payload.iss}`);

  // ── 2. Fetch Google's public JWKS and find the matching key ──────────────
  const jwksRes = await fetch(FIREBASE_JWKS_URL);
  if (!jwksRes.ok) throw new Error("Failed to fetch Firebase public keys");
  const { keys } = await jwksRes.json() as { keys: JsonWebKey[] };
  const jwk = keys.find((k) => k.kid === header.kid);
  if (!jwk) throw new Error(`No matching public key for kid=${header.kid}`);

  // ── 3. Import the RSA public key and verify the signature ─────────────────
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

// ── Phone normalisation ─────────────────────────────────────────────────────

function normalisePhone(raw: string): string {
  const digits = raw.replace(/\D/g, "");
  return digits.startsWith("91") ? digits : `91${digits}`;
}

// ── Session creation (same pattern as verify-otp) ───────────────────────────

async function getOrCreateSession(phone: string): Promise<Response> {
  const digits = normalisePhone(phone);
  const email  = `phone_${digits}@waiapp.internal`;

  // Happy path — returning user.
  const { data: signIn, error: signInErr } =
    await supabaseAdmin.auth.signInWithPassword({ email, password: INTERNAL_PASS });

  if (!signInErr && signIn.session) {
    return sessionResponse(signIn.session, signIn.user!.id, phone);
  }

  // New user — create, then sign in.
  const { error: createErr } = await supabaseAdmin.auth.admin.createUser({
    email,
    password: INTERNAL_PASS,
    email_confirm: true,
    user_metadata: { phone },
  });

  if (createErr && createErr.code !== "email_exists") {
    console.error("[firebase-verify] createUser error:", createErr);
    return errorResponse(500, "Failed to create user account");
  }

  const { data: newSignIn, error: newSignInErr } =
    await supabaseAdmin.auth.signInWithPassword({ email, password: INTERNAL_PASS });

  if (newSignInErr || !newSignIn.session) {
    console.error("[firebase-verify] post-signup sign-in error:", newSignInErr);
    return errorResponse(500, "Authentication failed after sign-up");
  }

  return sessionResponse(newSignIn.session, newSignIn.user!.id, phone);
}

function sessionResponse(
  session: { access_token: string; refresh_token: string; expires_in: number },
  userId: string,
  phone: string,
): Response {
  return new Response(
    JSON.stringify({
      access_token:  session.access_token,
      refresh_token: session.refresh_token,
      expires_in:    session.expires_in,
      user:          { id: userId, phone },
    }),
    { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

function errorResponse(status: number, message: string): Response {
  return new Response(
    JSON.stringify({ error: message }),
    { status, headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
}

// ── In-memory rate limiter ────────────────────────────────────────────────────
// Keyed by client IP. Resets on cold start but blocks rapid burst abuse.

const _rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const RATE_LIMIT_MAX_CALLS = 10;     // max 10 verify attempts per IP per minute

function isRateLimited(req: Request): boolean {
  const ip =
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    req.headers.get("cf-connecting-ip") ??
    "unknown";
  const now = Date.now();
  const entry = _rateLimitMap.get(ip);
  if (!entry || now > entry.resetAt) {
    _rateLimitMap.set(ip, { count: 1, resetAt: now + RATE_LIMIT_WINDOW_MS });
    return false;
  }
  if (entry.count >= RATE_LIMIT_MAX_CALLS) return true;
  entry.count++;
  return false;
}

// ── Main handler ─────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (isRateLimited(req)) {
    return errorResponse(429, "Too many requests. Please try again later.");
  }

  try {
    const body = await req.json() as { id_token?: string };
    const idToken = body?.id_token;
    if (!idToken) return errorResponse(400, "id_token is required");

    const claims = await verifyFirebaseIdToken(idToken);
    // Firebase Phone Auth stores the number in phone_number.
    const phone =
      claims.phone_number ??
      claims.firebase?.identities?.phone?.[0];

    if (!phone) {
      console.error("[firebase-verify] phone claim missing from verified token");
      return errorResponse(400, "Phone number not found in Firebase token");
    }

    return await getOrCreateSession(phone);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[firebase-verify] error:", message);

    // Surface token-validation errors as 401, everything else as 500.
    const status = message.includes("expired") ||
                   message.includes("Invalid token") ||
                   message.includes("Wrong audience") ||
                   message.includes("Wrong issuer") ||
                   message.includes("Malformed") ? 401 : 500;

    return errorResponse(status, message);
  }
});
