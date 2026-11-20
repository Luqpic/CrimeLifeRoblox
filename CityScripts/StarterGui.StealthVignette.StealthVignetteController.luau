-- Crouch stealth (developer, 2026-11-20): a soft dark edge round the screen while the server reports the character
-- Hidden (attribute Stealth, written by ServerScriptService.Movement.Scripts.Stealth). The edges are four black
-- frames with gradients under Vignette in this ScreenGui; this script fades their BackgroundTransparency between 1
-- (off) and SHOWN. To look at it in Edit, set the four edges' BackgroundTransparency to 0.1. (Plain frames, not a
-- CanvasGroup: a CanvasGroup's children did not draw in the Studio capture.)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local edges = script.Parent:WaitForChild("Vignette"):GetChildren()
local FADE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SHOWN = 0.1 -- each edge's BackgroundTransparency while hidden

local function show(hidden: boolean)
	for _, edge in edges do
		if edge:IsA("GuiObject") then
			TweenService:Create(edge, FADE, { BackgroundTransparency = if hidden then SHOWN else 1 }):Play()
		end
	end
end

local connection: RBXScriptConnection? = nil
local function watch(character: Model)
	if connection then
		connection:Disconnect()
	end
	show(character:GetAttribute("Stealth") == "Hidden")
	connection = character:GetAttributeChangedSignal("Stealth"):Connect(function()
		show(character:GetAttribute("Stealth") == "Hidden")
	end)
end

local player = Players.LocalPlayer
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end
