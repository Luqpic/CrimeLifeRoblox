-- Shared constants for the kill-based leveling system. Placeholders, not balance -- tune freely.
--
-- Session-only by design, matching Cash: there is no DataStoreService anywhere in this codebase, so
-- level and XP reset on every join rather than persisting.
local Constants = {}

-- XP per kill, by the dying character's weapon tier.
Constants.XP_VALUES = {
	Melee = 10,
	Pistol = 15,
	AutoRifle = 20,
}

Constants.LEVEL_CAP = 70
Constants.BASE_XP_TO_LEVEL = 30
Constants.XP_INCREMENT_PER_LEVEL = 15

-- XP required to advance from `level` to `level + 1`. Only meaningful for level < LEVEL_CAP.
function Constants.xpToNextLevel(level: number): number
	return Constants.BASE_XP_TO_LEVEL + Constants.XP_INCREMENT_PER_LEVEL * (level - 1)
end

-- Lifetime XP for a (Level, XP) pair. The XP attribute resets on every level-up, so the difference of
-- two raw XP readings is wrong across one; the difference of two totals is the XP actually gained.
function Constants.totalXp(level: number, xp: number): number
	local total = xp
	for l = 1, level - 1 do
		total += Constants.xpToNextLevel(l)
	end
	return total
end

-- White glyphs (tinted by ImageColor3), 24px originals from ~/Downloads upscaled 4x nearest-neighbour
-- so they stay crisp on the level-up popup. One owner for the ids: every leveling and health readout
-- reads them from here.
Constants.XP_ICON_ID = "rbxassetid://83512206604799" -- Experience.png
Constants.HEALTH_ICON_ID = "rbxassetid://85348455866621" -- Health.png

-- Criminal rank by level: seven tiers of ten, one career from the street corner to running the family,
-- with LEVEL_CAP (70) inside the last. Ordered by minLevel; the colour climbs from street grey to gold
-- so rank reads at a glance on a nameplate. Shown on the player card and on other players' overheads.
Constants.RANKS = {
	{ minLevel = 1, title = "Rookie Thug", color = Color3.fromHex("B4BAC8") },
	{ minLevel = 11, title = "Street Hustler", color = Color3.fromHex("8FE36B") },
	{ minLevel = 21, title = "Gang Enforcer", color = Color3.fromHex("61F0EE") },
	{ minLevel = 31, title = "Made Man", color = Color3.fromHex("5B9DFF") },
	{ minLevel = 41, title = "Mafia Hitman", color = Color3.fromHex("C77DFF") },
	{ minLevel = 51, title = "Capo", color = Color3.fromHex("FF8A3D") },
	{ minLevel = 61, title = "Godfather", color = Color3.fromHex("FFD23F") },
}

function Constants.rankForLevel(level: number): { minLevel: number, title: string, color: Color3 }
	local rank = Constants.RANKS[1]
	for _, candidate in Constants.RANKS do
		if level >= candidate.minLevel then
			rank = candidate
		end
	end
	return rank
end

-- Combat balance (2026-11-20, developer decision "health + armor by level"): +4 max health a level (level 70: 376;
-- was +2, 238). The armor half is ReplicatedStorage.Enemy.Combat's ARMOR_PER_LEVEL.
Constants.BASE_MAX_HEALTH = 100
Constants.MAX_HEALTH_PER_LEVEL = 4

function Constants.maxHealth(level: number): number
	return Constants.BASE_MAX_HEALTH + Constants.MAX_HEALTH_PER_LEVEL * (level - 1)
end
Constants.CASH_PER_LEVEL_UP = 25

Constants.LEVEL_UP_SOUND_ID = "rbxassetid://134821092416328"

return Constants
