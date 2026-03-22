-- ─────────────────────────────────────────────────────────────────────────────
-- 015_notes_add_type.sql  –  Add note_type column to existing notes table
-- (notes table was created before this column was added to 013_notes.sql)
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.notes
  add column if not exists note_type text not null default 'text';
