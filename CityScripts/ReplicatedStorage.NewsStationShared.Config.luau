--!strict
local Config = {}

-- NewsStation's own balance/timing values (spec addendum, 2026-09-2X),
-- entirely separate from HeistShared.Config/RestaurantShared.Config/
-- Gas2GoShared.Config -- only the SHARED systems (BankInstance,
-- GamepassManager, Forfeit, NPCReactionAnimator, the alarm sound template,
-- the claim-zone pattern) are common; every number is per-location. Field
-- NAMES below are dictated by BankInstance, which this config is
-- constructed for (BankInstance:TryStart/_seal read "SessionDuration"/
-- "CooldownDuration" verbatim, GetDuffelCap reads "DuffelCap") -- not
-- renamed to match this turn's prose ("HeistDuration"/"BaseDuffelCap")
-- even though that's what the spec called them informally, since
-- BankInstance itself is reused unchanged -- same convention
-- RestaurantShared.Config/Gas2GoShared.Config both already establish.
Config.SessionDuration = 600 -- 10 minutes, confirmed by the project owner
Config.CooldownDuration = 1200 -- 20 minutes, confirmed by the project owner
Config.DuffelCap = 10000 -- confirmed by the project owner
-- Studs the player must get from this location's StatusBillboardAnchor,
-- measured horizontally and only once clear of the building, before a
-- bag banks (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
-- 200 against the measured map: the ExitSpawns sit 54-80 studs out, so
-- this is a 120-145 stud run (~8-9s at WalkSpeed 16), and with
-- neighbouring locations 165-205 apart it reads as "about one block over"
-- without pushing the player through another location's grounds.
-- A starting value, not a tuned one -- expect to adjust after playtesting.
-- NOTE: anything at or above ~314 would let a Bank player satisfy the gate
-- from inside the vault if Getaway's inside-the-building gate were ever
-- removed. See Getaway's own header.
Config.EscapeDistance = 200
-- No time-based accrual mechanic exists at NewsStation either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- every other non-Bank location's own Config.
Config.AccrualPerSecond = 0

-- Flat amounts credited per successful rob hold (spec addendum,
-- 2026-09-2X) -- confirmed equal to Gas2Go/SlowFoods' own register value
-- and Gas2Go's own ATM value, kept as NewsStation's OWN config entries
-- regardless (never read from HeistShared.Config), same "Config
-- Separation" discipline as every other location.
Config.RegisterRobAmount = 2000
Config.ATMRobAmount = 3000

Config.HeartbeatRate = 10

-- Security guards (police and wanted Task 3, 2026-11-17): GuardPost components on the NewsStationGuardPost
-- markers in NewsStationMarkers, standing at their posts from boot (GuardsAlwaysPosted; the Bank's appear only
-- while Active). No cover points here: they hold their posts. The combat numbers equal the Bank's
-- (HeistShared.Config), kept as NewsStation's own entries like every number in this file.
Config.GuardsAlwaysPosted = true
-- GuardTemplate's pivot is at its feet: 0 puts them on the floor the markers are centred on (the Bank's
-- default of 3 lifts its guards 3 studs above their posts, measured 2026-11-17).
Config.GuardSpawnLift = 0
Config.GuardActivationRange = 60
Config.GuardSightRange = 120
Config.GuardFireInterval = 0.9
Config.GuardDamage = 0

-- Debug stays mutable so integration runs can shorten the lifecycle, same
-- pattern as every other location's own Config.
Config.Debug = { FastLifecycle = false }

local FAST = { SessionDuration = 10, CooldownDuration = 20 }

function Config.effective(key: string): number
	if Config.Debug.FastLifecycle and FAST[key] then
		return FAST[key]
	end
	return (Config :: any)[key]
end

-- Per-location-namespaced tags (spec addendum, 2026-09-2X), same discipline
-- as every other location's own Config.Tags -- CollectionService tags are
-- game-wide, so distinct names prevent NewsStation's own registry sweeps
-- from binding SlowFoods'/Gas2Go's/the Bank's parts, and vice versa.
-- Safe/MasterComputer (spec addendum, follow-up pass): MasterComputer/Safe
-- are now built and wired -- see NewsStationSafe below.
Config.Tags = table.freeze({
	NewsStationZone = "NewsStationZone",
	NewsStationExitSpawn = "NewsStationExitSpawn",
	NewsStationAccessBarrier = "NewsStationAccessBarrier",
	NewsWorker = "NewsWorker",
	-- Register/ATM/Camera: RobbableObject/SupplyObject reuse verbatim, same
	-- as every other location.
	NewsStationRegister = "NewsStationRegister",
	NewsStationATM = "NewsStationATM",
	NewsStationCamera = "NewsStationCamera",
	-- DeadlyOil: a static, always-armed LaserHazard-based touch hazard --
	-- deliberately NOT reusing the Bank's own HeistLaser tag, same
	-- cross-location-binding-collision reasoning as every tag above. The
	-- literal string was already applied to the real world parts before this
	-- entry was added here (confirmed live) -- this just gives the existing
	-- string a home in Config.Tags so T.NewsStationOilHazard resolves.
	NewsStationOilHazard = "NewsStationOilHazard",
	-- MasterComputer's Connect-the-Dots hacking chain (follow-up pass): tags
	-- the 3 real Safe.Safe models so NewsStationServer's own sweep can bind
	-- them -- same cross-location-namespacing reasoning as every tag here,
	-- distinct from the Bank's own BankSafe tag.
	NewsStationSafe = "NewsStationSafe",
	-- Guard posts (police and wanted Task 3): 3 invisible markers in NewsStationMarkers.
	NewsStationGuardPost = "NewsStationGuardPost",
})

return table.freeze(Config)
