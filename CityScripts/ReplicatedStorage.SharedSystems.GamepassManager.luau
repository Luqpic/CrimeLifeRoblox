--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

-- The heist's duffel gamepass multipliers, a thin adapter over the city's one gamepass system
-- (2026-11-18). The pass ids live in Monetization.Constants.Gamepasses (shop = false), ownership is
-- checked and confirmed by ServerScriptService.Monetization.Scripts.PassOwnership and published as the
-- GamepassOwned_<key> attribute, and this module only reads that attribute: no ids, no cache, no
-- network call. Lives under ReplicatedStorage.SharedSystems so any robbery system references it
-- (WorldSpec pins the place). A robbery-specific module (e.g. BankInstance) must never require it: it
-- only sees the RESULT through its injected duffelCapMultiplier / accrualRateMultiplier deps.
local GamepassManager = {}

-- Keyed by the pass key in Monetization.Constants. DuffelSpeedBoost's Multiplier is still TBD -- a real
-- balance decision, not a technical one.
GamepassManager.GamepassConfig = {
	DuffelCapacityX2 = { Multiplier = 2 },
	DuffelCapacityX4 = { Multiplier = 4 },
	DuffelSpeedBoost = { Multiplier = 1.5 },
}

function GamepassManager:PlayerOwnsGamepass(player, key: string): boolean
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor(key)) == true
end

-- Checks x4 first and returns immediately if owned, so an x4 owner never needs the x2 read. No
-- stacking between tiers: owning both resolves to x4 only, never x6 or any additive combination, and
-- the x2 -> x4 upgrade needs no invalidation since both records stay valid.
function GamepassManager:GetDuffelCapMultiplier(player): number
	local config = GamepassManager.GamepassConfig
	if GamepassManager:PlayerOwnsGamepass(player, "DuffelCapacityX4") then
		return config.DuffelCapacityX4.Multiplier
	end
	if GamepassManager:PlayerOwnsGamepass(player, "DuffelCapacityX2") then
		return config.DuffelCapacityX2.Multiplier
	end
	return 1
end

-- Independent of the capacity tiers -- stacks alongside whichever (if any) capacity pass is owned.
function GamepassManager:GetAccrualRateMultiplier(player): number
	if GamepassManager:PlayerOwnsGamepass(player, "DuffelSpeedBoost") then
		return GamepassManager.GamepassConfig.DuffelSpeedBoost.Multiplier
	end
	return 1
end

return GamepassManager
