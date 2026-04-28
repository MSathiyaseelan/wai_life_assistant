# Smart Parser Architecture

---

## Overview

WAI uses a **2-layer hybrid parsing system**. The local NLP layer is free and instant; it falls back to Gemini via a Supabase edge function when it lacks confidence. The Dashboard AI assistant uses a special 3-step flow.

```
User input (text or image)
        │
        ▼
┌──────────────────────────────┐
│  Layer 1: Local NLP Parser   │  Deterministic regex/keyword matching
│  (per module, client-side)   │  Zero API cost · Zero latency
│                              │  Wallet:  NlpParser — threshold ≥ 0.75
│                              │  Pantry:  PantryNlpParser — threshold ≥ 0.75
│                              │  SMS:     SMSRegexParser — threshold ≥ 0.80
└──────────────────────────────┘
        │ fails / confidence below threshold
        ▼
┌──────────────────────────────┐
│  Layer 2: Cloud AI (Gemini)  │  Supabase Edge Function /parse
│  Prompt fetched from DB      │  gemini-2.5-flash (text)
│  Context injected at runtime │  gemini-2.0-flash (images)
│  Response logged to DB       │
└──────────────────────────────┘
        │
        ▼
AIParseResult { success, data, confidence, needs_review, meta }
```

---

## Layer 1: Local NLP Parsers

### Wallet — `NlpParser`
**File:** `lib/features/wallet/AI/nlp_parser.dart`

7-step pipeline:
1. **Amount extraction** — handles `₹500`, `5k`, `2.5L`, `five hundred` (word numbers), `500/-`
2. **Flow type detection** — priority order: lend → borrow → split → request → income → expense
3. **Category detection** — `CategoryDetector.detectCategory(text)` (call `ensureLoaded()` first)
4. **Person extraction** — keywords: "to Ravi", "from Priya", "with Kumar"
5. **Pay mode detection** — `cash`, `online`, `upi`, `gpay`, `phonepe`, `neft`
6. **Note extraction** — remaining sentence fragment
7. **Confidence scoring** — weighted sum of matched fields

Threshold: confidence ≥ 0.75 → use local result. Below that → Gemini.

### Pantry — `PantryNlpParser`
**File:** `lib/features/pantry/AI/pantry_nlp_parser.dart`

Handles: meal logging ("had idli for breakfast"), basket additions ("add 2kg rice"), recipe requests ("show me dinner ideas with dal").

Detects `PantryIntent.kind`: `meal` | `basket` | `recipe` | `unknown`

### SMS — `SMSRegexParser`
**File:** `lib/features/wallet/AI/sms_regex_parser.dart`

10 bank-specific patterns handling HDFC, SBI, ICICI, Axis, Kotak, UPI, salary credits. Threshold: ≥ 0.80 = high confidence (Layer 2 skipped). Confidence 0.60–0.79 → falls through to Layer 2.

---

## Layer 2: Gemini AI via Edge Function

**File:** `supabase/functions/parse/index.ts`

### Prompt Loading

Prompts are stored in the `ai_prompts` Supabase table (version-controlled). The edge function fetches the active prompt for `(feature, sub_feature)` at request time:

```typescript
const { data: prompt } = await supabase
  .from('ai_prompts')
  .select('*')
  .eq('feature', feature)
  .eq('sub_feature', sub_feature)
  .eq('is_active', true)
  .order('version', { ascending: false })
  .limit(1)
  .single();
```

Highest active version wins. No code deploy needed to update a prompt.

### Context Injection

10 context placeholders are replaced in the prompt at runtime:

```typescript
const contextPlaceholders = {
  '{{TODAY}}':         context.today,
  '{{DAY_OF_WEEK}}':   context.day_of_week,
  '{{CURRENT_MONTH}}': context.current_month,
  '{{CURRENCY}}':      context.currency || 'INR',
  '{{CATEGORIES}}':    context.categories?.join(', ') || '',
  '{{RECENT_ITEMS}}':  context.recent_items?.join(', ') || '',
  '{{USER_PREFS}}':    context.user_prefs || '',
  '{{WALLET_NAME}}':   context.wallet_name || '',
  '{{FAMILY_MEMBERS}}': context.family_members?.join(', ') || '',
  '{{LOCALE}}':        context.locale || 'en-IN',
};
```

