-- Leveling HUD: a persistent, ALWAYS-VISIBLE XP progress bar positioned just above the hotbar
-- (ReplicatedStorage.GuiTemplates.LevelingBar), plus a separate, transient level-up popup + sound
-- (ReplicatedStorage.GuiTemplates.LevelUpPopup). The bar no longer fades in/out on XP change -- it
-- was easy to miss appearing only briefly after a kill, so it now stays on screen like the hotbar
-- itself. Only the level-up popup still fades in/out; that is a one-off celebration, not a readout.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LevelingConstants = require(ReplicatedStorage:WaitForChild("Leveling"):WaitForChild("Constants"))
local MovementConstants = require(ReplicatedStorage.Movement.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local POPUP_HOLD_TIME = 1.5
local POPUP_FADE_TIME = 0.5

local gui = Instance.new("ScreenGui")
gui.Name = "LevelingGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

-- ============================================
-- XP BAR (static -- always visible, no fade)
-- ============================================
local bar = guiTemplates:WaitForChild("LevelingBar"):Clone()
bar.Parent = gui

local fill = bar:WaitForChild("Fill")
local levelLabel = bar:WaitForChild("LevelLabel")

-- Experience icon inside the bar's left end, white like the level text: a fill-coloured icon vanished
-- into the fill as soon as the bar filled past it. Sized from the bar's height (80%) so it fits whatever
-- the template's height is, and drawn above the fill.
local BAR_ICON_INSET = 4
local barIcon = Instance.new("ImageLabel")
barIcon.Name = "XpIcon"
barIcon.BackgroundTransparency = 1
barIcon.Image = LevelingConstants.XP_ICON_ID
barIcon.ImageColor3 = Color3.new(1, 1, 1)
barIcon.ScaleType = Enum.ScaleType.Fit
barIcon.AnchorPoint = Vector2.new(0, 0.5)
barIcon.SizeConstraint = Enum.SizeConstraint.RelativeYY
barIcon.Size = UDim2.fromScale(0.8, 0.8)
barIcon.Position = UDim2.new(0, BAR_ICON_INSET, 0.5, 0)
barIcon.ZIndex = math.max(fill.ZIndex, levelLabel.ZIndex) + 1
barIcon.Parent = bar

-- ============================================
-- LEVEL-UP POPUP (still transient)
-- ============================================
local popup = guiTemplates:WaitForChild("LevelUpPopup"):Clone()
popup.Parent = gui

local popupLabel = popup:WaitForChild("Label")
local levelUpSound = popup:WaitForChild("LevelUpSound")
-- The redesign gave the popup an accent outline. A UIStroke has its own Transparency, which the
-- frame's BackgroundTransparency tween does NOT drive -- left alone it stays fully opaque and the
-- popup reads as a permanently visible empty box on screen between level-ups.
local popupStroke = popup:FindFirstChildOfClass("UIStroke")
-- The Figma popup splits its text: a muted "LEVEL UP" caption over the level line. The caption has
-- its own TextTransparency, which none of the tweens below drove -- so like the UIStroke above it,
-- it sat on screen permanently and the popup read as a box with a caption and nothing in it.
local popupCaption = popup:FindFirstChild("Caption")

-- Experience icon beside the level line. The label is centred text, so the icon cannot sit at a fixed
-- offset from it; both go into a centred horizontal row where the label sizes to its text, which keeps
-- the pair centred for "LEVEL 2" and "LEVEL 70" alike.
local POPUP_ICON_SIZE = 28
local popupRow = Instance.new("Frame")
popupRow.Name = "LevelRow"
popupRow.BackgroundTransparency = 1
popupRow.Position = popupLabel.Position
popupRow.Size = popupLabel.Size
popupRow.Parent = popup
local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Padding = UDim.new(0, 8)
rowLayout.Parent = popupRow
local popupIcon = Instance.new("ImageLabel")
popupIcon.Name = "XpIcon"
popupIcon.BackgroundTransparency = 1
popupIcon.Image = LevelingConstants.XP_ICON_ID
popupIcon.ImageColor3 = popupLabel.TextColor3
popupIcon.ScaleType = Enum.ScaleType.Fit
popupIcon.Size = UDim2.fromOffset(POPUP_ICON_SIZE, POPUP_ICON_SIZE)
popupIcon.LayoutOrder = 0
popupIcon.Parent = popupRow
popupLabel.AutomaticSize = Enum.AutomaticSize.X
popupLabel.Size = UDim2.new(0, 0, 1, 0)
popupLabel.Position = UDim2.new()
popupLabel.LayoutOrder = 1
popupLabel.Parent = popupRow

-- Force the whole popup hidden at startup rather than trusting the template to ship that way. Every
-- piece has its OWN transparency and none of them follow the frame's, so a template edit that sets
-- any one of them visible parks the popup on screen until the first level-up. That has now happened
-- twice; asserting the rest state here makes the template's values irrelevant.
popup.BackgroundTransparency = 1
popupLabel.TextTransparency = 1
popupIcon.ImageTransparency = 1
if popupCaption then
	popupCaption.TextTransparency = 1
end
if popupStroke then
	popupStroke.Transparency = 1
end
-- Set here rather than baked into the template so Leveling.Constants stays the single source.
levelUpSound.SoundId = LevelingConstants.LEVEL_UP_SOUND_ID

gui.Parent = playerGui

-- ============================================
-- STATE
-- ============================================
local popupHideThread: thread? = nil
local lastKnownLevel: number? = nil

-- ============================================
-- POPUP PLACEMENT
-- ============================================
-- The template's centre at 35 % height sat on the heist column (getaway and toast on desktop;
-- duffel, getaway and card at 844 x 390). Placed from the heist widgets' LIVE boxes at show time:
-- - desktop: top on the toast's bottom edge, centred, full size;
-- - small screens (smaller side < UI_SMALL_SCREEN_THRESHOLD, as WantedHud): no 360 px hole exists, so
--   the popup shrinks to fit the gap left of the duffel and centres on the duffel vertically.
-- No heist HUD yet (HeistClient builds it at runtime): the template's place.
-- The popup's on-screen scale follows the heist HUD's own (UIScaleController gives each ScreenGui its
-- own ResponsiveScale, capped at 1), and a viewport resize while it is shown places it again
-- (2026-11-18). The city notification stack is bottom-right, away from both placements.
local SMALL_SCREEN = require(ReplicatedStorage.Blaster.Constants).UI_SMALL_SCREEN_THRESHOLD
local POPUP_GAP_MARGIN = 8
local templatePosition, templateAnchor = popup.Position, popup.AnchorPoint
local popupScale = Instance.new("UIScale")
popupScale.Parent = popup

