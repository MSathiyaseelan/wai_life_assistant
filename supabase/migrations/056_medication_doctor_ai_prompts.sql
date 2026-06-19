-- ============================================================
--  WAI Life Assistant — Medication & Doctor AI Prompts
-- ============================================================

-- ── Medication ────────────────────────────────────────────────

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt) VALUES

('lifestyle', 'medication', 'text', 1,
 'Parse medication details from plain English description',
'{
  "name": "string",
  "dosage": "string|null",
  "frequency": "string|null",
  "schedule_times": "string[]",
  "meal_timing": "string|null",
  "duration_label": "string|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a medication data parser for an Indian personal health tracking app.

TASK: Extract structured medication details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "name": "",
  "dosage": null,
  "frequency": null,
  "schedule_times": [],
  "meal_timing": null,
  "duration_label": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

name:
- Medicine / drug name only (e.g. "Metformin", "Paracetamol", "Vitamin D3")
- Title case, exclude dosage and brand noise

dosage:
- Numeric value + unit (e.g. "500mg", "10ml", "1000 IU", "2 tablets")
- Return null if not mentioned

frequency:
- How often taken — free text is fine (e.g. "Twice daily", "Once a day", "Every 8 hours", "As needed")
- Return null if not mentioned

schedule_times:
- Array of: "Morning", "Afternoon", "Evening", "Night"
- Only include those explicitly mentioned or strongly implied
- Return [] if not mentioned

meal_timing:
- "Before food" or "After food" only
- Return null if not mentioned

duration_label:
- Must be EXACTLY one of: "3 Days", "5 Days", "7 Days", "10 Days", "14 Days", "1 Month", "3 Months", "6 Months", "Ongoing"
- Map naturally: "1 week" → "7 Days", "two weeks" → "14 Days", "lifelong"/"chronic" → "Ongoing"
- Return null if duration not mentioned

notes:
- Any additional instructions or remarks not captured above (e.g. "avoid in empty stomach", "take with warm water")
- Return null if nothing extra

confidence:
- 0.95 if name clearly stated and most fields found
- 0.8 if some fields inferred
- 0.6 if only name found$$
),

-- ── Doctor ────────────────────────────────────────────────────

('lifestyle', 'doctor', 'text', 1,
 'Parse doctor/specialist details from plain English description',
'{
  "name": "string",
  "specialty": "string|null",
  "hospital": "string|null",
  "phone": "string|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a doctor record parser for an Indian personal health tracking app.

TASK: Extract structured doctor details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "name": "",
  "specialty": null,
  "hospital": null,
  "phone": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

name:
- Doctor's name only, without "Dr." prefix (e.g. "Ramesh Kumar", "Priya Sharma")
- Strip "Dr." / "Doctor" prefix if present

specialty:
- Medical specialty in title case (e.g. "Cardiologist", "Dermatologist", "General Physician", "Orthopedic Surgeon")
- Use standard medical specialty names
- Return null if not mentioned

hospital:
- Hospital or clinic name (e.g. "Apollo Hospital, Chennai", "City Clinic")
- Include city if mentioned
- Return null if not mentioned

phone:
- Phone number, digits only, no spaces or dashes (e.g. "9876543210")
- Return null if not mentioned

notes:
- Any additional info (consultation timings, referral reason, next appointment context, etc.)
- Return null if nothing extra

confidence:
- 0.95 if name and at least one other field found
- 0.8 if name only clearly stated
- 0.6 if ambiguous$$
);
