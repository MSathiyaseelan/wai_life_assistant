ALTER TABLE split_group_transactions
ADD COLUMN IF NOT EXISTS payment_mode TEXT;
