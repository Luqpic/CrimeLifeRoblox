-- Tests that each service's mirror points actually write into the profile.
--
-- These use a stand-in player table, because a real Player cannot be constructed. The services read
-- and write attributes, so the stand-in implements GetAttribute/SetAttribute and nothing else.
return function(t)
	local Gateway = require(game.ServerScriptService.Persistence.Scripts.ProfileGateway)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local SpraypaintConstants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local expect = t.expect

	Gateway.useMockStore()

	local function standIn()
		local attributes = {}
		return {
			UserId = -math.random(1000, 999999),
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			_attributes = attributes,
		}
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
		local player = standIn()
		expect.truthy(pcall(function() SpraypaintService.grant(player, 5, "test") end))
		expect.equal(SpraypaintService.balanceOf(player), 5)
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
