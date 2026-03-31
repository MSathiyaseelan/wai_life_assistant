-- User-defined transaction categories
-- Stores custom categories created by users (either via AI parser or manual entry)
-- Default categories are defined in the app and never saved here.

CREATE TABLE user_tx_categories (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL,
  tx_type     TEXT        NOT NULL CHECK (tx_type IN ('expense', 'income', 'transfer')),
  created_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE (user_id, name, tx_type)
);

ALTER TABLE user_tx_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "users manage own categories"
  ON user_tx_categories FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
