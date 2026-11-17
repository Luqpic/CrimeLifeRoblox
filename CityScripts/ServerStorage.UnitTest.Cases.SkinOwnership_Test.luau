-- Buying a Spraypaint skin for a weapon the player does not own is refused before anything is charged.
-- Stand-in player (a real Player cannot be built); no profile is bound, so mirror is a no-op.
return function(t)
	local SpraypaintService = require(game.ServerScriptService.Spraypaint.Scripts.SpraypaintService)
	local CosmeticsService = require(game.ServerScriptService.Cosmetics.Scripts.CosmeticsService)
	local SpraypaintConstants = require(game.ReplicatedStorage.Spraypaint.Constants)
	local UpgradeConfig = require(game.ReplicatedStorage.Weapons.UpgradeConfig)
	local expect = t.expect

	local function standIn(owned: { string }?)
		local attributes = { [SpraypaintConstants.ATTRIBUTE] = 1500 }
		for _, name in owned or {} do
			attributes[name] = true
		end
		return {
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			FindFirstChildOfClass = function() return nil end,
		}
	end

	t.test("a skin bought for an owned weapon is charged, owned and equipped", function()
		local player = standIn({ UpgradeConfig.ownedAttributeFor("Crowbar") })
		SpraypaintService.handleBuySkinRequest(player, "Cobalt", "Crowbar")
		expect.equal(player:GetAttribute(SpraypaintConstants.ownedAttributeFor("Cobalt")), true)
		expect.equal(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")), "Cobalt")
		expect.truthy(SpraypaintService.balanceOf(player) < 1500)
	end)

	t.test("a skin for an unowned weapon is refused: nothing stored, nothing charged", function()
		local player = standIn() -- owns no weapon
		SpraypaintService.handleBuySkinRequest(player, "Cobalt", "Crowbar")
		expect.equal(SpraypaintService.balanceOf(player), 1500)
		expect.falsy(player:GetAttribute(SpraypaintConstants.ownedAttributeFor("Cobalt")))
		expect.falsy(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")))
	end)

	t.test("a non-string or unknown weapon name is refused before the charge", function()
		local player = standIn({ UpgradeConfig.ownedAttributeFor("Crowbar") })
		SpraypaintService.handleBuySkinRequest(player, "Cobalt", 7)
		SpraypaintService.handleBuySkinRequest(player, "Cobalt", "NoSuchWeapon")
		expect.equal(SpraypaintService.balanceOf(player), 1500)
		expect.falsy(player:GetAttribute(SpraypaintConstants.ownedAttributeFor("Cobalt")))
	end)
end
