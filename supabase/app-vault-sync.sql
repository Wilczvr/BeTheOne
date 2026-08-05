begin;

create table if not exists public.app_vault_sync (
  user_id uuid primary key references auth.users(id) on delete cascade,
  vault jsonb not null,
  vault_updated_at timestamptz not null default now(),
  checksum text not null default '',
  device_id text not null default '',
  synced_at timestamptz not null default now()
);

alter table public.app_vault_sync enable row level security;

drop policy if exists "app_vault_sync_select_own" on public.app_vault_sync;
drop policy if exists "app_vault_sync_insert_own" on public.app_vault_sync;
drop policy if exists "app_vault_sync_update_own" on public.app_vault_sync;

create policy "app_vault_sync_select_own"
on public.app_vault_sync
for select
to authenticated
using (auth.uid() = user_id);

create policy "app_vault_sync_insert_own"
on public.app_vault_sync
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "app_vault_sync_update_own"
on public.app_vault_sync
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

grant select, insert, update on public.app_vault_sync to authenticated;

commit;
