--!strict
local Config = {}

-- Gas2Go's own balance/timing values (spec addendum, 2026-09-14), entirely
-- separate from HeistShared.Config (the Bank's) and RestaurantShared.Config
-- (SlowFoods') -- only the SHARED systems (BankInstance, GamepassManager,
-- Forfeit, NPCReactionAnimator, RobbableObject, the alarm sound/light
-- templates, the claim-zone pattern) are common; every number is per-
-- location. Field NAMES below are dictated by BankInstance, which this
-- config is constructed for (BankInstance:TryStart/_seal read
-- "SessionDuration"/"CooldownDuration" verbatim, GetDuffelCap reads
-- "DuffelCap") -- same convention as RestaurantShared.Config.
Config.SessionDuration = 300 -- 5 minutes (confirmed, spec addendum 2026-09-14)
-- DEBUG (2026-09-2X): temporarily lowered from 600 (10 minutes, confirmed
-- spec addendum 2026-09-14) for Supplies Robbery testing -- revert to 600
-- before ship.
Config.CooldownDuration = 600 -- city (phase 3 Task 5): the spec's 10 minutes; was 60
Config.DuffelCap = 4000 -- matches SlowFoods' base
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
-- No time-based accrual mechanic exists at Gas2Go either (lump-sum
-- registers/ATM only, via BankInstance:TryAddDuffel) -- same reasoning as
-- RestaurantShared.Config.
Config.AccrualPerSecond = 0

-- Flat amounts credited per successful rob hold (spec addendum,
-- 2026-09-14) -- confirmed equal to the Bank's own register/ATM values,
-- kept as Gas2Go's OWN config entries regardless (never read from
-- HeistShared.Config), consistent with "Config Separation".
Config.RegisterRobAmount = 2000
Config.ATMRobAmount = 3000
-- Heist layers 2026-11-17 (Task 4): "Rip Out ATM" carries the whole ATM out and banks it at the
-- getaway for 3x the rob, paid outside the bag (the 4000 cap would refuse it). Server-timed hold.
Config.ATMRipAmount = 9000
Config.ATMRipHold = 10

Config.HeartbeatRate = 10

-- Sound asset ID, documentation only (matching RestaurantShared.Config's
-- own convention) -- RegisterRobSound/ATMRobSound are STATIC pre-placed
-- Sound instances on each object's attach part, same pattern as SlowFoods/
-- the Bank, never constructed or read from this table at runtime.
Config.Sounds = {
	RegisterRob = "rbxassetid://111982320099998",
	ATMRob = "rbxassetid://111982320099998",
}

-- Debug stays mutable so integration runs can shorten the lifecycle, same
-- pattern as HeistShared.Config/RestaurantShared.Config.
Config.Debug = { FastLifecycle = false }

local FAST = { SessionDuration = 10, CooldownDuration = 20 }

function Config.effective(key: string): number
	if Config.Debug.FastLifecycle and FAST[key] then
		return FAST[key]
	end
	return (Config :: any)[key]
end

-- Police sent INTO the store while robbers are inside (Heist.Services.HeistPolice; developer picker 2026-11-20, "Squads
-- follow + a store wave"): 2 at 60 s, then 1 more every 60 s, at most 3 alive, from Gas2GoMarkers.HeistPoliceSpawn1..2 outside
-- the entrance; they come in through the door, so the gunfight happens inside.
-- preferredRangeFraction 0.1: they keep closing in to about 9 studs (90-stud engage range), so they come inside
-- rather than shooting in from the forecourt at the usual 0.6 (measured at Gas2Go: 19 and 30 studs out).
Config.HeistPolice = table.freeze({ template = "Police", first = 60, count = 2, every = 60, more = 1, cap = 3,
	preferredRangeFraction = 0.1 })

return table.freeze(Config)
