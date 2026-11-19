-- Readable gunfights and level toughness (combat balance, 2026-11-20): every number of how NPCs shoot at players
-- (gangs, police, heist police and guards), what their hits do, and how a player heals out of combat, with the pure
-- maths that uses them. The server code that acts on these (EnemyAI, Enemy.Scripts.NpcFire, Heist.Components.GuardPost,
-- Blaster ShotResolver, StarterCharacterScripts.Health) holds no numbers of its own. Specs: UnitTest Combat_Test.
local Combat = {}

-- === Shooter tokens ===
-- At most this many NPCs fire at one player at a time; the others keep their aim and wait for a token. A token is
-- held from the wind-up through one burst.
Combat.MAX_SHOOTERS_PER_TARGET = 2
-- A safety net: a token not released this many seconds after it was taken is free again (a burst ends long before).
Combat.TOKEN_TIMEOUT = 8

-- === Wind-up ===
-- Seconds from acquiring a target (a new one, or the same one after REACQUIRE_AFTER without sight) to the first
-- shot, with the red aim line showing. Pistols and shotguns (semi-automatic) are quicker than rifles and SMGs.
Combat.REACTION_TIME_SEMI = 0.6
Combat.REACTION_TIME_AUTO = 0.8
Combat.REACQUIRE_AFTER = 1.5

-- The aim line: a plain-colour Beam from the muzzle to the target, seen by everyone, only during a wind-up.
Combat.TELL_COLOR = Color3.fromRGB(255, 35, 35)
Combat.TELL_WIDTH = 0.08
Combat.TELL_TRANSPARENCY = 0.1
-- A line is removed after this long whatever happens to its shooter.
Combat.TELL_MAX_SECONDS = 2

