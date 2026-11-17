--!strict

-- Supplies Robbery (spec addendum, 2026-09-19): global singleton -- one
-- player, one Backpack, and carrying is meaningful regardless of which of
-- the two locations (or the Bank) the player is currently standing in.
-- Self-instantiating, same pattern as CurrencyService/GamepassManager: the
-- module itself returns the one shared instance at the bottom, so every
-- `require()` anywhere (SlowFoodsServer, Gas2GoServer, HeistServer,
-- SuppliesServer) gets the SAME table regardless of which script requires
-- it first -- no separate "owner" construction call needed anywhere.
local CarryState = {}
CarryState.__index = CarryState

-- Heavy-loot carry (heist layers 2026-11-17): an object with a numeric speedCap slows its carrier
-- through this character attribute; the movement scripts read it.
local SPEED_CAP_ATTRIBUTE = require(game:GetService("ReplicatedStorage").Movement.Constants).CARRY_SPEED_CAP_ATTRIBUTE

-- On the player's CURRENT character, if any (a fake string player in a spec has none).
local function setSpeedCap(player, value: number?)
	local character = type(player) ~= "string" and player.Character
	if character then character:SetAttribute(SPEED_CAP_ATTRIBUTE, value) end
end

function CarryState.new()
	return setmetatable({
		_carrying = {}, -- player -> {tool, supplyObject, unequipConn}
	}, CarryState)
end

function CarryState:IsCarrying(player): boolean
	return self._carrying[player] ~= nil
end

-- The carried supplyObject, or nil.
function CarryState:GetCarried(player)
	local state = self._carrying[player]
	return state and state.supplyObject
end

-- toolTemplate: Tool to clone + force-equip server-side (Humanoid:EquipTool
-- is a real, documented Roblox Humanoid method -- no script-driven tool
-- equip precedent existed anywhere in this codebase before this).
-- supplyObject: the SupplyObject instance that was just picked up, needed
-- later so Drop/Consume know which world object to reappear (or leave
-- gone). Returns false (no-op) if already carrying or there's no live
-- character/Humanoid to equip onto.
function CarryState:PickUp(player, toolTemplate: Tool, supplyObject): boolean
	if self._carrying[player] then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end

	local tool = toolTemplate:Clone()
	local backpack = player:FindFirstChildOfClass("Backpack")
	tool.Parent = backpack or character
	humanoid:EquipTool(tool)

	-- Safeguard (spec: "prevent the player from manually switching to a
	-- different Backpack tool while carrying") -- Roblox's default
	-- tool-switching would otherwise let the player swap away freely; this
	-- immediately re-forces the carry tool back the instant anything
	-- unequips it (e.g. the player selects another hotbar slot), self-healing
	-- within the same engine tick. Belt-and-braces with the explicit
	-- isBlocked gate added to RobbableObject/Safe/the weapon-trigger path --
	-- this alone would already make switching away pointless, but the gate
	-- closes the loophole even in the unlikely event event ordering ever
	-- let a different tool's own equip logic run first.
	local unequipConn
	unequipConn = tool.Unequipped:Connect(function()
		local state = self._carrying[player]
		if state and state.tool == tool then
			humanoid:EquipTool(tool)
		end
	end)

	self._carrying[player] = { tool = tool, supplyObject = supplyObject, unequipConn = unequipConn }
	if supplyObject and type(supplyObject.speedCap) == "number" then
		setSpeedCap(player, supplyObject.speedCap)
	end
	return true
end

-- Shared by voluntary Drop (GUI button) and death-while-carrying: discards
-- the Tool, reappears the ORIGINATING SupplyObject at dropCFrame.
function CarryState:Drop(player, dropCFrame: CFrame)
	local state = self._carrying[player]
	if not state then return end
	self._carrying[player] = nil
	setSpeedCap(player, nil)
	if state.unequipConn then state.unequipConn:Disconnect() end
	pcall(function() state.tool:Destroy() end)
	state.supplyObject:DropAt(dropCFrame)
end

-- Illegal Supplier cash-out: discards the Tool with NO drop-back-into-world
-- step -- the originating SupplyObject just stays hidden for the rest of
-- the session (OnSessionStart is the only thing that ever brings it back).
-- Returns false if the player wasn't actually carrying, so the caller can
-- tell the two dialog outcomes apart ("sold" vs "no supplies"). SECOND
-- return value (spec addendum, 2026-09-2X): the consumed supplyObject
-- itself, so the caller can read ITS OWN cashOutAmount instead of a flat
-- global constant -- required now that NewsStation's ExpensiveCamera
-- grants a different amount than SlowFoods/Gas2Go's supplies do. Additive:
-- every existing boolean-only caller is unaffected (Luau callers that only
-- capture the first return value simply never see the second).
function CarryState:Consume(player): (boolean, any?)
	local state = self._carrying[player]
	if not state then return false, nil end
	self._carrying[player] = nil
	setSpeedCap(player, nil)
	if state.unequipConn then state.unequipConn:Disconnect() end
	pcall(function() state.tool:Destroy() end)
	return true, state.supplyObject
end

-- PlayerRemoving cleanup, same shape as every other per-player table in
-- this system -- does NOT try to preserve/restore carried state across a
-- reconnect (matches DuffelBag's own "not persisted" precedent).
function CarryState:Forget(player)
	local state = self._carrying[player]
	if state and state.unequipConn then state.unequipConn:Disconnect() end
	if state then setSpeedCap(player, nil) end
	self._carrying[player] = nil
end

return CarryState.new()
