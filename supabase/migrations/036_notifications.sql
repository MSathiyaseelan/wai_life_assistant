-- ============================================================
--  WAI Life Assistant — Notifications
--  Stores in-app notifications for family transaction activity.
--  Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ══════════════════════════════════════════════════════════════
--  1. NOTIFICATIONS TABLE
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  family_id   UUID        NOT NULL REFERENCES families(id)  ON DELETE CASCADE,
  tx_id       UUID        REFERENCES transactions(id)        ON DELETE SET NULL,
  actor_id    UUID        REFERENCES profiles(id)            ON DELETE SET NULL,
  actor_name  TEXT        NOT NULL DEFAULT '',
  actor_emoji TEXT        NOT NULL DEFAULT '👤',
  tx_type     TEXT        NOT NULL DEFAULT '',   -- income/expense/split/…
  tx_category TEXT        NOT NULL DEFAULT '',
  tx_amount   NUMERIC(12,2) NOT NULL DEFAULT 0,
  tx_title    TEXT,
  is_read     BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notif_user       ON notifications(user_id, created_at DESC);
CREATE INDEX idx_notif_family     ON notifications(family_id);
CREATE INDEX idx_notif_unread     ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- ── RLS ────────────────────────────────────────────────────────
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notifications
CREATE POLICY "notifications: own rows" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

-- Users can mark their own notifications as read
CREATE POLICY "notifications: mark read" ON notifications
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Trigger function inserts notifications (runs as SECURITY DEFINER to bypass RLS)
CREATE POLICY "notifications: service insert" ON notifications
  FOR INSERT WITH CHECK (TRUE);


-- ══════════════════════════════════════════════════════════════
--  2. TRIGGER — notify family members on new transaction
--     Fires AFTER INSERT on transactions.
--     Only acts when the wallet belongs to a family (family_id NOT NULL).
-- ══════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION notify_family_on_transaction()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- bypass RLS so we can insert for other users
SET search_path = public
AS $$
DECLARE
  v_family_id   UUID;
  v_actor_name  TEXT;
  v_actor_emoji TEXT;
  v_member      RECORD;
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

  -- Insert one notification for each OTHER family member who has a linked user_id
  FOR v_member IN
    SELECT fm.user_id
      FROM family_members fm
     WHERE fm.family_id = v_family_id
       AND fm.user_id IS NOT NULL
       AND fm.user_id <> NEW.user_id   -- skip the actor themselves
  LOOP
    INSERT INTO notifications (
      user_id, family_id, tx_id,
      actor_id, actor_name, actor_emoji,
      tx_type, tx_category, tx_amount, tx_title
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
      NEW.title
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_family_on_tx
  AFTER INSERT ON transactions
  FOR EACH ROW
  EXECUTE FUNCTION notify_family_on_transaction();
