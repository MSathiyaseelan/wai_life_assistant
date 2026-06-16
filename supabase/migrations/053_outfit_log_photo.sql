-- Add optional outfit selfie / photo to wardrobe outfit logs
ALTER TABLE wardrobe_outfit_logs
  ADD COLUMN IF NOT EXISTS photo_url text;
