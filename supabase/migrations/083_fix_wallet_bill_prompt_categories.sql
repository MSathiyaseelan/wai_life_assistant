-- ─────────────────────────────────────────────────────────────────────────────
-- 083_fix_wallet_bill_prompt_categories.sql
-- The 'wallet'/'bill' prompt (0170_ai_prompts.sql) was never actually wired
-- up to the Bill Watch screen — that screen instead had a dead client-side
-- direct-to-Anthropic call with a placeholder API key that always threw and
-- silently fell back to local parsing. Now that it's being wired to this
-- prompt (via AIParser, same as every other PlanIt feature), fix two real
-- mismatches between the prompt's output and what BillCategory/RepeatMode
-- (lib/data/models/planit/planit_models.dart) actually accept:
--   - category: prompt used utility/telecom/credit_card/custom, which don't
--     exist on BillCategory. Aligned to the enum's real values.
--   - recurrence: prompt allowed "quarterly", which RepeatMode doesn't have.
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE ai_prompts
SET
  schema_hint = '{
    "bill_name": "string",
    "amount": "number|null",
    "is_estimated": "boolean",
    "due_date": "YYYY-MM-DD",
    "recurrence": "none|daily|weekly|monthly|yearly",
    "category": "electricity|water|gas|internet|phone|insurance|school|rent|subscription|medical|emi|other",
    "scope": "personal|family",
    "confidence": "number"
  }'::jsonb,
  prompt = $$ROLE: You are a bill and subscription tracker parser for a household finance app.

TASK: Extract bill details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Current month: {{current_month}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "bill_name": "descriptive bill name",
  "amount": null,
  "is_estimated": true,
  "due_date": "{{today}}",
  "recurrence": "monthly",
  "recurrence_day": null,
  "category": "electricity",
  "scope": "family",
  "biller_hint": null,
  "confidence": 0.9
}

CATEGORY OPTIONS:
electricity, water, gas, internet, phone, insurance, school, rent, subscription, medical, emi, other

RECURRENCE RULES:
- monthly: every month, monthly, each month
- yearly: annual, yearly, once a year
- weekly: every week, weekly (rare for bills)
- daily: every day, daily (rare for bills)
- none: one-time, single payment

DUE DATE RULES:
- "15th every month" → recurrence_day: 15
- "due in 5 days" → today + 5 days
- "end of month" → last day of current month

SCOPE RULES:
- family: electricity, water, rent, gas, WiFi, internet, household
- personal: credit card, personal loan, OTT subscription, gym$$,
  updated_at = NOW()
WHERE feature = 'wallet' AND sub_feature = 'bill' AND input_type = 'text' AND version = 1;
