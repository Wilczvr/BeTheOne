-- BeTheOne League - PR event configuration.
-- Run once in Supabase Dashboard > SQL Editor after the base league schema.

begin;

create table if not exists public.league_pr_events (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 80),
  match_text text not null check (char_length(match_text) between 2 and 80),
  metric_type text not null check (metric_type in ('strength_max', 'reps_max', 'timed_distance', 'distance_max', 'duration_max')),
  target_distance_km numeric(8, 2) check (target_distance_km is null or target_distance_km between 0.1 and 300),
  order_index integer not null default 0 check (order_index between 0 and 1000),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (metric_type = 'timed_distance' and target_distance_km is not null)
    or (metric_type <> 'timed_distance' and target_distance_km is null)
  )
);

create index if not exists league_pr_events_order_idx
  on public.league_pr_events (league_id, order_index, created_at);

drop trigger if exists league_pr_events_updated_at on public.league_pr_events;
create trigger league_pr_events_updated_at
before update on public.league_pr_events
for each row execute function public.set_updated_at();

alter table public.league_pr_events enable row level security;

drop policy if exists "pr_events_read_member" on public.league_pr_events;
create policy "pr_events_read_member"
on public.league_pr_events for select
to authenticated
using (public.is_league_member(league_id));

drop policy if exists "pr_events_insert_owner" on public.league_pr_events;
create policy "pr_events_insert_owner"
on public.league_pr_events for insert
to authenticated
with check (created_by = auth.uid() and public.is_league_owner(league_id));

drop policy if exists "pr_events_update_owner" on public.league_pr_events;
create policy "pr_events_update_owner"
on public.league_pr_events for update
to authenticated
using (public.is_league_owner(league_id))
with check (public.is_league_owner(league_id));

drop policy if exists "pr_events_delete_owner" on public.league_pr_events;
create policy "pr_events_delete_owner"
on public.league_pr_events for delete
to authenticated
using (public.is_league_owner(league_id));

revoke all on table public.league_pr_events from anon;
grant select, insert, update, delete on table public.league_pr_events to authenticated;

alter table public.league_pr_events replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'league_pr_events'
  ) then
    alter publication supabase_realtime add table public.league_pr_events;
  end if;
end;
$$;

commit;
