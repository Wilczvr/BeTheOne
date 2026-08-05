-- Read-only installation check for BeTheOne League.

select
  expected.object_name,
  case when actual.object_name is null then 'MISSING' else 'OK' end as status
from (
  values
    ('league_profiles'),
    ('leagues'),
    ('league_members'),
    ('league_invites'),
    ('league_weekly_snapshots'),
    ('league_personal_records'),
    ('league_leaderboard')
) as expected(object_name)
left join (
  select table_name as object_name
  from information_schema.tables
  where table_schema = 'public'
  union
  select table_name as object_name
  from information_schema.views
  where table_schema = 'public'
) as actual using (object_name)
order by expected.object_name;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  count(p.policyname) as policy_count
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policies p
  on p.schemaname = n.nspname
  and p.tablename = c.relname
where n.nspname = 'public'
  and c.relname in (
    'league_profiles',
    'leagues',
    'league_members',
    'league_invites',
    'league_weekly_snapshots',
    'league_personal_records'
  )
group by c.relname, c.relrowsecurity
order by c.relname;

select
  tablename,
  case when pubname = 'supabase_realtime' then 'OK' else 'MISSING' end as realtime_status
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('league_weekly_snapshots', 'league_personal_records')
order by tablename;

select
  routine_name,
  'OK' as status
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'create_league',
    'join_league',
    'rotate_league_invite',
    'leave_league',
    'is_league_member',
    'is_league_owner',
    'shares_league_with'
  )
order by routine_name;
