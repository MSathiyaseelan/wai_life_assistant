// ============================================================
// Supabase Edge Function: /send-otp
// WAI Life Assistant — MSG91 OTP Sender
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const MSG91_AUTH_KEY = Deno.env.get("MSG91_AUTH_KEY")!;
// MSG91 dashboard calls it "Flow ID" but the OTP API parameter is template_id.
const MSG91_TEMPLATE_ID = Deno.env.get("MSG91_TEMPLATE_ID")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone } = await req.json() as { phone: string };

    if (!phone) {
      return new Response(
        JSON.stringify({ error: "phone is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Normalise: strip + and spaces, ensure it starts with country code
    // Expected input: "+919876543210" or "919876543210"
    const mobile = phone.replace(/\D/g, "");

    console.log("[send-otp] Sending OTP to mobile:", mobile, "template_id:", MSG91_TEMPLATE_ID);

    const msg91Res = await fetch("https://control.msg91.com/api/v5/otp", {
      method: "POST",
      headers: {
        "authkey": MSG91_AUTH_KEY,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        template_id: MSG91_TEMPLATE_ID,
        mobile,
        otp_length: 6,
        otp_expiry: 30,   // minutes — MSG91 default if omitted is ~5 min
      }),
    });

    const rawText = await msg91Res.text();
    console.log("[send-otp] MSG91 status:", msg91Res.status, "body:", rawText);

    let result: Record<string, unknown> = {};
    try { result = JSON.parse(rawText); } catch { /* ignore */ }

    if (!msg91Res.ok || result["type"] === "error") {
      console.error("[send-otp] MSG91 error:", result);
      return new Response(
        JSON.stringify({ error: (result["message"] as string) ?? "Failed to send OTP" }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, request_id: result["request_id"] }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("[send-otp] Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});