local function findDuffel(heistHud: Instance): GuiObject?
	for _, child in heistHud:GetChildren() do
		if child:IsA("GuiObject") and string.sub(child.Name, -6) == "Duffel" then
			return child
		end
	end
	return nil
end

local function placePopup()
	local camera = workspace.CurrentCamera
	local heistHud = playerGui:FindFirstChild("HeistHUD")
	local toast = heistHud and heistHud:FindFirstChild("Toast")
	if not (camera and toast) then
		popup.AnchorPoint, popup.Position, popupScale.Scale = templateAnchor, templatePosition, 1
		return
	end
	-- AbsolutePosition is reported in one frame for every ScreenGui (inset or not), so a point in it
	-- becomes an offset in this gui by subtracting the gui's own origin and undoing its UIScale.
	local guiScale = gui:FindFirstChildOfClass("UIScale")
	local unscale = if guiScale and guiScale.Scale > 0 then 1 / guiScale.Scale else 1
	local heistScale = heistHud:FindFirstChildOfClass("UIScale")
	local fullScale = (if heistScale then heistScale.Scale else 1) * unscale -- the heist HUD's size on screen
	local origin = gui.AbsolutePosition
	local viewport = camera.ViewportSize
	local small = math.min(viewport.X, viewport.Y) < SMALL_SCREEN
	local duffel = small and findDuffel(heistHud)
	if small and not duffel then
		-- Small screen, no duffel widget: no gap to measure, the template's place.
		popup.AnchorPoint, popup.Position, popupScale.Scale = templateAnchor, templatePosition, 1
	elseif small then
		local gapWidth = duffel.AbsolutePosition.X - origin.X - 2 * POPUP_GAP_MARGIN
		popupScale.Scale = math.clamp(gapWidth * unscale / popup.Size.X.Offset, 0.1, fullScale)
		popup.AnchorPoint = Vector2.new(0, 0.5)
		popup.Position = UDim2.fromOffset(
			POPUP_GAP_MARGIN * unscale,
			(duffel.AbsolutePosition.Y + duffel.AbsoluteSize.Y / 2 - origin.Y) * unscale
		)
	else
		popupScale.Scale = fullScale
		popup.AnchorPoint = Vector2.new(0.5, 0)
		popup.Position = UDim2.new(0.5, 0, 0, (toast.AbsolutePosition.Y + toast.AbsoluteSize.Y - origin.Y) * unscale)
	end
