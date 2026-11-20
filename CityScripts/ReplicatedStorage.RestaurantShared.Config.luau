--!strict
local Config = {}

-- SlowFoods' own balance/timing values (spec addendum, 2026-09-06),
-- entirely separate from HeistShared.Config (the Bank's) -- only the
-- SHARED systems (BankInstance, GamepassManager, Forfeit, NPCReactionAnimator,
-- the alarm sound template, the claim-zone pattern) are common; every
-- number is per-location. Field NAMES below are dictated by BankInstance,
-- which this config is constructed for (BankInstance:TryStart/_seal read
-- "SessionDuration"/"CooldownDuration" verbatim, GetDuffelCap reads
-- "DuffelCap") -- they are not renamed to match this turn's prose
-- ("HeistDuration"/"BaseDuffelCap") even though that's what the spec called
-- them informally, since BankInstance itself is reused unchanged.
Config.SessionDuration = 120 -- 2 minutes
-- Reverted to the balanced 1200s (20 minutes) (spec addendum, 2026-09-09,
-- re-applied 2026-09-11 after an earlier apply of this same fix was found
-- silently reverted -- likely a very-delayed background edit retry landing
-- with stale content; worth watching for if this keeps happening):
-- the temporary 120s debug value (spec addendum, 2026-09-08) was introduced
-- purely to speed up testing the NPC ragdoll/recloning bug, which is now
-- resolved -- see NPCReactionAnimator/NPCSpawnManager.
-- DEBUG (2026-09-2X): temporarily lowered from 1200 (20 minutes, the real
-- final value confirmed 2026-09-11) for Supplies Robbery testing -- revert
-- to 1200 before ship. Same revert-tracking discipline as the earlier
-- 120s SessionDuration debug value above.
Config.CooldownDuration = 1200 -- city (phase 3 Task 5): the spec's 20 minutes; was 60
Config.DuffelCap = 4000
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
-- No time-based accrual mechanic exists at SlowFoods (lump-sum registers
-- only, via BankInstance:TryAddDuffel) -- defined as 0, not left nil, so a
-- stray GetAccrualRate/Accrue call is inert instead of erroring on nil*n.
Config.AccrualPerSecond = 0

-- Flat amount credited per successful "Rob register" hold.
Config.RegisterRobAmount = 2000

Config.HeartbeatRate = 10

-- Heist layers 2026-11-17: the fleeing Manager. Studs from him a participant may hold "Take Key"
-- (server re-measured), the storage-safe lump (paid over the bag cap through AddBonus), and the
-- "Take Key" hold in seconds (server timed).
Config.ManagerKeyRange = 10
Config.ManagerSafeAmount = 3000
Config.ManagerKeyHold = 1

-- Sound asset ID, documentation only (spec addendum, 2026-09-09) -- matching
-- HeistShared.Config.Sounds' convention. RegisterRobSound itself is a
-- STATIC pre-placed Sound instance on each register's attach part (same
-- pattern as Terminal's ButtonClickSound), never constructed or read from
-- this table at runtime -- this entry exists only so a one-off Studio setup
-- script has one place to copy the ID from.
Config.Sounds = {
	RegisterRob = "rbxassetid://111982320099998",
}

-- Debug stays mutable so integration runs can shorten the lifecycle, same
-- pattern as HeistShared.Config.
Config.Debug = { FastLifecycle = false }

local FAST = { SessionDuration = 10, CooldownDuration = 20 }

function Config.effective(key: string): number
	if Config.Debug.FastLifecycle and FAST[key] then
		return FAST[key]
	end
	return (Config :: any)[key]
end

-- Police sent INTO the store while robbers are inside (Heist.Services.HeistPolice; developer picker 2026-11-20, "Squads
-- follow + a store wave"): 2 at 60 s, then 1 more every 60 s, at most 3 alive, from SlowFoodsMarkers.HeistPoliceSpawn1..2 outside
-- the entrance; they come in through the door, so the gunfight happens inside.
-- preferredRangeFraction 0.1: they keep closing in to about 9 studs (90-stud engage range), so they come inside
-- rather than shooting in from the forecourt at the usual 0.6 (measured at Gas2Go: 19 and 30 studs out).
Config.HeistPolice = table.freeze({ template = "Police", first = 60, count = 2, every = 60, more = 1, cap = 3,
	preferredRangeFraction = 0.1 })

return table.freeze(Config)
