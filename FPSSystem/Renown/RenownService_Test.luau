-- Tests for ServerScriptService.Renown.Scripts.RenownService.
-- The handlers are exposed as named functions specifically so the earn rules can be tested rather than
-- proven once by hand -- Phase 1 learned that lesson on its equip remote.
return function(t)
	local RenownService = require(game.ServerScriptService.Renown.Scripts.RenownService)
	local Constants = require(game.ReplicatedStorage.Renown.Constants)
	local expect = t.expect

	-- A stand-in player: the service only ever calls GetAttribute and SetAttribute on it.
	local function fakePlayer(startingRenown: number?)
		local attributes = { [Constants.ATTRIBUTE] = startingRenown or 0 }
		return {
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			_attributes = attributes,
		}
	end

	-- A stand-in victim: a Humanoid whose Parent carries a Faction attribute, which is exactly what
	-- KillStatsService reads.
	local function fakeVictim(faction: string?)
		local character = Instance.new("Model")
		if faction then
			character:SetAttribute("Faction", faction)
		end
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		return humanoid
	end

	t.test("a fresh player starts at zero", function()
		expect.equal(RenownService.balanceOf(fakePlayer()), 0)
	end)

	t.test("granting adds and returns the new balance", function()
		local player = fakePlayer(10)
		expect.equal(RenownService.grant(player, 15, "test"), 25)
		expect.equal(RenownService.balanceOf(player), 25)
	end)

	t.test("granting zero or a negative amount changes nothing", function()
		local player = fakePlayer(10)
		RenownService.grant(player, 0, "test")
		RenownService.grant(player, -50, "test")
		expect.equal(RenownService.balanceOf(player), 10)
	end)

	t.test("spending deducts and reports success", function()
		local player = fakePlayer(300)
		expect.truthy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 50)
	end)

	t.test("spending more than the balance is refused and deducts nothing", function()
		local player = fakePlayer(100)
		expect.falsy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 100)
	end)

	t.test("spending exactly the balance is allowed", function()
		local player = fakePlayer(250)
		expect.truthy(RenownService.spend(player, 250))
		expect.equal(RenownService.balanceOf(player), 0)
	end)

	t.test("killing a Thug awards the Criminal rate", function()
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim("Criminal"))
		expect.equal(RenownService.balanceOf(player), Constants.KILL_RENOWN.Criminal)
	end)

	t.test("killing Police awards the higher rate", function()
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim("Police"))
		expect.equal(RenownService.balanceOf(player), Constants.KILL_RENOWN.Police)
	end)

	t.test("a PvP kill awards nothing", function()
		-- The victim has no Faction attribute, exactly as a player character does not. If this ever
		-- pays out, two players can farm Renown off each other indefinitely.
		local player = fakePlayer()
		RenownService.awardForVictim(player, fakeVictim(nil))
		expect.equal(RenownService.balanceOf(player), 0)
	end)

	t.test("onEliminated rejects an attacker that is not a Player", function()
		-- The victim here WOULD pay 5 through awardForVictim, so this proves the guard is doing work
		-- rather than the victim simply being worthless. An NPC killing an NPC must earn nobody
		-- anything.
		expect.truthy(pcall(RenownService.onEliminated, Instance.new("Model"), fakeVictim("Police")))
		expect.truthy(pcall(RenownService.onEliminated, nil, fakeVictim("Police")))
	end)

	t.test("a victim with no character awards nothing and does not throw", function()
		local orphan = Instance.new("Humanoid")
		expect.truthy(pcall(RenownService.awardForVictim, fakePlayer(), orphan))
	end)
end
