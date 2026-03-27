-- Migration 027: Feature limits table
-- Stores per-feature monthly scan/usage limits so they can be changed without redeploying.

CREATE TABLE IF NOT EXISTS feature_limits (
  feature        TEXT PRIMARY KEY,
  monthly_limit  INTEGER NOT NULL DEFAULT 3,
  notes          TEXT
);

-- Seed default limits
INSERT INTO feature_limits (feature, monthly_limit, notes)
VALUES ('bill_scan', 3, 'Free tier: 3 bill scans per month')
ON CONFLICT (feature) DO NOTHING;

-- RLS: readable by all authenticated users (limit values are not sensitive)
ALTER TABLE feature_limits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read feature limits"
  ON feature_limits
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Update check_feature_limit to read limit from feature_limits table.
-- p_limit parameter removed — limit is now DB-driven.
CREATE OR REPLACE FUNCTION check_feature_limit(
  p_user_id UUID,
  p_feature TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  current_count INTEGER;
  allowed_limit INTEGER;
  current_month TEXT := TO_CHAR(NOW(), 'YYYY-MM');
BEGIN
  -- Read limit from table; default to 3 if not configured
  SELECT monthly_limit INTO allowed_limit
  FROM feature_limits
  WHERE feature = p_feature;

  IF allowed_limit IS NULL THEN
    allowed_limit := 3;
  END IF;

  INSERT INTO feature_usage (user_id, feature, month, count)
  VALUES (p_user_id, p_feature, current_month, 1)
  ON CONFLICT (user_id, feature, month)
  DO UPDATE SET count = feature_usage.count + 1
  RETURNING count INTO current_count;

  RETURN current_count <= allowed_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
