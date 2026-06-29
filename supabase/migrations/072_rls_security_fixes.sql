-- ══════════════════════════════════════════════════════════════
-- 072_rls_security_fixes.sql
-- Closes three RLS gaps identified in security audit:
--   1. notifications INSERT policy was open to any authenticated user
--   2. user_fcm_tokens had no RLS at all
--   3. dev_link_profile_by_phone had no REVOKE (callable by any user)
-- ══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
-- 1. NOTIFICATIONS — remove the blanket INSERT policy
--    The trigger function that inserts notifications runs as
--    SECURITY DEFINER and bypasses RLS entirely, so this policy
--    was never needed and allowed any user to forge notifications
--    for another user's account.
-- ─────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "notifications: service insert" ON notifications;


-- ─────────────────────────────────────────────────────────────
-- 2. USER_FCM_TOKENS — enable RLS (table was created without it)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE user_fcm_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "fcm_own_select" ON user_fcm_tokens
  FOR SELECT TO authenticated USING (user_id = auth.uid());

CREATE POLICY "fcm_own_insert" ON user_fcm_tokens
  FOR INSERT TO authenticated WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_own_update" ON user_fcm_tokens
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "fcm_own_delete" ON user_fcm_tokens
  FOR DELETE TO authenticated USING (user_id = auth.uid());


-- ─────────────────────────────────────────────────────────────
-- 3. DEV_LINK_PROFILE_BY_PHONE — restrict to service_role only
--    This was a dev/migration utility; no end-user should be
--    able to call it. Revoke PUBLIC execute so it cannot be
--    invoked via PostgREST RPC by any authenticated client.
-- ─────────────────────────────────────────────────────────────
REVOKE ALL ON FUNCTION dev_link_profile_by_phone(TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION dev_link_profile_by_phone(TEXT) TO service_role;
