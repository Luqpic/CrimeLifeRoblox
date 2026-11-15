-- Debug level tooling for one account: a /setlevel chat command and an F2 panel. Both are thin
-- fronts on the same SetLevelRequest remote -- the only enforcement is the UserId check in
-- LevelingService, server-side. The check below merely keeps the command out of chat autocomplete
-- and the panel off screen for everyone else; it is tidiness, not security, since anyone can fire
-- the remote directly.
--
-- The panel is built here rather than added to GuiTemplates on purpose: nothing else ever clones it,
-- and a shared template would replicate an admin-only asset to every client for no benefit. The
-- tradeoff is that it does not sit alongside the other panels in GuiTemplates -- acceptable for a
-- single-instance debug tool, and it would be moved there the moment anything else needed it.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Effects = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Effects"))
local TextChatService = game:GetService("TextChatService")

local ADMIN_USER_ID = 58662576

local player = Players.LocalPlayer
if player.UserId ~= ADMIN_USER_ID then
	return
end

local LevelingConstants = require(ReplicatedStorage:WaitForChild("Leveling"):WaitForChild("Constants"))
local setLevelRequest = ReplicatedStorage.Leveling:WaitForChild("Remotes"):WaitForChild("SetLevelRequest")
local playerGui = player:WaitForChild("PlayerGui")

local GOTHAM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local PANEL_DARK = Color3.new(0, 0, 0)
local APPLY_GREEN = Color3.fromRGB(50, 200, 90)

-- ============================================
-- SHARED SUBMIT PATH
-- ============================================
-- Both the command and the panel funnel through here, so malformed input is rejected once rather
-- than in two places that could drift. The server clamps the range; this only rejects non-numbers.
local function submitLevel(text: string?): boolean
	local level = text and tonumber(text)
	if not level then
		return false
	end
	setLevelRequest:FireServer(level)
	return true
end

-- ============================================
-- CHAT COMMAND
-- ============================================
local setLevelCommand = Instance.new("TextChatCommand")
setLevelCommand.Name = "SetLevel"
setLevelCommand.PrimaryAlias = "/setlevel"
setLevelCommand.Parent = TextChatService

setLevelCommand.Triggered:Connect(function(_, unfilteredText: string)
	submitLevel(unfilteredText:match("^/setlevel%s+(%S+)$"))
end)

-- ============================================
-- PANEL
-- ============================================
local gui = Instance.new("ScreenGui")
gui.Name = "AdminLevelGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20 -- above the shop/quest panels, so it is never buried while debugging
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(300, 200)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = PANEL_DARK
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.ClipsDescendants = true
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -60, 0, 32)
title.Position = UDim2.fromOffset(16, 12)
title.BackgroundTransparency = 1
title.Text = "Admin - Set Level"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.FontFace = GOTHAM
title.Parent = panel

-- Same close X as every authored panel in this place and in Robbery System: one shared slice at
-- one size, bound through UI.Effects. Built in code here only because this panel is.
local closeButton = Instance.new("ImageButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.fromOffset(Effects.CLOSE_SIZE, Effects.CLOSE_SIZE)
closeButton.Position = UDim2.new(1, -16, 0, 16)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.BackgroundTransparency = 1
closeButton.BorderSizePixel = 0
closeButton.Image = Effects.CLOSE_IMAGE
closeButton.ScaleType = Enum.ScaleType.Fit
closeButton.Parent = panel
Effects.bindClose(closeButton)

local currentLabel = Instance.new("TextLabel")
currentLabel.Name = "CurrentLabel"
currentLabel.Size = UDim2.new(1, -32, 0, 26)
currentLabel.Position = UDim2.fromOffset(16, 52)
currentLabel.BackgroundTransparency = 1
currentLabel.Text = "Level -"
currentLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
currentLabel.TextScaled = true
currentLabel.TextXAlignment = Enum.TextXAlignment.Left
currentLabel.FontFace = GOTHAM
currentLabel.Parent = panel

local input = Instance.new("TextBox")
input.Name = "LevelInput"
input.Size = UDim2.new(1, -32, 0, 40)
input.Position = UDim2.fromOffset(16, 88)
input.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
input.BorderSizePixel = 0
input.Text = ""
input.PlaceholderText = `1 - {LevelingConstants.LEVEL_CAP}`
input.TextColor3 = Color3.new(1, 1, 1)
input.PlaceholderColor3 = Color3.fromRGB(130, 130, 138)
input.TextScaled = true
input.ClearTextOnFocus = false
input.FontFace = GOTHAM
input.Parent = panel
local inputCorner = Instance.new("UICorner")
inputCorner.CornerRadius = UDim.new(0, 6)
inputCorner.Parent = input
local inputPad = Instance.new("UIPadding")
inputPad.PaddingLeft = UDim.new(0, 10)
inputPad.PaddingTop = UDim.new(0, 6)
inputPad.PaddingBottom = UDim.new(0, 6)
inputPad.Parent = input

local applyButton = Instance.new("TextButton")
applyButton.Name = "ApplyButton"
applyButton.Size = UDim2.new(1, -32, 0, 40)
applyButton.Position = UDim2.fromOffset(16, 140)
applyButton.BackgroundColor3 = APPLY_GREEN
applyButton.BorderSizePixel = 0
applyButton.Text = "APPLY"
applyButton.TextColor3 = Color3.new(1, 1, 1)
applyButton.TextScaled = true
applyButton.FontFace = GOTHAM
applyButton.Parent = panel
local applyCorner = Instance.new("UICorner")
applyCorner.CornerRadius = UDim.new(0, 6)
applyCorner.Parent = applyButton

-- ============================================
-- BEHAVIOUR
-- ============================================
-- Reads back from the replicated Level attribute rather than echoing what was typed, so the panel
-- shows what the SERVER actually settled on -- including when it clamps 9999 down to the cap.
local function refresh()
	currentLabel.Text = `Level {tostring(player:GetAttribute("Level") or "-")} / {LevelingConstants.LEVEL_CAP}`
end

local function apply()
	if submitLevel(input.Text) then
		input.Text = ""
	end
end

applyButton.MouseButton1Click:Connect(apply)
input.FocusLost:Connect(function(enterPressed: boolean)
	if enterPressed then
		apply()
	end
end)
closeButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

player:GetAttributeChangedSignal("Level"):Connect(refresh)
refresh()

ContextActionService:BindAction("ToggleAdminLevelPanel", function(_, inputState)
	-- Ignored while the box has focus, so typing a level cannot also toggle the panel shut.
	if inputState == Enum.UserInputState.Begin and not input:IsFocused() then
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			refresh()
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F2)
