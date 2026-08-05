begin;

create table if not exists public.app_email_recovery (
  user_id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  recovery_secret text not null,
  recovery_version integer not null default 2,
  updated_at timestamptz not null default now()
);

alter table public.app_email_recovery enable row level security;

drop policy if exists "app_email_recovery_select_own" on public.app_email_recovery;
drop policy if exists "app_email_recovery_insert_own" on public.app_email_recovery;
drop policy if exists "app_email_recovery_update_own" on public.app_email_recovery;
drop policy if exists "app_email_recovery_delete_own" on public.app_email_recovery;

create policy "app_email_recovery_select_own"
on public.app_email_recovery
for select
to authenticated
using (auth.uid() = user_id);

create policy "app_email_recovery_insert_own"
on public.app_email_recovery
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "app_email_recovery_update_own"
on public.app_email_recovery
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "app_email_recovery_delete_own"
on public.app_email_recovery
for delete
to authenticated
using (auth.uid() = user_id);

grant select, insert, update, delete on public.app_email_recovery to authenticated;

commit;