-- === Focus ===
-- The aim cone starts at FOCUS_START_MULTIPLIER x the template's error and tightens linearly to 1 x over FOCUS_TIME
-- seconds of continuous sight; losing sight starts it over. A hit on the shooter (a flinch) sets its focus back
-- FLINCH_FOCUS_SETBACK seconds and its next shot FLINCH_SHOT_DELAY seconds, at most once per FLINCH_COOLDOWN (a fast
-- gun's steady hits must not silence a shooter for good: review I2). A rolling target gets the widest cone.
Combat.FOCUS_START_MULTIPLIER = 2.5
Combat.FOCUS_TIME = 2
Combat.FLINCH_FOCUS_SETBACK = 0.75
Combat.FLINCH_SHOT_DELAY = 0.3
Combat.FLINCH_COOLDOWN = 1

-- === Bursts ===
-- Every NPC gun fires bursts of BURST_SHOTS_MIN to MAX shots, then lets its token go for BURST_PAUSE_MIN to MAX
-- seconds. A semi-automatic fires no faster than one shot per SEMI_MIN_INTERVAL.
Combat.BURST_SHOTS_MIN = 3
Combat.BURST_SHOTS_MAX = 5
Combat.BURST_PAUSE_MIN = 0.8
Combat.BURST_PAUSE_MAX = 1.2
Combat.SEMI_MIN_INTERVAL = 0.45

-- === NPC damage ===
-- Range falloff (NPC shots only): x1 within FALLOFF_NEAR studs, linear to FALLOFF_MIN at FALLOFF_FAR and beyond.
Combat.FALLOFF_NEAR = 25
Combat.FALLOFF_FAR = 90
Combat.FALLOFF_MIN = 0.5
-- Armor: NPC damage to a player is reduced ARMOR_PER_LEVEL per level above 1, at most ARMOR_MAX (level 70: 25 %).
Combat.ARMOR_PER_LEVEL = 0.004
Combat.ARMOR_MAX = 0.25

-- === Out-of-combat regen ===
-- REGEN_DELAY seconds after a character last lost health it heals REGEN_PER_SECOND of its max health a second,
-- in REGEN_TICK steps, until full.
Combat.REGEN_DELAY = 6
Combat.REGEN_PER_SECOND = 0.06
Combat.REGEN_TICK = 0.5

local random = Random.new()

function Combat.reactionTime(isAutomatic: boolean): number
	return if isAutomatic then Combat.REACTION_TIME_AUTO else Combat.REACTION_TIME_SEMI
end

-- The aim cone in degrees: `baseDegrees` (AimConfig's cone for this distance, speed and template) widened by the
-- focus ramp, or `maxDegrees` (the template's ceiling) x the start multiplier against a rolling target.
function Combat.aimError(baseDegrees: number, maxDegrees: number, focusSeconds: number, rolling: boolean): number
	if rolling then
		return maxDegrees * Combat.FOCUS_START_MULTIPLIER
	end
	local settled = math.clamp(focusSeconds / Combat.FOCUS_TIME, 0, 1)
	return baseDegrees * (Combat.FOCUS_START_MULTIPLIER + (1 - Combat.FOCUS_START_MULTIPLIER) * settled)
end

-- Seconds between two shots of a burst: the weapon's own cooldown (60 / rateOfFire), and for a semi-automatic at
-- least SEMI_MIN_INTERVAL.
function Combat.shotInterval(isAutomatic: boolean, cooldown: number): number
	return if isAutomatic then cooldown else math.max(cooldown, Combat.SEMI_MIN_INTERVAL)
end

function Combat.burstShots(rng: Random?): number
	return (rng or random):NextInteger(Combat.BURST_SHOTS_MIN, Combat.BURST_SHOTS_MAX)
end

function Combat.burstPause(rng: Random?): number
	return Combat.BURST_PAUSE_MIN + (rng or random):NextNumber() * (Combat.BURST_PAUSE_MAX - Combat.BURST_PAUSE_MIN)
end

function Combat.rangeFalloff(distance: number): number
	local t = math.clamp((distance - Combat.FALLOFF_NEAR) / (Combat.FALLOFF_FAR - Combat.FALLOFF_NEAR), 0, 1)
	return 1 - (1 - Combat.FALLOFF_MIN) * t
end

function Combat.armor(level: number): number
	return math.clamp((level - 1) * Combat.ARMOR_PER_LEVEL, 0, Combat.ARMOR_MAX)
end

-- What an NPC's hit of `damage` does from `distance` studs to a player of `level` (nil: no armor).
function Combat.npcDamage(damage: number, distance: number, level: number?): number
	local armor = if level then Combat.armor(level) else 0
	return damage * Combat.rangeFalloff(distance) * (1 - armor)
end

-- Health after `dt` seconds of regen, `sinceHurt` seconds after the last loss. Nothing while dead or full.
function Combat.regenStep(health: number, maxHealth: number, sinceHurt: number, dt: number): number
	if health <= 0 or health >= maxHealth or sinceHurt < Combat.REGEN_DELAY then
		return health
	end
	return math.min(maxHealth, health + maxHealth * Combat.REGEN_PER_SECOND * dt)
end

-- Shooter tokens for every target: acquire(target, shooter) is true while the shooter holds one of the target's
-- MAX tokens (taking a free one if needed; a shooter holds tokens for one target at a time, so taking one for a new
-- target gives back the old). `clock` (default os.clock) only times out stale holders.
local Tokens = {}
Tokens.__index = Tokens

function Combat.newTokens(max: number, clock: (() -> number)?)
	return setmetatable({
		max = max,
		clock = clock or os.clock,
		holders = setmetatable({}, { __mode = "k" }), -- [target] = { [shooter] = taken at }
		targetOf = setmetatable({}, { __mode = "k" }), -- [shooter] = target
	}, Tokens)
end

function Tokens:count(target): number
	local n = 0
	local now = self.clock()
	for shooter, takenAt in self.holders[target] or {} do
		if now - takenAt >= Combat.TOKEN_TIMEOUT then
			self:release(target, shooter)
		else
			n += 1
		end
	end
	return n
end

function Tokens:acquire(target, shooter): boolean
	local set = self.holders[target]
	if set and set[shooter] and self.clock() - set[shooter] < Combat.TOKEN_TIMEOUT then
		return true
	end
	if self:count(target) >= self.max then
		return false
	end
	self:releaseShooter(shooter)
	set = self.holders[target]
	if not set then
		set = {}
		self.holders[target] = set
	end
	set[shooter] = self.clock()
	self.targetOf[shooter] = target
	return true
end

function Tokens:release(target, shooter)
	local set = self.holders[target]
	if set then
		set[shooter] = nil
		if next(set) == nil then
			self.holders[target] = nil
		end
	end
	if self.targetOf[shooter] == target then
		self.targetOf[shooter] = nil
	end
end

function Tokens:releaseShooter(shooter)
	local target = self.targetOf[shooter]
	if target ~= nil then
		self:release(target, shooter)
	end
end

function Tokens:clear(target)
	for shooter in self.holders[target] or {} do
		if self.targetOf[shooter] == target then
			self.targetOf[shooter] = nil
		end
	end
	self.holders[target] = nil
end

return Combat
