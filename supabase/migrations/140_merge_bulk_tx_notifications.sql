-- ============================================================
-- 140_merge_bulk_tx_notifications.sql
--
-- trg_notify_family_on_tx (036_notifications.sql) fires AFTER INSERT
-- FOR EACH ROW on transactions, inserting one notification row per family
-- member for every single row inserted. A scanned bill inserts one
-- transaction row per line item (wallet_bill_scan_sheet.dart), and moving
-- a tx group between wallets deletes+re-inserts one row per original
-- transaction (wallet_screen.dart _moveGroupToWallet) — so each family
-- member got flooded with one notification per item instead of a single
-- notification for the whole bill/move.
--
-- Fix: instead of always inserting a fresh row, merge into an existing
-- unread notification from the same actor/type created in the last 30
-- seconds (summing the amount, bumping item_count) — covers both the
-- scanned-bill loop and the move-group loop without requiring either
-- client flow to change how it inserts rows.
-- ============================================================

ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS item_count INTEGER NOT NULL DEFAULT 1;

CREATE OR REPLACE FUNCTION notify_family_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_family_id   UUID;
  v_actor_name  TEXT;
  v_actor_emoji TEXT;
  v_member      RECORD;
  v_updated     INT;
BEGIN
  -- Only proceed if this wallet is a family wallet
  SELECT w.family_id
    INTO v_family_id
    FROM wallets w
   WHERE w.id = NEW.wallet_id
     AND w.family_id IS NOT NULL;

  IF v_family_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- Fetch actor profile (name + emoji)
  SELECT p.name, p.emoji
    INTO v_actor_name, v_actor_emoji
    FROM profiles p
   WHERE p.id = NEW.user_id;

  v_actor_name  := COALESCE(v_actor_name,  '');
  v_actor_emoji := COALESCE(v_actor_emoji, '👤');

  FOR v_member IN
    SELECT fm.user_id
      FROM family_members fm
     WHERE fm.family_id = v_family_id
       AND fm.user_id IS NOT NULL
       AND fm.user_id <> NEW.user_id   -- skip the actor themselves
  LOOP
    -- Merge into an existing unread notification from the same actor/type
    -- created in the last 30s (multiple items from one scanned bill, or a
    -- group being moved between wallets) rather than adding a new row.
    UPDATE notifications
       SET tx_amount   = tx_amount + NEW.amount,
           item_count  = item_count + 1,
           tx_id       = NEW.id,
           tx_category = CASE WHEN tx_category = NEW.category THEN tx_category ELSE 'Multiple' END,
           tx_title    = NULL,
           created_at  = NOW()
     WHERE user_id    = v_member.user_id
       AND family_id  = v_family_id
       AND actor_id   = NEW.user_id
       AND tx_type    = NEW.type
       AND is_read    = FALSE
       AND created_at > NOW() - INTERVAL '30 seconds';
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    IF v_updated = 0 THEN
      INSERT INTO notifications (
        user_id, family_id, tx_id,
        actor_id, actor_name, actor_emoji,
        tx_type, tx_category, tx_amount, tx_title, item_count
      ) VALUES (
        v_member.user_id,
        v_family_id,
        NEW.id,
        NEW.user_id,
        v_actor_name,
        v_actor_emoji,
        NEW.type,
        NEW.category,
        NEW.amount,
        NEW.title,
        1
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;
