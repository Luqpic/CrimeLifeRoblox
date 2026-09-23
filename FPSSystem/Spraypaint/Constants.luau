-- Spraypaint earn rates and the names Spraypaint state is stored under.
--
-- Data only. Rates live here rather than inline so they can be tuned from one place without touching
-- the service that awards them -- these figures are a play-testing starting point, not a balance claim.
local Constants = {}

-- The balance is now PER WEAPON, so it can no longer live under one player attribute -- a Player
-- attribute holds one scalar, not a map. One attribute per weapon instead, matching the
-- ownedAttributeFor / equip-attribute convention already used across this place. No leaderstats
-- column: Cash is public because it is the combat economy, and a second column for a cosmetic
-- currency clutters the player list for everyone in the server.
function Constants.balanceAttributeFor(weaponName: string): string
	return "Spraypaint_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

-- The shared bucket every weapon may draw on once its own balance (above) is exhausted. One
-- attribute, not per-weapon: there is exactly one bucket. Fed only by the v1->v2 migration and by a
-- level-up with no weapon equipped to credit -- see SpraypaintService.
Constants.SHARED_ATTRIBUTE = "SpraypaintShared"

-- Keyed by the Faction attribute the enemy rigs already carry. Police are worth more because EnemyAI
-- gives them per-type accuracy and damage overrides that make them the harder target.
Constants.KILL_SPRAYPAINT = {
	Criminal = 2,
	Police = 5,
}

Constants.LEVEL_SPRAYPAINT = 25

-- Anything that is not a recognised NPC faction is worth nothing, and that includes nil.
--
-- This is the anti-farming rule, not a defensive nicety: a player's own character carries no Faction
-- attribute, so PvP kills arrive here as nil and must stay worthless. KillStatsService and CashService
-- both already exclude PvP for the same reason.
function Constants.spraypaintForFaction(faction: unknown): number
	if typeof(faction) ~= "string" then
		return 0
	end
	return Constants.KILL_SPRAYPAINT[faction] or 0
end

-- Ownership of a bought palette, mirroring the WeaponOwned_* convention already in the place.
-- Sanitised because SetAttribute throws on a name containing anything outside [A-Za-z0-9_].
function Constants.ownedAttributeFor(paletteKey: string): string
	return "SkinOwned_" .. (string.gsub(paletteKey, "[^%w_]", "_"))
end

return Constants
