-- Run once if league-schema.sql was installed before the pgcrypto schema fix.
-- Supabase installs pgcrypto in the "extensions" schema.

begin;

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

revoke all on function public.create_league(text) from public, anon;
revoke all on function public.join_league(text) from public, anon;
revoke all on function public.rotate_league_invite(uuid) from public, anon;
grant execute on function public.create_league(text) to authenticated;
grant execute on function public.join_league(text) to authenticated;
grant execute on function public.rotate_league_invite(uuid) to authenticated;

commit;
