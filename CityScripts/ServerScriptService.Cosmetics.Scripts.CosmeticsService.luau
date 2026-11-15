-- Server side of cosmetics: decides what a player may wear, stamps it on the Tool, and dresses the
-- world model everyone else sees.
--
-- The viewmodel is NOT dressed here. It is built client-side and is dressed there, after the motion
-- module has solved its joints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)
local SpraypaintConstants = require(ReplicatedStorage.Spraypaint.Constants)
local ProfileGateway = require(ServerScriptService.Persistence.Scripts.ProfileGateway)

local CosmeticsService = {}

-- Which game pass unlocks the Vip tier. The pass already advertises "Exclusive weapon skins".
local VIP_KEY = "Vip"

-- Per weapon, so a player can dress each gun differently. Republished as a player attribute the way
-- LoadoutSlot already is, which is what makes it survive a respawn without a DataStore.
function CosmeticsService.attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

function CosmeticsService.ownsPalette(player: Player, key: string): boolean
	local palette = Palettes.byKey(key)
	if not palette then
		return false
	end
	if Palettes.isVipOnly(key) then
		return player:GetAttribute(MonetizationConstants.ownedAttributeFor(VIP_KEY)) == true
	end
	-- Gated on SOURCE, not on a price existing. Those are equivalent in today's catalogue, but they
	-- are separate invariants maintained by hand, and if they ever diverge this branch must fail
	-- CLOSED: a Spraypaint palette added without a price would otherwise fall through to `return true`
	-- and be free for everyone, permanently. The Vip branch above fails closed for the same reason.
	if palette.source == "Spraypaint" then
		return player:GetAttribute(SpraypaintConstants.ownedAttributeFor(key)) == true
	end
	return true
end

function CosmeticsService.equippedKeyFor(player: Player, weaponName: string): string
	local key = player:GetAttribute(CosmeticsService.attributeFor(weaponName))
	if typeof(key) ~= "string" or not CosmeticsService.ownsPalette(player, key) then
		return Palettes.DEFAULT_KEY
	end
	return key
end

-- Restores each weapon's persisted equipped skin onto the attribute the rest of the game reads.
--
-- `profile` is normally supplied by the gateway's own hydrator loop, which runs before the profile is
-- bound (see ProfileGateway.registerHydrator below) -- ProfileGateway.get(player) would still be nil
-- at that point. The fallback lookup exists only so a direct call, such as a test that has already
-- bound a stand-in with Gateway._bind, still works without threading a profile through by hand.
--
-- Deliberately does NOT re-dress a Tool already in hand here. Whether an equipped skin is even worn
-- can depend on SpraypaintService's ownership attributes (a Spraypaint-sourced skin), which this
-- service's own hydrator has no guarantee has run yet -- CosmeticsService is a require of
-- SpraypaintService, so its hydrator always registers first. See the post-hydrator registered below,
-- which runs only once every hydrator, not just this one, has finished.
function CosmeticsService.hydrate(player: any, profile: any?)
	profile = profile or ProfileGateway.get(player)
	if not profile then
		return
	end
	for weaponName, paletteKey in profile.Data.equippedSkin do
		player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
	end
end

-- Called by WeaponShopService wherever it hands a weapon to a player, including the respawn restore.
-- Silent by design: it writes appearance and nothing else, so it cannot make a restore sound like a
-- purchase.
function CosmeticsService.applyToTool(player: Player, tool: Tool)
	local key = CosmeticsService.equippedKeyFor(player, tool.Name)
	tool:SetAttribute("SkinId", key)
	-- The applier locates the Tool's Blaster sub-model itself and skips invisible skeleton parts.
	SkinApplier.applyKey(tool, key)
end

-- Re-dresses every weapon a player is currently carrying. Used when the equipped skin changes.
function CosmeticsService.refresh(player: Player, weaponName: string?)
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, tool in container:GetChildren() do
				if tool:IsA("Tool") and (weaponName == nil or tool.Name == weaponName) then
					-- One weapon's failure must not stop its neighbours being re-dressed -- guarded the
					-- same way WeaponShopService already guards this same call.
					local ok, err = pcall(CosmeticsService.applyToTool, player, tool)
					if not ok then
						warn("[Cosmetics] failed to skin " .. tool.Name .. ": " .. tostring(err))
					end
				end
			end
		end
	end
end

-- The client asks; the server decides. Ownership is re-checked here rather than trusted from the
-- caller, so a forged request naming a Vip palette from a player without the pass is refused. Named
-- (rather than inline in the connection) so the check ordering -- the feature's paid-content boundary
-- -- has a seam the test suite can call directly.
function CosmeticsService.handleEquipRequest(player: Player, weaponName: unknown, paletteKey: unknown)
	if typeof(weaponName) ~= "string" or typeof(paletteKey) ~= "string" then
		return
	end
	-- Bounds the attribute namespace to the real armoury (29 tools, already proven collision-free)
	-- and keeps every derived name far under Roblox's 100-character attribute-name limit -- an
	-- arbitrary client-supplied string could guarantee neither.
	local tool = ServerStorage.Weapons:FindFirstChild(weaponName)
	if not tool or not tool:IsA("Tool") then
		return
	end
	if not CosmeticsService.ownsPalette(player, paletteKey) then
		return
	end
	player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
	ProfileGateway.mirror(player, function(profile)
		profile.Data.equippedSkin[weaponName] = paletteKey
	end)
	CosmeticsService.refresh(player, weaponName)
end

ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest.OnServerEvent:Connect(CosmeticsService.handleEquipRequest)

-- Registered at require time, so the gateway can restore this service's attributes before any other
-- code can observe a bound profile. Self-registered rather than called from SpraypaintService's join
-- handler, which is what coupled the two services before this moved into the gateway.
ProfileGateway.registerHydrator(CosmeticsService.hydrate)

-- Re-dressing a Tool already in hand is a CONSEQUENCE of hydration, not a part of it -- it needs the
-- whole profile restored (this service's equipped-skin attribute AND SpraypaintService's ownership
-- attribute), not just this one's slice. A post-hydrator runs only after every hydrator has finished,
-- so this is correct regardless of which service happened to register its hydrator first.
ProfileGateway.registerPostHydrator(function(player: any, _profile: any)
	CosmeticsService.refresh(player)
end)

return CosmeticsService
