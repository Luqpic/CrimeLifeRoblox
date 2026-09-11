# Prompt: GUI Templates (Clone, Not Instance.new), Cash Pickup Sound, Static Leveling Bar

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Context, confirmed live before writing this — read this first

Every script touched below (`StaminaHud`, `LevelingHud`, `WeaponStatBillboard`, `DamageDirectionIndicator`, `CashService`) was re-read directly from the live game, not from memory, so this is a faithful conversion of what actually exists today, not a redesign.

**The architecture change:** these four HUD scripts currently build their entire visual tree with `Instance.new(...)` at runtime. Going forward, each one's visual shell is a pre-built template Instance living under a new `ReplicatedStorage.GuiTemplates` folder, which the script `:Clone()`s at runtime instead of constructing. This means the look of any of these HUDs (colors, sizes, fonts, positions) can be edited directly in Studio's Explorer/property panel from now on, without touching a script. Only content that is inherently per-instance (a `BillboardGui`'s per-pickup `Adornee`, a damage-direction arrow's per-hit rotation, live stat text) still comes from script.

This does **not** apply to `StarterGui."Custom Inventory"` — that GUI is already a static, hand-built Studio object (not `Instance.new`-generated), which is exactly the end state this prompt is moving the other four toward.

**Two unrelated small fixes bundled in because they touch the same files:**
- The `LevelingBar` no longer fades in/out on XP gain — it was easy to miss appearing only briefly after a kill. It is now static/always-visible, like the hotbar it sits above. Only the separate level-up popup still fades in/out (that part is intentional — it is a one-off celebration, not a persistent readout).
- Cash drop pickups currently play no sound at all on collection — confirmed by reading `ServerStorage.Cash`'s live children (`Smooth Block Model`, `Part`, `Highlight` — no `Sound`) and `CashService`'s `prompt.Triggered` handler (no sound anywhere in it). This adds one.

**Measured, not guessed, placement:** `StarterGui."Custom Inventory".hotBar` is live-inspected at `AnchorPoint (0.5, 1)`, `Position ({0.5,0},{0.99,-5})`, `Size ({0.3,0},{0.05,20})` — its top edge sits at scale `0.94`, offset `-25`. The `LevelingBar` template below is positioned at `(0.5, 0, 0.94, -35)` with `AnchorPoint (0.5, 1)`, putting its bottom edge 10px above the hotbar's top edge. Still worth a visual check (screen resolutions vary), but this is a measured starting point, not a blind one.

---

## Part 1 — Build the template tree (one-time setup)

Run this **once** — paste into the Studio Command Bar and execute, or drop it into a temporary `Script` and delete the script after running. It is not meant to run on every server start; only needs to run once per place (or again if `ReplicatedStorage.GuiTemplates` is ever wiped). Afterward, everything below is a normal Instance tree sitting in `ReplicatedStorage` — open it in Explorer and edit freely.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MovementConstants = require(ReplicatedStorage.Movement.Constants)

local templates = ReplicatedStorage:FindFirstChild("GuiTemplates")
if not templates then
	templates = Instance.new("Folder")
	templates.Name = "GuiTemplates"
	templates.Parent = ReplicatedStorage
end

-- ============================================
-- StaminaBar
-- ============================================
do
	local bar = Instance.new("CanvasGroup")
	bar.Name = "StaminaBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, MovementConstants.HUD_TOP_OFFSET)
	bar.Size = UDim2.fromOffset(MovementConstants.HUD_WIDTH, MovementConstants.HUD_HEIGHT)
	bar.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	bar.BackgroundTransparency = MovementConstants.HUD_BACKGROUND_TRANSPARENCY
	bar.BorderSizePixel = 0
	bar.GroupTransparency = 1 -- starts hidden; StaminaHud fades it in/out as before

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = MovementConstants.HUD_FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	fillCorner.Parent = fill

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = bar

	bar.Parent = templates
end

