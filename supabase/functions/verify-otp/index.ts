// ============================================================
// Supabase Edge Function: /verify-otp
// WAI Life Assistant — MSG91 OTP Verifier + Session Creator
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const MSG91_AUTH_KEY     = Deno.env.get("MSG91_AUTH_KEY")!;
const SUPABASE_URL       = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Stable password used server-side — never exposed to the client.
const INTERNAL_PASS = Deno.env.get("WAI_INTERNAL_AUTH_PASS") ?? "wai_dev_bypass_2024";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Admin client (service role — server only, never shipped to client).
const supabaseAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone, otp } = await req.json() as { phone: string; otp: string };

    if (!phone || !otp) {
      return new Response(
        JSON.stringify({ error: "phone and otp are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const mobile = phone.replace(/\D/g, "");

    // ── 1. Verify OTP with MSG91 ─────────────────────────────────────────────
    // MSG91 v5 OTP verify is a GET with query parameters.
    const verifyUrl = new URL("https://control.msg91.com/api/v5/otp/verify");
    verifyUrl.searchParams.set("authkey", MSG91_AUTH_KEY);
    verifyUrl.searchParams.set("mobile", mobile);
    verifyUrl.searchParams.set("otp", otp);

    console.log("[verify-otp] Calling MSG91 verify for mobile:", mobile);

    const msg91Res = await fetch(verifyUrl.toString(), {
      method: "GET",
      headers: { "Accept": "application/json" },
    });

    const rawText = await msg91Res.text();
    console.log("[verify-otp] MSG91 status:", msg91Res.status, "body:", rawText);

    let msg91Data: Record<string, unknown> = {};
    try {
      msg91Data = JSON.parse(rawText);
    } catch {
      // Non-JSON response — treat as failure
      return new Response(
        JSON.stringify({ error: "Unexpected response from OTP provider" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!msg91Res.ok || msg91Data["type"] === "error") {
      console.error("[verify-otp] MSG91 rejection:", msg91Data);
      return new Response(
        JSON.stringify({ error: (msg91Data["message"] as string) ?? "Invalid OTP" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── 2. Create or sign in the Supabase user ───────────────────────────────
    // Derive a stable internal email from the phone number so the same user
    // always gets the same auth.uid(). The email is never visible to the user.
    const digits = mobile.replace(/\D/g, "");
    const email  = `phone_${digits}@waiapp.internal`;

    // Try sign-in first (most common path for returning users).
    const { data: signInData, error: signInError } =
      await supabaseAdmin.auth.signInWithPassword({ email, password: INTERNAL_PASS });

    if (!signInError && signInData.session) {
      return new Response(
        JSON.stringify({
          access_token:  signInData.session.access_token,
          refresh_token: signInData.session.refresh_token,
          expires_in:    signInData.session.expires_in,
          user:          { id: signInData.user!.id, phone },
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // User doesn't exist yet — sign up, then sign in.
    const { error: signUpError } = await supabaseAdmin.auth.admin.createUser({
      email,
      password: INTERNAL_PASS,
      email_confirm: true,
      user_metadata: { phone },
    });

    if (signUpError && !signUpError.message.includes("already registered")) {
      console.error("[verify-otp] createUser error:", signUpError);
      return new Response(
        JSON.stringify({ error: "Failed to create user account" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: newSignIn, error: newSignInError } =
      await supabaseAdmin.auth.signInWithPassword({ email, password: INTERNAL_PASS });

    if (newSignInError || !newSignIn.session) {
      console.error("[verify-otp] post-signup sign-in error:", newSignInError);
      return new Response(
        JSON.stringify({ error: "Authentication failed after sign-up" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({
        access_token:  newSignIn.session.access_token,
        refresh_token: newSignIn.session.refresh_token,
        expires_in:    newSignIn.session.expires_in,
        user:          { id: newSignIn.user!.id, phone },
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[verify-otp] Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
