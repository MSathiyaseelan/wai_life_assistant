-- Migration 021: Add 'returned' to transactions type check constraint
-- 'returned' = money I paid back to someone I borrowed from (outflow, like lend/expense)

-- Drop old constraint and recreate with 'returned' included
ALTER TABLE transactions
  DROP CONSTRAINT IF EXISTS transactions_type_check;

ALTER TABLE transactions
  ADD CONSTRAINT transactions_type_check
  CHECK (type IN ('income','expense','split','lend','borrow','request','returned'));

-- Update sync_wallet_balance trigger:
-- 'returned' is an outflow (cash_out / online_out), same as 'expense'/'lend'
CREATE OR REPLACE FUNCTION sync_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type IN ('income','borrow') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in   = cash_in   + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    ELSIF NEW.type IN ('expense','lend','returned') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out   = cash_out   + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.type IN ('income','borrow') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in   = cash_in   - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    ELSIF OLD.type IN ('expense','lend','returned') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out   = cash_out   - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    END IF;
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
