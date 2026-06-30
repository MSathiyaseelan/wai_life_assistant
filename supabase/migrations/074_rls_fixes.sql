-- ══════════════════════════════════════════════════════════════════════════════
-- 074_rls_fixes.sql
--
-- Fix 1: notes table — broken family-member UNION branch in all 4 policies.
--         family_members has no wallet_id column; correct path is
--         family_members.family_id → wallets.family_id.
--
-- Fix 2: families table — missing DELETE policy.
--         Without it, direct REST deletes are denied; only the SECURITY DEFINER
--         delete_family() RPC works. Add explicit policy for consistency and
--         so future code paths are not silently blocked.
--
-- Fix 3: purge_old_deleted_records() — SECURITY DEFINER function callable by
--         any authenticated user (PostgreSQL default: EXECUTE to PUBLIC).
--         An attacker can hard-delete soft-deleted rows across all users.
--         Restrict to service_role only (pg_cron runs as postgres/superuser).
-- ══════════════════════════════════════════════════════════════════════════════


-- ── Fix 1: notes RLS ──────────────────────────────────────────────────────────

DROP POLICY IF EXISTS "notes_select" ON public.notes;
DROP POLICY IF EXISTS "notes_insert" ON public.notes;
DROP POLICY IF EXISTS "notes_update" ON public.notes;
DROP POLICY IF EXISTS "notes_delete" ON public.notes;

-- Helper expression (used identically in all four policies):
--   Personal wallet owner  → wallets.owner_id = auth.uid()
--   Family wallet member   → family_members.family_id = wallets.family_id
--                            where the member's user_id = auth.uid()

CREATE POLICY "notes_select" ON public.notes
  FOR SELECT USING (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE owner_id = auth.uid()
      UNION
      SELECT w.id FROM public.wallets w
        WHERE w.family_id IN (
          SELECT family_id FROM public.family_members WHERE user_id = auth.uid()
        )
    )
  );

CREATE POLICY "notes_insert" ON public.notes
  FOR INSERT WITH CHECK (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE owner_id = auth.uid()
      UNION
      SELECT w.id FROM public.wallets w
        WHERE w.family_id IN (
          SELECT family_id FROM public.family_members WHERE user_id = auth.uid()
        )
    )
  );

CREATE POLICY "notes_update" ON public.notes
  FOR UPDATE USING (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE owner_id = auth.uid()
      UNION
      SELECT w.id FROM public.wallets w
        WHERE w.family_id IN (
          SELECT family_id FROM public.family_members WHERE user_id = auth.uid()
        )
    )
  );

CREATE POLICY "notes_delete" ON public.notes
  FOR DELETE USING (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE owner_id = auth.uid()
      UNION
      SELECT w.id FROM public.wallets w
        WHERE w.family_id IN (
          SELECT family_id FROM public.family_members WHERE user_id = auth.uid()
        )
    )
  );


-- ── Fix 2: families — add missing DELETE policy ───────────────────────────────

DROP POLICY IF EXISTS "families: admin can delete" ON public.families;

CREATE POLICY "families: admin can delete" ON public.families
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.family_members fm
        WHERE fm.family_id = families.id
          AND fm.user_id   = auth.uid()
          AND fm.role      = 'admin'
    )
  );


-- ── Fix 3: restrict purge_old_deleted_records to service_role ─────────────────

REVOKE EXECUTE ON FUNCTION public.purge_old_deleted_records() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.purge_old_deleted_records() TO service_role;
-- pg_cron jobs run as the postgres superuser, so the daily schedule is unaffected.
