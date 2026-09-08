-- ─────────────────────────────────────────────────────────────────────────────
-- 172_plan_expiry_banner_copy_config.sql
-- Moves the dashboard "plan about to expire" renewal banner's wording out
-- of the client (previously hardcoded in family_plan_expiry_banner.dart)
-- and into app_config, following the same pattern as plan_expiry_banner_days
-- (171) — so copy can be changed or A/B'd with an UPDATE statement, no app
-- deployment required.
--
-- plan_expiry_banner_title_template must contain a literal "{days}"
-- placeholder — the client substitutes it with the actual day count for
-- anything beyond tomorrow (today/tomorrow use their own dedicated keys).
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO app_config (key, value, description) VALUES
  ('plan_expiry_banner_title_today', 'Your family plan expires today', 'Dashboard renewal banner title when the plan lapses today.'),
  ('plan_expiry_banner_title_tomorrow', 'Your family plan expires tomorrow', 'Dashboard renewal banner title when the plan lapses tomorrow.'),
  ('plan_expiry_banner_title_template', 'Your family plan expires in {days} days', 'Dashboard renewal banner title for 2+ days out — {days} is substituted client-side.'),
  ('plan_expiry_banner_subtitle', 'Renew to keep your family group''s features active.', 'Dashboard renewal banner subtitle text.'),
  ('plan_expiry_banner_cta', 'Renew Now', 'Dashboard renewal banner call-to-action button label.')
ON CONFLICT (key) DO NOTHING;
