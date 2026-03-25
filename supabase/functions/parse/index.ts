// ============================================================
// Supabase Edge Function: /parse
// WAI Life Assistant — AI Text & Image Parser
// Uses: Gemini 1.5 Flash + Supabase DB prompt storage
// ============================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Types ─────────────────────────────────────────────────────
interface ParseRequest {
  feature: string;          // wallet | pantry | planit | mylife
  sub_feature: string;      // expense | meal | reminder | etc.
  input_type: "text" | "image" | "voice_transcript";
  text?: string;
  image_base64?: string;
  image_mime_type?: string; // image/jpeg | image/png | image/webp
  context?: {
    today?: string;
    scope?: string;
    members?: string[];
    categories?: string[];
    vehicles?: string[];
    people_count?: number;
    current_month?: string;
    day_of_week?: string;
    currency?: string;
  };
}

interface GeminiPart {
  text?: string;
  inline_data?: {
    mime_type: string;
    data: string;
  };
}

// ── Constants ─────────────────────────────────────────────────
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/" +
  "gemini-2.5-flash:generateContent";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// ── Helpers ───────────────────────────────────────────────────
function getToday(): string {
  return new Date().toISOString().split("T")[0];
}

function getDayOfWeek(): string {
  return new Date().toLocaleDateString("en-IN", { weekday: "long" });
}

function getCurrentMonth(): string {
  return new Date().toLocaleDateString("en-IN", {
    month: "long",
    year: "numeric",
  });
}

function injectContext(prompt: string, ctx: ParseRequest["context"] & { text?: string }): string {
  const today = ctx?.today || getToday();
  const replacements: Record<string, string> = {
    "{{text}}":          ctx?.text || "",
    "{{today}}":         today,
    "{{day_of_week}}":   ctx?.day_of_week || getDayOfWeek(),
    "{{current_month}}": ctx?.current_month || getCurrentMonth(),
    "{{scope}}":         ctx?.scope || "personal",
    "{{members}}":       ctx?.members?.join(", ") || "not specified",
    "{{categories}}":    ctx?.categories?.join(", ") || "Food, Transport, Shopping, Health, Other",
    "{{vehicles}}":      ctx?.vehicles?.join(", ") || "not specified",
    "{{people_count}}":  String(ctx?.people_count || "not specified"),
    "{{currency}}":      ctx?.currency || "INR",
  };

  let result = prompt;
  for (const [key, value] of Object.entries(replacements)) {
    result = result.replaceAll(key, value);
  }
  return result;
}

function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function errorResponse(message: string, status = 400): Response {
  return jsonResponse({ success: false, error: message }, status);
}

// ── Fetch Prompt from DB ──────────────────────────────────────
async function fetchPrompt(
  supabase: ReturnType<typeof createClient>,
  feature: string,
  sub_feature: string,
  input_type: string
): Promise<{ id: string; prompt: string; schema_hint: unknown } | null> {

  // Try exact input_type match first, then fallback to 'both', then 'text'
  const fallbacks = [input_type, "both", "text"];

  for (const type of fallbacks) {
    const { data, error } = await supabase
      .from("ai_prompts")
      .select("id, prompt, schema_hint")
      .eq("feature", feature)
      .eq("sub_feature", sub_feature)
      .eq("input_type", type)
      .eq("is_active", true)
      .order("version", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (!error && data) return data;
  }

  return null;
}

// ── Call Gemini ───────────────────────────────────────────────
async function callGemini(
  prompt: string,
  imageBase64?: string,
  imageMimeType?: string
): Promise<{ text: string; tokens: number; latencyMs: number }> {

  const start = Date.now();
  const parts: GeminiPart[] = [{ text: prompt }];

  if (imageBase64 && imageMimeType) {
    parts.push({
      inline_data: {
        mime_type: imageMimeType,
        data: imageBase64,
      },
    });
  }

  const response = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts }],
      generationConfig: {
        temperature: 0.1,
        maxOutputTokens: 1024,
        responseMimeType: "application/json",
      },
      safetySettings: [
        { category: "HARM_CATEGORY_HARASSMENT",       threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_HATE_SPEECH",      threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",threshold: "BLOCK_NONE" },
        { category: "HARM_CATEGORY_DANGEROUS_CONTENT",threshold: "BLOCK_NONE" },
      ],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`Gemini API error ${response.status}: ${err}`);
  }

  const data = await response.json();

  if (!data.candidates?.[0]?.content?.parts?.[0]?.text) {
    throw new Error("Gemini returned empty response");
  }

  return {
    text: data.candidates[0].content.parts[0].text,
    tokens: data.usageMetadata?.totalTokenCount || 0,
    latencyMs: Date.now() - start,
  };
}

