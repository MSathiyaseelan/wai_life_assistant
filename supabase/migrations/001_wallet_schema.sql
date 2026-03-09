-- ============================================================
--  WAI Life Assistant — Wallet Module Schema
--  Run this in: Supabase Dashboard → SQL Editor
-- ============================================================

-- ── Utility: auto-update updated_at ────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ══════════════════════════════════════════════════════════════
--  1. PROFILES  (extends auth.users)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS profiles (
  id          UUID        PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT        NOT NULL DEFAULT '',
  emoji       TEXT        NOT NULL DEFAULT '👤',
  phone       TEXT        UNIQUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-create profile row when a user signs up
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, phone)
  VALUES (NEW.id, NEW.phone)
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles: own row" ON profiles
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- ══════════════════════════════════════════════════════════════
--  2. FAMILIES  (groups / shared accounts)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS families (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT        NOT NULL,
  emoji       TEXT        NOT NULL DEFAULT '👨‍👩‍👧',
  color_index INTEGER     NOT NULL DEFAULT 0,
  created_by  UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE families ENABLE ROW LEVEL SECURITY;
-- Visible to members (joined via family_members)
CREATE POLICY "families: members can view" ON families
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = families.id AND fm.user_id = auth.uid()
    )
  );
CREATE POLICY "families: admin can insert" ON families
  FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "families: admin can update" ON families
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = families.id
        AND fm.user_id = auth.uid()
        AND fm.role = 'admin'
    )
  );


-- ══════════════════════════════════════════════════════════════
--  3. FAMILY_MEMBERS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS family_members (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id   UUID        NOT NULL REFERENCES families(id)  ON DELETE CASCADE,
  user_id     UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  name        TEXT        NOT NULL,
  emoji       TEXT        NOT NULL DEFAULT '👤',
  role        TEXT        NOT NULL DEFAULT 'member'
                          CHECK (role IN ('admin', 'member', 'viewer')),
  relation    TEXT,
  phone       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_family_members_family ON family_members(family_id);
CREATE INDEX idx_family_members_user   ON family_members(user_id);

ALTER TABLE family_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "family_members: members can view" ON family_members
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM family_members fm2
      WHERE fm2.family_id = family_members.family_id
        AND fm2.user_id = auth.uid()
    )
  );
CREATE POLICY "family_members: admin can manage" ON family_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM family_members fm2
      WHERE fm2.family_id = family_members.family_id
        AND fm2.user_id = auth.uid()
        AND fm2.role = 'admin'
    )
  );


-- ══════════════════════════════════════════════════════════════
--  4. WALLETS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS wallets (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id     UUID        REFERENCES profiles(id) ON DELETE CASCADE,
  family_id    UUID        REFERENCES families(id) ON DELETE CASCADE,
  name         TEXT        NOT NULL,
  emoji        TEXT        NOT NULL DEFAULT '💰',
  is_personal  BOOLEAN     NOT NULL DEFAULT TRUE,
  -- Running balances (updated via trigger on transactions)
  cash_in      NUMERIC(12,2) NOT NULL DEFAULT 0,
  cash_out     NUMERIC(12,2) NOT NULL DEFAULT 0,
  online_in    NUMERIC(12,2) NOT NULL DEFAULT 0,
  online_out   NUMERIC(12,2) NOT NULL DEFAULT 0,
  gradient_index INTEGER   NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT chk_wallet_owner CHECK (
    (is_personal = TRUE  AND owner_id IS NOT NULL AND family_id IS NULL) OR
    (is_personal = FALSE AND family_id IS NOT NULL AND owner_id IS NULL)
  )
);

CREATE TRIGGER trg_wallets_updated_at
  BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "wallets: personal owner" ON wallets
  FOR ALL USING (owner_id = auth.uid());
CREATE POLICY "wallets: family members" ON wallets
  FOR SELECT USING (
    family_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = wallets.family_id AND fm.user_id = auth.uid()
    )
  );
CREATE POLICY "wallets: family admin manage" ON wallets
  FOR ALL USING (
    family_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM family_members fm
      WHERE fm.family_id = wallets.family_id
        AND fm.user_id = auth.uid()
        AND fm.role = 'admin'
    )
  );


