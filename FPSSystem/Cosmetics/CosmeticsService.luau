-- Server side of cosmetics: decides what a player may wear, stamps it on the Tool, and dresses the
-- world model everyone else sees.
--
-- The viewmodel is NOT dressed here. It is built client-side and is dressed there, after the motion
-- module has solved its joints.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palettes = require(ReplicatedStorage.Cosmetics.Palettes)
local SkinApplier = require(ReplicatedStorage.Cosmetics.SkinApplier)
local MonetizationConstants = require(ReplicatedStorage.Monetization.Constants)

local CosmeticsService = {}

-- Which game pass unlocks the Vip tier. The pass already advertises "Exclusive weapon skins".
local VIP_KEY = "Vip"

-- Per weapon, so a player can dress each gun differently. Republished as a player attribute the way
-- LoadoutSlot already is, which is what makes it survive a respawn without a DataStore.
function CosmeticsService.attributeFor(weaponName: string): string
	return "EquippedSkin_" .. (string.gsub(weaponName, "[^%w_]", "_"))
end

function CosmeticsService.ownsPalette(player: Player, key: string): boolean
	if not Palettes.byKey(key) then
		return false
	end
	if not Palettes.isVipOnly(key) then
		return true
	end
	return player:GetAttribute(MonetizationConstants.ownedAttributeFor(VIP_KEY)) == true
end

function CosmeticsService.equippedKeyFor(player: Player, weaponName: string): string
	local key = player:GetAttribute(CosmeticsService.attributeFor(weaponName))
	if typeof(key) ~= "string" or not CosmeticsService.ownsPalette(player, key) then
		return Palettes.DEFAULT_KEY
	end
	return key
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
					CosmeticsService.applyToTool(player, tool)
				end
			end
		end
	end
end

-- The client asks; the server decides. Ownership is re-checked here rather than trusted from the
-- caller, so a forged request naming a Vip palette from a player without the pass is refused.
ReplicatedStorage.Cosmetics.Remotes.EquipSkinRequest.OnServerEvent:Connect(
	function(player: Player, weaponName: unknown, paletteKey: unknown)
		if typeof(weaponName) ~= "string" or typeof(paletteKey) ~= "string" then
			return
		end
		if not CosmeticsService.ownsPalette(player, paletteKey) then
			return
		end
		player:SetAttribute(CosmeticsService.attributeFor(weaponName), paletteKey)
		CosmeticsService.refresh(player, weaponName)
	end
)

return CosmeticsService
