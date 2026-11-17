--!strict
-- Heist layers 2026-11-17 (Task 6): carrier-only ledges (tag "CarrierLedge") are invisible on the
-- server and only collide with the "Carrier" collision group. While the local character carries a
-- slowed load (attribute CarrySpeedCap), show them locally with their authored transparency
-- (attribute CarrierTransparency on each part/texture).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local SPEED_CAP_ATTRIBUTE = require(game:GetService("ReplicatedStorage").Movement.Constants).CARRY_SPEED_CAP_ATTRIBUTE

local player = Players.LocalPlayer
local shown = false

local function paint(ledge: Instance)
	for _, d in ipairs(ledge:GetDescendants()) do
		local visible = d:GetAttribute("CarrierTransparency")
		if type(visible) == "number" and (d:IsA("BasePart") or d:IsA("Texture") or d:IsA("Decal")) then
			(d :: any).Transparency = if shown then visible else 1
		end
	end
end

local function refresh()
	local character = player.Character
	shown = character ~= nil and character:GetAttribute(SPEED_CAP_ATTRIBUTE) ~= nil
	for _, ledge in ipairs(CollectionService:GetTagged("CarrierLedge")) do paint(ledge) end
end

local attributeConn
local function watch(character: Model)
	if attributeConn then attributeConn:Disconnect() end
	attributeConn = character:GetAttributeChangedSignal(SPEED_CAP_ATTRIBUTE):Connect(refresh)
	refresh()
end

CollectionService:GetInstanceAddedSignal("CarrierLedge"):Connect(paint) -- streamed in later
if player.Character then watch(player.Character) end
player.CharacterAdded:Connect(watch)