// ── Log Parse Attempt ─────────────────────────────────────────
async function logParse(
  supabase: ReturnType<typeof createClient>,
  userId: string | null,
  req: ParseRequest,
  promptId: string,
  result: unknown,
  tokensUsed: number,
  latencyMs: number,
  error?: string
) {
  // Fire and forget — don't block response
  supabase.from("ai_parse_logs").insert({
    user_id:       userId,
    feature:       req.feature,
    sub_feature:   req.sub_feature,
    input_type:    req.input_type,
    prompt_id:     promptId,
    raw_input:     req.text || (req.image_base64 ? "[image]" : null),
    parsed_output: result || null,
    confidence:    (result as Record<string, unknown>)?.confidence || null,
    tokens_used:   tokensUsed,
    latency_ms:    latencyMs,
    error:         error || null,
  }).then(() => {}).catch(() => {});
}

// ── Main Handler ──────────────────────────────────────────────
serve(async (req: Request) => {

  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // ── Parse request body
  let body: ParseRequest;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const { feature, sub_feature, input_type, text, image_base64,
          image_mime_type, context } = body;

  // ── Validate required fields
  if (!feature || !sub_feature || !input_type) {
    return errorResponse("Missing required fields: feature, sub_feature, input_type");
  }

  const validFeatures = ["wallet", "pantry", "planit", "mylife", "functions", "lifestyle"];
  if (!validFeatures.includes(feature)) {
    return errorResponse(`Invalid feature. Must be one of: ${validFeatures.join(", ")}`);
  }

  if (input_type === "text" && !text?.trim()) {
    return errorResponse("text field required for input_type: text");
  }

  if (input_type === "image" && !image_base64) {
    return errorResponse("image_base64 required for input_type: image");
  }

  // ── Init Supabase client
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  // ── Get user from auth header (optional — for logging)
  let userId: string | null = null;
  try {
    const authHeader = req.headers.get("Authorization");
    if (authHeader) {
      const token = authHeader.replace("Bearer ", "");
      const { data: { user } } = await supabase.auth.getUser(token);
      userId = user?.id || null;
    }
  } catch { /* auth optional */ }

  // ── Fetch prompt from database
  let promptRow: { id: string; prompt: string; schema_hint: unknown } | null = null;
  try {
    promptRow = await fetchPrompt(supabase, feature, sub_feature, input_type);
  } catch (e) {
    return errorResponse(`DB error fetching prompt: ${(e as Error).message}`, 500);
  }

  if (!promptRow) {
    return errorResponse(
      `No active prompt found for: ${feature}.${sub_feature} (${input_type})`,
      404
    );
  }

  // ── Inject context into prompt
  const enrichedContext = {
    ...context,
    text: text || "",
    today:         context?.today || getToday(),
    day_of_week:   context?.day_of_week || getDayOfWeek(),
    current_month: context?.current_month || getCurrentMonth(),
  };

  const finalPrompt = injectContext(promptRow.prompt, enrichedContext);

  // ── Call Gemini
  let geminiResult: { text: string; tokens: number; latencyMs: number };
  try {
    geminiResult = await callGemini(
      finalPrompt,
      image_base64,
      image_mime_type || "image/jpeg"
    );
  } catch (e) {
    const errMsg = (e as Error).message;
    await logParse(supabase, userId, body, promptRow.id,
                   null, 0, 0, errMsg);
    return errorResponse(`Gemini error: ${errMsg}`, 502);
  }

  // ── Parse JSON response
  let parsed: Record<string, unknown>;
  try {
    // 1) Strip markdown code fences
    let cleanText = geminiResult.text
      .replace(/^```json\s*/i, "")
      .replace(/^```\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();

    // 2) If still not parseable, extract the first {...} block
    try {
      parsed = JSON.parse(cleanText);
    } catch {
      const jsonMatch = cleanText.match(/\{[\s\S]*\}/);
      if (!jsonMatch) throw new Error("No JSON object found in response");
      parsed = JSON.parse(jsonMatch[0]);
    }
  } catch {
    await logParse(supabase, userId, body, promptRow.id,
                   null, geminiResult.tokens, geminiResult.latencyMs,
                   "JSON parse failed");
    return errorResponse("AI returned invalid JSON", 422);
  }

  // ── Log successful parse
  await logParse(
    supabase, userId, body, promptRow.id,
    parsed, geminiResult.tokens, geminiResult.latencyMs
  );

  // ── Return result
  return jsonResponse({
    success:     true,
    feature,
    sub_feature,
    input_type,
    data:        parsed,
    confidence:  parsed.confidence || null,
    needs_review: (parsed.confidence as number) < 0.7,
    meta: {
      tokens_used: geminiResult.tokens,
      latency_ms:  geminiResult.latencyMs,
      prompt_id:   promptRow.id,
    },
  });
});