-- ============================================================
-- 131_add_notifications_delete_policy.sql
--
-- "Clear all" (and dismissing an individual invite notification) appeared
-- to work but always reverted on the next refresh — the notifications
-- table only ever had SELECT ("own rows") and UPDATE ("mark read")
-- policies, no DELETE policy at all. RLS defaults to deny any command
-- without an explicit permissive policy, so every client-side
-- NotificationService.dismiss()/clearAll() DELETE call was silently
-- affecting 0 rows the whole time.
--
-- (accept_family_invite/decline_family_invite's own DELETE calls were
-- unaffected by this — those run as SECURITY DEFINER functions, which
-- bypass RLS entirely, so that part of migration 128 worked correctly.)
-- ============================================================

CREATE POLICY "notifications: delete own rows" ON notifications
  FOR DELETE USING (auth.uid() = user_id);
