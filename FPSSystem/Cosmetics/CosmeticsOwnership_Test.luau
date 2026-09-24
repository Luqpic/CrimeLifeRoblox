-- Tests for the ownership rule in CosmeticsService. These run against a stand-in player object
-- rather than a real Player, because a unit test cannot mint one.
return function(t)
	local ReplicatedStorage = game.ReplicatedStorage
	local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
	local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
	local CosmeticsService = require(game.ServerScriptService.Cosmetics.Scripts.CosmeticsService)
	local expect = t.expect

	-- Minimal stand-in, now also exercising handleEquipRequest, which writes via SetAttribute and
	-- then unconditionally calls refresh -- refresh only touches a container through
	-- FindFirstChildOfClass, so that stub (returning nil, same as a player with an empty Backpack)
	-- is enough to let refresh no-op instead of throwing on a plain table.
	-- `owned` lists attribute names the stand-in already holds (the Vip pass flag, SkinOwned_<key>).
	local function fakePlayer(owned: { string }?)
		local attributes = {}
		for _, name in owned or {} do
			attributes[name] = true
		end
		return {
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			FindFirstChildOfClass = function() return nil end,
		}
	end

	local SpraypaintConstants = require(ReplicatedStorage.Spraypaint.Constants)
	local VIP_PASS = MonetizationConstants.ownedAttributeFor("Vip")
	local freeKey, paidKey, vipCount = nil, nil, 0
	for _, palette in Palettes.list do
		if palette.source == "Vip" then vipCount += 1 end
		if palette.source == "Spraypaint" and not paidKey then paidKey = palette.key end
		if palette.source == "Free" and not freeKey then freeKey = palette.key end
	end

	-- VIP IS ON HOLD. With no Vip palette in the catalogue, the three Vip-gate tests that stood here
	-- would have looked up a nil key and passed without testing anything, so they now exercise the same
	-- ownership gate through a Spraypaint palette instead. This test pins the on-hold state: the day a
	-- Vip palette returns it fails, and the Vip-pass tests (refused without the pass, allowed with it,
	-- and the equip handler refusing it) should come back alongside the Spraypaint ones below.
	t.test("no palette is gated behind the Vip pass while Vip is on hold", function()
		expect.equal(vipCount, 0)
	end)

	t.test("a free palette is owned by everyone", function()
		expect.truthy(CosmeticsService.ownsPalette(fakePlayer(), freeKey))
	end)

	t.test("a Spraypaint palette is refused until it has been bought, even with the Vip pass", function()
		expect.falsy(CosmeticsService.ownsPalette(fakePlayer({ VIP_PASS }), paidKey))
	end)

	t.test("a Spraypaint palette is allowed once bought", function()
		expect.truthy(CosmeticsService.ownsPalette(fakePlayer({ SpraypaintConstants.ownedAttributeFor(paidKey) }), paidKey))
	end)

	t.test("an unknown key is never owned, pass or no pass", function()
		expect.falsy(CosmeticsService.ownsPalette(fakePlayer({ VIP_PASS }), "NoSuchPalette"))
	end)

	t.test("attributeFor is stable and sanitises a weapon name with a space", function()
		expect.equal(CosmeticsService.attributeFor("Mossberg 590"), "EquippedSkin_Mossberg_590")
	end)

	t.test("every weapon in the armoury maps to a legal, unique attribute name", function()
		-- Not decorative. Roblox rejects an attribute name containing a space, hyphen or '&', and 16
		-- of the 29 weapon names contain one ("AUG A-3", "S&W 29", "Mossberg 590"...). Without the
		-- sanitising gsub the equip remote throws for over half the armoury. And two weapons must
		-- never collapse to the same key, or they would silently share one skin.
		local probe = Instance.new("Part")
		local seen = {}
		for _, tool in game.ServerStorage.Weapons:GetChildren() do
			if tool:IsA("Tool") then
				local key = CosmeticsService.attributeFor(tool.Name)
				expect.falsy(seen[key])
				seen[key] = tool.Name
				expect.truthy(pcall(function() probe:SetAttribute(key, "x") end))
			end
		end
	end)

	-- Regression coverage for the security ordering itself (type check, then armoury check, then
	-- ownership, then write) -- proven once manually during review; a later edit that reordered the
	-- write ahead of the ownership check would hand out unbought skins with none of the ownership tests above
	-- failing, since they call ownsPalette directly rather than the handler.
	t.test("handleEquipRequest refuses an unbought Spraypaint palette and leaves the attribute unset", function()
		local player = fakePlayer()
		CosmeticsService.handleEquipRequest(player, "Crowbar", paidKey)
		expect.falsy(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")))
	end)

	t.test("handleEquipRequest writes a free palette", function()
		local player = fakePlayer()
		CosmeticsService.handleEquipRequest(player, "Crowbar", freeKey)
		expect.equal(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")), freeKey)
	end)

	t.test("handleEquipRequest ignores a non-string weapon name or palette key", function()
		local player = fakePlayer({ VIP_PASS })
		CosmeticsService.handleEquipRequest(player, 123, freeKey)
		CosmeticsService.handleEquipRequest(player, "Crowbar", 456)
		expect.falsy(player:GetAttribute(CosmeticsService.attributeFor("Crowbar")))
	end)

	t.test("handleEquipRequest ignores a weapon name outside the armoury", function()
		local player = fakePlayer({ VIP_PASS })
		CosmeticsService.handleEquipRequest(player, "NoSuchWeapon", freeKey)
		expect.falsy(player:GetAttribute(CosmeticsService.attributeFor("NoSuchWeapon")))
	end)

	t.test("handleEquipRequest rejects an over-long weapon name without throwing", function()
		local player = fakePlayer({ VIP_PASS })
		local longName = string.rep("a", 90)
		expect.truthy(pcall(CosmeticsService.handleEquipRequest, player, longName, freeKey))
		expect.falsy(player:GetAttribute(CosmeticsService.attributeFor(longName)))
	end)
end
