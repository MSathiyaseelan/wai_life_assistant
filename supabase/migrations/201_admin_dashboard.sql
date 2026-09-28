-- ============================================================
-- 201_admin_dashboard.sql
--
-- Backend for the admin dashboard web app (admin/). Everything the
-- dashboard reads or writes goes through the SECURITY DEFINER admin_*
-- functions below, each gated on dashboard_admins — the app's own tables
-- and RLS policies are left untouched.
--
-- dashboard_admins is deliberately separate from admin_users (158):
-- adding a row there grants the top paid plan, which dashboard access
-- should not.
--
-- Roles:
--   admin  — read everything, triage issues/errors, edit app_config
--   viewer — read-only
--
-- Add an admin (Supabase dashboard → Authentication → Add user, with an
-- email + password), then:
--   INSERT INTO dashboard_admins (user_id, role)
--   SELECT id, 'admin' FROM auth.users WHERE email = '<email>';
-- ============================================================

CREATE TABLE IF NOT EXISTS dashboard_admins (
  user_id   UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role      TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('admin', 'viewer')),
  note      TEXT,
  added_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE dashboard_admins ENABLE ROW LEVEL SECURITY;
-- No policies — service_role / SQL editor only, like admin_users.

-- ── Access helpers ──────────────────────────────────────────────────────────

-- The caller's dashboard role, or NULL. Used by the web app's login gate.
CREATE OR REPLACE FUNCTION admin_whoami()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM dashboard_admins WHERE user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION _admin_require(p_write BOOLEAN DEFAULT FALSE)
RETURNS VOID
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role TEXT := (SELECT role FROM dashboard_admins WHERE user_id = auth.uid());
BEGIN
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'Not a dashboard admin' USING ERRCODE = '42501';
  END IF;
  IF p_write AND v_role <> 'admin' THEN
    RAISE EXCEPTION 'Read-only dashboard access' USING ERRCODE = '42501';
  END IF;
END;
$$;

-- ── Overview ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TIMESTAMPTZ := NOW();
  v_result JSONB;
BEGIN
  PERFORM _admin_require();

  WITH app_users AS (
    SELECT p.* FROM profiles p
    WHERE NOT EXISTS (SELECT 1 FROM dashboard_admins d WHERE d.user_id = p.id)
  )
  SELECT jsonb_build_object(
    'users', jsonb_build_object(
      'total',     (SELECT COUNT(*) FROM app_users),
      'onboarded', (SELECT COUNT(*) FROM app_users WHERE onboarded),
      'new_7d',    (SELECT COUNT(*) FROM app_users WHERE created_at >= v_now - INTERVAL '7 days'),
      'new_30d',   (SELECT COUNT(*) FROM app_users WHERE created_at >= v_now - INTERVAL '30 days')
    ),
    'plans', COALESCE((
      SELECT jsonb_object_agg(plan_key, n) FROM (
        SELECT sp.plan_key, COUNT(*) n
        FROM wallet_subscriptions ws JOIN subscription_plans sp ON sp.id = ws.plan_id
        WHERE ws.status IN ('active', 'trialing')
        GROUP BY sp.plan_key
      ) x), '{}'::jsonb),
    'subscriptions', jsonb_build_object(
      'by_status', COALESCE((
        SELECT jsonb_object_agg(status, n) FROM (
          SELECT status, COUNT(*) n FROM wallet_subscriptions GROUP BY status
        ) x), '{}'::jsonb),
      'lapsing_7d', (
        SELECT COUNT(*) FROM wallet_subscriptions
        WHERE status = 'active' AND NOT auto_renew
          AND expires_at BETWEEN v_now AND v_now + INTERVAL '7 days'),
      'trials_ending_7d', (
        SELECT COUNT(*) FROM wallet_subscriptions
        WHERE trial_ends_at BETWEEN v_now AND v_now + INTERVAL '7 days')
    ),
    'issues', COALESCE((
      SELECT jsonb_object_agg(status, n) FROM (
        SELECT status, COUNT(*) n FROM issue_reports GROUP BY status
      ) x), '{}'::jsonb),
    'errors', jsonb_build_object(
      'last_24h',     (SELECT COUNT(*) FROM error_logs WHERE created_at >= v_now - INTERVAL '24 hours'),
      'last_7d',      (SELECT COUNT(*) FROM error_logs WHERE created_at >= v_now - INTERVAL '7 days'),
      'critical_7d',  (SELECT COUNT(*) FROM error_logs WHERE created_at >= v_now - INTERVAL '7 days' AND severity = 'critical'),
      'users_7d',     (SELECT COUNT(DISTINCT user_id) FROM error_logs WHERE created_at >= v_now - INTERVAL '7 days'),
      'new_unhandled',(SELECT COUNT(*) FROM error_logs WHERE status = 'new' AND created_at >= v_now - INTERVAL '7 days')
    ),
    'ai', jsonb_build_object(
      'calls_24h',  (SELECT COUNT(*) FROM ai_parse_logs WHERE created_at >= v_now - INTERVAL '24 hours'),
      'errors_24h', (SELECT COUNT(*) FROM ai_parse_logs WHERE created_at >= v_now - INTERVAL '24 hours' AND error IS NOT NULL),
      'calls_7d',   (SELECT COUNT(*) FROM ai_parse_logs WHERE created_at >= v_now - INTERVAL '7 days'),
      'avg_latency_ms_7d', (SELECT ROUND(AVG(latency_ms)) FROM ai_parse_logs WHERE created_at >= v_now - INTERVAL '7 days'),
      'tokens_7d',  (SELECT COALESCE(SUM(tokens_used), 0) FROM ai_parse_logs WHERE created_at >= v_now - INTERVAL '7 days')
    ),
    'generated_at', v_now
  ) INTO v_result;

  RETURN v_result;
