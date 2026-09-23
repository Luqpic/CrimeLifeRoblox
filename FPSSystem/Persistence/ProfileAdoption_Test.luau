-- Tests that each service's mirror points actually write into the profile, that hydration restores
-- attributes from a profile, that hydration cannot be raced by a mirror (Finding 3), and that a
-- post-hydrator sees every hydrator's result regardless of registration order (fix round 2), that a
-- restored level is not paid out as a level-up, and that a hydrator registered after a bind still
-- hydrates that player (final fix round).
--
-- These use a stand-in player table, because a real Player cannot be constructed. The services read
-- and write attributes, and CosmeticsService's post-hydrator calls refresh, which additionally reads
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

	t.test("mirror hands the callback the profile itself, so a write only counts through profile.Data", function()
		-- The contract every adoption in this phase is built on, and the one that was misread. `apply`
		-- receives the PROFILE; a write to the argument's own top level lands on the ProfileStore profile
		-- object, which is never serialised, so it looks saved and is silently lost. That exact mistake
		-- shipped in Task 4 as `function(data) data.cash = cash.Value end` and cost cash, level and XP
		-- their persistence -- measured live at profile.Data.cash = 500 while the player held 9525.
		--
		-- This is the only part of Task 5's three services that is reachable from a test at all (they are
		-- Scripts), and it is worth having: it is a real assertion against deployed ProfileGateway code.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-mirror-contract-" .. os.clock())
		Gateway._bind(player, profile)

		local received
		Gateway.mirror(player, function(p)
			received = p
			p.Data.cash = 4242 -- correct
			p.spraypaint = 99 -- the mistake
		end)

		expect.equal(received, profile)
		expect.equal(profile.Data.cash, 4242)
		expect.equal(profile.Data.spraypaint, 0) -- the top-level write did NOT reach the saved table

		Gateway._unbind(player)
		profile:EndSession()
	end)

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

	t.test("post-hydrators run after every hydrator, regardless of registration order", function()
		-- CosmeticsService is a require of SpraypaintService, so CosmeticsService's hydrator ALWAYS
		-- registers before SpraypaintService's -- that is fixed by the require graph and this test does
		-- not, and must not need to, control it. What it proves instead is the actual invariant: a
		-- post-hydrator never runs until every hydrator, including one registered AFTER it, has
		-- finished. The probe checks the one attribute that only SpraypaintService's LATER-registered
		-- hydrator can have set -- exactly the dependency Finding 4's fix round 1 got wrong.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-posthydrate-order-" .. os.clock())
		profile.Data.skinsOwned.Cobalt = true

		local ownedSeenByProbe = "not set"
		Gateway.registerPostHydrator(function(p, _profile)
			if p == player then
				ownedSeenByProbe = p:GetAttribute(SpraypaintConstants.ownedAttributeFor("Cobalt"))
			end
		end)

		Gateway._runHydrators(player, profile)
		Gateway._runPostHydrators(player, profile)

		expect.equal(ownedSeenByProbe, true)

		profile:EndSession()
	end)

	t.test("a restored level is not paid out as a level-up", function()
		-- The Critical the whole-branch review found. `lastLevel` is DERIVED and never persisted, and
		-- SpraypaintService.start seeds it inside safePlayerAdded -- which runs BEFORE the gateway's
		-- yielding load resolves, so the seed is LevelingService's default 1. Hydration's
		-- SetAttribute("Level", 12) then lands afterwards and reads as an 11-level level-up worth
		-- (12 - 1) * 25 = 275 spraypaint, paid on every single rejoin. It was silent only when
		-- SpraypaintRunner happened to require first and the seed was nil: correct by ordering luck.
		--
		-- Runs the REAL registered hydrator and post-hydrator lists. LevelingService is a Script, so its
		-- hydrator registers at server start rather than on require and this file cannot make it
		-- present; the probe below writes the same attribute from the same field, so the case measures
		-- the same thing either way, and the Level assertion catches it if neither ran.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-lastlevel-" .. os.clock())
		profile.Data.level = 12
		profile.Data.spraypaint = 40

		Gateway.registerHydrator(function(p, prof)
			if p == player then
				p:SetAttribute("Level", prof.Data.level)
			end
		end)

		-- What safePlayerAdded sees at join: the pre-restore default, never the saved level.
		player:SetAttribute("Level", 1)
		SpraypaintService.onLevelChanged(player) -- seeds the baseline at 1, pays nothing (previous nil)

		Gateway._runHydrators(player, profile)
		Gateway._runPostHydrators(player, profile)
		Gateway._bind(player, profile)

		-- The GetAttributeChangedSignal that hydration's SetAttribute fires. Measured deferred in this
		-- place, so it lands after the post-hydrators; a stand-in table has no signals, so it is driven
		-- directly here, which is exactly what that connection does.
		SpraypaintService.onLevelChanged(player)

		expect.equal(player:GetAttribute("Level"), 12) -- the restore really happened
		expect.equal(SpraypaintService.balanceOf(player), 40) -- not 40 + 275
		expect.equal(profile.Data.spraypaint, 40) -- and nothing inflated was mirrored back

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("a hydrator registered after a player is already bound still hydrates them", function()
		-- The Major the whole-branch review found. _runHydrators runs whatever is registered at that
		-- instant and then binds unconditionally, so a service that registers late never hydrates that
		-- player -- and its own guarded default then gets mirrored over real saved data by the next
		-- ordinary action. registerHydrator now runs the new function for every already-bound player.
		local player = standIn()
		local profile = Gateway.loadForKey("adopt-late-register-" .. os.clock())
		profile.Data.spraypaint = 808

		Gateway._runHydrators(player, profile)
		Gateway._runPostHydrators(player, profile)
		Gateway._bind(player, profile) -- bound BEFORE the service below exists

		local lateSaw
		Gateway.registerHydrator(function(p, prof)
			if p == player then
				lateSaw = prof.Data.spraypaint
			end
		end)
		expect.equal(lateSaw, 808)

		-- Same for post-hydrators, and a throwing one must not break registration for the next service.
		expect.truthy(pcall(function()
			Gateway.registerPostHydrator(function(p)
				if p == player then
					error("a late post-hydrator that throws")
				end
			end)
		end))
		local latePostSaw
		Gateway.registerPostHydrator(function(p, prof)
			if p == player then
				latePostSaw = prof.Data.spraypaint
			end
		end)
		expect.equal(latePostSaw, 808)

		Gateway._unbind(player)
		profile:EndSession()
	end)

	t.test("hydrating restores a Spraypaint-sourced equipped skin onto a Tool already in hand", function()
		-- The exact case fix round 2 closes: a Tool for "Crowbar" already exists (as if WeaponShopService
		-- granted and skinned it before this ran), and the equipped skin, "Cobalt", is Spraypaint-sourced,
		-- so re-dressing it correctly depends on SpraypaintService's SkinOwned_Cobalt attribute as well as
		-- CosmeticsService's own EquippedSkin_Crowbar attribute. If refresh ran as part of hydrate (fix
		-- round 1's version) rather than as a post-hydrator, this would come out Stock, not Cobalt.
		local player = standIn()
		local character = Instance.new("Model")
		local tool = Instance.new("Tool")
		tool.Name = "Crowbar"
		tool.Parent = character
		player.Character = character

		local profile = Gateway.loadForKey("adopt-posthydrate-skin-" .. os.clock())
		profile.Data.skinsOwned.Cobalt = true
		profile.Data.equippedSkin.Crowbar = "Cobalt"

		Gateway._runHydrators(player, profile)
		Gateway._runPostHydrators(player, profile)

		expect.equal(tool:GetAttribute("SkinId"), "Cobalt")

		character:Destroy()
		profile:EndSession()
	end)
end
