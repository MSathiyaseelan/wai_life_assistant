-- ─────────────────────────────────────────────────────────────────────────────
-- 084_travel_board_ai_prompt.sql
-- Travel Board never had a Gemini prompt — it had a dead client-side
-- direct-to-Anthropic call (_TripClaudeParser) with a placeholder API key
-- that always threw and silently fell back to local parsing. This adds a
-- real prompt so it can be wired through AIParser like every other PlanIt
-- feature.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt)
VALUES (
'planit', 'travel', 'text', 1, 'Parse trip/travel plan from plain text',
'{
  "title": "string",
  "emoji": "string",
  "destinations": ["string"],
  "travel_mode": "flight|train|car|bus|bike|ship|mixed",
  "start_date": "YYYY-MM-DD|null",
  "end_date": "YYYY-MM-DD|null",
  "budget": "number|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a trip and travel planning parser for a family life management app.

TASK: Extract trip details from this plain text input.

Input: "{{text}}"
Today is: {{today}}
Family members: {{members}}

Return ONLY valid JSON — no explanation, no markdown:
{
  "title": "concise trip name",
  "emoji": "single best emoji for the trip",
  "destinations": [],
  "travel_mode": "mixed",
  "start_date": null,
  "end_date": null,
  "budget": null,
  "member_ids": ["me"],
  "note": null,
  "confidence": 0.9
}

TITLE RULES:
- "Goa trip in December" → "Goa Trip"
- If multiple destinations, use the first or a general name ("South India Trip")

EMOJI RULES:
- Beach destination → 🏖️, mountains → ⛰️, pilgrimage → 🙏, generic → ✈️

DESTINATIONS:
- Extract every place mentioned, in the order mentioned
- "Goa" → ["Goa"], "Delhi then Agra then Jaipur" → ["Delhi", "Agra", "Jaipur"]

TRAVEL MODE OPTIONS:
flight, train, car, bus, bike, ship, mixed
- Infer from context ("driving to" → car, "flying to" → flight)
- Default to mixed if not mentioned and destination is far/international

DATE RULES:
- "in December" → 1st of next December (or this December if not yet passed)
- "next week" → next Monday from {{today}}
- "for 5 days from the 10th" → start_date = 10th, end_date = start + 5 days
- Not mentioned → null

BUDGET:
- Extract if mentioned ("budget of 50000" → 50000, "1.5 lakh" → 150000)
- null if not mentioned

MEMBERS:
- "me and family" / "whole family" → member_ids matching {{members}}
- Not mentioned → ["me"]$$
);
