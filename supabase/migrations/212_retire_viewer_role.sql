-- ============================================================
-- 212_retire_viewer_role.sql
--
-- The family "Viewer" role was meant to be read-only, but nothing ever
-- enforced it: no RLS policy distinguishes viewer from member (they only
-- check admin vs. everyone else), and the app never hid or blocked
-- anything for viewers. A viewer could add, edit and delete exactly like a
-- member, while the label said otherwise.
--
-- Until read-only access is actually built, retire the role:
--   • the app no longer offers it (MemberRole.assignable),
--   • existing viewers and pending viewer invites become members,
--   • any 'viewer' still written (older app builds offer it) is saved as
--     'member', so the misleading label can't come back.
-- The CHECK constraints still allow 'viewer', so this is easy to undo when
-- the role is implemented properly: drop the two triggers below.
-- ============================================================

UPDATE family_members SET role = 'member' WHERE role = 'viewer';

UPDATE family_invites SET role = 'member'
WHERE role = 'viewer' AND status = 'pending';

CREATE OR REPLACE FUNCTION coerce_viewer_role_to_member()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'viewer' THEN
    NEW.role := 'member';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS coerce_viewer_role ON family_members;
CREATE TRIGGER coerce_viewer_role
  BEFORE INSERT OR UPDATE OF role ON family_members
  FOR EACH ROW EXECUTE FUNCTION coerce_viewer_role_to_member();

DROP TRIGGER IF EXISTS coerce_viewer_role ON family_invites;
CREATE TRIGGER coerce_viewer_role
  BEFORE INSERT OR UPDATE OF role ON family_invites
  FOR EACH ROW EXECUTE FUNCTION coerce_viewer_role_to_member();
