-- ══════════════════════════════════════════════════════════════════════════════
-- 075_leave_family_rpc.sql
--
-- Adds two SECURITY DEFINER functions that are the ONLY server-side path for
-- leaving a family, providing enforcement that the Flutter UI cannot bypass:
--
--  leave_family(p_member_id)
--    • Verifies the caller owns p_member_id
--    • Blocks if caller is the last admin
--    • Soft-deletes the member row
--
--  transfer_admin_and_leave(p_new_admin_member_id, p_my_member_id)
--    • Verifies caller owns p_my_member_id and is an admin
--    • Promotes p_new_admin_member_id to admin
--    • Demotes caller to member
--    • Soft-deletes caller's member row
--    All three steps run in one transaction.
-- ══════════════════════════════════════════════════════════════════════════════


-- ── leave_family ─────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.leave_family(p_member_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_family_id UUID;
  v_admin_count INT;
BEGIN
  -- Confirm the caller actually owns this member row
  SELECT family_id INTO v_family_id
    FROM family_members
   WHERE id = p_member_id
     AND user_id = auth.uid()
     AND deleted_at IS NULL;

  IF v_family_id IS NULL THEN
    RAISE EXCEPTION 'Member not found or does not belong to the current user';
  END IF;

  -- Count remaining non-deleted admins in this family
  SELECT COUNT(*) INTO v_admin_count
    FROM family_members
   WHERE family_id = v_family_id
     AND role = 'admin'
     AND deleted_at IS NULL;

  -- Block if this user is the only admin and other members remain
  IF v_admin_count = 1
     AND EXISTS (
       SELECT 1 FROM family_members
        WHERE family_id  = v_family_id
          AND id         <> p_member_id
          AND deleted_at IS NULL
     )
     AND EXISTS (
       SELECT 1 FROM family_members
        WHERE id      = p_member_id
          AND role    = 'admin'
     )
  THEN
    RAISE EXCEPTION 'last_admin_cannot_leave';
  END IF;

  -- Soft-delete the caller's member row
  UPDATE family_members
     SET deleted_at = NOW()
   WHERE id = p_member_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.leave_family(UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.leave_family(UUID) TO authenticated;


-- ── transfer_admin_and_leave ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.transfer_admin_and_leave(
  p_new_admin_member_id UUID,
  p_my_member_id        UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_family_id      UUID;
  v_new_family_id  UUID;
BEGIN
  -- Confirm caller owns p_my_member_id and is an admin
  SELECT family_id INTO v_family_id
    FROM family_members
   WHERE id      = p_my_member_id
     AND user_id = auth.uid()
     AND role    = 'admin'
     AND deleted_at IS NULL;

  IF v_family_id IS NULL THEN
    RAISE EXCEPTION 'You are not an admin of this family';
  END IF;

  -- Confirm new admin belongs to the same family
  SELECT family_id INTO v_new_family_id
    FROM family_members
   WHERE id = p_new_admin_member_id
     AND deleted_at IS NULL;

  IF v_new_family_id IS NULL OR v_new_family_id <> v_family_id THEN
    RAISE EXCEPTION 'Target member not found or belongs to a different family';
  END IF;

  -- Promote the new admin
  UPDATE family_members
     SET role = 'admin'
   WHERE id = p_new_admin_member_id;

  -- Demote the current user to member before leaving
  UPDATE family_members
     SET role = 'member'
   WHERE id = p_my_member_id;

  -- Soft-delete the current user's member row
  UPDATE family_members
     SET deleted_at = NOW()
   WHERE id = p_my_member_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.transfer_admin_and_leave(UUID, UUID) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.transfer_admin_and_leave(UUID, UUID) TO authenticated;