end

-- Placed again on a viewport resize while shown (hold + fade); the camera can be nil this early and
-- can be replaced later, so follow workspace.CurrentCamera (as WantedHud does).
local popupShownUntil = 0
local viewportConn: RBXScriptConnection? = nil
local function bindCamera()
	if viewportConn then viewportConn:Disconnect() end
	local camera = workspace.CurrentCamera
	viewportConn = if camera
		then camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if os.clock() < popupShownUntil then
				placePopup()
			end
		end)
		else nil
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

local function showLevelUpPopup(level: number)
	placePopup()
	popupShownUntil = os.clock() + POPUP_HOLD_TIME + POPUP_FADE_TIME
	-- "LEVEL UP" is the caption; this line is just the level, per the Figma popup.
	popupLabel.Text = `LEVEL {level}`
	levelUpSound:Play()

	if popupHideThread then
		task.cancel(popupHideThread)
	end

	TweenService:Create(
		popup,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = MovementConstants.HUD_BACKGROUND_TRANSPARENCY }
	):Play()
	TweenService:Create(
		popupLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	):Play()
	TweenService:Create(
		popupIcon,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ ImageTransparency = 0 }
	):Play()
	if popupStroke then
		TweenService:Create(
			popupStroke,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transparency = 0 }
		):Play()
	end
	if popupCaption then
		TweenService:Create(
			popupCaption,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 0 }
		):Play()
	end

	popupHideThread = task.delay(POPUP_HOLD_TIME, function()
		TweenService:Create(
			popup,
			TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			popupLabel,
			TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		):Play()
		TweenService:Create(
			popupIcon,
			TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ ImageTransparency = 1 }
		):Play()
		if popupCaption then
			TweenService:Create(
				popupCaption,
				TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ TextTransparency = 1 }
			):Play()
		end
		if popupStroke then
			TweenService:Create(
				popupStroke,
				TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Transparency = 1 }
			):Play()
		end
	end)
end

-- ============================================
-- WIRING
-- ============================================
-- The fill animates to each new value rather than snapping. Cancel-before-replay is the same
-- pattern the level-up popup's tweens already use, so two XP gains in quick succession hand off
-- cleanly instead of fighting each other.
local FILL_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fillTween: Tween? = nil

local function refreshBarValues()
	local xp = (player:GetAttribute("XP") :: number?) or 0
	local nextLevelXp = (player:GetAttribute("NextLevelXP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	levelLabel.Text = `Lv. {level}`
	-- NextLevelXP is 0 only at the cap, where a full bar is the right "maxed" read.
	local fraction = if nextLevelXp > 0 then math.clamp(xp / nextLevelXp, 0, 1) else 1

	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(fill, FILL_TWEEN_INFO, { Size = UDim2.fromScale(fraction, 1) })
	fillTween:Play()
end

local function onLevelChanged()
	local level = (player:GetAttribute("Level") :: number?) or 1
	-- lastKnownLevel is seeded by a plain read below, before this signal is connected, so the
	-- initial attribute set on join cannot fire a false popup. A multi-level jump fires once.
	if lastKnownLevel and level > lastKnownLevel then
		showLevelUpPopup(level)
	end
	lastKnownLevel = level
	refreshBarValues()
end

refreshBarValues()
lastKnownLevel = (player:GetAttribute("Level") :: number?) or 1

player:GetAttributeChangedSignal("XP"):Connect(refreshBarValues)
player:GetAttributeChangedSignal("NextLevelXP"):Connect(refreshBarValues)
player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
