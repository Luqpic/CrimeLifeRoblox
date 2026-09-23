-- Tests for ServerScriptService.Spraypaint.Scripts.SpraypaintService.
-- The handlers are exposed as named functions specifically so the earn rules can be tested rather than
-- proven once by hand -- Phase 1 learned that lesson on its equip remote.
return function(t)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local Constants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local expect = t.expect

	-- A REAL weapon name is required wherever a call validates against ServerStorage.Weapons (buy
	-- and buy-skin) -- handleBuyRequest now refuses a name with no backing Tool template, since it is
	-- what decides which balance gets charged. "Crowbar" is the name the rest of this test suite
	-- (ProfileAdoption_Test, CosmeticsOwnership_Test) already relies on existing there.
	local REAL_WEAPON = "Crowbar"

	-- A stand-in player: the service only ever calls GetAttribute and SetAttribute on it.
	-- `startingBalances` seeds one or more per-weapon balances; `startingShared` seeds the shared
	-- bucket. Both default empty/zero, matching a fresh join.
	local function fakePlayer(startingBalances: { [string]: number }?, startingShared: number?)
		local attributes = {}
		for weaponName, amount in (startingBalances or {}) do
			attributes[Constants.balanceAttributeFor(weaponName)] = amount
		end
		attributes[Constants.SHARED_ATTRIBUTE] = startingShared or 0
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

	-- ============================================================
	-- balanceOf / sharedBalanceOf / spendableBalanceOf
	-- ============================================================

	t.test("a fresh player starts at zero for any weapon", function()
		expect.equal(SpraypaintService.balanceOf(fakePlayer(), "AK47"), 0)
	end)

	t.test("balanceOf falls back to zero when the attribute is unset", function()
		local unset = { GetAttribute = function() return nil end, SetAttribute = function() end }
		expect.equal(SpraypaintService.balanceOf(unset, "AK47"), 0)
	end)

	t.test("balanceOf falls back to zero when the attribute is not a number", function()
		local wrongType = { GetAttribute = function() return "not a number" end, SetAttribute = function() end }
		expect.equal(SpraypaintService.balanceOf(wrongType, "AK47"), 0)
	end)

	t.test("balanceOf falls back to zero, not an error, when weaponName is not a string", function()
		-- Constants.balanceAttributeFor throws on a non-string (gsub on nil). A caller passing an
		-- unvalidated value through must get 0, never a crash.
		local player = fakePlayer({ AK47 = 10 })
		expect.equal(SpraypaintService.balanceOf(player, nil), 0)
		expect.equal(SpraypaintService.balanceOf(player, 42), 0)
	end)

	t.test("sharedBalanceOf falls back to zero when unset", function()
		local unset = { GetAttribute = function() return nil end, SetAttribute = function() end }
		expect.equal(SpraypaintService.sharedBalanceOf(unset), 0)
	end)

	t.test("spendableBalanceOf sums a weapon's own balance and the shared bucket", function()
		local player = fakePlayer({ AK47 = 10 }, 25)
		expect.equal(SpraypaintService.spendableBalanceOf(player, "AK47"), 35)
		-- An unrelated weapon has no OWN balance, but still sees the shared bucket.
		expect.equal(SpraypaintService.spendableBalanceOf(player, "M4A1"), 25)
	end)

	-- ============================================================
	-- grant / grantShared
	-- ============================================================

	t.test("granting adds to the named weapon and returns the new balance", function()
		local player = fakePlayer({ AK47 = 10 })
		expect.equal(SpraypaintService.grant(player, "AK47", 15, "test"), 25)
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 25)
	end)

	t.test("granting credits whichever weapon name was passed in, not a fixed one", function()
		-- Every other grant test in this file happens to use "AK47" as the credited weapon, which
		-- alone cannot distinguish real attribution from a grant() that ignores its weaponName
		-- parameter and always writes to a hardcoded "AK47" attribute. A second, different weapon
		-- name is the only thing that closes that gap.
		local player = fakePlayer()
		expect.equal(SpraypaintService.grant(player, "M4A1", 15, "test"), 15)
		expect.equal(SpraypaintService.balanceOf(player, "M4A1"), 15)
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
	end)

	t.test("granting a weapon does not affect another weapon's balance or the shared bucket", function()
		-- Mutation target: a grant that wrote to the wrong attribute, or to Constants.SHARED_ATTRIBUTE
		-- instead of the weapon's own, would pass every other grant test in this file and fail only
		-- this one.
		local player = fakePlayer({ AK47 = 10, M4A1 = 40 }, 5)
		SpraypaintService.grant(player, "AK47", 15, "test")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 25)
		expect.equal(SpraypaintService.balanceOf(player, "M4A1"), 40)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 5)
	end)

	t.test("granting zero or a negative amount changes nothing", function()
		local player = fakePlayer({ AK47 = 10 })
		SpraypaintService.grant(player, "AK47", 0, "test")
		SpraypaintService.grant(player, "AK47", -50, "test")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 10)
	end)

	t.test("granting NaN or infinity changes nothing", function()
		-- Neither passes a bare `amount <= 0` check (NaN compares false to everything; infinity is
		-- merely large), and an infinite balance would make every future spend succeed forever.
		local player = fakePlayer({ AK47 = 10 })
		SpraypaintService.grant(player, "AK47", 0 / 0, "test")
		SpraypaintService.grant(player, "AK47", math.huge, "test")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 10)
	end)

	t.test("granting with a non-string weapon name changes nothing", function()
		local player = fakePlayer({ AK47 = 10 })
		expect.equal(SpraypaintService.grant(player, nil, 15, "test"), 0)
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 10)
	end)

	t.test("grantShared adds to the shared bucket only, never a weapon's own balance", function()
		local player = fakePlayer({ AK47 = 10 }, 5)
		expect.equal(SpraypaintService.grantShared(player, 20, "level"), 25)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 25)
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 10)
	end)

	t.test("grantShared rejects the same invalid amounts as grant", function()
		local player = fakePlayer(nil, 5)
		SpraypaintService.grantShared(player, 0, "level")
		SpraypaintService.grantShared(player, -50, "level")
		SpraypaintService.grantShared(player, 0 / 0, "level")
		expect.equal(SpraypaintService.sharedBalanceOf(player), 5)
	end)

	-- ============================================================
	-- spend: own balance first, shared bucket as fallback
	-- ============================================================

	t.test("spending deducts from the weapon's own balance when it fully covers the cost", function()
		local player = fakePlayer({ AK47 = 300 }, 50)
		expect.truthy(SpraypaintService.spend(player, "AK47", 250))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 50)
		-- Untouched: the own balance alone covered it, so the shared bucket must not move.
		expect.equal(SpraypaintService.sharedBalanceOf(player), 50)
	end)

	t.test("spending exactly the weapon's own balance is allowed and leaves the shared bucket untouched", function()
		local player = fakePlayer({ AK47 = 250 }, 10)
		expect.truthy(SpraypaintService.spend(player, "AK47", 250))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 10)
	end)

	t.test("spending draws from the shared bucket only for what the weapon's own balance cannot cover", function()
		-- The fallback order the design calls for: own first, shared only for the remainder.
		local player = fakePlayer({ AK47 = 10 }, 50)
		expect.truthy(SpraypaintService.spend(player, "AK47", 30))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 30) -- 50 - (30 - 10)
	end)

	t.test("spending with no own balance draws entirely from the shared bucket", function()
		local player = fakePlayer(nil, 100)
		expect.truthy(SpraypaintService.spend(player, "AK47", 40))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 60)
	end)

	t.test("spending more than the combined own-plus-shared balance is refused and deducts nothing", function()
		local player = fakePlayer({ AK47 = 10 }, 20)
		expect.falsy(SpraypaintService.spend(player, "AK47", 100))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 10)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 20)
	end)

	t.test("spending against one weapon never draws down another weapon's balance", function()
		-- Mutation target: a spend that summed ALL weapons' balances (rather than one weapon's own
		-- plus the single shared bucket) would pass the insufficient-balance test above by accident
		-- and only fail here.
		local player = fakePlayer({ AK47 = 5, M4A1 = 500 })
		expect.falsy(SpraypaintService.spend(player, "AK47", 100))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 5)
		expect.equal(SpraypaintService.balanceOf(player, "M4A1"), 500)
	end)

	t.test("spending a fractional amount is refused and deducts nothing", function()
		local player = fakePlayer({ AK47 = 100 })
		expect.falsy(SpraypaintService.spend(player, "AK47", 12.5))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 100)
	end)

	t.test("spending with a non-string weapon name is refused and does not throw", function()
		local player = fakePlayer(nil, 100)
		expect.truthy(pcall(function()
			expect.falsy(SpraypaintService.spend(player, nil, 10))
		end))
	end)

	-- ============================================================
	-- Kill attribution
	-- ============================================================

	t.test("killing a Thug with a weapon awards the Criminal rate to THAT weapon", function()
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Criminal"), "AK47")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), Constants.KILL_SPRAYPAINT.Criminal)
	end)

	t.test("killing Police awards the higher rate to the weapon used", function()
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Police"), "AK47")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), Constants.KILL_SPRAYPAINT.Police)
	end)

	t.test("a kill with weapon X raises X's balance and no other weapon's", function()
		-- The exact property the design names: attribution, not a shared pool. Mutation target: a
		-- kill handler that credited a fixed/hardcoded weapon name, or the shared bucket, would still
		-- pass the two tests above (they only check the credited weapon) and fail only here.
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Police"), "AK47")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), Constants.KILL_SPRAYPAINT.Police)
		expect.equal(SpraypaintService.balanceOf(player, "M4A1"), 0)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 0)
	end)

	t.test("a kill credits whichever weapon name was passed in, not a fixed one", function()
		-- Every award test above uses "AK47", which alone cannot distinguish real attribution from
		-- an awardForVictim that ignores its weaponName parameter and always credits a hardcoded
		-- "AK47". This is the ONLY case in the whole suite that credits a kill to a weapon other
		-- than "AK47" -- without it, the kill-credit path could be silently hardcoded and nothing
		-- here would notice.
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim("Police"), "M4A1")
		expect.equal(SpraypaintService.balanceOf(player, "M4A1"), Constants.KILL_SPRAYPAINT.Police)
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
	end)

	t.test("a PvP kill awards nothing", function()
		-- The victim has no Faction attribute, exactly as a player character does not. If this ever
		-- pays out, two players can farm Spraypaint off each other indefinitely.
		local player = fakePlayer()
		SpraypaintService.awardForVictim(player, fakeVictim(nil), "AK47")
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
	end)

	t.test("awardForVictim with a non-string weapon name pays nothing, even for a worthy kill", function()
		local player = fakePlayer()
		expect.truthy(pcall(SpraypaintService.awardForVictim, player, fakeVictim("Police"), nil))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
		expect.equal(SpraypaintService.sharedBalanceOf(player), 0)
	end)

	t.test("onEliminated rejects an attacker that is not a Player", function()
		-- The victim WOULD pay through awardForVictim, so this proves the guard blocks rather than
		-- the victim being worthless. Asserting the Model was never paid, not merely that nothing
		-- threw: a Model accepts SetAttribute quite happily, so a regression that dropped the
		-- IsA("Player") check would survive a no-throw assertion untouched.
		local notAPlayer = Instance.new("Model")
		expect.truthy(pcall(SpraypaintService.onEliminated, notAPlayer, fakeVictim("Police"), 25, "AK47"))
		expect.equal(notAPlayer:GetAttribute(Constants.balanceAttributeFor("AK47")), nil)
		expect.truthy(pcall(SpraypaintService.onEliminated, nil, fakeVictim("Police"), 25, "AK47"))
	end)

	t.test("a victim with no character awards nothing and does not throw", function()
		local orphan = Instance.new("Humanoid")
		local player = fakePlayer()
		expect.truthy(pcall(SpraypaintService.awardForVictim, player, orphan, "AK47"))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 0)
	end)

	-- ============================================================
	-- Buying skins: charges the named weapon
	-- ============================================================

	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)

	local function ownedName(key)
		return Constants.ownedAttributeFor(key)
	end

	t.test("buying a Spraypaint palette charges the named weapon and records ownership", function()
		local player = fakePlayer({ [REAL_WEAPON] = 1000 })
		expect.truthy(SpraypaintService.handleBuyRequest(player, "Cobalt", REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), 1000 - Palettes.priceOf("Cobalt"))
		expect.equal(player._attributes[ownedName("Cobalt")], true)
	end)

	t.test("buying a skin for weapon X charges X and leaves another weapon's balance untouched", function()
		-- The exact property the design names for the buy path.
		local player = fakePlayer({ [REAL_WEAPON] = 1000, AK47 = 1000 })
		expect.truthy(SpraypaintService.handleBuyRequest(player, "Cobalt", REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), 1000 - Palettes.priceOf("Cobalt"))
		expect.equal(SpraypaintService.balanceOf(player, "AK47"), 1000)
	end)

	t.test("buying without enough combined balance is refused and changes nothing", function()
		local player = fakePlayer({ [REAL_WEAPON] = 10 })
		expect.falsy(SpraypaintService.handleBuyRequest(player, "Cobalt", REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), 10)
		expect.equal(player._attributes[ownedName("Cobalt")], nil)
	end)

	t.test("buying with a weapon name that has no real Tool template is refused and changes nothing", function()
		-- The check that makes charging a name safe at all: a crafted weaponName must not be able to
		-- both create an unbounded attribute AND succeed as a purchase.
		local player = fakePlayer({ [REAL_WEAPON] = 1000 })
		expect.falsy(SpraypaintService.handleBuyRequest(player, "Cobalt", "NotARealWeapon"))
		expect.equal(player._attributes[ownedName("Cobalt")], nil)
	end)

	t.test("buying the same palette twice deducts once", function()
		local player = fakePlayer({ [REAL_WEAPON] = 1000 })
		SpraypaintService.handleBuyRequest(player, "Cobalt", REAL_WEAPON)
		local afterFirst = SpraypaintService.balanceOf(player, REAL_WEAPON)
		expect.falsy(SpraypaintService.handleBuyRequest(player, "Cobalt", REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), afterFirst)
	end)

	-- Gold and Carbon alone cannot prove the source check runs: neither carries a `price`, so both
	-- are refused by handleBuyRequest's price guard regardless of whether the source check exists at
	-- all -- deleting the source check would leave this suite fully green. A property over the WHOLE
	-- catalogue is the only version of this test that can catch a future palette whose source and
	-- price disagree.
	t.test("purchasability matches source: every palette succeeds only if it is Spraypaint-sourced", function()
		for _, palette in Palettes.list do
			local player = fakePlayer({ [REAL_WEAPON] = 99999 })
			local bought = SpraypaintService.handleBuyRequest(player, palette.key, REAL_WEAPON)
			expect.equal(bought, palette.source == "Spraypaint")
		end
	end)

	t.test("an unknown palette key is refused and does not throw", function()
		local player = fakePlayer({ [REAL_WEAPON] = 100000 })
		expect.falsy(SpraypaintService.handleBuyRequest(player, "NoSuchPalette", REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), 100000)
	end)

	t.test("a non-string palette key is refused and does not throw", function()
		local player = fakePlayer({ [REAL_WEAPON] = 100000 })
		expect.falsy(SpraypaintService.handleBuyRequest(player, 42, REAL_WEAPON))
		expect.falsy(SpraypaintService.handleBuyRequest(player, nil, REAL_WEAPON))
		expect.equal(SpraypaintService.balanceOf(player, REAL_WEAPON), 100000)
	end)
end
