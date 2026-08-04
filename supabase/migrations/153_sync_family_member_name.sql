-- ══════════════════════════════════════════════════════════════
--  Keep family_members.name in sync with profiles.name
--
--  family_members.name is a denormalized copy of profiles.name taken
--  at insert/link time. When a user renames themselves via
--  Profile & Account, only profiles.name was updated, so every
--  family_members row for that user (across every family they belong
--  to) kept showing the old name. Add a trigger to cascade renames,
--  and backfill existing rows that have already drifted.
-- ══════════════════════════════════════════════════════════════

-- One-time backfill: sync any rows that are currently out of date.
UPDATE family_members fm
SET name = p.name
FROM profiles p
WHERE fm.user_id = p.id
  AND p.name <> ''
  AND fm.name <> p.name;

CREATE OR REPLACE FUNCTION sync_family_member_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.name IS DISTINCT FROM OLD.name AND NEW.name <> '' THEN
    UPDATE family_members
    SET name = NEW.name
    WHERE user_id = NEW.id
      AND name <> NEW.name;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_sync_family_member_name ON profiles;
CREATE TRIGGER trg_sync_family_member_name
  AFTER UPDATE OF name ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION sync_family_member_name();
