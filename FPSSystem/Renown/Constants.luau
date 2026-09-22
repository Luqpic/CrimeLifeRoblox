-- Renown earn rates and the names Renown state is stored under.
--
-- Data only. Rates live here rather than inline so they can be tuned from one place without touching
-- the service that awards them -- these figures are a play-testing starting point, not a balance claim.
local Constants = {}

-- The balance replicates as a player attribute, matching Level, XP and the kill counters. No
-- leaderstats column: Cash is public because it is the combat economy, and a second column for a
-- cosmetic currency clutters the player list for everyone in the server.
Constants.ATTRIBUTE = "Renown"

-- Keyed by the Faction attribute the enemy rigs already carry. Police are worth more because EnemyAI
-- gives them per-type accuracy and damage overrides that make them the harder target.
Constants.KILL_RENOWN = {
	Criminal = 2,
	Police = 5,
}

Constants.LEVEL_RENOWN = 25

-- Anything that is not a recognised NPC faction is worth nothing, and that includes nil.
--
-- This is the anti-farming rule, not a defensive nicety: a player's own character carries no Faction
-- attribute, so PvP kills arrive here as nil and must stay worthless. KillStatsService and CashService
-- both already exclude PvP for the same reason.
function Constants.renownForFaction(faction: unknown): number
	if typeof(faction) ~= "string" then
		return 0
	end
	return Constants.KILL_RENOWN[faction] or 0
end

-- Ownership of a bought palette, mirroring the WeaponOwned_* convention already in the place.
-- Sanitised because SetAttribute throws on a name containing anything outside [A-Za-z0-9_].
function Constants.ownedAttributeFor(paletteKey: string): string
	return "SkinOwned_" .. (string.gsub(paletteKey, "[^%w_]", "_"))
end

return Constants
