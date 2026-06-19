-- ============================================================
--  WAI Life Assistant — Health Profile AI Prompt
-- ============================================================

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt) VALUES

('lifestyle', 'health_profile', 'text', 1,
 'Parse health profile details from plain English description',
'{
  "blood_group": "string|null",
  "height": "string|null",
  "weight": "string|null",
  "allergies": "string[]",
  "conditions": "string[]",
  "disabilities": "string[]",
  "emergency_contact": "string|null",
  "emergency_phone": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a health data parser for an Indian personal health tracking app.

TASK: Extract structured health profile details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "blood_group": null,
  "height": null,
  "weight": null,
  "allergies": [],
  "conditions": [],
  "disabilities": [],
  "emergency_contact": null,
  "emergency_phone": null,
  "confidence": 0.9
}

FIELD RULES:

blood_group:
- Normalise to standard format: A+, A-, B+, B-, AB+, AB-, O+, O-
- Accept: "O positive", "B negative", "AB+", "o pos", "b-ve" etc.
- Return null if not mentioned

height:
- Extract numeric value only (no units) in cm
- Convert if needed: 5'9" → "175", 5 feet 8 inches → "173"
- If given in cm already, return as-is string e.g. "172"
- Return null if not mentioned

weight:
- Extract numeric value only (no units) in kg
- If given in kg, return as string e.g. "68"
- Return null if not mentioned

allergies:
- List any mentioned allergies as individual strings
- Common examples: penicillin, peanuts, dust, pollen, shellfish, latex, sulfa drugs
- Normalise to title case, singular form
- Return [] if none mentioned

conditions:
- List any chronic conditions, diseases, or medical history as individual strings
- Common examples: Diabetes, Hypertension, Asthma, Thyroid, Arthritis, Migraine, PCOD, Anemia, Epilepsy, Depression, High Cholesterol, Heart Disease
- Normalise to standard medical name in title case
- Return [] if none mentioned

disabilities:
- List any physical or mental disabilities, special needs as individual strings
- Return [] if none mentioned

emergency_contact:
- Person's name to contact in emergency
- Return null if not mentioned

emergency_phone:
- Emergency contact phone number (digits only, no formatting)
- Return null if not mentioned

confidence:
- 0.95 if all main fields clearly stated
- 0.8 if some fields inferred or partially stated
- 0.6 if only 1-2 fields found$$
);
