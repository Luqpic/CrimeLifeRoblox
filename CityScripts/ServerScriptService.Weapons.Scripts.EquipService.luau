-- Server-side equip/unequip on behalf of a client's inventory UI.
--
-- Why this exists: the Custom Inventory equips with a client-side Humanoid:EquipTool(), which moves
-- the Tool only in that client's own view. The server keeps it parented to the Backpack, and
-- ServerScriptService.Blaster.Scripts.Blaster.validateShot rejects any shot whose weapon is not
-- parented to the character -- so a weapon equipped that way looked equipped, animated, and dealt no
-- damage. Routing the request through the server makes the server's view authoritative, which is
-- what the rest of the shot path already assumes, instead of weakening that check.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local validateInstance = require(ServerScriptService.Utility.TypeValidation.validateInstance)

-- NOTE: this RemoteEvent must keep `Sandboxed = true`. The Custom Inventory came from a Creator
-- Store package, so its scripts run sandboxed, and a sandboxed thread may only fire a RemoteEvent
-- explicitly marked Sandboxed -- holding the RemoteEvent capability is not enough. With it false,
-- FireServer throws on the client ("the calling thread is sandboxed") and nothing arrives here,
-- which looks exactly like a dead handler.
local equipRequest = ReplicatedStorage.Weapons.Remotes.EquipRequest

equipRequest.OnServerEvent:Connect(function(player: Player, tool: any, equip: any)
	if typeof(equip) ~= "boolean" then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Unequipping is always allowed, deliberately including while dead: the inventory's own
	-- lockSlots(true) unequips on death, and refusing that would leave a corpse holding its weapon.
	if not equip then
		humanoid:UnequipTools()
		return
	end

	if humanoid.Health <= 0 then
		return
	end
	if not validateInstance(tool, "Tool") then
		return
	end

	-- The only weapon a client may ask to equip is one already sitting in its own Backpack. This is
	-- what stops the remote being a "give me any Tool in the game" call.
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or tool.Parent ~= backpack then
		return
	end

	humanoid:EquipTool(tool)
end)
