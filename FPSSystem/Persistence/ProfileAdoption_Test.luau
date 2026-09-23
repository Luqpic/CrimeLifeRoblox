-- Tests that each service's mirror points actually write into the profile, that hydration restores
-- attributes from a profile, and that hydration cannot be raced by a mirror (Finding 3).
--
-- These use a stand-in player table, because a real Player cannot be constructed. The services read
-- and write attributes, and CosmeticsService.refresh (now called from hydrate) additionally reads
-- FindFirstChildOfClass/Character, so the stand-in stubs that the same way CosmeticsOwnership_Test's
-- fakePlayer does -- enough to let refresh no-op instead of throwing on a plain table.
return function(t)
	local Gateway = require(game.ServerScriptService.Persistence.Scripts.ProfileGateway)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local CosmeticsService = require(game.ServerScriptService.Cosmetics.Scripts.CosmeticsService)
	local SpraypaintConstants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local Palettes = require(game.ReplicatedStorage.Cosmetics.Palettes)
	local expect = t.expect

	Gateway.useMockStore()

	local function standIn()
		local attributes = {}
		return {
			UserId = -math.random(1000, 999999),
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			FindFirstChildOfClass = function() return nil end,
			_attributes = attributes,
		}
	end

	local freeKey
	for _, palette in Palettes.list do
		if palette.source == "Free" then
			freeKey = palette.key
			break
		end
	end

	t.test("granting Spraypaint mirrors the new balance into the profile", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-grant-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 12, "test")
		expect.equal(profile.Data.spraypaint, 12)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("spending Spraypaint mirrors the deduction", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-spend-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 100, "test")
		SpraypaintService.spend(player, 40)
		expect.equal(profile.Data.spraypaint, 60)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("buying a skin mirrors ownership", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-buy-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 1000, "test")
		expect.truthy(SpraypaintService.handleBuyRequest(player, "Cobalt"))
		expect.equal(profile.Data.skinsOwned.Cobalt, true)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("a player with no profile still works and mirrors nothing", function()
		-- A mirror must never be the reason a gameplay path throws. The player simply plays a session
		-- that is not saved, which is what the kick path exists to prevent from happening silently.
		--
		-- Binds a real profile with a known balance, then unbinds before granting, so this proves the
		-- guard genuinely skipped the write. The original version of this test never bound a profile at
		-- all, so it could not tell a correct guard from a broken one that merely did not throw.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-noprofile-" .. os.clock())
		profile.Data.spraypaint = 42
		Gateway._bind(player, profile)
		Gateway._unbind(player)

		expect.truthy(pcall(function() SpraypaintService.grant(player, 5, "test") end))
		expect.equal(SpraypaintService.balanceOf(player), 5)
		expect.equal(profile.Data.spraypaint, 42)

		profile:EndSession()
	end)

	t.test("buying a skin with an auto-equip mirrors both ownership and the equip", function()
		-- Finding 1: the BuySkinRequest auto-equip write was not mirrored -- ownership persisted but the
		-- equip did not. handleBuySkinRequest is the named seam extracted from that remote handler.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-buy-equip-" .. os.clock())
		Gateway._bind(player, profile)

		SpraypaintService.grant(player, 1000, "test")
		SpraypaintService.handleBuySkinRequest(player, "Cobalt", "Crowbar")

		expect.equal(profile.Data.skinsOwned.Cobalt, true)
		expect.equal(profile.Data.equippedSkin.Crowbar, "Cobalt")

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("equipping a skin through CosmeticsService mirrors it into the profile", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-equip-" .. os.clock())
		Gateway._bind(player, profile)

		CosmeticsService.handleEquipRequest(player, "Crowbar", freeKey)
		expect.equal(profile.Data.equippedSkin.Crowbar, freeKey)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("hydrating CosmeticsService restores equipped skins onto the attributes", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-cosmetics-hydrate-" .. os.clock())
		profile.Data.equippedSkin.Crowbar = freeKey
		Gateway._bind(player, profile)

		CosmeticsService.hydrate(player)
		expect.equal(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")), freeKey)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("hydration runs before the bind, so a change earned mid-hydration is lost rather than written from an un-hydrated balance", function()
		-- Finding 3: mirror is guarded on ProfileGateway.get(player), so this is only closed if that
		-- stays nil for the ENTIRE hydrator loop, not just before SpraypaintService's own hydrator runs.
		-- The probe below registers into the SAME hydrators list the real services use (they already
		-- registered at require time above) and fires mid-loop, exactly the window the bug lived in.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-race-" .. os.clock())
		profile.Data.spraypaint = 777 -- the real persisted balance

		local getDuringHydration = "not set"
		Gateway.registerHydrator(function(p, _profile)
			if p == player then
				getDuringHydration = Gateway.get(player)
				SpraypaintService.grant(player, 5, "race-probe")
			end
		end)

		Gateway._runHydrators(player, profile)
		Gateway._bind(player, profile)

		expect.equal(getDuringHydration, nil)
		expect.equal(profile.Data.spraypaint, 777)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("hydrating restores a balance and owned skins onto the attributes", function()
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-hydrate-" .. os.clock())
		profile.Data.spraypaint = 321
		profile.Data.skinsOwned.Ember = true
		Gateway._bind(player, profile)

		SpraypaintService.hydrate(player)
		expect.equal(player:GetAttribute(SpraypaintConstants.ATTRIBUTE), 321)
		expect.equal(player:GetAttribute(SpraypaintConstants.ownedAttributeFor("Ember")), true)

		Gateway._unbind(player)
		profile:EndSession()
	end)
end