-- ══════════════════════════════════════════════════════════════
--  5. TRANSACTIONS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS transactions (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  user_id     UUID        NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type        TEXT        NOT NULL
                          CHECK (type IN ('income','expense','split','lend','borrow','request')),
  pay_mode    TEXT        CHECK (pay_mode IN ('cash','online')),
  amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  category    TEXT        NOT NULL,
  note        TEXT,
  person      TEXT,       -- for lend / borrow / request
  persons     TEXT[],     -- for split (display names)
  status      TEXT,       -- e.g. '2/3 paid', 'pending'
  due_date    TEXT,       -- free-form for now, e.g. 'Mar 1'
  date        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tx_wallet  ON transactions(wallet_id);
CREATE INDEX idx_tx_user    ON transactions(user_id);
CREATE INDEX idx_tx_date    ON transactions(date DESC);
CREATE INDEX idx_tx_type    ON transactions(type);

-- Trigger: keep wallet balance columns in sync
CREATE OR REPLACE FUNCTION sync_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.type IN ('income','borrow') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in  = cash_in  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    ELSIF NEW.type IN ('expense','lend') THEN
      IF NEW.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out  = cash_out  + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      ELSIF NEW.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out + NEW.amount, updated_at = NOW() WHERE id = NEW.wallet_id;
      END IF;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.type IN ('income','borrow') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_in  = cash_in  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_in = online_in - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    ELSIF OLD.type IN ('expense','lend') THEN
      IF OLD.pay_mode = 'cash' THEN
        UPDATE wallets SET cash_out  = cash_out  - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      ELSIF OLD.pay_mode = 'online' THEN
        UPDATE wallets SET online_out = online_out - OLD.amount, updated_at = NOW() WHERE id = OLD.wallet_id;
      END IF;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_sync_wallet_balance
  AFTER INSERT OR DELETE ON transactions
  FOR EACH ROW EXECUTE FUNCTION sync_wallet_balance();

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
-- User can see transactions in wallets they own or are members of
CREATE POLICY "transactions: wallet access" ON transactions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM wallets w
      WHERE w.id = transactions.wallet_id
        AND (
          w.owner_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM family_members fm
            WHERE fm.family_id = w.family_id AND fm.user_id = auth.uid()
          )
        )
    )
  );


-- ══════════════════════════════════════════════════════════════
--  6. SPLIT_GROUPS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS split_groups (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id   UUID        NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  created_by  UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  name        TEXT        NOT NULL,
  emoji       TEXT        NOT NULL DEFAULT '👥',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE split_groups ENABLE ROW LEVEL SECURITY;
CREATE POLICY "split_groups: participant access" ON split_groups
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM split_participants sp
      WHERE sp.group_id = split_groups.id AND sp.user_id = auth.uid()
    )
    OR created_by = auth.uid()
  );


-- ══════════════════════════════════════════════════════════════
--  7. SPLIT_PARTICIPANTS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS split_participants (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id    UUID        NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
  user_id     UUID        REFERENCES profiles(id) ON DELETE SET NULL,
  name        TEXT        NOT NULL,
  emoji       TEXT        NOT NULL DEFAULT '👤',
  phone       TEXT,
  is_me       BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_split_participants_group ON split_participants(group_id);

ALTER TABLE split_participants ENABLE ROW LEVEL SECURITY;
CREATE POLICY "split_participants: group members" ON split_participants
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM split_participants sp2
      WHERE sp2.group_id = split_participants.group_id AND sp2.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM split_groups sg
      WHERE sg.id = split_participants.group_id AND sg.created_by = auth.uid()
    )
  );


