-- ============================================================
--  WAI Life Assistant — Appointment, Vital, Vaccination & Insurance AI Prompts
-- ============================================================

-- ── Appointment ───────────────────────────────────────────────

INSERT INTO ai_prompts (feature, sub_feature, input_type, version, notes, schema_hint, prompt) VALUES

('lifestyle', 'appointment', 'text', 1,
 'Parse appointment details from plain English description',
'{
  "doctor_name": "string",
  "date": "YYYY-MM-DD|null",
  "time": "string|null",
  "location": "string|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are an appointment data parser for an Indian personal health tracking app.

TASK: Extract structured appointment details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "doctor_name": "",
  "date": null,
  "time": null,
  "location": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

doctor_name:
- Doctor name, hospital name, or department (e.g. "Dr. Ramesh Kumar", "Apollo Hospital", "Cardiology OPD")
- Keep as provided — do not strip titles

date:
- Return in YYYY-MM-DD format
- Resolve relative dates using today={{today}}: "tomorrow" → next day, "next Monday" → compute from today
- Return null if no date mentioned

time:
- Time of appointment as a string (e.g. "10:30 AM", "3:00 PM", "morning")
- Return null if not mentioned

location:
- Clinic, hospital, floor, room, or address (e.g. "Ground floor OPD", "Apollo Hospital Greams Road")
- Return null if not mentioned

notes:
- Any extra instructions (bring reports, fasting required, follow-up, etc.)
- Return null if nothing extra

confidence:
- 0.95 if doctor_name and date both found
- 0.8 if only one main field found
- 0.6 if ambiguous$$
),

-- ── Vital ─────────────────────────────────────────────────────

('lifestyle', 'vital', 'text', 1,
 'Parse health vital reading from plain English description',
'{
  "vital_type": "bloodPressure|bloodSugar|weight|temperature|spo2|heartRate",
  "value": "number",
  "value2": "number|null",
  "sub_type": "string|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a health vitals parser for an Indian personal health tracking app.

TASK: Extract structured vital reading details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "vital_type": "heartRate",
  "value": 0,
  "value2": null,
  "sub_type": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

vital_type — MUST be exactly one of these enum names:
- "bloodPressure"  → BP, blood pressure, systolic/diastolic
- "bloodSugar"     → glucose, sugar, RBS, FBS, PPBS, HbA1c (treat as blood sugar)
- "weight"         → weight, kg, body weight
- "temperature"    → temp, fever, °C, °F (convert F to C: (F-32)×5/9)
- "spo2"           → oxygen saturation, SpO2, pulse ox, %
- "heartRate"      → heart rate, pulse, bpm

value:
- Primary numeric value (no units)
- For blood pressure: systolic (higher number)
- For weight: in kg
- For temperature: in °C

value2:
- Secondary value only for blood pressure: diastolic (lower number)
- null for all other types

sub_type:
- For blood sugar only: "Fasting", "Post-meal", "Random" — infer from context
- null for all other types

notes:
- Any extra context (device used, condition, remarks)
- null if nothing extra

confidence:
- 0.95 if type and value clearly identified
- 0.7 if inferred from context$$
),

-- ── Vaccination ───────────────────────────────────────────────

('lifestyle', 'vaccination', 'text', 1,
 'Parse vaccination details from plain English description',
'{
  "vaccine_name": "string",
  "dose_number": "number|null",
  "date_given": "YYYY-MM-DD|null",
  "next_due": "YYYY-MM-DD|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a vaccination record parser for an Indian personal health tracking app.

TASK: Extract structured vaccination details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "vaccine_name": "",
  "dose_number": null,
  "date_given": null,
  "next_due": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

vaccine_name:
- Standard vaccine name in title case (e.g. "Covishield", "Covaxin", "Hepatitis B", "MMR", "Typhoid", "Flu")
- Strip manufacturer noise, keep the vaccine/disease name

dose_number:
- Integer dose number if mentioned (e.g. "dose 1", "second dose", "booster" → null)
- null if not mentioned or if booster (booster is not a numbered dose)

date_given:
- Date the vaccine was administered, in YYYY-MM-DD format
- Resolve relative dates using today={{today}}
- null if not mentioned

next_due:
- Date of next dose or booster, in YYYY-MM-DD format
- Compute from context if possible (e.g. "next due in 6 months" → add 6 months to date_given)
- null if not mentioned

notes:
- Any extra info (batch number, clinic, side effects, etc.)
- null if nothing extra

confidence:
- 0.95 if vaccine name and at least one date found
- 0.8 if name only
- 0.6 if ambiguous$$
),

-- ── Insurance Policy ──────────────────────────────────────────

('lifestyle', 'insurance_policy', 'text', 1,
 'Parse health insurance policy details from plain English description',
'{
  "policy_name": "string",
  "policy_number": "string|null",
  "provider": "string|null",
  "coverage_amount": "number|null",
  "expiry_date": "YYYY-MM-DD|null",
  "notes": "string|null",
  "confidence": "number"
}'::jsonb,
$$ROLE: You are a health insurance record parser for an Indian personal health tracking app.

TASK: Extract structured insurance policy details from this plain text input.

Input: "{{text}}"
Today is: {{today}}

Return ONLY valid JSON matching this exact structure — no explanation, no markdown:
{
  "policy_name": "",
  "policy_number": null,
  "provider": null,
  "coverage_amount": null,
  "expiry_date": null,
  "notes": null,
  "confidence": 0.9
}

FIELD RULES:

policy_name:
- Short descriptive name for the policy (e.g. "Family Floater", "Individual Health", "Critical Illness")
- If user gives a product name like "Star Comprehensive", use that

policy_number:
- Alphanumeric policy ID as a string
- Return null if not mentioned

provider:
- Insurance company name (e.g. "Star Health", "HDFC Ergo", "Niva Bupa", "LIC Health")
- Return null if not mentioned

coverage_amount:
- Sum insured in rupees as a plain number (no ₹ or commas)
- Convert "5 lakhs" → 500000, "10 lakh" → 1000000, "1 crore" → 10000000
- Return null if not mentioned

expiry_date:
- Policy expiry / renewal date in YYYY-MM-DD format
- Resolve month+year inputs to last day of that month (e.g. "expires Jan 2026" → "2026-01-31")
- Return null if not mentioned

notes:
- Any extra info (premium amount, agent name, linked members, etc.)
- Return null if nothing extra

confidence:
- 0.95 if policy_name and at least one other field found
- 0.8 if name only
- 0.6 if ambiguous$$
);