-- ============================================
-- LevelingBar -- static/always-visible now, so GroupTransparency is baked to 0, not 1
-- ============================================
do
	local bar = Instance.new("CanvasGroup")
	bar.Name = "LevelingBar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 0.94, -35) -- just above hotBar's top edge; verify, nudge if needed
	bar.Size = UDim2.fromOffset(260, 14)
	bar.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	bar.BackgroundTransparency = MovementConstants.HUD_BACKGROUND_TRANSPARENCY
	bar.BorderSizePixel = 0
	bar.GroupTransparency = 0

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	barCorner.Parent = bar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 0.5)
	fill.Position = UDim2.fromScale(0, 0.5)
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = MovementConstants.HUD_FILL_COLOR
	fill.BorderSizePixel = 0
	fill.Parent = bar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	fillCorner.Parent = fill

	local levelLabel = Instance.new("TextLabel")
	levelLabel.Name = "LevelLabel"
	levelLabel.BackgroundTransparency = 1
	levelLabel.Size = UDim2.fromScale(1, 1)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.TextScaled = true
	levelLabel.TextColor3 = Color3.new(1, 1, 1)
	levelLabel.Text = "Lv. 1"
	levelLabel.Parent = bar

	bar.Parent = templates
end

-- ============================================
-- LevelUpPopup -- unchanged behaviour, still a transient celebration
-- ============================================
do
	local popup = Instance.new("Frame")
	popup.Name = "LevelUpPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.35)
	popup.Size = UDim2.fromOffset(360, 90)
	popup.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
	popup.BackgroundTransparency = 1
	popup.BorderSizePixel = 0

	local popupCorner = Instance.new("UICorner")
	popupCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
	popupCorner.Parent = popup

	local popupLabel = Instance.new("TextLabel")
	popupLabel.Name = "Label"
	popupLabel.BackgroundTransparency = 1
	popupLabel.Size = UDim2.fromScale(1, 1)
	popupLabel.Font = Enum.Font.GothamBold
	popupLabel.TextScaled = true
	popupLabel.TextColor3 = Color3.new(1, 1, 1)
	popupLabel.TextTransparency = 1
	popupLabel.Text = ""
	popupLabel.Parent = popup

	local levelUpSound = Instance.new("Sound")
	levelUpSound.Name = "LevelUpSound"
	-- SoundId left blank here on purpose -- LevelingHud sets it from Leveling.Constants at runtime,
	-- so that module stays the single source of truth instead of duplicating the id into the template.
	levelUpSound.Parent = popup

	popup.Parent = templates
end

-- ============================================
-- WeaponStatPanel -- the Panel's contents only. The BillboardGui wrapper and its per-pickup
-- Adornee are inherently per-instance and still come from script.
--
-- LAYOUT NOTE (carried over from the original script): every internal size here is a SCALE
-- fraction, never a pixel offset. A BillboardGui has its own internal pixel resolution that is
-- unreadable until it is actually on screen, so pixel children cannot be reconciled with the stud
-- height reliably. Scale fractions that sum to 1 sidestep that entirely.
-- ============================================
do
	local PANEL_COLOR = Color3.fromRGB(20, 20, 24)
	local DAMAGE_COLOR = Color3.fromRGB(120, 90, 230)
	local AMMO_COLOR = Color3.fromRGB(90, 200, 100)
	local FIRE_RATE_COLOR = Color3.fromRGB(230, 165, 60)
	local PAD_Y, PAD_X, GAP = 0.05, 0.021, 0.03
	local HEADER_H, ROW_H, BUTTON_H = 0.233, 0.131, 0.152

	-- Row instance names are collapsed to one word (FireRate, not "Fire Rate") so the consuming
	-- script can index them without bracket syntax. Label text ("Fire Rate") is unaffected.
	local function buildStatRow(instanceName: string, labelText: string, color: Color3, layoutOrder: number): Frame
		local row = Instance.new("Frame")
		row.Name = instanceName
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(1, 0, ROW_H, 0)
		row.BackgroundColor3 = color
		row.BackgroundTransparency = 0.15

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = row

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.03, 0)
		label.Size = UDim2.fromScale(0.44, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = labelText
		label.Parent = row

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.BackgroundTransparency = 1
		value.Position = UDim2.fromScale(0.47, 0)
		value.Size = UDim2.fromScale(0.5, 1)
		value.Font = Enum.Font.GothamBold
		value.TextScaled = true
		value.TextColor3 = Color3.new(1, 1, 1)
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.Parent = row

		return row
	end

	local panel = Instance.new("Frame")
	panel.Name = "WeaponStatPanel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.1

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0.08, 0)
	panelCorner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(PAD_Y, 0)
	padding.PaddingBottom = UDim.new(PAD_Y, 0)
	padding.PaddingLeft = UDim.new(PAD_X, 0)
	padding.PaddingRight = UDim.new(PAD_X, 0)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(GAP, 0)
	layout.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, HEADER_H, 0)
	header.LayoutOrder = 1
	header.Parent = panel

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.fromScale(0.103, 1)
	icon.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	icon.Image = ""
	icon.Parent = header

	local iconAspect = Instance.new("UIAspectRatioConstraint")
	iconAspect.AspectRatio = 1
	iconAspect.DominantAxis = Enum.DominantAxis.Height
	iconAspect.Parent = icon

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.15, 0)
	iconCorner.Parent = icon

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "WeaponName"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0.13, 0)
	nameLabel.Size = UDim2.fromScale(0.87, 1)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = ""
	nameLabel.Parent = header

	buildStatRow("Damage", "Damage", DAMAGE_COLOR, 2).Parent = panel
	buildStatRow("Ammo", "Ammo", AMMO_COLOR, 3).Parent = panel
	buildStatRow("FireRate", "Fire Rate", FIRE_RATE_COLOR, 4).Parent = panel

	local upgradeButton = Instance.new("TextButton")
	upgradeButton.Name = "UpgradeButton"
	upgradeButton.Size = UDim2.new(1, 0, BUTTON_H, 0)
	upgradeButton.LayoutOrder = 5
	upgradeButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	upgradeButton.Font = Enum.Font.GothamBold
	upgradeButton.TextScaled = true
	upgradeButton.TextColor3 = Color3.new(1, 1, 1)
	upgradeButton.Text = ""
	upgradeButton.Parent = panel

	local upgradeCorner = Instance.new("UICorner")
	upgradeCorner.CornerRadius = UDim.new(0.3, 0)
	upgradeCorner.Parent = upgradeButton

	panel.Parent = templates
