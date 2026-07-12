-- ============================================================
--  user_fcm_tokens — support multiple devices per user/platform
--
--  The original UNIQUE(user_id, platform) constraint meant a second
--  Android (or iOS) device signed into the same account would silently
--  overwrite the first device's token on every upsert, killing push
--  delivery to the first device with no error or indication anywhere.
--
--  Widening the constraint to include the token itself lets each
--  device keep its own row. Existing single-device behavior is
--  unaffected — this only adds capacity, it doesn't change any read
--  path's shape.
--
--  NOTE: any server-side sender (e.g. a `send-notification` edge
--  function) that assumed one row per (user_id, platform) must be
--  updated to iterate every row for a user, not just the first, or
--  multi-device delivery will still only reach one device.
-- ============================================================

ALTER TABLE user_fcm_tokens DROP CONSTRAINT IF EXISTS user_fcm_tokens_user_id_platform_key;
ALTER TABLE user_fcm_tokens ADD CONSTRAINT user_fcm_tokens_user_id_platform_token_key
  UNIQUE (user_id, platform, fcm_token);
