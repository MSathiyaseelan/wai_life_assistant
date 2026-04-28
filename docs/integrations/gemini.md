# Google Gemini AI Integration

---

## Purpose

All AI parsing in WAI — expense parsing, receipt scanning, task creation, grocery detection, event planning, bank SMS parsing, and the dashboard AI assistant — is handled by Google Gemini.

---

## Architecture

Gemini is **never called directly from the Flutter client**. All calls go through the `parse` Supabase edge function.

```
Flutter client
    ↓  supabase_flutter.functions.invoke('parse', body)
Supabase Edge Function (/parse)
    ↓  fetch(geminiUrl + '?key=' + GEMINI_API_KEY)
Google Gemini REST API
    ↓  JSON response
Edge function normalises + returns
    ↓
AIParseResult { success, data, confidence, needsReview, meta }
```

The client calls `AIParser.parseText()` or `AIParser.parseImage()` in `lib/core/services/ai_parser.dart`.

> There is also a legacy `GeminiService` (`lib/core/services/gemini_service.dart`) that calls Gemini directly via REST with `_apiKey = 'YOUR_GEMINI_API_KEY'`. This is a scaffold — not used in the production path.

---

## Models

| Model | Used for | Config |
|---|---|---|
| `gemini-2.5-flash` | All text parsing (28+ prompts) | `temperature: 0.1`, `maxOutputTokens: 2048`, `responseMimeType: application/json` |
| `gemini-2.0-flash` | Image parsing (`pantry/bill_scan` only) | Same, but no `responseMimeType` — image+JSON causes 422 |

---

## Authentication

**API key** as query parameter — stored as Supabase secret, never shipped to client:
```
https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=GEMINI_API_KEY
```

---

## Request Format (POST /parse)

```json
{
  "feature":     "wallet",
  "sub_feature": "expense",
  "input_type":  "text",
  "text":        "250 for lunch at Saravana Bhavan",
  "context": {
    "today":         "2026-04-28",
    "day_of_week":   "Monday",
    "current_month": "April 2026",
    "currency":      "INR",
    "categories":    ["Food", "Transport", "Shopping", "Health", "Other"]
  }
}
```

For images:
```json
{
  "feature":          "pantry",
  "sub_feature":      "bill_scan",
  "input_type":       "image",
  "image_base64":     "<base64-encoded JPEG>",
  "image_mime_type":  "image/jpeg",
  "context":          { "today": "2026-04-28", "currency": "INR" }
}
```

---

## Response Format

```json
{
  "success":      true,
  "feature":      "wallet",
  "sub_feature":  "expense",
  "data": {
    "amount":      250,
    "category":    "Food",
    "title":       "Lunch at Saravana Bhavan",
    "type":        "expense",
    "date":        "2026-04-28",
    "confidence":  0.94
  },
  "confidence":   0.94,
  "needs_review": false,
  "meta": {
    "tokens_used": 312,
    "latency_ms":  1840,
    "prompt_id":   "a1b2c3d4-...",
    "model":       "gemini-2.5-flash"
  }
}
```

When `needs_review: true` (confidence < 0.7), the client shows a confirmation sheet before saving.

---

## Safety Settings

All four harm categories are set to `BLOCK_NONE` — financial/medical text regularly triggers false positives with default settings:

```typescript
safetySettings: [
  { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
  { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" },
]
```

---

## Error Handling

| Error | Handling |
|---|---|
| HTTP error (non-200) | Returns `{ success: false, error: "Gemini API error 429: ..." }` with status 502 |
| Invalid JSON response | Tries `{...}` extraction fallback; if still fails → 422 "AI returned invalid JSON" |
| Empty candidates | Returns 502 "Gemini returned empty response" |
| Edge function unreachable | `AIParser._invoke()` catches `FunctionException`, returns `AIParseResult.error(...)` |

---

## Cost Estimate

**Gemini 2.5 Flash pricing (2026):**

| Input | Cost |
|---|---|
| Text input | $0.15 / 1M tokens |
| Text output | $0.60 / 1M tokens |
| Image input | $0.075 / 1K images |

Per-parse estimate: ~600 input + 200 output tokens = **~0.18¢ per text parse**.

| Scale (MAU) | Parses/month | Est. cost |
|---|---|---|
| 1,000 | 150,000 | ~$0.27 |
| 10,000 | 1.5M | ~$2.70 |

---

## Setup

```bash
# 1. Get API key from https://aistudio.google.com/app/apikey

# 2. Set in Supabase secrets
supabase secrets set GEMINI_API_KEY=AIzaSy...

# 3. Verify
curl -X POST https://oeclczbamrnouuzooitx.supabase.co/functions/v1/parse \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"feature":"wallet","sub_feature":"expense","input_type":"text","text":"100 chai"}'

# Expected: { "success": true, "data": { "amount": 100, "category": "Food", ... } }
```

---

## Related Documentation

- [Smart Parser Architecture](../ai/smart-parser.md) — two-layer NLP → Gemini pipeline
- [Prompts Reference](../ai/prompts-reference.md) — all 28 prompts and versioning
- [Supabase Integration](supabase.md) — edge function invocation