### JSON Cleaning

The edge function handles malformed Gemini responses gracefully:
1. Strip markdown code fences (` ```json ... ``` `)
2. Extract `{...}` block as fallback if surrounding text present
3. If still invalid JSON → return 422 "AI returned invalid JSON"

### Response Logging

Every parse is logged fire-and-forget to `ai_parse_logs`:
```typescript
supabase.from('ai_parse_logs').insert({
  feature, sub_feature, input_type,
  prompt_id: prompt.id,
  tokens_used: meta.tokens_used,
  latency_ms: meta.latency_ms,
  was_corrected: false,   // updated later if user edits
  user_id,
}).then(() => {});  // fire-and-forget
```

---

## Dashboard AI — 3-Step Flow

The Dashboard AI assistant uses a different pattern — it grounds Gemini with real data before asking it to answer:

```
User asks: "How much did I spend this month?"
        │
        ▼
Step 1: IntentClassifier.classify(question)
  └─ Deterministic regex → QuestionIntent
     { dataSources: [wallet], timeRange: thisMonth, queryType: specific }
        │
        ▼
Step 2: ContextFetcher.fetch(intent, walletId)
  └─ Fetches real data from Supabase (parallel queries)
     → HouseholdContext { wallet: {...}, pantry: {}, planit: {}, ... }
     → Serialised as labelled text block
        │
        ▼
Step 3: AIParser.parseText(
           feature: 'dashboard',
           subFeature: 'ai_assistant',
           text: contextBlock + "\nQUESTION: " + question
        )
  └─ Gemini answers grounded in real data
     → AssistantResponse { answer, highlights, suggestions, actions }
```

This approach prevents hallucination — Gemini never invents numbers because the actual numbers are in the prompt.

---

## Client-Side API

```dart
// lib/core/services/ai_parser.dart

// Text parsing (all features except bill_scan)
final result = await AIParser.parseText(
  feature:    'wallet',
  subFeature: 'expense',
  text:       userInput,
  context: {
    'today':      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'currency':   'INR',
    'categories': categories,
  },
);

// Image parsing (bill_scan only)
final result = await AIParser.parseImage(
  feature:    'pantry',
  subFeature: 'bill_scan',
  bytes:      imageBytes,
  mimeType:   'image/jpeg',
  context:    { 'today': '2026-04-28', 'currency': 'INR' },
);

// Both return:
result.success      // bool
result.data         // Map<String, dynamic>
result.confidence   // double 0.0–1.0
result.needsReview  // bool (confidence < 0.7 → show confirm sheet)
result.error        // String? if success == false
```

---

## Confidence Thresholds

| Parser | Threshold | Action when below |
|---|---|---|
| `NlpParser` | 0.75 | Fall through to Gemini |
| `SMSRegexParser.isHighConfidence` | 0.80 | Fall through to Gemini |
| Gemini response | 0.70 | `needs_review: true` → show confirm sheet |

---

## Common Issues

**CategoryDetector.ensureLoaded()** must be called before any `NlpParser.parse()` call. Skipping this causes category to always return the default category. Call it once at screen init, not on every parse.

**Image + responseMimeType causes 422:** The edge function disables `responseMimeType: "application/json"` for image requests. Do not re-enable it — this breaks Gemini 2.0 Flash image requests.

**Gemini cold start latency:** First parse after function deploy can take 3–5 seconds. Subsequent parses average 1–2 seconds.

---

## Related Documentation

- [Prompts Reference](prompts-reference.md) — all 28 prompts, versioning, placeholders
- [Training Data](training-data.md) — `ai_parse_logs` correction pipeline
- [Gemini Integration](../integrations/gemini.md) — API details, cost, setup
