-- ============================================================
-- 213_member_left_notification.sql
--
-- When a member leaves a family, nobody was told. Both leave paths —
-- leave_family() and transfer_admin_and_leave() (075) — end by
-- soft-deleting the caller's own family_members row, so a trigger on that
-- transition covers both: every remaining linked member gets an in-app
-- notification (tx_type 'member_left'; actor_name = who left, tx_title =
-- the family's name). The app also sends the push (family.member_left).
--
-- Only self-leaves (NEW.user_id = auth.uid()) notify — an admin removing
-- someone is a different event and is left for later.
-- ============================================================

CREATE OR REPLACE FUNCTION notify_family_member_left()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_family_name TEXT;
BEGIN
  IF OLD.deleted_at IS NOT NULL
     OR NEW.deleted_at IS NULL
     OR NEW.user_id IS NULL
     OR NEW.user_id IS DISTINCT FROM auth.uid() THEN
    RETURN NEW;
  END IF;

  SELECT name INTO v_family_name FROM families WHERE id = NEW.family_id;

  INSERT INTO notifications (
    user_id, family_id, actor_id, actor_name, actor_emoji,
    tx_type, tx_category, tx_amount, tx_title, is_read
  )
  SELECT fm.user_id, NEW.family_id, NEW.user_id,
         -- Fixed emoji: a member's own "emoji" can be an uploaded photo
         -- URL, which the tile would print as text.
         COALESCE(NEW.name, ''), '👋',
         'member_left', 'Family', 0, v_family_name, FALSE
    FROM family_members fm
   WHERE fm.family_id  = NEW.family_id
     AND fm.user_id   IS NOT NULL
     AND fm.user_id   <> NEW.user_id
     AND fm.deleted_at IS NULL;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_family_member_left ON family_members;
CREATE TRIGGER notify_family_member_left
  AFTER UPDATE OF deleted_at ON family_members
  FOR EACH ROW EXECUTE FUNCTION notify_family_member_left();
