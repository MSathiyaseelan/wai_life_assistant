-- ============================================================
-- 116_planit_edit_delete_perms.sql
--
-- Same gap class fixed for Wallet (110), Pantry (112), and MyHub (114):
-- tasks/reminders/notes/wishes/special_days correctly share READ access
-- across a family wallet, but UPDATE/DELETE never checked
-- perm_edit/perm_delete at all — any wallet member could edit or delete
-- any other member's task/reminder/note/wish/special-day.
--
-- Unlike Wallet/Pantry/MyHub, none of these 5 tables had a creator
-- column to fall back on, so this migration adds `created_by` to each
-- (nullable — existing rows have no recorded creator, which just means
-- they fall through to the wallet_can_edit/wallet_can_delete check with
-- no personal-ownership exception) and wires it into the same
-- creator-OR-admin-OR-any_member pattern used everywhere else. New
-- inserts populate it via the Dart service layer (see task_service.dart
-- et al. — each addX() now includes 'created_by': _uid).
--
-- All 5 tables use wallet_id UUID (not TEXT), so the existing UUID
-- helpers (wallet_accessible/wallet_can_edit/wallet_can_delete from
-- 110) apply directly — no _txt wrapper needed.
-- ============================================================

ALTER TABLE tasks        ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE reminders     ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE notes         ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE wishes        ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE special_days  ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- ── tasks ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "tasks: wallet members can update" ON tasks;
CREATE POLICY "tasks: creator or admin update" ON tasks
  FOR UPDATE USING (created_by = auth.uid() OR wallet_can_edit(wallet_id));

DROP POLICY IF EXISTS "tasks: wallet members can delete" ON tasks;
CREATE POLICY "tasks: creator or admin delete" ON tasks
  FOR DELETE USING (created_by = auth.uid() OR wallet_can_delete(wallet_id));

-- ── reminders ────────────────────────────────────────────────────────────
-- Was a single FOR ALL policy covering every command; split so SELECT/INSERT
-- keep the original wallet-membership check and only UPDATE/DELETE gain the
-- creator/perm gate.
DROP POLICY IF EXISTS "Users can manage reminders for their wallets" ON reminders;

CREATE POLICY "reminders: wallet members can view" ON reminders
  FOR SELECT USING (wallet_accessible(wallet_id));

CREATE POLICY "reminders: wallet members can insert" ON reminders
  FOR INSERT WITH CHECK (wallet_accessible(wallet_id));

CREATE POLICY "reminders: creator or admin update" ON reminders
  FOR UPDATE USING (created_by = auth.uid() OR wallet_can_edit(wallet_id));

CREATE POLICY "reminders: creator or admin delete" ON reminders
  FOR DELETE USING (created_by = auth.uid() OR wallet_can_delete(wallet_id));

-- ── notes ────────────────────────────────────────────────────────────────
-- Actual policy names are "notes_update"/"notes_delete" (074_rls_fixes.sql),
-- not the "table: description" naming used by the other tables.
DROP POLICY IF EXISTS "notes_update" ON notes;
CREATE POLICY "notes: creator or admin update" ON notes
  FOR UPDATE USING (created_by = auth.uid() OR wallet_can_edit(wallet_id));

DROP POLICY IF EXISTS "notes_delete" ON notes;
CREATE POLICY "notes: creator or admin delete" ON notes
  FOR DELETE USING (created_by = auth.uid() OR wallet_can_delete(wallet_id));

-- ── wishes ───────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "wishes: wallet members can update" ON wishes;
CREATE POLICY "wishes: creator or admin update" ON wishes
  FOR UPDATE USING (created_by = auth.uid() OR wallet_can_edit(wallet_id));

DROP POLICY IF EXISTS "wishes: wallet members can delete" ON wishes;
CREATE POLICY "wishes: creator or admin delete" ON wishes
  FOR DELETE USING (created_by = auth.uid() OR wallet_can_delete(wallet_id));

-- ── special_days ─────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "special_days: wallet members can update" ON special_days;
CREATE POLICY "special_days: creator or admin update" ON special_days
  FOR UPDATE USING (created_by = auth.uid() OR wallet_can_edit(wallet_id));

DROP POLICY IF EXISTS "special_days: wallet members can delete" ON special_days;
CREATE POLICY "special_days: creator or admin delete" ON special_days
  FOR DELETE USING (created_by = auth.uid() OR wallet_can_delete(wallet_id));
