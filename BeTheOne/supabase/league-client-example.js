// Reference contract for the BeTheOne League integration.
// This file is not loaded by index.html yet. It documents the client calls
// that will be connected to the League tab in the next implementation step.

export function createLeagueApi(createClient, config) {
  const client = createClient(config.url, config.publishableKey);

  async function ensureSession() {
    const { data: sessionData, error: sessionError } = await client.auth.getSession();
    if (sessionError) {
      throw sessionError;
    }

    if (sessionData.session) {
      return sessionData.session;
    }

    const { data, error } = await client.auth.signInAnonymously();
    if (error) {
      throw error;
    }
    return data.session;
  }

  async function saveProfile(profile) {
    const session = await ensureSession();
    const payload = {
      user_id: session.user.id,
      display_name: profile.displayName,
      avatar_species: profile.avatarSpecies,
      avatar_mood: profile.avatarMood,
      avatar_effect: profile.avatarEffect,
    };
    const { error } = await client.from("league_profiles").upsert(payload);
    if (error) {
      throw error;
    }
  }

  async function createLeague(name) {
    await ensureSession();
    const { data, error } = await client.rpc("create_league", { p_name: name });
    if (error) {
      throw error;
    }
    return data[0];
  }

  async function joinLeague(inviteToken) {
    await ensureSession();
    const { data, error } = await client.rpc("join_league", {
      p_invite_token: inviteToken,
    });
    if (error) {
      throw error;
    }
    return data[0];
  }

  async function publishWeeklySnapshot(snapshot) {
    const session = await ensureSession();
    const payload = {
      league_id: snapshot.leagueId,
      user_id: session.user.id,
      week_start: snapshot.weekStart,
      workouts_count: snapshot.workoutsCount,
      active_days: snapshot.activeDays,
      planned_days: snapshot.plannedDays,
      streak_days: snapshot.streakDays,
      total_minutes: snapshot.totalMinutes,
      distance_km: snapshot.distanceKm,
      total_volume_kg: snapshot.totalVolumeKg,
      calories_burned: snapshot.caloriesBurned,
      prs_count: snapshot.prsCount,
      synced_at: new Date().toISOString(),
    };
    const { error } = await client
      .from("league_weekly_snapshots")
      .upsert(payload, { onConflict: "league_id,user_id,week_start" });
    if (error) {
      throw error;
    }
  }

  async function getLeaderboard(leagueId, weekStart) {
    const { data, error } = await client
      .from("league_leaderboard")
      .select("*")
      .eq("league_id", leagueId)
      .eq("week_start", weekStart)
      .order("rank_position", { ascending: true });
    if (error) {
      throw error;
    }
    return data;
  }

  function subscribeToLeague(leagueId, onChange) {
    return client
      .channel(`league-${leagueId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "league_weekly_snapshots",
          filter: `league_id=eq.${leagueId}`,
        },
        onChange
      )
      .subscribe();
  }

  return {
    client,
    ensureSession,
    saveProfile,
    createLeague,
    joinLeague,
    publishWeeklySnapshot,
    getLeaderboard,
    subscribeToLeague,
  };
}