END;
$$;

-- Per-day counts for the overview charts, bucketed in p_tz.
CREATE OR REPLACE FUNCTION admin_daily_series(p_days INT DEFAULT 30, p_tz TEXT DEFAULT 'Asia/Kolkata')
RETURNS TABLE (day DATE, signups BIGINT, errors BIGINT, ai_calls BIGINT, ai_errors BIGINT, issues BIGINT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_from DATE := (NOW() AT TIME ZONE p_tz)::date - (LEAST(GREATEST(p_days, 1), 365) - 1);
  v_since TIMESTAMPTZ := v_from::timestamp AT TIME ZONE p_tz;
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  WITH days AS (
    SELECT generate_series(v_from, (NOW() AT TIME ZONE p_tz)::date, INTERVAL '1 day')::date AS d
  ),
  su AS (
    SELECT (p.created_at AT TIME ZONE p_tz)::date d, COUNT(*) n FROM profiles p
    WHERE p.created_at >= v_since
      AND NOT EXISTS (SELECT 1 FROM dashboard_admins a WHERE a.user_id = p.id)
    GROUP BY 1
  ),
  er AS (
    SELECT (created_at AT TIME ZONE p_tz)::date d, COUNT(*) n FROM error_logs
    WHERE created_at >= v_since GROUP BY 1
  ),
  ai AS (
    SELECT (created_at AT TIME ZONE p_tz)::date d, COUNT(*) n, COUNT(*) FILTER (WHERE error IS NOT NULL) e
    FROM ai_parse_logs WHERE created_at >= v_since GROUP BY 1
  ),
  iss AS (
    SELECT (created_at AT TIME ZONE p_tz)::date d, COUNT(*) n FROM issue_reports
    WHERE created_at >= v_since GROUP BY 1
  )
  SELECT days.d,
         COALESCE(su.n, 0), COALESCE(er.n, 0), COALESCE(ai.n, 0), COALESCE(ai.e, 0), COALESCE(iss.n, 0)
  FROM days
  LEFT JOIN su  ON su.d  = days.d
  LEFT JOIN er  ON er.d  = days.d
  LEFT JOIN ai  ON ai.d  = days.d
  LEFT JOIN iss ON iss.d = days.d
  ORDER BY days.d;
END;
$$;

-- ── Reported issues ─────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_list_issues(
  p_status   TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_limit    INT  DEFAULT 50,
  p_offset   INT  DEFAULT 0
)
RETURNS TABLE (
  id UUID, user_id UUID, reporter_name TEXT, reporter_phone TEXT,
  category TEXT, title TEXT, description TEXT, screenshots TEXT[],
  device_info JSONB, priority TEXT, status TEXT, admin_note TEXT,
  created_at TIMESTAMPTZ, updated_at TIMESTAMPTZ, total_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT r.id, r.user_id, COALESCE(p.display_name, p.name), p.phone,
         r.category, r.title, r.description, r.screenshots::TEXT[],
         r.device_info, r.priority, r.status, r.admin_note,
         r.created_at, r.updated_at, COUNT(*) OVER ()
  FROM issue_reports r
  LEFT JOIN profiles p ON p.id = r.user_id
  WHERE (p_status IS NULL OR r.status = p_status)
    AND (p_category IS NULL OR r.category = p_category)
  ORDER BY r.created_at DESC
  LIMIT LEAST(p_limit, 200) OFFSET p_offset;
END;
$$;

-- Users see status + admin_note under "My reports" in the app.
CREATE OR REPLACE FUNCTION admin_update_issue(
  p_id UUID, p_status TEXT, p_priority TEXT, p_admin_note TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require(TRUE);
  IF p_status NOT IN ('open', 'in_progress', 'resolved', 'closed') THEN
    RAISE EXCEPTION 'Invalid status %', p_status;
  END IF;
  IF p_priority NOT IN ('low', 'medium', 'high') THEN
    RAISE EXCEPTION 'Invalid priority %', p_priority;
  END IF;

  UPDATE issue_reports
  SET status = p_status,
      priority = p_priority,
      admin_note = NULLIF(TRIM(p_admin_note), ''),
      updated_at = NOW()
  WHERE id = p_id;
END;
$$;

-- ── Error logs ──────────────────────────────────────────────────────────────

-- Errors grouped by (type, message, screen, action) — one row per distinct
-- problem rather than per occurrence.
CREATE OR REPLACE FUNCTION admin_error_groups(
  p_days     INT  DEFAULT 7,
  p_severity TEXT DEFAULT NULL,
  p_status   TEXT DEFAULT NULL,
  p_limit    INT  DEFAULT 100
)
RETURNS TABLE (
  error_type TEXT, error_message TEXT, screen_name TEXT, action TEXT,
  severity TEXT, occurrences BIGINT, users BIGINT,
  first_seen TIMESTAMPTZ, last_seen TIMESTAMPTZ,
  latest_version TEXT, latest_id UUID, new_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT e.error_type, e.error_message, e.screen_name, e.action,
         (ARRAY_AGG(e.severity ORDER BY e.created_at DESC))[1],
         COUNT(*), COUNT(DISTINCT e.user_id),
         MIN(e.created_at), MAX(e.created_at),
         (ARRAY_AGG(e.app_version || COALESCE('+' || e.build_number, '') ORDER BY e.created_at DESC))[1],
         (ARRAY_AGG(e.id ORDER BY e.created_at DESC))[1],
         COUNT(*) FILTER (WHERE e.status = 'new')
  FROM error_logs e
  WHERE e.created_at >= NOW() - make_interval(days => LEAST(GREATEST(p_days, 1), 365))
    AND (p_severity IS NULL OR e.severity = p_severity)
    AND (p_status IS NULL OR e.status = p_status)
  GROUP BY e.error_type, e.error_message, e.screen_name, e.action
  ORDER BY MAX(e.created_at) DESC
  LIMIT LEAST(p_limit, 500);
END;
$$;

-- Recent occurrences of one error group, newest first.
CREATE OR REPLACE FUNCTION admin_error_occurrences(
  p_error_type TEXT, p_error_message TEXT, p_screen_name TEXT, p_action TEXT,
  p_limit INT DEFAULT 25
)
RETURNS TABLE (
  id UUID, created_at TIMESTAMPTZ, user_id UUID, user_name TEXT,
  severity TEXT, status TEXT, stack_trace TEXT, feature TEXT,
  device_os TEXT, os_version TEXT, device_model TEXT,
  app_version TEXT, build_number TEXT, was_online BOOLEAN, extra_data JSONB
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT e.id, e.created_at, e.user_id, COALESCE(p.display_name, p.name),
         e.severity, e.status, e.stack_trace, e.feature,
         e.device_os, e.os_version, e.device_model,
         e.app_version, e.build_number, e.was_online, e.extra_data
  FROM error_logs e
  LEFT JOIN profiles p ON p.id = e.user_id
  WHERE e.error_type    IS NOT DISTINCT FROM p_error_type
    AND e.error_message IS NOT DISTINCT FROM p_error_message
    AND e.screen_name   IS NOT DISTINCT FROM p_screen_name
    AND e.action        IS NOT DISTINCT FROM p_action
  ORDER BY e.created_at DESC
  LIMIT LEAST(p_limit, 200);
END;
$$;

-- Marks every occurrence of an error group (new / acknowledged / resolved /
-- ignored). Returns the number of rows updated.
CREATE OR REPLACE FUNCTION admin_set_error_status(
  p_error_type TEXT, p_error_message TEXT, p_screen_name TEXT, p_action TEXT,
  p_status TEXT
)
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count INT;
BEGIN
  PERFORM _admin_require(TRUE);
  IF p_status NOT IN ('new', 'acknowledged', 'resolved', 'ignored') THEN
    RAISE EXCEPTION 'Invalid status %', p_status;
  END IF;

  UPDATE error_logs e
  SET status = p_status
  WHERE e.error_type    IS NOT DISTINCT FROM p_error_type
    AND e.error_message IS NOT DISTINCT FROM p_error_message
    AND e.screen_name   IS NOT DISTINCT FROM p_screen_name
    AND e.action        IS NOT DISTINCT FROM p_action;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ── Users ───────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_list_users(
  p_search TEXT DEFAULT NULL,
  p_limit  INT  DEFAULT 50,
  p_offset INT  DEFAULT 0
)
RETURNS TABLE (
  id UUID, name TEXT, emoji TEXT, phone TEXT, plan TEXT, onboarded BOOLEAN,
  created_at TIMESTAMPTZ, families BIGINT, issues BIGINT, errors_7d BIGINT,
  ai_calls_30d BIGINT, total_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_q TEXT := NULLIF(TRIM(p_search), '');
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT p.id, COALESCE(p.display_name, p.name), p.emoji, p.phone, p.plan, p.onboarded,
         p.created_at,
         (SELECT COUNT(*) FROM family_members fm WHERE fm.user_id = p.id AND fm.deleted_at IS NULL),
         (SELECT COUNT(*) FROM issue_reports r WHERE r.user_id = p.id),
         (SELECT COUNT(*) FROM error_logs e WHERE e.user_id = p.id AND e.created_at >= NOW() - INTERVAL '7 days'),
         (SELECT COUNT(*) FROM ai_parse_logs a WHERE a.user_id = p.id AND a.created_at >= NOW() - INTERVAL '30 days'),
         COUNT(*) OVER ()
  FROM profiles p
  WHERE NOT EXISTS (SELECT 1 FROM dashboard_admins d WHERE d.user_id = p.id)
    AND (v_q IS NULL
         OR p.name ILIKE '%' || v_q || '%'
         OR p.display_name ILIKE '%' || v_q || '%'
         OR p.phone ILIKE '%' || v_q || '%')
  ORDER BY p.created_at DESC
  LIMIT LEAST(p_limit, 200) OFFSET p_offset;
END;
$$;

-- ── Subscriptions ───────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_list_subscriptions(
  p_status TEXT DEFAULT NULL,
  p_limit  INT  DEFAULT 100,
  p_offset INT  DEFAULT 0
)
RETURNS TABLE (
  id UUID, wallet_id UUID, wallet_name TEXT, is_personal BOOLEAN,
  owner_name TEXT, owner_phone TEXT, plan_key TEXT, plan_name TEXT,
  status TEXT, auto_renew BOOLEAN, started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ, trial_ends_at TIMESTAMPTZ,
  payment_reference TEXT, total_count BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT ws.id, ws.wallet_id, w.name, w.is_personal,
         COALESCE(p.display_name, p.name), p.phone, sp.plan_key, sp.name,
         ws.status, ws.auto_renew, ws.started_at, ws.expires_at, ws.trial_ends_at,
         ws.payment_reference, COUNT(*) OVER ()
  FROM wallet_subscriptions ws
  LEFT JOIN wallets w             ON w.id = ws.wallet_id
  LEFT JOIN profiles p            ON p.id = w.owner_id
  LEFT JOIN subscription_plans sp ON sp.id = ws.plan_id
  WHERE (p_status IS NULL OR ws.status = p_status)
  ORDER BY ws.expires_at NULLS LAST
  LIMIT LEAST(p_limit, 500) OFFSET p_offset;
END;
$$;

-- ── AI usage ────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_ai_stats(p_days INT DEFAULT 7)
RETURNS TABLE (
  feature TEXT, sub_feature TEXT, calls BIGINT, errors BIGINT,
  corrected BIGINT, users BIGINT, avg_latency_ms NUMERIC,
  avg_confidence NUMERIC, tokens BIGINT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT a.feature, a.sub_feature, COUNT(*),
         COUNT(*) FILTER (WHERE a.error IS NOT NULL),
         COUNT(*) FILTER (WHERE a.was_corrected),
         COUNT(DISTINCT a.user_id),
         ROUND(AVG(a.latency_ms)),
         ROUND(AVG(a.confidence)::NUMERIC, 2),
         COALESCE(SUM(a.tokens_used), 0)
  FROM ai_parse_logs a
  WHERE a.created_at >= NOW() - make_interval(days => LEAST(GREATEST(p_days, 1), 365))
  GROUP BY a.feature, a.sub_feature
  ORDER BY COUNT(*) DESC;
END;
$$;

CREATE OR REPLACE FUNCTION admin_ai_recent_errors(p_limit INT DEFAULT 50)
RETURNS TABLE (
  id UUID, created_at TIMESTAMPTZ, feature TEXT, sub_feature TEXT,
  input_type TEXT, error TEXT, raw_input TEXT, user_name TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();

  RETURN QUERY
  SELECT a.id, a.created_at, a.feature, a.sub_feature, a.input_type,
         a.error, a.raw_input, COALESCE(p.display_name, p.name)
  FROM ai_parse_logs a
  LEFT JOIN profiles p ON p.id = a.user_id
  WHERE a.error IS NOT NULL
  ORDER BY a.created_at DESC
  LIMIT LEAST(p_limit, 200);
END;
$$;

-- ── App config ──────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION admin_list_config()
RETURNS SETOF app_config
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require();
  RETURN QUERY SELECT * FROM app_config ORDER BY key;
END;
$$;

-- Edits existing keys only — new keys are added by migrations, so the app
-- code that reads them ships alongside.
CREATE OR REPLACE FUNCTION admin_set_config(p_key TEXT, p_value TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM _admin_require(TRUE);
  UPDATE app_config SET value = p_value WHERE key = p_key;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Unknown config key %', p_key;
  END IF;
END;
$$;

-- ── Grants ──────────────────────────────────────────────────────────────────
-- Functions are executable by PUBLIC by default; limit to signed-in users
-- (each one still checks dashboard_admins itself).
DO $$
DECLARE
  f TEXT;
BEGIN
  FOREACH f IN ARRAY ARRAY[
    'admin_whoami()',
    '_admin_require(boolean)',
    'admin_overview()',
    'admin_daily_series(int, text)',
    'admin_list_issues(text, text, int, int)',
    'admin_update_issue(uuid, text, text, text)',
    'admin_error_groups(int, text, text, int)',
    'admin_error_occurrences(text, text, text, text, int)',
    'admin_set_error_status(text, text, text, text, text)',
    'admin_list_users(text, int, int)',
    'admin_list_subscriptions(text, int, int)',
    'admin_ai_stats(int)',
    'admin_ai_recent_errors(int)',
    'admin_list_config()',
    'admin_set_config(text, text)'
  ] LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', f);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', f);
  END LOOP;
END $$;
