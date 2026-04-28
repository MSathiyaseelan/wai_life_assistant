# AI Training Data System

---

## Overview

WAI has a correction logging system that captures when users edit AI-parsed results. This data is stored in `ai_parse_logs` and is designed as the foundation for future prompt improvement and fine-tuning.

---

## `ai_parse_logs` Table

Every AI parse (whether the user accepts or corrects it) is logged:

```sql
CREATE TABLE ai_parse_logs (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
  feature       TEXT        NOT NULL,
  sub_feature   TEXT        NOT NULL,
  input_type    TEXT        NOT NULL,        -- 'text' | 'image'
  prompt_id     UUID        REFERENCES ai_prompts(id),
  tokens_used   INTEGER,
  latency_ms    INTEGER,
  was_corrected BOOLEAN     NOT NULL DEFAULT FALSE,
  correction    JSONB,                       -- { original: {...}, corrected: {...} }
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## Current State

### What works now

The edge function logs every parse fire-and-forget:

```typescript
// supabase/functions/parse/index.ts
supabase.from('ai_parse_logs').insert({
  feature,
  sub_feature,
  input_type,
  prompt_id: prompt.id,
  tokens_used: usage?.totalTokenCount,
  latency_ms: Date.now() - startTime,
  user_id,
  was_corrected: false,   // default; updated by client if user edits
}).then(() => {});
```

### What is not yet implemented

**Client-side correction writes are a stub.** When the user edits a field in `IntentConfirmSheet` or `PantryIntentConfirmSheet`, the schema supports writing back:

```dart
// This write is NOT currently called from any client code:
await Supabase.instance.client.from('ai_parse_logs').update({
  'was_corrected': true,
  'correction': {
    'original': originalParsedData,
    'corrected': userEditedData,
  },
}).eq('id', parseLogId);
```

The `parse_log_id` is returned in `AIParseResult.meta` but is not stored on the client between the parse and the save.

---

## Correction Data Schema

When `was_corrected = true`, the `correction` JSONB stores a diff:

```json
{
  "original": {
    "amount": 250,
    "category": "Food",
    "type": "expense"
  },
  "corrected": {
    "amount": 250,
    "category": "Transport",
    "type": "expense"
  }
}
```

Only changed fields need to be present in `corrected` — the schema doesn't enforce this, but the convention makes analysis easier.

---

## Querying Training Data

### Most corrected sub_features

```sql
SELECT
  sub_feature,
  COUNT(*) FILTER (WHERE was_corrected = true)  AS corrections,
  COUNT(*)                                       AS total_parses,
  ROUND(
    COUNT(*) FILTER (WHERE was_corrected = true)::numeric / COUNT(*) * 100,
    1
  ) AS correction_rate_pct
FROM ai_parse_logs
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY sub_feature
ORDER BY correction_rate_pct DESC;
```

High correction rate = the prompt for that `sub_feature` needs improvement.

### Most common corrections by field

```sql
SELECT
  sub_feature,
  correction->'original'  AS was,
  correction->'corrected' AS became,
  COUNT(*) AS frequency
FROM ai_parse_logs
WHERE was_corrected = true
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY sub_feature, correction->'original', correction->'corrected'
ORDER BY frequency DESC
LIMIT 20;
```

### Category misclassification analysis

```sql
SELECT
  correction->'original'->>'category'  AS ai_said,
  correction->'corrected'->>'category' AS user_corrected_to,
  COUNT(*) AS occurrences
FROM ai_parse_logs
WHERE was_corrected = true
  AND correction->'original'->>'category' IS NOT NULL
  AND correction->'corrected'->>'category' IS NOT NULL
GROUP BY ai_said, user_corrected_to
ORDER BY occurrences DESC;
```

---

## How to Use This for Prompt Improvement

1. Run the correction rate query above. Find the sub_feature with the highest rate.

2. Pull raw correction examples:
```sql
SELECT
  feature, sub_feature,
  correction->'original'  AS original_parse,
  correction->'corrected' AS user_correction,
  created_at
FROM ai_parse_logs
WHERE sub_feature = 'expense'
  AND was_corrected = true
ORDER BY created_at DESC
LIMIT 50;
```

3. Identify the pattern — e.g., "the AI keeps saying Transport when users say Food for restaurant deliveries".

4. Add examples to the prompt as few-shot examples or tighten the category descriptions.

5. INSERT a new prompt version (see [prompts-reference.md](prompts-reference.md)).

6. Monitor the correction rate for that sub_feature over the next 7 days.

---

## Roadmap

The training data system is designed for these future improvements (not yet implemented):

| Phase | Description |
|---|---|
| **Phase 1** (current) | Log parses + `was_corrected` flag (edge function logs, client writes stub) |
| **Phase 2** | Implement client-side correction writes from `IntentConfirmSheet` |
| **Phase 3** | Weekly batch job: extract top corrections per sub_feature, auto-generate few-shot examples |
| **Phase 4** | Fine-tuned model or Gemini context caching for high-volume sub_features |

---

## Related Documentation

- [Prompts Reference](prompts-reference.md) — how to update prompts based on correction data
- [Smart Parser Architecture](smart-parser.md) — where `ai_parse_logs` is written
- [Error Tracking: Metric 6](../operations/error-tracking.md) — AI parse error rate monitoring
