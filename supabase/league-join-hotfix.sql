-- Standalone repair for the join_league RPC.
-- Run this entire file in Supabase SQL Editor without selecting only a fragment.

begin;

create or replace function public.join_league(p_invite_token text)
returns table (league_id uuid, league_name text)
language plpgsql
security definer
set search_path = ''
as $join$
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
  from public.league_invites as invite
  where invite.token_hash = extensions.digest(p_invite_token, 'sha256')
    and invite.revoked_at is null
    and (invite.expires_at is null or invite.expires_at > now())
  for update;

  if v_invite_id is null
    or (v_max_uses is not null and v_uses_count >= v_max_uses) then
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
    update public.league_invites as invite
    set uses_count = invite.uses_count + 1
    where invite.id = v_invite_id;
  end if;

  return query
  select league.id, league.name
  from public.leagues as league
  where league.id = v_league_id;
end;
$join$;

revoke all on function public.join_league(text) from public, anon;
grant execute on function public.join_league(text) to authenticated;

commit;
