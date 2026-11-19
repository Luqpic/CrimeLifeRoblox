-- Tests for ServerScriptService.Movement.Scripts.RollAuthority: the server's re-check of a roll and its stamina
-- (2026-11-20). A stand-in player (a table with a Character) keeps SprintAuthority and CarryState off real players.
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Config = require(ReplicatedStorage.PlayerMovement.Config)
	local Constants = require(ReplicatedStorage.Movement.Constants)
	local SprintAuthority = require(ServerScriptService.Movement.Scripts.SprintAuthority)
	local RollAuthority = require(ServerScriptService.Movement.Scripts.RollAuthority)
	local expect = t.expect

	local COST = Config.Roll.Stamina
	local COOLDOWN = Config.Roll.Cooldown

	-- a body out of the Workspace and a player-shaped table around it
	local function fakePlayer()
		local character = Instance.new("Model")
		Instance.new("Humanoid").Parent = character
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = character
		local player = { Character = character }
		function player:GetAttribute()
			return nil
		end
		return player, character, root
	end
	local function done(player)
		RollAuthority.cleanup(player)
		SprintAuthority.cleanup(player)
		player.Character:Destroy()
	end

	t.test("a roll spends its stamina once and the cooldown refuses the next for free", function()
		local player = fakePlayer()
		expect.truthy(RollAuthority.request(player, 100))
		expect.near(SprintAuthority.getStamina(player), Constants.MAX_STAMINA - COST, 1e-6)
		local ok, why = RollAuthority.request(player, 100 + COOLDOWN / 2)
		expect.falsy(ok)
		expect.equal(why, "cooldown")
		expect.near(SprintAuthority.getStamina(player), Constants.MAX_STAMINA - COST, 1e-6)
		expect.truthy(RollAuthority.request(player, 100 + COOLDOWN))
		expect.near(SprintAuthority.getStamina(player), Constants.MAX_STAMINA - 2 * COST, 1e-6)
		done(player)
	end)

	t.test("refused while carrying, for free", function()
		local player, character = fakePlayer()
		character:SetAttribute(Constants.CARRY_SPEED_CAP_ATTRIBUTE, Constants.CARRY_SPEED_CAP)
		local ok, why = RollAuthority.request(player, 100)
		expect.falsy(ok)
		expect.equal(why, "carrying")
		expect.equal(SprintAuthority.getStamina(player), nil) -- never asked for stamina
		done(player)
	end)

	t.test("refused without enough stamina, and the bar is left as it was", function()
		local player = fakePlayer()
		local now = 100
		while (SprintAuthority.getStamina(player) or Constants.MAX_STAMINA) >= COST do
			expect.truthy(RollAuthority.request(player, now))
			now += COOLDOWN
		end
		local left = SprintAuthority.getStamina(player)
		local ok, why = RollAuthority.request(player, now)
		expect.falsy(ok)
		expect.equal(why, "stamina")
		expect.equal(SprintAuthority.getStamina(player), left)
		done(player)
	end)

	t.test("refused when dead, stunned or frozen", function()
		local player, character, root = fakePlayer()
		root:SetAttribute("StunnedUntil", 105)
		expect.equal(select(2, RollAuthority.request(player, 100)), "blocked")
		root:SetAttribute("StunnedUntil", nil)
		character:SetAttribute("AdminFrozen", true)
		expect.equal(select(2, RollAuthority.request(player, 100)), "blocked")
		character:SetAttribute("AdminFrozen", nil)
		character.Humanoid.Health = 0
		expect.equal(select(2, RollAuthority.request(player, 100)), "dead")
		expect.equal(SprintAuthority.getStamina(player), nil)
		done(player)
	end)

	-- Combat balance (2026-11-20): NPC aim reads a roll from the root's RollingUntil (the longest roll, a sprint roll).
	t.test("an accepted roll stamps RollingUntil on the root; a refused one does not", function()
		local player, character, root = fakePlayer()
		character:SetAttribute(Constants.CARRY_SPEED_CAP_ATTRIBUTE, Constants.CARRY_SPEED_CAP)
		RollAuthority.request(player, 100)
		expect.equal(root:GetAttribute("RollingUntil"), nil)
		character:SetAttribute(Constants.CARRY_SPEED_CAP_ATTRIBUTE, nil)
		expect.truthy(RollAuthority.request(player, 100))
		expect.near(root:GetAttribute("RollingUntil"), 100 + Config.Roll.Time * Config.Roll.Sprint.Time)
		done(player)
	end)
end
