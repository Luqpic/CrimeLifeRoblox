-- Readable gunfights and level toughness (combat balance, 2026-11-20): the pure parts in ReplicatedStorage.Enemy.Combat
-- (shooter tokens, wind-up time, focus ramp, shot rhythm, range falloff, armor, regen step) and the health formula in
-- ReplicatedStorage.Leveling.Constants. Stand-in shooters and targets are plain tables; the token clock is injected.
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Combat = require(ReplicatedStorage.Enemy.Combat)
	local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)
	local expect = t.expect

	t.test("tokens: at most two shooters per player; a third waits until one lets go", function()
		local clock = 0
		local tokens = Combat.newTokens(2, function() return clock end)
		local player, other = {}, {}
		local a, b, c = {}, {}, {}
		expect.truthy(tokens:acquire(player, a))
		expect.truthy(tokens:acquire(player, b))
		expect.falsy(tokens:acquire(player, c))
		expect.truthy(tokens:acquire(player, a)) -- a holder asking again keeps its token
		expect.equal(tokens:count(player), 2)
		expect.truthy(tokens:acquire(other, c)) -- another player has two of their own
		tokens:release(player, a)
		expect.truthy(tokens:acquire(player, c)) -- c leaves `other` for `player`
		expect.equal(tokens:count(other), 0)
		expect.equal(tokens:count(player), 2)
	end)

	t.test("tokens: a shooter's death and the target's death or leaving free them; a stale one times out", function()
		local clock = 0
		local tokens = Combat.newTokens(2, function() return clock end)
		local player = {}
		local a, b, c = {}, {}, {}
		tokens:acquire(player, a)
		tokens:acquire(player, b)
		tokens:releaseShooter(a)
		expect.equal(tokens:count(player), 1)
		tokens:clear(player)
		expect.equal(tokens:count(player), 0)
		expect.truthy(tokens:acquire(player, a))
		expect.truthy(tokens:acquire(player, b))
		clock = Combat.TOKEN_TIMEOUT + 0.01
		expect.truthy(tokens:acquire(player, c)) -- a and b never let go: their tokens lapsed
		expect.equal(tokens:count(player), 1)
	end)

	t.test("wind-up: 0.6 s for semi-automatics, 0.8 s for automatics", function()
		expect.equal(Combat.reactionTime(false), 0.6)
		expect.equal(Combat.reactionTime(true), 0.8)
	end)

	t.test("focus: 2.5 x the cone at first sight, 1 x after 2 s, linear between; a rolling target gets the widest", function()
		expect.near(Combat.aimError(6, 16, 0, false), 15)
		expect.near(Combat.aimError(6, 16, 1, false), 10.5)
		expect.near(Combat.aimError(6, 16, 2, false), 6)
		expect.near(Combat.aimError(6, 16, 5, false), 6)
		expect.near(Combat.aimError(6, 16, 2, true), 40)
	end)

	t.test("bursts: 3 to 5 shots, a 0.8 to 1.2 s pause; semi-automatics no faster than one shot per 0.45 s", function()
		local rng = Random.new(7)
		for _ = 1, 200 do
			local shots = Combat.burstShots(rng)
			expect.truthy(shots >= 3 and shots <= 5 and shots % 1 == 0)
			local pause = Combat.burstPause(rng)
			expect.truthy(pause >= 0.8 and pause <= 1.2)
		end
		expect.near(Combat.shotInterval(false, 60 / 400), 0.45)
		expect.near(Combat.shotInterval(false, 60 / 90), 60 / 90)
		expect.near(Combat.shotInterval(true, 60 / 600), 0.1)
	end)

	t.test("range falloff: x1 to 25 studs, linear to x0.5 at 90 studs and beyond", function()
		expect.equal(Combat.rangeFalloff(0), 1)
		expect.equal(Combat.rangeFalloff(25), 1)
		expect.near(Combat.rangeFalloff(57.5), 0.75)
		expect.near(Combat.rangeFalloff(90), 0.5)
		expect.near(Combat.rangeFalloff(400), 0.5)
	end)

	t.test("armor: 0.4 % per level above 1, at most 25 %; NPC damage takes falloff and armor", function()
		expect.equal(Combat.armor(1), 0)
		expect.near(Combat.armor(11), 0.04)
		expect.near(Combat.armor(63), 0.248)
		expect.near(Combat.armor(70), 0.25)
		expect.near(Combat.npcDamage(8, 10, 70), 6)
		expect.near(Combat.npcDamage(12, 90, 1), 6)
		expect.near(Combat.npcDamage(12, 90, nil), 6) -- no level: no armor
	end)

	t.test("an enemy flinches at most once per FLINCH_COOLDOWN (review I2: steady hits must not silence it)", function()
		local EnemyAI = require(game:GetService("ServerScriptService").Enemy.Scripts.EnemyAI)
		local enemy = { sightSince = 9, shotAfter = 0, flinchedAt = -math.huge }
		EnemyAI._flinch(enemy, 10)
		expect.near(enemy.shotAfter, 10 + Combat.FLINCH_SHOT_DELAY)
		expect.near(enemy.sightSince, 9 + Combat.FLINCH_FOCUS_SETBACK)
		EnemyAI._flinch(enemy, 10.2)
		expect.near(enemy.shotAfter, 10 + Combat.FLINCH_SHOT_DELAY)
		expect.near(enemy.sightSince, 9 + Combat.FLINCH_FOCUS_SETBACK)
		EnemyAI._flinch(enemy, 10 + Combat.FLINCH_COOLDOWN)
		expect.near(enemy.shotAfter, 10 + Combat.FLINCH_COOLDOWN + Combat.FLINCH_SHOT_DELAY)
	end)

	t.test("max health: 100 at level 1, +4 a level, 376 at level 70", function()
		expect.equal(LevelingConstants.maxHealth(1), 100)
		expect.equal(LevelingConstants.maxHealth(2), 104)
		expect.equal(LevelingConstants.maxHealth(70), 376)
	end)

	t.test("regen: nothing for 6 s after a hit, then 6 % of max health a second, never past full or from 0", function()
		expect.equal(Combat.regenStep(50, 100, 5.9, 0.5), 50)
		expect.near(Combat.regenStep(50, 100, 6, 0.5), 53)
		expect.near(Combat.regenStep(100, 376, 10, 1), 122.56)
		expect.equal(Combat.regenStep(99, 100, 10, 1), 100)
		expect.equal(Combat.regenStep(100, 100, 10, 1), 100)
		expect.equal(Combat.regenStep(0, 100, 10, 1), 0)
	end)
end
