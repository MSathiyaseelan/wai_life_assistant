-- ============================================================
-- 169_nlp_parser_enabled_flag.sql
--
-- The local deterministic NLP parser (lib/features/wallet/AI/nlp_parser.dart)
-- has had a string of correctness bugs found in quick succession (title
-- going blank, "150 lunch" parsed as ₹15,000,000, "for FZ bike" mistaken
-- for a person named FZ). Rather than trust it while further testing is
-- still ongoing, this flag lets it be switched off app-wide (Dashboard AI
-- Assistant's and Wallet quick-add's pre-AI shortcut, and Wallet's
-- on-AI-failure fallback) without a redeploy — flip back to 'true' once
-- confident in it again.
-- ============================================================

INSERT INTO app_config (key, value, description) VALUES
  ('nlp_parser_enabled', 'false', 'Whether the local deterministic NLP parser can run in Dashboard AI Assistant / Wallet quick-add. When false, those flows always go through the AI parser (with a blank manual-entry fallback if the AI call itself fails).')
ON CONFLICT (key) DO NOTHING;
