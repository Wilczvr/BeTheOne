-- BeTheOne League - database schema, RPC functions, RLS and Realtime setup.
-- Run the whole file once in Supabase Dashboard > SQL Editor.

begin;

create extension if not exists pgcrypto;

create table if not exists public.league_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 2 and 32),
  avatar_species text not null default 'panda'
    check (avatar_species in ('panda', 'tiger', 'wolf', 'dragon')),
  avatar_mood text not null default 'calm'
    check (avatar_mood in ('calm', 'feral')),
  avatar_effect text not null default 'ruby_aura'
    check (avatar_effect in ('ruby_aura', 'fire_aura', 'water_flow', 'emerald_field', 'shadow_veil', 'firework_burst')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.leagues (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 3 and 60),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.league_members (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create unique index if not exists league_single_owner_idx
  on public.league_members (league_id)
  where role = 'owner';

create index if not exists league_members_user_idx
  on public.league_members (user_id, league_id);

create table if not exists public.league_invites (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  token_hash bytea not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  uses_count integer not null default 0 check (uses_count >= 0),
  max_uses integer check (max_uses is null or max_uses > 0),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists league_invites_active_idx
  on public.league_invites (league_id, expires_at)
  where revoked_at is null;

create table if not exists public.league_weekly_snapshots (
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  week_start date not null check (extract(isodow from week_start) = 1),
  workouts_count integer not null default 0 check (workouts_count between 0 and 100),
  active_days integer not null default 0 check (active_days between 0 and 7),
  planned_days integer not null default 0 check (planned_days between 0 and 7),
  streak_days integer not null default 0 check (streak_days between 0 and 36500),
  total_minutes integer not null default 0 check (total_minutes between 0 and 10080),
  distance_km numeric(10, 2) not null default 0 check (distance_km between 0 and 100000),
  total_volume_kg numeric(14, 1) not null default 0 check (total_volume_kg between 0 and 1000000000),
  calories_burned integer not null default 0 check (calories_burned between 0 and 10000000),
  prs_count integer not null default 0 check (prs_count between 0 and 1000),
  points integer generated always as (
    workouts_count * 100
    + active_days * 40
    + least(streak_days, 30) * 10
    + prs_count * 75
  ) stored,
  synced_at timestamptz not null default now(),
  primary key (league_id, user_id, week_start),
  foreign key (league_id, user_id)
    references public.league_members(league_id, user_id)
    on delete cascade
);

create index if not exists league_weekly_ranking_idx
  on public.league_weekly_snapshots (league_id, week_start, points desc);

create table if not exists public.league_personal_records (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references public.leagues(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  exercise_key text not null check (char_length(exercise_key) between 1 and 100),
  exercise_name text not null check (char_length(exercise_name) between 1 and 100),
  value numeric(14, 2) not null check (value >= 0),
  unit text not null check (unit in ('kg', 'reps', 'km', 'min', 'kg_volume')),
  achieved_on date not null,
  synced_at timestamptz not null default now(),
  unique (league_id, user_id, exercise_key, unit),
  foreign key (league_id, user_id)
    references public.league_members(league_id, user_id)
    on delete cascade
);

create index if not exists league_pr_feed_idx
  on public.league_personal_records (league_id, achieved_on desc);

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

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists league_profiles_updated_at on public.league_profiles;
create trigger league_profiles_updated_at
before update on public.league_profiles
for each row execute function public.set_updated_at();

drop trigger if exists leagues_updated_at on public.leagues;
create trigger leagues_updated_at
before update on public.leagues
for each row execute function public.set_updated_at();

drop trigger if exists league_pr_events_updated_at on public.league_pr_events;
create trigger league_pr_events_updated_at
before update on public.league_pr_events
for each row execute function public.set_updated_at();

create or replace function public.is_league_member(
  p_league_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.league_members member
    where member.league_id = p_league_id
      and member.user_id = p_user_id
  );
$$;

create or replace function public.is_league_owner(
  p_league_id uuid,
  p_user_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.leagues league
    where league.id = p_league_id
      and league.owner_id = p_user_id
  );
$$;

create or replace function public.shares_league_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.league_members mine
    join public.league_members theirs
      on theirs.league_id = mine.league_id
    where mine.user_id = auth.uid()
      and theirs.user_id = p_other_user_id
  );
$$;

alter table public.league_profiles enable row level security;
alter table public.leagues enable row level security;
alter table public.league_members enable row level security;
alter table public.league_invites enable row level security;
alter table public.league_weekly_snapshots enable row level security;
alter table public.league_personal_records enable row level security;
alter table public.league_pr_events enable row level security;

drop policy if exists "profiles_read_shared" on public.league_profiles;
create policy "profiles_read_shared"
on public.league_profiles for select
to authenticated
using (user_id = auth.uid() or public.shares_league_with(user_id));

drop policy if exists "profiles_insert_own" on public.league_profiles;
create policy "profiles_insert_own"
on public.league_profiles for insert
to authenticated
with check (user_id = auth.uid());

drop policy if exists "profiles_update_own" on public.league_profiles;
create policy "profiles_update_own"
on public.league_profiles for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "leagues_read_member" on public.leagues;
create policy "leagues_read_member"
on public.leagues for select
to authenticated
using (public.is_league_member(id));

drop policy if exists "leagues_update_owner" on public.leagues;
create policy "leagues_update_owner"
on public.leagues for update
to authenticated
using (public.is_league_owner(id))
with check (owner_id = auth.uid());

drop policy if exists "leagues_delete_owner" on public.leagues;
create policy "leagues_delete_owner"
on public.leagues for delete
to authenticated
using (public.is_league_owner(id));

drop policy if exists "members_read_member" on public.league_members;
create policy "members_read_member"
on public.league_members for select
to authenticated
using (public.is_league_member(league_id));

drop policy if exists "members_delete_owner" on public.league_members;
create policy "members_delete_owner"
on public.league_members for delete
to authenticated
using (public.is_league_owner(league_id) and role <> 'owner');

drop policy if exists "invites_read_owner" on public.league_invites;
create policy "invites_read_owner"
on public.league_invites for select
to authenticated
using (public.is_league_owner(league_id));

drop policy if exists "snapshots_read_member" on public.league_weekly_snapshots;
create policy "snapshots_read_member"
on public.league_weekly_snapshots for select
to authenticated
using (public.is_league_member(league_id));

drop policy if exists "snapshots_insert_own" on public.league_weekly_snapshots;
create policy "snapshots_insert_own"
on public.league_weekly_snapshots for insert
to authenticated
with check (user_id = auth.uid() and public.is_league_member(league_id));

drop policy if exists "snapshots_update_own" on public.league_weekly_snapshots;
create policy "snapshots_update_own"
on public.league_weekly_snapshots for update
to authenticated
using (user_id = auth.uid() and public.is_league_member(league_id))
with check (user_id = auth.uid() and public.is_league_member(league_id));

drop policy if exists "snapshots_delete_own" on public.league_weekly_snapshots;
create policy "snapshots_delete_own"
on public.league_weekly_snapshots for delete
to authenticated
using (user_id = auth.uid());

drop policy if exists "prs_read_member" on public.league_personal_records;
create policy "prs_read_member"
on public.league_personal_records for select
to authenticated
using (public.is_league_member(league_id));

drop policy if exists "prs_insert_own" on public.league_personal_records;
create policy "prs_insert_own"
on public.league_personal_records for insert
to authenticated
with check (user_id = auth.uid() and public.is_league_member(league_id));

drop policy if exists "prs_update_own" on public.league_personal_records;
create policy "prs_update_own"
on public.league_personal_records for update
to authenticated
using (user_id = auth.uid() and public.is_league_member(league_id))
with check (user_id = auth.uid() and public.is_league_member(league_id));

drop policy if exists "prs_delete_own" on public.league_personal_records;
create policy "prs_delete_own"
on public.league_personal_records for delete
to authenticated
using (user_id = auth.uid());

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

create or replace function public.create_league(p_name text)
returns table (league_id uuid, invite_token text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_league_id uuid;
  v_token text;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  p_name := btrim(p_name);
  if char_length(p_name) < 3 or char_length(p_name) > 60 then
    raise exception 'invalid_league_name';
  end if;

  insert into public.league_profiles (user_id, display_name)
  values (v_user_id, 'Zawodnik')
  on conflict (user_id) do nothing;

  insert into public.leagues (owner_id, name)
  values (v_user_id, p_name)
  returning id into v_league_id;

  insert into public.league_members (league_id, user_id, role)
  values (v_league_id, v_user_id, 'owner');

  v_token := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_');

  insert into public.league_invites (league_id, token_hash, created_by)
  values (v_league_id, extensions.digest(v_token, 'sha256'), v_user_id);

  return query select v_league_id, v_token;
end;
$$;

create or replace function public.join_league(p_invite_token text)
returns table (league_id uuid, league_name text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_invite_id uuid;
  v_league_id uuid;
  v_max_uses integer;
  v_uses_count integer;
  v_inserted integer;
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  p_invite_token := btrim(p_invite_token);
  if char_length(p_invite_token) < 20 then
    raise exception 'invalid_invite';
  end if;

  select invite.id, invite.league_id, invite.max_uses, invite.uses_count
    into v_invite_id, v_league_id, v_max_uses, v_uses_count
  from public.league_invites invite
  where invite.token_hash = extensions.digest(p_invite_token, 'sha256')
    and invite.revoked_at is null
    and (invite.expires_at is null or invite.expires_at > now())
  for update;

  if v_invite_id is null or (v_max_uses is not null and v_uses_count >= v_max_uses) then
    raise exception 'invalid_or_expired_invite';
  end if;

  insert into public.league_profiles (user_id, display_name)
  values (v_user_id, 'Zawodnik')
  on conflict (user_id) do nothing;

  insert into public.league_members (league_id, user_id, role)
  values (v_league_id, v_user_id, 'member')
  on conflict on constraint league_members_pkey do nothing;

  get diagnostics v_inserted = row_count;

  if v_inserted > 0 then
    update public.league_invites
    set uses_count = uses_count + 1
    where id = v_invite_id;
  end if;

  return query
  select league.id, league.name
  from public.leagues league
  where league.id = v_league_id;
end;
$$;

create or replace function public.rotate_league_invite(p_league_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_token text;
begin
  if not public.is_league_owner(p_league_id, v_user_id) then
    raise exception 'owner_required';
  end if;

  update public.league_invites
  set revoked_at = now()
  where league_id = p_league_id
    and revoked_at is null;

  v_token := translate(encode(extensions.gen_random_bytes(24), 'base64'), '+/=', '-_');

  insert into public.league_invites (league_id, token_hash, created_by)
  values (p_league_id, extensions.digest(v_token, 'sha256'), v_user_id);

  return v_token;
end;
$$;

create or replace function public.leave_league(p_league_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'authentication_required';
  end if;

  if public.is_league_owner(p_league_id, v_user_id) then
    raise exception 'owner_must_delete_league';
  end if;

  delete from public.league_members
  where league_id = p_league_id
    and user_id = v_user_id;
end;
$$;

create or replace view public.league_leaderboard
with (security_invoker = true)
as
select
  snapshot.league_id,
  snapshot.week_start,
  snapshot.user_id,
  profile.display_name,
  profile.avatar_species,
  profile.avatar_mood,
  profile.avatar_effect,
  member.role,
  snapshot.workouts_count,
  snapshot.active_days,
  snapshot.planned_days,
  snapshot.streak_days,
  snapshot.total_minutes,
  snapshot.distance_km,
  snapshot.total_volume_kg,
  snapshot.calories_burned,
  snapshot.prs_count,
  snapshot.points,
  snapshot.synced_at,
  dense_rank() over (
    partition by snapshot.league_id, snapshot.week_start
    order by
      snapshot.points desc,
      snapshot.workouts_count desc,
      snapshot.total_minutes desc,
      snapshot.synced_at asc
  ) as rank_position
from public.league_weekly_snapshots snapshot
join public.league_profiles profile on profile.user_id = snapshot.user_id
join public.league_members member
  on member.league_id = snapshot.league_id
  and member.user_id = snapshot.user_id;

revoke all on table public.league_profiles from anon;
revoke all on table public.leagues from anon;
revoke all on table public.league_members from anon;
revoke all on table public.league_invites from anon;
revoke all on table public.league_weekly_snapshots from anon;
revoke all on table public.league_personal_records from anon;
revoke all on table public.league_pr_events from anon;
revoke all on table public.league_leaderboard from anon;

grant select, insert, update on table public.league_profiles to authenticated;
grant select, update, delete on table public.leagues to authenticated;
grant select, delete on table public.league_members to authenticated;
grant select on table public.league_invites to authenticated;
grant select, insert, update, delete on table public.league_weekly_snapshots to authenticated;
grant select, insert, update, delete on table public.league_personal_records to authenticated;
grant select, insert, update, delete on table public.league_pr_events to authenticated;
grant select on table public.league_leaderboard to authenticated;

revoke all on function public.is_league_member(uuid, uuid) from public, anon;
revoke all on function public.is_league_owner(uuid, uuid) from public, anon;
revoke all on function public.shares_league_with(uuid) from public, anon;
revoke all on function public.create_league(text) from public, anon;
revoke all on function public.join_league(text) from public, anon;
revoke all on function public.rotate_league_invite(uuid) from public, anon;
revoke all on function public.leave_league(uuid) from public, anon;

grant execute on function public.is_league_member(uuid, uuid) to authenticated;
grant execute on function public.is_league_owner(uuid, uuid) to authenticated;
grant execute on function public.shares_league_with(uuid) to authenticated;
grant execute on function public.create_league(text) to authenticated;
grant execute on function public.join_league(text) to authenticated;
grant execute on function public.rotate_league_invite(uuid) to authenticated;
grant execute on function public.leave_league(uuid) to authenticated;

alter table public.league_weekly_snapshots replica identity full;
alter table public.league_personal_records replica identity full;
alter table public.league_pr_events replica identity full;

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'league_weekly_snapshots'
  ) then
    alter publication supabase_realtime add table public.league_weekly_snapshots;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'league_personal_records'
  ) then
    alter publication supabase_realtime add table public.league_personal_records;
  end if;

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
