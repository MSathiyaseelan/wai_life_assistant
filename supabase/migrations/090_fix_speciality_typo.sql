-- ─────────────────────────────────────────────────────────────────────────────
-- 090_fix_speciality_typo.sql
-- The dashboard AI Assistant's write-action prompt (049/051/052) has a
-- "speciality" (misspelled) field baked into two action schemas:
--   - add_appointment: health_appointments has NO specialty-type column at
--     all (see 046_health_schema.sql) — the field shouldn't exist here.
--     Every "book an appointment" action was throwing PGRST204
--     ("Could not find the 'speciality' column of 'health_appointments'").
--   - add_doctor: health_doctors DOES have this column, but it's spelled
--     "specialty" (046_health_schema.sql), not "speciality" — same
--     PGRST204 failure whenever the AI included a specialty.
-- Uses the same targeted replace() pattern as 059_ai_grocery_is_grocery_field.sql
-- so it only edits these two lines rather than reinserting the whole
-- prompt (which would silently revert 059's already-applied is_grocery change).
-- ─────────────────────────────────────────────────────────────────────────────

UPDATE ai_prompts
SET prompt = replace(
  prompt,
  'add_appointment — book a doctor appointment
  data: { "doctor_name": "Dr. Rajesh", "speciality": "Cardiologist", "appt_date": "YYYY-MM-DD", "notes": "" }',

  'add_appointment — book a doctor appointment
  data: { "doctor_name": "Dr. Rajesh", "appt_date": "YYYY-MM-DD", "notes": "" }'
)
WHERE feature = 'dashboard'
  AND sub_feature = 'ai_assistant'
  AND is_active = true;

UPDATE ai_prompts
SET prompt = replace(
  prompt,
  'add_doctor — add a doctor to your records
  data: { "name": "Dr. Priya", "speciality": "Dermatologist", "phone": "9876543210", "hospital": "Apollo Hospital", "notes": "" }',

  'add_doctor — add a doctor to your records
  data: { "name": "Dr. Priya", "specialty": "Dermatologist", "phone": "9876543210", "hospital": "Apollo Hospital", "notes": "" }'
)
WHERE feature = 'dashboard'
  AND sub_feature = 'ai_assistant'
  AND is_active = true;
