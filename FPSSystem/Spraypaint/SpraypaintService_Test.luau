-- Tests for ServerScriptService.Spraypaint.Scripts.SpraypaintService.
-- The handlers are exposed as named functions specifically so the earn rules can be tested rather than
-- proven once by hand -- Phase 1 learned that lesson on its equip remote.
return function(t)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local Constants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local expect = t.expect

	-- A stand-in player: the service only ever calls GetAttribute and SetAttribute on it.
	local function fakePlayer(startingSpraypaint: number?)
		local attributes = { [Constants.ATTRIBUTE] = startingSpraypaint or 0 }
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
		expect.equal(SpraypaintService.balanceOf(fakePlayer()), 0)
	end)

	t.test("balanceOf falls back to zero when the attribute is unset", function()
		-- No pre-seeded Spraypaint attribute at all, unlike fakePlayer's default -- the stand-in usually
		-- pre-seeds a numeric attribute, so this path otherwise has no coverage.
		local unset = { GetAttribute = function() return nil end, SetAttribute = function() end }
		expect.equal(SpraypaintService.balanceOf(unset), 0)
	end)

	t.test("balanceOf falls back to zero when the attribute is not a number", function()
		local wrongType = { GetAttribute = function() return "not a number" end, SetAttribute = function() end }
		expect.equal(SpraypaintService.balanceOf(wrongType), 0)
	end)

	t.test("granting adds and returns the new balance", function()
		local player = fakePlayer(10)
		expect.equal(SpraypaintService.grant(player, 15, "test"), 25)
		expect.equal(SpraypaintService.balanceOf(player), 25)
	end)

	t.test("granting zero or a negative amount changes nothing", function()
		local player = fakePlayer(10)
		SpraypaintService.grant(player, 0, "test")
		SpraypaintService.grant(player, -50, "test")
		expect.equal(SpraypaintService.balanceOf(player), 10)
	end)

	t.test("granting NaN or infinity changes nothing", function()
		-- Neither passes a bare `amount <= 0` check (NaN compares false to everything; infinity is
		-- merely large), and an infinite balance would make every future spend succeed forever.
		local player = fakePlayer(10)
		SpraypaintService.grant(player, 0 / 0, "test")
		SpraypaintService.grant(player, math.huge, "test")
		expect.equal(SpraypaintService.balanceOf(player), 10)
	end)

	t.test("spending deducts and reports success", function()
		local player = fakePlayer(300)
		expect.truthy(SpraypaintService.spend(player, 250))
		expect.equal(SpraypaintService.balanceOf(player), 50)
	end)

	t.test("spending more than the balance is refused and deducts nothing", function()
		local player = fakePlayer(100)
		expect.falsy(SpraypaintService.spend(player, 250))
		expect.equal(SpraypaintService.balanceOf(player), 100)
	end)

	t.test("spending exactly the balance is allowed", function()
		local player = fakePlayer(250)
		expect.truthy(SpraypaintService.spend(player, 250))
		expect.equal(SpraypaintService.balanceOf(player), 0)
	end)

	t.test("spending a fractional amount is refused and deducts nothing", function()
		-- grant floors a fractional amount; spend must not silently accept one, or a caller's
		-- programming error leaves a permanently fractional balance nothing downstream re-normalises.
		local player = fakePlayer(100)
		expect.falsy(SpraypaintService.spend(player, 12.5))
		expect.equal(SpraypaintService.balanceOf(player), 100)
	end)

	t.test("killing a Thug awards the Criminal rate", function()
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Criminal"))
		expect.equal(SpraypaintService.balanceOf(player), Constants.KILL_SPRAYPAINT.Criminal)
	end)

	t.test("killing Police awards the higher rate", function()
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Police"))
		expect.equal(SpraypaintService.balanceOf(player), Constants.KILL_SPRAYPAINT.Police)
	end)

	t.test("a PvP kill awards nothing", function()
		-- The victim has no Faction attribute, exactly as a player character does not. If this ever
		-- pays out, two players can farm Spraypaint off each other indefinitely.
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim(nil))
		expect.equal(SpraypaintService.balanceOf(player), 0)
	end)

	t.test("onEliminated rejects an attacker that is not a Player", function()
		-- The victim WOULD pay 5 through awardForVictim, so this proves the guard blocks rather than
		-- the victim being worthless. Asserting the Model was never paid, not merely that nothing
		-- threw: a Model accepts SetAttribute quite happily, so a regression that dropped the
		-- IsA("Player") check would survive a no-throw assertion untouched.
		local notAPlayer = Instance.new("Model")
		expect.truthy(pcall(SpraypaintService.onEliminated, notAPlayer, fakeVictim("Police")))
		expect.equal(notAPlayer:GetAttribute(Constants.ATTRIBUTE), nil)
		expect.truthy(pcall(SpraypaintService.onEliminated, nil, fakeVictim("Police")))
	end)

	t.test("a victim with no character awards nothing and does not throw", function()
		local orphan = Instance.new("Humanoid")
		local player = fakePlayer()
		expect.truthy(pcall(SpraypaintService.awardForVictim, player, orphan))
		expect.equal(SpraypaintService.balanceOf(player), 0)
	end)

	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)

	local function ownedName(key)
		return Constants.ownedAttributeFor(key)
	end

	t.test("buying a Spraypaint palette deducts the price and records ownership", function()
		local player = fakePlayer(1000)
		expect.truthy(SpraypaintService.handleBuyRequest(player, "Cobalt"))
		expect.equal(SpraypaintService.balanceOf(player), 1000 - Palettes.priceOf("Cobalt"))
		expect.equal(player._attributes[ownedName("Cobalt")], true)
	end)

	t.test("buying without enough Spraypaint is refused and changes nothing", function()
		local player = fakePlayer(10)
		expect.falsy(SpraypaintService.handleBuyRequest(player, "Cobalt"))
		expect.equal(SpraypaintService.balanceOf(player), 10)
		expect.equal(player._attributes[ownedName("Cobalt")], nil)
	end)

	t.test("buying the same palette twice deducts once", function()
		local player = fakePlayer(1000)
		SpraypaintService.handleBuyRequest(player, "Cobalt")
		local afterFirst = SpraypaintService.balanceOf(player)
		expect.falsy(SpraypaintService.handleBuyRequest(player, "Cobalt"))
		expect.equal(SpraypaintService.balanceOf(player), afterFirst)
	end)

	-- Gold and Carbon alone cannot prove the source check runs: neither carries a `price`, so both
	-- are refused by handleBuyRequest's price guard regardless of whether the source check exists at
	-- all -- deleting the source check would leave this suite fully green. A property over the WHOLE
	-- catalogue is the only version of this test that can catch a future palette whose source and
	-- price disagree.
	t.test("purchasability matches source: every palette succeeds only if it is Spraypaint-sourced", function()
		for _, palette in Palettes.list do
			local player = fakePlayer(99999)
			local bought = SpraypaintService.handleBuyRequest(player, palette.key)
			expect.equal(bought, palette.source == "Spraypaint")
		end
	end)

	t.test("an unknown palette key is refused and does not throw", function()
		local player = fakePlayer(100000)
		expect.falsy(SpraypaintService.handleBuyRequest(player, "NoSuchPalette"))
		expect.equal(SpraypaintService.balanceOf(player), 100000)
	end)

	t.test("a non-string palette key is refused and does not throw", function()
		local player = fakePlayer(100000)
		expect.falsy(SpraypaintService.handleBuyRequest(player, 42))
		expect.falsy(SpraypaintService.handleBuyRequest(player, nil))
		expect.equal(SpraypaintService.balanceOf(player), 100000)
	end)
end
