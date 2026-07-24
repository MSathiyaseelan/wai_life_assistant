-- ============================================================
-- 114_myhub_family_sharing.sql
--
-- Item Locator, Wardrobe, and Health Space are presented in the app as
-- "FamilyHub" modules (MyHub flips to FamilyHub on a family wallet,
-- with per-member pickers), but their RLS policies were still pure
-- single-owner (`user_id = auth.uid()`) — the exact bug
-- 091_functions_shared_collab.sql already diagnosed and fixed for
-- functions_my/functions_upcoming ("no other family member sharing the
-- same wallet could ever see or write these rows"), just never
-- extended to these three modules. A family member adding a container,
-- medication, or wardrobe item was invisible to every other member of
-- the same family wallet — RLS silently returns zero rows, no error.
--
-- Fixes both at once (rather than sequentially, to avoid a window where
-- family members can read/write but with no admin gate):
--   1. Widen SELECT/INSERT to wallet_accessible_txt() — any member of
--      the wallet's family can see and add.
--   2. UPDATE/DELETE: the creator can always manage their own row
--      (unchanged); beyond that, gated by wallet_can_edit_txt()/
--      wallet_can_delete_txt() — a wallet admin is always allowed, any
--      other member only when perm_edit/perm_delete = 'any_member' —
--      mirroring the fix already applied to Wallet (110) and Pantry
--      (112).
--
-- wallet_id on all these tables is TEXT (not a FK to wallets.id), same
-- as functions_my/functions_upcoming, so — like
-- functions_wallet_accessible/functions_wallet_admin in 091 — these
-- helpers defensively no-op on values that aren't a UUID rather than
-- erroring, and INSERT keeps the same fallback allowing a non-UUID
-- wallet_id straight through (matches 091's defensive pattern for
-- legacy/placeholder values).
-- ============================================================

CREATE OR REPLACE FUNCTION wallet_accessible_txt(wid TEXT)
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

CREATE OR REPLACE FUNCTION wallet_can_edit_txt(wid TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT CASE
    WHEN wid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN wallet_can_edit(wid::uuid)
    ELSE FALSE
  END;
$$;

CREATE OR REPLACE FUNCTION wallet_can_delete_txt(wid TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT CASE
    WHEN wid ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      THEN wallet_can_delete(wid::uuid)
    ELSE FALSE
  END;
$$;

-- ── item_locator_containers ─────────────────────────────────────────────
DROP POLICY IF EXISTS "item_locator_containers_user_policy" ON item_locator_containers;

CREATE POLICY "item_locator_containers: wallet members read" ON item_locator_containers
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "item_locator_containers: wallet members insert" ON item_locator_containers
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "item_locator_containers: creator or admin update" ON item_locator_containers
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "item_locator_containers: creator or admin delete" ON item_locator_containers
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── item_locator_items ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "item_locator_items_user_policy" ON item_locator_items;

CREATE POLICY "item_locator_items: wallet members read" ON item_locator_items
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "item_locator_items: wallet members insert" ON item_locator_items
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "item_locator_items: creator or admin update" ON item_locator_items
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "item_locator_items: creator or admin delete" ON item_locator_items
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── wardrobe_items ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "wardrobe_items_user_policy" ON wardrobe_items;

CREATE POLICY "wardrobe_items: wallet members read" ON wardrobe_items
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "wardrobe_items: wallet members insert" ON wardrobe_items
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "wardrobe_items: creator or admin update" ON wardrobe_items
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "wardrobe_items: creator or admin delete" ON wardrobe_items
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── wardrobe_outfit_logs ─────────────────────────────────────────────────
DROP POLICY IF EXISTS "wardrobe_outfit_logs_user_policy" ON wardrobe_outfit_logs;

CREATE POLICY "wardrobe_outfit_logs: wallet members read" ON wardrobe_outfit_logs
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "wardrobe_outfit_logs: wallet members insert" ON wardrobe_outfit_logs
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "wardrobe_outfit_logs: creator or admin update" ON wardrobe_outfit_logs
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "wardrobe_outfit_logs: creator or admin delete" ON wardrobe_outfit_logs
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_profiles ──────────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_profiles_user_policy" ON health_profiles;

CREATE POLICY "health_profiles: wallet members read" ON health_profiles
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_profiles: wallet members insert" ON health_profiles
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_profiles: creator or admin update" ON health_profiles
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_profiles: creator or admin delete" ON health_profiles
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_medications ───────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_medications_user_policy" ON health_medications;

CREATE POLICY "health_medications: wallet members read" ON health_medications
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_medications: wallet members insert" ON health_medications
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_medications: creator or admin update" ON health_medications
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_medications: creator or admin delete" ON health_medications
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_doctors ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_doctors_user_policy" ON health_doctors;

CREATE POLICY "health_doctors: wallet members read" ON health_doctors
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_doctors: wallet members insert" ON health_doctors
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_doctors: creator or admin update" ON health_doctors
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_doctors: creator or admin delete" ON health_doctors
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_documents ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_documents_user_policy" ON health_documents;

CREATE POLICY "health_documents: wallet members read" ON health_documents
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_documents: wallet members insert" ON health_documents
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_documents: creator or admin update" ON health_documents
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_documents: creator or admin delete" ON health_documents
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_appointments ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_appointments_user_policy" ON health_appointments;

CREATE POLICY "health_appointments: wallet members read" ON health_appointments
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_appointments: wallet members insert" ON health_appointments
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_appointments: creator or admin update" ON health_appointments
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_appointments: creator or admin delete" ON health_appointments
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_vitals ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_vitals_user_policy" ON health_vitals;

CREATE POLICY "health_vitals: wallet members read" ON health_vitals
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_vitals: wallet members insert" ON health_vitals
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_vitals: creator or admin update" ON health_vitals
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_vitals: creator or admin delete" ON health_vitals
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_vaccinations ──────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_vaccinations_user_policy" ON health_vaccinations;

CREATE POLICY "health_vaccinations: wallet members read" ON health_vaccinations
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_vaccinations: wallet members insert" ON health_vaccinations
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_vaccinations: creator or admin update" ON health_vaccinations
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_vaccinations: creator or admin delete" ON health_vaccinations
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));

-- ── health_insurance ─────────────────────────────────────────────────────
DROP POLICY IF EXISTS "health_insurance_user_policy" ON health_insurance;

CREATE POLICY "health_insurance: wallet members read" ON health_insurance
  FOR SELECT USING (user_id = auth.uid() OR wallet_accessible_txt(wallet_id));

CREATE POLICY "health_insurance: wallet members insert" ON health_insurance
  FOR INSERT WITH CHECK (
    user_id = auth.uid() AND
    (wallet_accessible_txt(wallet_id) OR wallet_id !~* '^[0-9a-f]{8}-')
  );

CREATE POLICY "health_insurance: creator or admin update" ON health_insurance
  FOR UPDATE USING (user_id = auth.uid() OR wallet_can_edit_txt(wallet_id));

CREATE POLICY "health_insurance: creator or admin delete" ON health_insurance
  FOR DELETE USING (user_id = auth.uid() OR wallet_can_delete_txt(wallet_id));
