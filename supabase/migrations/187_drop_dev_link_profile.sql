-- ============================================================
-- 187_drop_dev_link_profile.sql
--
-- dev_link_profile_by_phone() was a dev-only bypass helper (009) that
-- merges one user's entire account (wallets, transactions, families,
-- split groups) into the caller's account by phone number, then
-- deletes the old profile. It was already locked down to service_role
-- only in 072 (REVOKE ALL ... FROM PUBLIC), so it hasn't been callable
-- by end users for a while — but the pre-release checklist
-- (docs/operations/deployment.md) still flags it as needing to be
-- dropped outright from production, and nothing calls it anymore
-- (the Dart wrapper ProfileService.linkProfileByPhone() had zero
-- callers — removed alongside this migration).
-- ============================================================

DROP FUNCTION IF EXISTS dev_link_profile_by_phone(TEXT);