end

-- ============================================
-- DamageArrow -- single reusable template, cloned once per hit
-- ============================================
do
	local indicator = Instance.new("TextLabel")
	indicator.Name = "DamageArrow"
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.BackgroundTransparency = 1
	indicator.Size = UDim2.fromOffset(40, 40)
	indicator.Font = Enum.Font.GothamBold
	indicator.TextScaled = true
	indicator.TextColor3 = Color3.fromRGB(255, 60, 60)
	indicator.Text = "\u{25B2}"
	indicator.Parent = templates
end

print("GuiTemplates built:", templates:GetChildren())
```

### Verify
- `ReplicatedStorage.GuiTemplates` now contains `StaminaBar`, `LevelingBar`, `LevelUpPopup`, `WeaponStatPanel`, `DamageArrow`.
- Re-running the script a second time does not duplicate anything (the `FindFirstChild` guard at the top only guards the folder itself — each `do...end` block below it always creates a fresh copy on every run, so **only run this once**; if you do need to re-run it, delete the old children first).

---

## Part 2 — `StaminaHud`: clone instead of construct

Replace the `-- GUI` section of `StarterPlayer.StarterPlayerScripts.StaminaHud` (everything from `local gui = Instance.new("ScreenGui")` through `uiScale.Parent = bar`) with:
```lua
local gui = Instance.new("ScreenGui")
gui.Name = "StaminaGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local bar = guiTemplates:WaitForChild("StaminaBar"):Clone()
bar.Parent = gui

local fill = bar:WaitForChild("Fill")
local uiScale = bar:WaitForChild("UIScale")

gui.Parent = playerGui
```
Everything else in the script (state, character binding, predict/reconcile/render, `updateScale`, the `RenderStepped` connection) is unchanged — it only ever referenced `bar`, `fill`, and `uiScale` by variable, never rebuilt them, so nothing downstream needs to change.

### Verify
- Sprinting still shows the stamina bar fading in at the top-centre, draining and regenerating exactly as before; locked-out coloring still works.
- Visually identical to before this change (this is a pure refactor, not a visual change).

---

## Part 3 — `LevelingHud`: clone instead of construct, bar is now static

Replace the entire script with:
```lua
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

-- ============================================
-- LEVEL-UP POPUP (still transient)
-- ============================================
local popup = guiTemplates:WaitForChild("LevelUpPopup"):Clone()
popup.Parent = gui

