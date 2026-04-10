-- Add extension_response_msg to split_shares
-- Stores the payer's agree/disagree message when responding to an extension request

ALTER TABLE split_shares
  ADD COLUMN IF NOT EXISTS extension_response_msg TEXT;
