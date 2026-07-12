-- ============================================================
--  WAI Life Assistant — Functions Module: Shared Collaboration
--
--  functions_upcoming / functions_my previously used a
--  single-owner RLS policy (user_id = auth.uid()), which meant
--  no other family member sharing the same wallet could ever
--  see or write these rows — even though the app UI (voting,
--  chat) is built as a family-collaborative feature.
--
--  This migration:
--   1. Adds `chat` (functions_my + functions_upcoming) and
--      `votes` (functions_upcoming) JSONB columns so those
--      fields are actually persisted (previously in-memory only
--      and lost on reload).
--   2. Widens RLS to the wallet_accessible() family-sharing model
--      already used by pantry/wallet tables, so any member of the
--      wallet's family can read/write.
-- ============================================================

ALTER TABLE functions_my       ADD COLUMN IF NOT EXISTS chat  JSONB NOT NULL DEFAULT '[]';
ALTER TABLE functions_upcoming ADD COLUMN IF NOT EXISTS chat  JSONB NOT NULL DEFAULT '[]';
ALTER TABLE functions_upcoming ADD COLUMN IF NOT EXISTS votes JSONB NOT NULL DEFAULT '{}';

-- wallet_id is stored as TEXT (not a FK to wallets.id) on these tables, so we
-- defensively cast only when it actually looks like a UUID — a malformed
-- legacy value must not abort the whole policy evaluation for other rows.
CREATE OR REPLACE FUNCTION functions_wallet_accessible(wid TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT CASE
    WHEN wid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN wallet_accessible(wid::uuid)
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION functions_wallet_admin(wid TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT CASE
    WHEN wid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN wallet_admin(wid::uuid)
    ELSE FALSE
  END;
$$;

-- ── functions_my ─────────────────────────────────────────────
DROP POLICY IF EXISTS "functions_my_user_policy" ON functions_my;

DROP POLICY IF EXISTS "functions_my: wallet members read" ON functions_my;
CREATE POLICY "functions_my: wallet members read" ON functions_my
  FOR SELECT USING (
    user_id = auth.uid() OR functions_wallet_accessible(wallet_id)
  );

DROP POLICY IF EXISTS "functions_my: wallet members insert" ON functions_my;
CREATE POLICY "functions_my: wallet members insert" ON functions_my
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (functions_wallet_accessible(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

DROP POLICY IF EXISTS "functions_my: creator or admin update" ON functions_my;
CREATE POLICY "functions_my: creator or admin update" ON functions_my
  FOR UPDATE USING (
    user_id = auth.uid() OR functions_wallet_accessible(wallet_id)
  );

DROP POLICY IF EXISTS "functions_my: creator or admin delete" ON functions_my;
CREATE POLICY "functions_my: creator or admin delete" ON functions_my
  FOR DELETE USING (
    user_id = auth.uid() OR functions_wallet_admin(wallet_id)
  );

-- ── functions_upcoming ───────────────────────────────────────
DROP POLICY IF EXISTS "functions_upcoming_user_policy" ON functions_upcoming;

DROP POLICY IF EXISTS "functions_upcoming: wallet members read" ON functions_upcoming;
CREATE POLICY "functions_upcoming: wallet members read" ON functions_upcoming
  FOR SELECT USING (
    user_id = auth.uid() OR functions_wallet_accessible(wallet_id)
  );

DROP POLICY IF EXISTS "functions_upcoming: wallet members insert" ON functions_upcoming;
CREATE POLICY "functions_upcoming: wallet members insert" ON functions_upcoming
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (functions_wallet_accessible(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

DROP POLICY IF EXISTS "functions_upcoming: creator or admin update" ON functions_upcoming;
CREATE POLICY "functions_upcoming: creator or admin update" ON functions_upcoming
  FOR UPDATE USING (
    user_id = auth.uid() OR functions_wallet_accessible(wallet_id)
  );

DROP POLICY IF EXISTS "functions_upcoming: creator or admin delete" ON functions_upcoming;
CREATE POLICY "functions_upcoming: creator or admin delete" ON functions_upcoming
  FOR DELETE USING (
    user_id = auth.uid() OR functions_wallet_admin(wallet_id)
  );
