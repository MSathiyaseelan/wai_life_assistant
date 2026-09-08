-- ─────────────────────────────────────────────────────────────────────────────
-- 173_health_space_enabled_override.sql
-- Health Space is currently gated by a build-time --dart-define flag
-- (FeatureFlags.healthSpaceEnabled, env/prod.json sets it false because
-- declaring Health features on Play Console requires a verified
-- Organization developer account this app doesn't have yet). A compile-time
-- flag means re-enabling it — or disabling it in an emergency if Play
-- Console flags it after the fact — requires shipping a new build.
--
-- This adds a runtime override read once at app-state init
-- (AppConfigService.fetchHealthSpaceEnabledOverride, applied via
-- FeatureFlags.applyHealthSpaceEnabledOverride): set the value to 'true' or
-- 'false' to force that state immediately for all users, or leave it as
-- the 'inherit' sentinel to keep deferring to the build-time flag — the
-- safe fallback if this table is ever unreachable.
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO app_config (key, value, description) VALUES
  ('health_space_enabled_override', 'inherit', 'Overrides FeatureFlags.healthSpaceEnabled at runtime. ''true''/''false'' to force that state; ''inherit'' to defer to the build-time --dart-define flag (the safe default).')
ON CONFLICT (key) DO NOTHING;
