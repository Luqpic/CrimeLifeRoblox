-- WantedHud: the star meter (police and wanted, Task 4, 2026-11-17).
--
-- Five stars on a UITheme plate: one filled per whole star, the next filled by the fraction (a left-to-right
-- clip over the glyph's ink, not its whole box). While the server says WantedSeen the plate's stroke pulses red; while WantedDraining the next star to
-- go blinks. Hidden at 0 and while a full-screen panel is open (UI.Panels, like the rest of the HUD).
-- Reads only the server's player attributes WantedHeat, WantedSeen, WantedDraining.
-- Placed top centre beside the heist column (timer, duffel, getaway, toast: within 150 px of centre): to its
-- right, clear of the chat bar (top left); on a small screen (the Blaster HUD's own rule) to its left. (That
-- side was chosen when the heist cards stacked up the right edge; since 2026-11-18 they are the city's
-- bottom-right pile of at most 3, and the left spot still overlaps nothing.)
-- Overlaps no city or heist HUD at 1080 x 659 or 844 x 390 (measured; see the Task 4 report).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UITheme = require(ReplicatedStorage.SharedSystems.UITheme)
local Panels = require(ReplicatedStorage.UI.Panels)
local MAX = require(ReplicatedStorage.Wanted.Constants).MAX_HEAT
local SMALL_SCREEN = require(ReplicatedStorage.Blaster.Constants).UI_SMALL_SCREEN_THRESHOLD

local player = Players.LocalPlayer
local C = UITheme.Color

local STAR, GAP, PAD = 24, 4, 6

local gui = Instance.new("ScreenGui")
gui.Name = "WantedHud"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local scale = Instance.new("UIScale") -- its own, so UIScaleController leaves the measured size alone
scale.Parent = gui

local plate = Instance.new("Frame")
plate.Name = "Meter"
plate.Size = UDim2.fromOffset(MAX * STAR + (MAX - 1) * GAP + 2 * PAD, STAR + 2 * PAD)
plate.BackgroundColor3 = C.panel
plate.BackgroundTransparency = 0.15
plate.Visible = false
plate.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = plate
local stroke = Instance.new("UIStroke")
stroke.Color = C.line
stroke.Parent = plate

local function glyph(name: string, color: Color3, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(STAR, STAR)
	label.FontFace = UITheme.Font.Display
	label.Text = "\u{2605}" -- black star
	label.TextSize = STAR
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local clips, fills = {}, {}
for i = 1, MAX do
	local slot = Instance.new("Frame")
	slot.Name = "Star" .. i
	slot.BackgroundTransparency = 1
	slot.Position = UDim2.fromOffset(PAD + (i - 1) * (STAR + GAP), PAD)
	slot.Size = UDim2.fromOffset(STAR, STAR)
	slot.Parent = plate
	glyph("Empty", C.muted, slot).TextTransparency = 0.55
	local clip = Instance.new("Frame")
	clip.Name = "Clip"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Size = UDim2.fromScale(0, 1)
	clip.Parent = slot
	clips[i] = clip
	fills[i] = glyph("Fill", C.gold, clip)
end

local pulse = TweenService:Create(stroke,
	TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Transparency = 0, Thickness = 2.5 })
local pulsing = false
local function setPulse(on: boolean)
	if on == pulsing then return end
	pulsing = on
	pulse:Cancel()
	if on then
		stroke.Color, stroke.Transparency, stroke.Thickness = C.danger, 0.8, 1
		pulse:Play()
	else
		stroke.Color, stroke.Transparency, stroke.Thickness = C.line, 0, 1
	end
end

local blinking: TextLabel? = nil
local blink: Tween? = nil
local function setBlink(target: TextLabel?)
	if target == blinking then return end
	if blink then blink:Cancel() end
	if blinking then blinking.TextTransparency = 0 end
	blinking, blink = target, nil
	if target then
		blink = TweenService:Create(target,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ TextTransparency = 0.85 })
		blink:Play()
	end
end

-- Clip width for a fraction of one star. The glyph's ink (TextBounds, centred) is narrower than its box, so
-- the fraction is laid over the ink: 0.25 shows a quarter of the star. Before the font measures, the box.
local function clipWidth(fraction: number): number
	if fraction <= 0 then return 0 end
	if fraction >= 1 then return STAR end
	local ink = fills[1].TextBounds.X
	if ink <= 0 or ink > STAR then ink = STAR end
	return math.round((STAR - ink) / 2 + fraction * ink) -- an Offset truncates; round instead
end

local panelOpen = false
local function render()
	local heat = math.clamp(tonumber(player:GetAttribute("WantedHeat")) or 0, 0, MAX)
	local shown = heat > 0 and not panelOpen
	plate.Visible = shown
	for i = 1, MAX do
		clips[i].Size = UDim2.new(0, clipWidth(heat - (i - 1)), 1, 0)
	end
	-- The next star to go is the highest lit one (whole or partial): a drain step drops to the integer below.
	setBlink(if shown and player:GetAttribute("WantedDraining") == true then fills[math.ceil(heat)] else nil)
	setPulse(shown and player:GetAttribute("WantedSeen") == true)
end
fills[1]:GetPropertyChangedSignal("TextBounds"):Connect(render)

-- The camera can be nil this early and can be replaced later: follow workspace.CurrentCamera.
local function place()
	local camera = workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize
	local left = viewport ~= nil and math.min(viewport.X, viewport.Y) < SMALL_SCREEN
	plate.AnchorPoint = Vector2.new(if left then 1 else 0, 0)
	plate.Position = UDim2.new(0.5, if left then -160 else 160, 0, 6)
end
local viewportConn: RBXScriptConnection? = nil
local function bindCamera()
	if viewportConn then viewportConn:Disconnect() end
	local camera = workspace.CurrentCamera
	viewportConn = if camera then camera:GetPropertyChangedSignal("ViewportSize"):Connect(place) else nil
	place()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
bindCamera()

for _, name in { "WantedHeat", "WantedSeen", "WantedDraining" } do
	player:GetAttributeChangedSignal(name):Connect(render)
end
Panels.onChanged(function(name: string?) -- fires once now, then on every open and close
	panelOpen = name ~= nil
	render()
end)
render()
gui.Parent = player:WaitForChild("PlayerGui")
