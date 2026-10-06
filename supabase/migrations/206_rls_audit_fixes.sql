-- ============================================================
-- 206_rls_audit_fixes.sql
--
-- Fixes from an RLS audit of all migrations (2026-10-06).
--
-- 1. Removed / departed family members kept full access.
--    Leaving or being removed from a family only soft-deletes the
--    family_members row (deleted_at), but wallet_accessible, wallet_admin
--    and is_family_member never checked deleted_at — and every family
--    policy funnels through them. A removed member could still read and
--    write the family's transactions, health records, notes, etc. through
--    the API (the app UI hid the family, the database didn't).
--    Same gap in policies that query family_members inline, and in
--    delete_family / restore_family (a removed admin could delete the family).
--
-- 2. wallet_subscriptions was readable by everyone in any family.
--    Its policy did `wallet_id IN (SELECT wallet_id FROM family_members …)`,
--    but family_members has no wallet_id column, so the name bound to the
--    OUTER wallet_subscriptions.wallet_id and the check was always true.
--
-- 3. UPDATE could move a row into a wallet you can't access.
--    UPDATE policies like `user_id = auth.uid() OR wallet_admin(wallet_id)`
--    had no WITH CHECK, and the USING clause alone doesn't pin wallet_id —
--    so you could update your own row to any other wallet's id and inject
--    it there (e.g. a transaction into another family's wallet, moving its
--    balance; or your split_participants row into another split group, then
--    read its expenses). A trigger now rejects a change of wallet / group /
--    family column to one you can't access; edits that don't move the row
--    are never checked, so existing flows are unaffected.
--
-- 4. Rejoining a family left the user locked out (old row stayed deleted);
--    the old membership row is now revived on rejoin.
--
-- Everything else checked out: RLS is on for every table; the three
-- tables with no policies (admin_users, cron_config, dashboard_admins) are
-- deny-all by design.
-- ============================================================

-- ── 1a. Helpers: ignore soft-deleted memberships ─────────────────────────────
-- The live parameter names differ from the migrations (e.g. is_family_member
-- has p_family_id), and CREATE OR REPLACE can't rename a parameter — nor can
-- these be dropped, since dozens of policies depend on them. Same approach as
-- 196: reuse whatever name exists and reference the argument as $1.

DO $do$
DECLARE
  v_fn   TEXT;
  v_arg  TEXT;
  v_body TEXT;
BEGIN
  FOR v_fn, v_body IN SELECT * FROM (VALUES
    ('wallet_accessible', $b$
      SELECT EXISTS (
        SELECT 1 FROM wallets w
        WHERE w.id = $1
          AND (
            w.owner_id = auth.uid()
            OR EXISTS (
              SELECT 1 FROM family_members fm
              WHERE fm.family_id  = w.family_id
                AND fm.user_id    = auth.uid()
                AND fm.deleted_at IS NULL
            )
          )
      );
    $b$),
    ('wallet_admin', $b$
      SELECT EXISTS (
        SELECT 1 FROM wallets w
        JOIN family_members fm ON fm.family_id = w.family_id
        WHERE w.id = $1
          AND fm.user_id    = auth.uid()
          AND fm.role       = 'admin'
          AND fm.deleted_at IS NULL
      ) OR EXISTS (
        SELECT 1 FROM wallets w
        WHERE w.id = $1 AND w.owner_id = auth.uid()
      );
    $b$),
    ('is_family_member', $b$
      SELECT EXISTS (
        SELECT 1 FROM family_members
        WHERE family_id  = $1
          AND user_id    = auth.uid()
          AND deleted_at IS NULL
      );
    $b$)
  ) AS v(fn, body) LOOP
    SELECT p.proargnames[1] INTO v_arg
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = v_fn
      AND p.pronargs = 1
      AND p.proargtypes[0] = 'uuid'::regtype;

    EXECUTE format(
      'CREATE OR REPLACE FUNCTION public.%I(%s UUID)
       RETURNS BOOLEAN
       LANGUAGE sql
       SECURITY DEFINER
       SET search_path = public
       STABLE
       AS %L',
      v_fn,
      CASE WHEN v_arg IS NULL OR v_arg = '' THEN '' ELSE quote_ident(v_arg) END,
      v_body);
  END LOOP;
END
$do$;

-- ── 1b. Policies that queried family_members inline ──────────────────────────

DROP POLICY IF EXISTS "Users can manage bills for their wallets" ON bills;
CREATE POLICY "Users can manage bills for their wallets" ON bills
  FOR ALL USING (wallet_accessible(wallet_id))
  WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "notes_select" ON notes;
CREATE POLICY "notes_select" ON notes
  FOR SELECT USING (wallet_accessible(wallet_id));
DROP POLICY IF EXISTS "notes_insert" ON notes;
CREATE POLICY "notes_insert" ON notes
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "special_days: wallet members can view" ON special_days;
CREATE POLICY "special_days: wallet members can view" ON special_days
  FOR SELECT USING (wallet_accessible(wallet_id));
DROP POLICY IF EXISTS "special_days: wallet members can insert" ON special_days;
CREATE POLICY "special_days: wallet members can insert" ON special_days
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "tasks: wallet members can view" ON tasks;
CREATE POLICY "tasks: wallet members can view" ON tasks
  FOR SELECT USING (wallet_accessible(wallet_id));
DROP POLICY IF EXISTS "tasks: wallet members can insert" ON tasks;
CREATE POLICY "tasks: wallet members can insert" ON tasks
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "wishes: wallet members can view" ON wishes;
CREATE POLICY "wishes: wallet members can view" ON wishes
  FOR SELECT USING (wallet_accessible(wallet_id));
DROP POLICY IF EXISTS "wishes: wallet members can insert" ON wishes;
CREATE POLICY "wishes: wallet members can insert" ON wishes
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "tx_groups: wallet access" ON tx_groups;
CREATE POLICY "tx_groups: wallet access" ON tx_groups
  FOR ALL USING (wallet_accessible(wallet_id))
  WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "wallet_budget_access" ON wallet_budgets;
CREATE POLICY "wallet_budget_access" ON wallet_budgets
  FOR ALL USING (wallet_accessible(wallet_id))
  WITH CHECK (wallet_accessible(wallet_id));

DROP POLICY IF EXISTS "wallets: family members" ON wallets;
CREATE POLICY "wallets: family members" ON wallets
  FOR SELECT USING (family_id IS NOT NULL AND is_family_member(family_id));

DROP POLICY IF EXISTS "wallets: family admin manage" ON wallets;
CREATE POLICY "wallets: family admin manage" ON wallets
  FOR ALL USING (family_id IS NOT NULL AND is_family_admin(family_id))
  WITH CHECK (family_id IS NOT NULL AND is_family_admin(family_id));

DROP POLICY IF EXISTS "families: members can view" ON families;
CREATE POLICY "families: members can view" ON families
  FOR SELECT USING (is_family_member(id));

DROP POLICY IF EXISTS "families: admin can delete" ON families;
CREATE POLICY "families: admin can delete" ON families
  FOR DELETE USING (is_family_admin(id));

-- ── 2. wallet_subscriptions: the always-true policy ──────────────────────────

DROP POLICY IF EXISTS "Family members can read their wallet subscription" ON wallet_subscriptions;
CREATE POLICY "Family members can read their wallet subscription" ON wallet_subscriptions
  FOR SELECT USING (wallet_accessible(wallet_id));

-- ── 1c. delete_family / restore_family: current admins only ──────────────────
-- Same parameter-name issue as 1a, so the bodies use $1.

DO $do$
DECLARE
  v_fn   TEXT;
  v_arg  TEXT;
  v_body TEXT;
BEGIN
  FOR v_fn, v_body IN SELECT * FROM (VALUES
    ('delete_family', $b$
BEGIN
  IF NOT is_family_admin($1) THEN
    RAISE EXCEPTION 'Only admins can delete a family';
  END IF;

  UPDATE transactions
  SET deleted_at = NOW()
  WHERE wallet_id IN (SELECT id FROM wallets WHERE family_id = $1)
    AND deleted_at IS NULL;

  UPDATE families
  SET is_archived = TRUE,
      deleted_at  = NOW()
  WHERE id = $1;
END;
    $b$),
    ('restore_family', $b$
DECLARE
  v_deleted_at TIMESTAMPTZ;
  v_cutoff     TIMESTAMPTZ;
BEGIN
  IF NOT is_family_admin($1) THEN
    RAISE EXCEPTION 'Only admins can restore a family';
  END IF;

  SELECT deleted_at INTO v_deleted_at FROM families WHERE id = $1;

  IF v_deleted_at IS NULL THEN
    RAISE EXCEPTION 'This group is not deleted';
  END IF;

  SELECT NOW() - (COALESCE(
    (SELECT value FROM app_config WHERE key = 'recycle_bin_retention_days'),
    '30'
  ) || ' days')::interval
  INTO v_cutoff;

  IF v_deleted_at < v_cutoff THEN
    RAISE EXCEPTION 'This group can no longer be restored';
  END IF;

  UPDATE transactions
  SET deleted_at = NULL
  WHERE wallet_id IN (SELECT id FROM wallets WHERE family_id = $1)
    AND deleted_at = v_deleted_at;

  UPDATE families
  SET is_archived = FALSE,
      deleted_at  = NULL
  WHERE id = $1;
END;
    $b$)
  ) AS v(fn, body) LOOP
    SELECT p.proargnames[1] INTO v_arg
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = v_fn
      AND p.pronargs = 1
      AND p.proargtypes[0] = 'uuid'::regtype;

    EXECUTE format(
      'CREATE OR REPLACE FUNCTION public.%I(%s UUID)
       RETURNS VOID
       LANGUAGE plpgsql
       SECURITY DEFINER
       SET search_path = public
       AS %L',
      v_fn,
      CASE WHEN v_arg IS NULL OR v_arg = '' THEN '' ELSE quote_ident(v_arg) END,
      v_body);
  END LOOP;
END
$do$;

-- ── 3. Moving a row into a wallet / group you can't access ───────────────────
-- Enforced with a trigger rather than policy WITH CHECKs: it fires only
-- when the wallet/group column actually changes (UPDATE OF col), so every
-- ordinary edit — including editing your own row in a family you've since
-- left, or a money-request target updating the request — is untouched.
-- Calls without a user (service role, cron, SQL editor) are not checked.

CREATE OR REPLACE FUNCTION guard_row_move()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_col  TEXT := TG_ARGV[0];
  v_kind TEXT := TG_ARGV[1];
  v_old  TEXT;
  v_new  TEXT;
  v_ok   BOOLEAN;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  EXECUTE format('SELECT ($1).%I::text, ($2).%I::text', v_col, v_col)
    INTO v_old, v_new USING OLD, NEW;

  IF v_new IS NULL OR v_new IS NOT DISTINCT FROM v_old THEN
    RETURN NEW;
  END IF;

  v_ok := CASE v_kind
    -- Same rule as the INSERT policies: an accessible wallet, or a legacy
    -- non-UUID personal id (MyHub tables).
    WHEN 'wallet' THEN
      wallet_accessible_txt(v_new) OR v_new !~* '^[0-9a-f]{8}-'
    WHEN 'family' THEN
      is_family_member(v_new::uuid)
    WHEN 'function' THEN
      function_row_wallet_accessible(v_new::uuid)
    WHEN 'meal' THEN
      EXISTS (SELECT 1 FROM meal_entries me
              WHERE me.id = v_new::uuid AND wallet_accessible(me.wallet_id))
    WHEN 'split_group' THEN
      is_split_group_participant(v_new::uuid) OR is_split_group_creator(v_new::uuid)
    WHEN 'split_tx' THEN
      EXISTS (SELECT 1 FROM split_group_transactions sgt
              WHERE sgt.id = v_new::uuid
                AND (is_split_group_participant(sgt.group_id)
                     OR is_split_group_creator(sgt.group_id)))
    ELSE FALSE
  END;

  IF NOT COALESCE(v_ok, FALSE) THEN
    RAISE EXCEPTION 'Not allowed to move % to %', TG_TABLE_NAME, v_col
      USING ERRCODE = '42501';
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT * FROM (VALUES
    ('transactions',               'wallet_id',        'wallet'),
    ('meal_entries',               'wallet_id',        'wallet'),
    ('recipes',                    'wallet_id',        'wallet'),
    ('member_food_prefs',          'wallet_id',        'wallet'),
    ('notes',                      'wallet_id',        'wallet'),
    ('reminders',                  'wallet_id',        'wallet'),
    ('special_days',               'wallet_id',        'wallet'),
    ('tasks',                      'wallet_id',        'wallet'),
    ('wishes',                     'wallet_id',        'wallet'),
    ('health_appointments',        'wallet_id',        'wallet'),
    ('health_doctors',             'wallet_id',        'wallet'),
    ('health_documents',           'wallet_id',        'wallet'),
    ('health_insurance',           'wallet_id',        'wallet'),
    ('health_medications',         'wallet_id',        'wallet'),
    ('health_profiles',            'wallet_id',        'wallet'),
    ('health_vaccinations',        'wallet_id',        'wallet'),
    ('health_vitals',              'wallet_id',        'wallet'),
    ('item_locator_containers',    'wallet_id',        'wallet'),
    ('item_locator_items',         'wallet_id',        'wallet'),
    ('wardrobe_items',             'wallet_id',        'wallet'),
    ('wardrobe_items',             'shared_wallet_id', 'wallet'),
    ('wardrobe_outfit_logs',       'wallet_id',        'wallet'),
    ('wardrobe_outfit_logs',       'shared_wallet_id', 'wallet'),
    ('functions_my',               'wallet_id',        'wallet'),
    ('functions_upcoming',         'wallet_id',        'wallet'),
    ('function_clothing_families', 'function_id',      'function'),
    ('function_dishes',            'function_id',      'function'),
    ('function_essentials',        'function_id',      'function'),
    ('function_participants',      'function_id',      'function'),
    ('function_return_gifts',      'function_id',      'function'),
    ('meal_reactions',             'meal_id',          'meal'),
    ('split_participants',         'group_id',         'split_group'),
    ('split_group_transactions',   'group_id',         'split_group'),
    ('split_shares',               'transaction_id',   'split_tx'),
    ('wallets',                    'family_id',        'family')
  ) AS v(tbl, col, kind) LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I',
                   'guard_move_' || r.col, r.tbl);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE UPDATE OF %I ON %I
         FOR EACH ROW EXECUTE FUNCTION guard_row_move(%L, %L)',
      'guard_move_' || r.col, r.col, r.tbl, r.col, r.kind);
  END LOOP;
END $$;

-- ── 4. Rejoining a family revives the old membership ─────────────────────────
-- Leaving soft-deletes the family_members row, and accept_family_invite /
-- join_family_by_token insert with ON CONFLICT (family_id, user_id) DO
-- NOTHING — so a rejoin kept the deleted row and the user stayed out
-- (already hidden in the switcher since 121; with 1a also no data access).
-- Revive the old row instead. Placeholder rows (user_id NULL) are untouched.

CREATE OR REPLACE FUNCTION revive_family_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.user_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE family_members
     SET deleted_at = NULL,
         role       = NEW.role,
         name       = COALESCE(NEW.name,     name),
         emoji      = COALESCE(NEW.emoji,    emoji),
         phone      = COALESCE(NEW.phone,    phone),
         relation   = COALESCE(NEW.relation, relation)
   WHERE family_id = NEW.family_id
     AND user_id   = NEW.user_id
     AND deleted_at IS NOT NULL;

  IF FOUND THEN
    RETURN NULL;  -- revived the old row; skip the duplicate insert
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS revive_family_membership ON family_members;
CREATE TRIGGER revive_family_membership
  BEFORE INSERT ON family_members
  FOR EACH ROW EXECUTE FUNCTION revive_family_membership();