local popupLabel = popup:WaitForChild("Label")
local levelUpSound = popup:WaitForChild("LevelUpSound")
levelUpSound.SoundId = LevelingConstants.LEVEL_UP_SOUND_ID

gui.Parent = playerGui

-- ============================================
-- STATE
-- ============================================
local popupHideThread: thread? = nil
local lastKnownLevel: number? = nil

local function showLevelUpPopup(level: number)
	popupLabel.Text = `LEVEL UP! Lv. {level}`
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
	end)
end

-- ============================================
-- WIRING
-- ============================================
local function refreshBarValues()
	local xp = (player:GetAttribute("XP") :: number?) or 0
	local nextLevelXp = (player:GetAttribute("NextLevelXP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	levelLabel.Text = `Lv. {level}`
	local fraction = if nextLevelXp > 0 then math.clamp(xp / nextLevelXp, 0, 1) else 1
	fill.Size = UDim2.fromScale(fraction, 1)
end

local function onLevelChanged()
	local level = (player:GetAttribute("Level") :: number?) or 1
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
```

### Verify
- The XP bar is visible immediately on join and stays visible permanently — it no longer fades out after a couple of seconds of no XP change.
- It sits just above the hotbar with no overlap; nudge the `LevelingBar` template's `Position` in Part 1 if there is any on your screen.
- Kill something: the fill/level number update live on the always-visible bar; the level-up popup still fades in, holds, and fades out separately, with sound, exactly as before.

---

## Part 4 — `WeaponStatBillboard`: clone the panel instead of constructing it

Replace the whole script with:
```lua
-- Floating stat panel above each weapon pickup: name, damage (including this player's own upgrade
-- level), ammo, fire rate, a placeholder icon, and an upgrade button. The panel's visual shell is
-- cloned from ReplicatedStorage.GuiTemplates.WeaponStatPanel; only the BillboardGui wrapper (which
-- needs a per-pickup Adornee) is still built in script.
--
-- Stats are read from Attributes that WeaponPickup mirrors onto the pickup Model, because
-- ServerStorage never replicates to clients -- a LocalScript cannot read them off the Tool itself.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local builtFor: { [Instance]: BillboardGui } = {}

local weaponsFolder = ReplicatedStorage:WaitForChild("Weapons")
local upgradeRequest = weaponsFolder:WaitForChild("Remotes"):WaitForChild("UpgradeRequest")
local UpgradeConfig = require(weaponsFolder:WaitForChild("UpgradeConfig"))
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local PICKUP_TAG = "WeaponPickup"

local PANEL_SHOW_DISTANCE = 10
local PANEL_POLL_INTERVAL = 0.15
local PANEL_MAX_DISTANCE = 200

local BILLBOARD_SIZE = UDim2.new(5.625, 0, 2.375, 0)

local function buildBillboard(pickup: Model)
	if builtFor[pickup] then
		return
	end

	local weaponValue = pickup:WaitForChild("Weapon", 30)
	if not (weaponValue and weaponValue:IsA("StringValue")) then
		warn(`WeaponStatBillboard: {pickup:GetFullName()} has no Weapon StringValue`)
		return
	end
	local weaponName = weaponValue.Value

	local adornee = pickup.PrimaryPart
	if not adornee then
		local deadline = os.clock() + 30
		repeat
			task.wait(0.1)
			adornee = pickup.PrimaryPart
		until adornee or os.clock() > deadline
	end
	if not adornee then
		warn(`WeaponStatBillboard: {pickup:GetFullName()} has no PrimaryPart to adorn`)
		return
	end

	if builtFor[pickup] then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = `StatPanel_{pickup.Name}`
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.MaxDistance = PANEL_MAX_DISTANCE
	billboard.Enabled = false
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Active = true
	billboard.Adornee = adornee
	billboard.ResetOnSpawn = false
	billboard.Parent = playerGui
	builtFor[pickup] = billboard

	pickup.Destroying:Connect(function()
		builtFor[pickup] = nil
		billboard:Destroy()
	end)

	local panel = guiTemplates:WaitForChild("WeaponStatPanel"):Clone()
	panel.Parent = billboard

	local header = panel:WaitForChild("Header")
	local nameLabel = header:WaitForChild("WeaponName")
	local damageValue = panel:WaitForChild("Damage"):WaitForChild("Value")
	local ammoValue = panel:WaitForChild("Ammo"):WaitForChild("Value")
	local fireRateValue = panel:WaitForChild("FireRate"):WaitForChild("Value")
	local upgradeButton = panel:WaitForChild("UpgradeButton") :: TextButton

	nameLabel.Text = weaponName

	local attributeName = UpgradeConfig.attributeFor(weaponName)

	local function refresh()
		local stockDamage = pickup:GetAttribute("damage") or 0
		local level = player:GetAttribute(attributeName) or 0
		local rateOfFire = pickup:GetAttribute("rateOfFire") or 0
		local magazineSize = pickup:GetAttribute("magazineSize") or 0

		if level > 0 then
			damageValue.Text = `{stockDamage + level} (+{level})`
		else
			damageValue.Text = tostring(stockDamage)
		end
		ammoValue.Text = tostring(magazineSize)
		fireRateValue.Text = `{rateOfFire} RPM`

		local nextLevel = level + 1
		upgradeButton.Text = `Upgrade Damage (Lv.{nextLevel}) - ${UpgradeConfig.COST_PER_LEVEL * nextLevel}`
	end

	refresh()
	pickup:GetAttributeChangedSignal("damage"):Connect(refresh)
	player:GetAttributeChangedSignal(attributeName):Connect(refresh)

	upgradeButton.MouseButton1Click:Connect(function()
		upgradeRequest:FireServer(weaponName)
	end)
end

for _, pickup in CollectionService:GetTagged(PICKUP_TAG) do
	task.spawn(buildBillboard, pickup)
end
CollectionService:GetInstanceAddedSignal(PICKUP_TAG):Connect(function(pickup)
	task.spawn(buildBillboard, pickup)
end)

-- Show only the nearest station's panel, and gate that station's Equip prompt to the same choice
-- (unchanged from before -- see the original script's comments for why both halves must be one
-- decision).
task.spawn(function()
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")

		local nearest: BillboardGui? = nil
		local nearestDistance = math.huge
		if root then
			for _, billboard in builtFor do
				local adornee = billboard.Adornee
				if adornee then
					local distance = (adornee.Position - root.Position).Magnitude
					if distance < nearestDistance then
						nearest, nearestDistance = billboard, distance
					end
				end
			end
		end

		local shouldShow = nearest ~= nil and nearestDistance <= PANEL_SHOW_DISTANCE
		for pickup, billboard in builtFor do
			local isNearest = shouldShow and billboard == nearest
			billboard.Enabled = isNearest

			local prompt = pickup:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Enabled = isNearest
			end
		end

		task.wait(PANEL_POLL_INTERVAL)
	end
end)
```
Note the `createStatRow` helper and all the `PANEL_COLOR`/`PAD_Y`/etc. layout constants are gone — they now live only in the Part 1 template, not duplicated here.

### Verify
- Approach any weapon pickup: the panel appears identically to before (name, damage with upgrade bonus, ammo, fire rate, upgrade button), visually unchanged.
- Click the upgrade button: still fires `UpgradeRequest` and the damage value still updates live.
- Only the nearest station's panel/prompt is enabled at a time, same as before.

---

## Part 5 — `DamageDirectionIndicator`: clone the arrow instead of constructing it

Replace the whole script with:
```lua
-- Screen-edge arrow pointing toward whatever just damaged you, fading out after a moment. Cloned
-- per-hit from ReplicatedStorage.GuiTemplates.DamageArrow instead of built with Instance.new.
--
-- BEARING MATH. Both the camera's look direction and the direction to the attacker are flattened
-- onto the horizontal plane, then atan2(cross.Y, dot) gives a signed angle where 0 is dead ahead,
-- positive is clockwise (right) and +/-180 is directly behind. The cross product must be
-- toAttacker:Cross(lookVector), in that order. Checked by hand rather than from memory: with the
-- Roblox default forward look (0,0,-1), camera-right is look x up = (1,0,0); an attacker at
-- (1,0,0) then gives cross = A x L = (0,1,0), so cross.Y = +1 and dot = 0, so angle = +90 deg.
-- Positive therefore means "to the right". Reversing the operands mirrors every indicator.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local damageDirectionRemote = ReplicatedStorage:WaitForChild("Blaster")
	:WaitForChild("Remotes")
	:WaitForChild("DamageDirection")
local damageArrowTemplate = ReplicatedStorage:WaitForChild("GuiTemplates"):WaitForChild("DamageArrow")

local RADIUS = 150
local HOLD_TIME = 0.15
local FADE_TIME = 1.2

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DamageDirectionIndicator"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function showIndicator(attackerPosition: Vector3)
	local cameraPosition = camera.CFrame.Position
	local toAttacker = attackerPosition - cameraPosition
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 1e-3 then
		return
	end
	toAttacker = toAttacker.Unit

	local lookVector = camera.CFrame.LookVector
	lookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	if lookVector.Magnitude < 1e-3 then
		return
	end
	lookVector = lookVector.Unit

	local dot = math.clamp(lookVector:Dot(toAttacker), -1, 1)
	local cross = toAttacker:Cross(lookVector)
	local angle = math.atan2(cross.Y, dot)

	local indicator = damageArrowTemplate:Clone()
	indicator.Rotation = math.deg(angle)
	indicator.Position = UDim2.new(
		0.5, math.sin(angle) * RADIUS,
		0.5, -math.cos(angle) * RADIUS
	)
	indicator.Parent = screenGui

	task.wait(HOLD_TIME)
	if not indicator.Parent then
		return
	end
	local tween = TweenService:Create(
		indicator,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	indicator:Destroy()
end

damageDirectionRemote.OnClientEvent:Connect(function(attackerPosition: Vector3)
	task.spawn(showIndicator, attackerPosition)
end)
```

### Verify
- Take damage from each of the four cardinal directions: arrows still appear at the correct screen position/rotation, identical to before.
- Multiple simultaneous hits still show multiple independent arrows, each fading on its own.

---

## Part 6 — Cash pickup sound

**`ServerScriptService.Weapons.Scripts.CashService`** — add a constant near the other placeholders:
```lua
local COLLECT_SOUND_ID = "rbxassetid://127722178646940"
local COLLECT_SOUND_LINGER = 2 -- seconds the sound is allowed to keep playing after the model is gone
```

Add a small helper (near `implode`):
```lua
-- Plays independently of the cash model's own lifetime: the model is destroyed by `implode` well
-- before a short pickup sound would finish, and a Sound parented to a part that gets Destroyed is
-- cut off immediately regardless of its own Debris timer. Anchoring it to a short-lived throwaway
-- part avoids that.
local function playPickupSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "CashPickupSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = COLLECT_SOUND_ID
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, COLLECT_SOUND_LINGER)
end
```

In `spawnCashDrop`'s `prompt.Triggered` handler, call it right before `implode`:
```lua
	local collected = false
	prompt.Triggered:Connect(function(player: Player)
		if collected then
			return
		end
		local leaderstats = player:FindFirstChild("leaderstats")
		local cash = leaderstats and leaderstats:FindFirstChild("Cash")
		if not cash then
			return
		end
		collected = true
		cash.Value += value
		playPickupSound(cashModel.PrimaryPart.Position)
		implode(cashModel)
	end)
```

### Verify
- Collect a cash drop: `rbxassetid://127722178646940` is audibly heard in full, not cut off by the model's ~0.4s implode/despawn.
- The despawn-without-collection path (leaving a drop untouched for 10s) still does **not** play this sound — it's only wired into the `Triggered` handler, not the despawn `task.delay`.
- No leftover invisible anchor parts lingering in `Workspace` after the sound finishes (`Debris:AddItem` cleans it up).

## Verification checklist

- [ ] `ReplicatedStorage.GuiTemplates` exists with all five templates, built exactly once.
- [ ] `StaminaHud`, `LevelingHud`, `WeaponStatBillboard`, `DamageDirectionIndicator` all clone their visuals from templates; none of them call `Instance.new` to build their static visual shell anymore (per-instance content like the BillboardGui wrapper and per-hit arrow rotation still legitimately does).
- [ ] Editing a template's color/size/position directly in Studio Explorer visibly changes the corresponding HUD next Play-mode run, with no script edit.
- [ ] LevelingBar is always visible, never fades, sits just above the hotbar with no overlap.
- [ ] Level-up popup behavior (fade in/hold/fade out + sound) is unchanged.
- [ ] Cash pickup now plays `rbxassetid://127722178646940` in full on collection; despawn-without-pickup stays silent.
- [ ] All four converted HUDs are visually and functionally identical to before, aside from the LevelingBar's static-visibility change.
