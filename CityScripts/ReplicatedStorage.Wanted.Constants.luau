--!strict
-- Every number of the police and wanted design (spec section 5, 2026-11-17) lives here and nowhere else.
return {
	-- Heat and stars
	MAX_HEAT = 5,
	-- "heat becomes at least" this on the robbery's alarm; keys are the names the robbery paths announce
	ALARM_LEVELS = { Gas2Go = 1, SlowFoods = 1, NewsStation = 2, Bank = 3 },
	POLICE_HIT_HEAT = 0.25,
	POLICE_KILL_HEAT = 1,
	PUBLIC_KILL_HEAT = 0.5, -- killing any NPC while a witness sees it
	PUBLIC_HURT_HEAT = 0.25, -- hurting a heist civilian while a witness sees it
	WITNESS_RANGE = 120,
	-- The pellets of one shotgun blast, or the rays of one melee swing, land within one frame: hits on the
	-- same officer by the same player this close together count once (not in the spec; the builder's call).
	HIT_MERGE_WINDOW = 0.1,

	-- Being seen and the drain
	SEEN_RANGE = 150,
	DRAIN_INTERVAL = 8,
	-- Design section 9: after any rise in heat the unseen timer may not start for this long.
	SEARCH_SECONDS = 20,
	SEEN_CHECK_HZ = 2,
	-- A death with no damage the server saw in the last this-many seconds is a self-reset: the stars carry into
	-- the next character (developer decision, open items pass 2026-11-18). A death after damage clears them.
	RESET_DAMAGE_SECONDS = 5,

	-- Police dispatch
	POLICE_TEMPLATES = { Police = true, ["Armed Police"] = true }, -- victim attribute EnemyTemplate
	SQUAD_BY_STARS = {
		[1] = { police = 2, armed = 0 },
		[2] = { police = 4, armed = 0 },
		[3] = { police = 4, armed = 2 },
		[4] = { police = 4, armed = 4 },
		[5] = { police = 4, armed = 6 },
	},
	ARMED_FROM_STARS = 3,
	ALARM_RING_MIN = 60,
	ALARM_RING_MAX = 120,
	TOPUP_RING_MIN = 90,
	TOPUP_RING_MAX = 160,
	TOPUP_INTERVAL = 5,
	POLICE_CAP = 24,
	-- Dispatcher (Task 2, the builder's numbers): a spawn point stands SPAWN_HEIGHT above road or footpath
	-- ground found within GROUND_PROBE studs below it; ring samples are cast down from SAMPLE_TOP_Y for
	-- SAMPLE_DEPTH studs, up to SPAWN_SAMPLES per officer; the cheap checks (box, ground, sight) are unbudgeted,
	-- the path checks share SPAWN_PATH_BUDGET per player per round (slow fill fix, 2026-11-17). The path check uses the AI's own agent (EnemyAI:_computePath).
	SPAWN_HEIGHT = 3,
	GROUND_PROBE = 5,
	SAMPLE_TOP_Y = 500,
	SAMPLE_DEPTH = 700,
	SIGHT_PROBE_HEIGHTS = { -2, 0, 2 }, -- officer's legs, root and head relative to its spawn point
	SIGHT_PROBE_SIDE = 1.5, -- and left and right of the root, across the line of view (a pole hides none of it)
	SEE_THROUGH_TRANSPARENCY = 0.3, -- a part at least this transparent (glass) does not hide an officer
	SIGHT_RECASTS = 8, -- see-through parts passed per sight ray at most
	-- Measured 2026-11-17: near SlowFoods about 1 in 20 ring samples passes every check, at the city spawn plaza
	-- 4 in 3,000 (the open road grid is in sight out to 320 studs); 3,000 cheap samples took 0.48 s spread over
	-- frames. 2,000 samples find a point there about 93 % of the time.
	SPAWN_SAMPLES = 2000,
	SPAWN_PATH_BUDGET = 20, -- ComputeAsync calls per player per round
	POLICE_AGENT = { AgentRadius = 2, AgentHeight = 5, AgentCanJump = true },
	-- An officer whose player is cleared, dead or gone and who sees no other wanted player walks this far away
	-- from the nearest player, and despawns once no player has line of sight to it, or after LEAVE_TIMEOUT.
	LEAVE_DISTANCE = 200,
	LEAVE_TIMEOUT = 60, -- review fix round 1: 30 s could remove an officer a player was looking at
	DISPATCH_TICK = 1, -- orphans and leavers are handled every tick; top-ups every TOPUP_INTERVAL

	-- Security guards
	NEWSSTATION_GUARDS = 3,
}
