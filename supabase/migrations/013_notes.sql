-- ─────────────────────────────────────────────────────────────────────────────
-- 013_notes.sql  –  PlanIt Notes (sticky notes)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  wallet_id   uuid not null references public.wallets(id) on delete cascade,
  title       text not null default '',
  content     text not null default '',
  color       text not null default 'yellow',   -- NoteColor name
  is_pinned   boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Updated-at trigger
create or replace function public.set_notes_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_notes_updated_at on public.notes;
create trigger trg_notes_updated_at
  before update on public.notes
  for each row execute procedure public.set_notes_updated_at();

-- Indexes
create index if not exists notes_wallet_id_idx on public.notes(wallet_id);
create index if not exists notes_is_pinned_idx  on public.notes(wallet_id, is_pinned);

-- RLS
alter table public.notes enable row level security;

-- Members of the wallet (personal owner or family member) can read
create policy "notes_select" on public.notes
  for select using (
    wallet_id in (
      select id from public.wallets where owner_id = auth.uid()
      union
      select wallet_id from public.family_members where user_id = auth.uid()
    )
  );

-- Same users can insert
create policy "notes_insert" on public.notes
  for insert with check (
    wallet_id in (
      select id from public.wallets where owner_id = auth.uid()
      union
      select wallet_id from public.family_members where user_id = auth.uid()
    )
  );

-- Same users can update
create policy "notes_update" on public.notes
  for update using (
    wallet_id in (
      select id from public.wallets where owner_id = auth.uid()
      union
      select wallet_id from public.family_members where user_id = auth.uid()
    )
  );

-- Same users can delete
create policy "notes_delete" on public.notes
  for delete using (
    wallet_id in (
      select id from public.wallets where owner_id = auth.uid()
      union
      select wallet_id from public.family_members where user_id = auth.uid()
    )
  );
