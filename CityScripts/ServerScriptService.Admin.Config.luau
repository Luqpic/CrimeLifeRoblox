-- Admin numbers (2026-11-20, admin-design.md). Server only: ServerScriptService never replicates.
return table.freeze({
	-- Roles (Admin.Roles): SolarArc Studios, whatever group or user created the place.
	GROUP_ID = 4998611,
	OWNER_RANK = 255,
	HELPER_RANK = 252,
	-- A failed rank lookup is retried this many times, this far apart (no role meanwhile).
	RANK_RETRY_SECONDS = 60,
	RANK_RETRIES = 3,

	-- Dispatcher (Admin.Actions)
	COOLDOWN = 0.25, -- seconds between two calls from one admin
	LOG_SIZE = 150, -- rows kept in memory per server, newest first
	REFUSAL_LOG_SECONDS = 60, -- a caller with no role writes at most one row this often

	-- Ranges
	CASH_LIMIT = 1e9, -- addCash amount, either sign (a gift is further bound by CurrencyService's MaxCashCredit)
	SPRAYPAINT_LIMIT = 1e6,
	STARS_MAX = 5,
	SPAWN_COUNT_MAX = 6,
	POLICE_ARMED_FROM = 3, -- the 3rd officer of a spawn on is Armed Police, as the squads arm from 3 stars
	SPAWN_RING = 12, -- studs from the admin to a spawned body
	WALK_SPEED_MIN = 8,
	WALK_SPEED_MAX = 100,
	KICK_REASON_MAX = 120,
	ANNOUNCE_MAX = 140,

	-- Ban lengths in seconds (-1 = forever); a helper may pick up to HELPER_BAN_MAX.
	BAN_DURATIONS = table.freeze({ ["1h"] = 3600, ["1d"] = 86400, ["7d"] = 604800, forever = -1 }),
	HELPER_BAN_MAX = 86400,

	-- Teleports land this far above the marker.
	TELEPORT_UP = 4,
	-- A god admin falling within this many studs of Workspace.FallenPartsDestroyHeight is put back on the spawn.
	VOID_MARGIN = 60,

	HEISTS = table.freeze({ "Bank", "SlowFoods", "Gas2Go", "NewsStation" }),
	-- teleportTo: Workspace path of each place; "Spawn" is the enabled SpawnLocation.
	PLACES = table.freeze({
		Bank = table.freeze({ "HeistMarkers", "ExitSpawn" }),
		SlowFoods = table.freeze({ "SlowFoodsMarkers", "SlowFoodsExitSpawn" }),
		Gas2Go = table.freeze({ "Gas2GoMarkers", "Gas2GoExitSpawn" }),
		NewsStation = table.freeze({ "NewsStationMarkers", "NewsStationExitSpawn" }),
		["Illegal Supplier"] = table.freeze({ "Illegal Supplier", "Interaction" }),
		Spawn = true,
	}),
})
