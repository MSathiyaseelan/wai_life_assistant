-- Migration 025: Feature usage tracking (scan limits for free users)

-- Track scan usage per user per feature per month
CREATE TABLE IF NOT EXISTS feature_usage (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  feature     TEXT NOT NULL,    -- e.g. 'bill_scan'
  month       TEXT NOT NULL,    -- e.g. '2026-03'
  count       INTEGER DEFAULT 0,
  UNIQUE(user_id, feature, month)
);

-- RLS: users can only read/write their own rows
ALTER TABLE feature_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own usage"
  ON feature_usage
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Atomically increment usage and return whether user is within the limit.
-- Returns TRUE if allowed (count after increment <= p_limit), FALSE if over limit.
CREATE OR REPLACE FUNCTION check_feature_limit(
  p_user_id UUID,
  p_feature TEXT,
  p_limit   INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
BEGIN
  INSERT INTO feature_usage (user_id, feature, month, count)
  VALUES (p_user_id, p_feature, current_month, 1)
  ON CONFLICT (user_id, feature, month)
  DO UPDATE SET count = feature_usage.count + 1
  RETURNING count INTO current_count;

  RETURN current_count <= p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