-- ══════════════════════════════════════════════════════════════
--  8. SPLIT_GROUP_TRANSACTIONS
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS split_group_transactions (
  id              UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id        UUID          NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
  added_by_id     UUID          REFERENCES split_participants(id) ON DELETE SET NULL,
  title           TEXT          NOT NULL,
  total_amount    NUMERIC(12,2) NOT NULL CHECK (total_amount > 0),
  split_type      TEXT          NOT NULL DEFAULT 'equal'
                                CHECK (split_type IN ('equal','unequal','percentage','custom')),
  note            TEXT,
  date            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sgt_group ON split_group_transactions(group_id);

ALTER TABLE split_group_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "split_group_tx: group members" ON split_group_transactions
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM split_participants sp
      WHERE sp.group_id = split_group_transactions.group_id AND sp.user_id = auth.uid()
    )
  );


-- ══════════════════════════════════════════════════════════════
--  9. SPLIT_SHARES  (per-person portion of a split tx)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS split_shares (
  id                UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id    UUID          NOT NULL REFERENCES split_group_transactions(id) ON DELETE CASCADE,
  participant_id    UUID          NOT NULL REFERENCES split_participants(id) ON DELETE CASCADE,
  amount            NUMERIC(12,2) NOT NULL,
  percentage        NUMERIC(5,2),
  status            TEXT          NOT NULL DEFAULT 'pending'
                                  CHECK (status IN (
                                    'pending','proof_submitted','settled',
                                    'extension_requested','extension_granted'
                                  )),
  proof_note        TEXT,
  proof_image_path  TEXT,
  proof_date        TIMESTAMPTZ,
  extension_date    TIMESTAMPTZ,
  extension_reason  TEXT,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

CREATE TRIGGER trg_split_shares_updated_at
  BEFORE UPDATE ON split_shares
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE INDEX idx_split_shares_tx ON split_shares(transaction_id);

ALTER TABLE split_shares ENABLE ROW LEVEL SECURITY;
CREATE POLICY "split_shares: group members" ON split_shares
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM split_group_transactions sgt
      JOIN split_participants sp ON sp.group_id = sgt.group_id
      WHERE sgt.id = split_shares.transaction_id AND sp.user_id = auth.uid()
    )
  );


-- ══════════════════════════════════════════════════════════════
--  10. SPLIT_GROUP_MESSAGES  (group chat)
-- ══════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS split_group_messages (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id      UUID        NOT NULL REFERENCES split_groups(id) ON DELETE CASCADE,
  sender_id     UUID        REFERENCES split_participants(id) ON DELETE SET NULL,
  sender_name   TEXT        NOT NULL,
  sender_emoji  TEXT        NOT NULL DEFAULT '👤',
  text          TEXT        NOT NULL,
  type          TEXT        NOT NULL DEFAULT 'text'
                            CHECK (type IN (
                              'text','tx_added','settled',
                              'extension_req','extension_granted','reminder'
                            )),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sgm_group ON split_group_messages(group_id);

ALTER TABLE split_group_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "split_group_messages: group members" ON split_group_messages
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM split_participants sp
      WHERE sp.group_id = split_group_messages.group_id AND sp.user_id = auth.uid()
    )
  );


-- ══════════════════════════════════════════════════════════════
--  USEFUL VIEWS
-- ══════════════════════════════════════════════════════════════

-- wallet summary (computed balance)
CREATE OR REPLACE VIEW wallet_summary AS
SELECT
  id,
  name,
  emoji,
  is_personal,
  owner_id,
  family_id,
  cash_in,
  cash_out,
  online_in,
  online_out,
  (cash_in + online_in)         AS total_in,
  (cash_out + online_out)       AS total_out,
  (cash_in + online_in - cash_out - online_out) AS balance
FROM wallets;

-- pending split amounts per user
CREATE OR REPLACE VIEW my_pending_splits AS
SELECT
  ss.id           AS share_id,
  sg.name         AS group_name,
  sg.emoji        AS group_emoji,
  sgt.title       AS tx_title,
  ss.amount,
  ss.status,
  ss.extension_date,
  sp.name         AS participant_name,
  sp.user_id
FROM split_shares ss
JOIN split_group_transactions sgt ON sgt.id = ss.transaction_id
JOIN split_groups sg               ON sg.id  = sgt.group_id
JOIN split_participants sp         ON sp.id  = ss.participant_id
WHERE ss.status IN ('pending','extension_requested','extension_granted');

-- ── Done ───────────────────────────────────────────────────────────────────
