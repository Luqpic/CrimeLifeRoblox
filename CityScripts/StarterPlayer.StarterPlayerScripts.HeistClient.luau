--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local shared = ReplicatedStorage:WaitForChild("HeistShared")
local remotes = shared:WaitForChild("Remotes")
local UITransitions = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("UITransitions"))
local CashClaimVFX = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("CashClaimVFX"))
-- Figma-exported chrome (2026-09-18). Every panel background, ribbon, stroke,
-- shadow and STATIC label now ships as a pre-rendered slice, because the
-- design system's Archivo Black / Barlow Semi Condensed do not exist in
-- Roblox's font catalogue and Font.fromName falls back SILENTLY. Only the
-- dynamic values below are still drawn natively.
local UITheme = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("UITheme"))
-- Required here purely to read the static GamepassConfig Ids for the purchase
-- prompt below. This is the intended client-side use, NOT a violation of the
-- module header's restriction: that rule scopes to server-side robbery logic
-- (e.g. BankInstance), which must only ever see injected multiplier RESULTS so
-- it stays unit-testable without a real MarketplaceService round-trip. Purchase
-- UI has no other way to learn a real Gamepass Id. No ownership state is read
-- client-side -- only the static config table.
local GamepassManager = require(ReplicatedStorage:WaitForChild("SharedSystems"):WaitForChild("GamepassManager"))
-- Heavy carries get the getaway widget (developer decision 2026-11-18): CarryState names the carried
-- object's location in this character attribute while it is carried.
local CARRY_GETAWAY_ATTRIBUTE = require(shared:WaitForChild("Config")).CarryGetawayAttribute

-- The client re-derives the display from the same function the server uses.
-- Duplicated rather than required: Net lives in ServerScriptService, which
-- clients cannot access. Keep this identical to Net.extrapolate.
local function extrapolate(base, rate, since, now, cap)
	local elapsed = math.max(0, now - since)
	return math.min(cap, base + rate * elapsed)
end

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "HeistHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- Modal dialogs live in their OWN ScreenGui, not in HeistHUD.
-- Focus mode (UiButtonEffects) hides the ambient HUD by disabling HeistHUD while a puzzle is up.
-- The safe keypad IS a puzzle, so if it sat in HeistHUD it would hide itself. Separating them also
-- means the per-frame writes in the render loop below (dropButton.Visible, the slide transitions)
-- can never fight focus mode, because a disabled ScreenGui stops rendering regardless of what its
-- children's Visible flags say.
local modalGui = Instance.new("ScreenGui")
modalGui.Name = "HeistModals"
modalGui.ResetOnSpawn = false
modalGui.IgnoreGuiInset = true
modalGui.DisplayOrder = 5 -- above the ambient HUD
modalGui.Parent = player.PlayerGui

-- Chrome slice + one dynamic text child. Returns BOTH: the root is what
-- UITransitions slides (it is the positioned element), the text child is what
-- callers write values into. The old helper returned a single TextLabel that
-- was both at once; splitting them is what lets the background be an image.
local function imagePanel(name, key, position)
	local size = UITheme.Size[key]
	local root = Instance.new("ImageLabel")
	root.Name = name
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = position
	root.Size = UDim2.fromOffset(size.X, size.Y)
	root.BackgroundTransparency = 1
	root.Image = UITheme.Assets[key]
	root.Visible = false
	root.Parent = gui
	return root
end

-- Resting positions, kept as named locals (not just baked into label())
-- since UITransitions needs each element's own "final on-screen position"
-- to compute where it slides in from / out to.
-- The HUD strip stacks top-centre with an 8px gutter, and every element's
-- slot is derived from the one above it rather than hardcoded -- the previous
-- literals (12 / 64 / 128) were sized for the OLD 46px timer and 56px duffel,
-- so when the redesign grew them to 76 and 92 they silently overlapped each
-- other and the toast. Deriving the offsets means a future size change moves
-- everything below it automatically instead of re-introducing the same bug.
-- City (phase 3 Task 4): the city StaminaBar sits at screen y 78..88, top-centre. HUD_TOP 12 -> 2 ends
-- the timer at 78, and the duffel gap below gets +2 so the duffel starts at 88.
local HUD_TOP, HUD_GUTTER = 2, 8
local TIMER_POSITION = UDim2.new(0.5, 0, 0, HUD_TOP)
local DUFFEL_TOP = HUD_TOP + 76 + HUD_GUTTER + 2      -- below the 76px timer (+2: city StaminaBar)
local DUFFEL_POSITION = UDim2.new(0.5, 0, 0, DUFFEL_TOP)
-- Moved 110 -> 128 (spec addendum, 2026-09-12): the duffel element grew from a
-- 38px label to a 56px composite card (header + fill bar), so it now occupies
-- y 64..120. 128 preserves the original 8px gap beneath it.
--
-- The getaway widget (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19) claims
-- the slot that used to be the toast's, and the toast moves down below it.
-- Extended through the same derived chain rather than with a literal, exactly
-- as the comment above requires -- and TOAST_CENTER further down is derived
-- from TOAST_POSITION, so the cash-burst VFX origin follows automatically.
local GETAWAY_TOP = DUFFEL_TOP + 92 + HUD_GUTTER      -- below the 92px duffel
local GETAWAY_POSITION = UDim2.new(0.5, 0, 0, GETAWAY_TOP)
-- The getaway bar's track width in pixels, shared by the track itself and the
-- fill quantiser a thousand lines below it. The quantiser exists precisely to
-- round the ratio to THIS bar's own pixel resolution, so the two are the same
-- number by definition -- as two literals, a track resize that left the
-- quantiser behind would silently restore the ~60-tweens-a-second it was added
-- to prevent, with nothing to notice.
local GETAWAY_BAR_WIDTH = 190
local TOAST_POSITION = UDim2.new(0.5, 0, 0, GETAWAY_TOP + 76 + HUD_GUTTER) -- below the 76px getaway
local TOAST_SIZE = UDim2.new(0, 420, 0, 48)
local TOAST_ANCHOR = Vector2.new(0.5, 0) -- matches label()'s own AnchorPoint

-- Every robbery location gets its own independent timer/duffel GUI element
-- and slide state (spec addendum, 2026-09-06, extended 2026-09-14 for
-- Gas2Go), so one location's transitions can never be confused with
-- another's even if more than one happens to be active at once. Every
-- location's elements rest at the same on-screen position as each other --
-- harmless, since a player can only ever be physically inside one
-- location's zone at a time, so at most one of any given set is ever
-- visible.
local LOCATIONS = { "Bank", "SlowFoods", "Gas2Go", "NewsStation" }

-- Duffel widget palette. All three are this file's own existing constants
-- rather than new ones: the fill green is the project's established affirmative
-- green (SupplierDialogGui's YesButton), and the full-state amber is the same
-- one the DUFFEL FULL text has always used -- now shared with the status
-- billboards too.
local DUFFEL_SIZE = UDim2.new(0, 260, 0, 56)
local BAR_TRACK_COLOR = Color3.fromRGB(28, 42, 30)
local BAR_FILL_COLOR = Color3.fromRGB(60, 140, 60)
local DUFFEL_FULL_COLOR = Color3.fromRGB(255, 200, 80)
local TEXT_DEFAULT_COLOR = Color3.fromRGB(240, 240, 240)

-- The duffel display is a composite card rather than a single TextLabel
-- (spec addendum, 2026-09-12): a "DuffelBag" header, a proportional fill bar,
-- the amount overlaid on the bar, and a "+" opening the capacity-upgrade
-- dialog. Still built with Instance.new() here, matching its immediate
-- siblings (the timer and toast labels) -- the newer "pre-built in StarterGui"
-- convention covers triggered dialogs like DuffelUpgradeGui, not this ambient
-- always-present HUD strip.
--
-- Everything lives under one root Frame so the existing SlideIn/SlideOut calls
-- move the whole widget as a unit, exactly as they moved the old label.
local function duffelWidget(name: string)
	-- The panel, its "DUFFELBAG" header and the empty track are all baked into
	-- the slice. Only the fill width, the amount and the FULL state swap are
	-- live -- and the FULL state is a whole second slice, not a recolour,
	-- because its header text is baked gold too.
	local root = Instance.new("ImageLabel")
	root.Name = name
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = DUFFEL_POSITION
	root.Size = UDim2.fromOffset(UITheme.Size.DuffelPanel.X, UITheme.Size.DuffelPanel.Y)
	root.BackgroundTransparency = 1
	root.Image = UITheme.Assets.DuffelPanel
	root.Visible = false
	root.Parent = gui

	-- Header is baked; kept as an invisible stub so nothing downstream that
	-- pokes widget.header has to be special-cased.
	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Visible = false
	header.Text = ""
	header.Parent = root

	-- Track geometry matches the baked slice exactly: body (16,66) 268x12, r6.
	local track = Instance.new("Frame")
	track.Name = "BarTrack"
	track.Position = UDim2.fromOffset(16, 66)
	track.Size = UDim2.fromOffset(268, 12)
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.ZIndex = 2
	track.Parent = root
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 6)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "BarFill"
	fill.Position = UDim2.fromOffset(0, 0)
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = UITheme.Color.accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 3
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	-- Highest ZIndex in the widget, per spec: reads over both track and fill.
	-- Sits ABOVE the bar in the redesign, not overlaid on it.
	local amount = Instance.new("TextLabel")
	amount.Name = "AmountText"
	amount.Position = UDim2.fromOffset(16, 32)
	amount.Size = UDim2.fromOffset(230, 28)
	amount.BackgroundTransparency = 1
	amount.FontFace = UITheme.Font.Display
	amount.TextSize = 22
	amount.TextXAlignment = Enum.TextXAlignment.Left
	amount.TextColor3 = UITheme.Color.accent
	amount.Text = ""
	amount.ZIndex = 4
	amount.Parent = root

	-- Its own slice, not baked into the panel: the hover feedback is a DARKENING
	-- tint, and ImageColor3 on the panel would tint the entire widget rather than
	-- just this pill.
	local plus = Instance.new("ImageButton")
	plus.Name = "UpgradeButton"
	plus.Position = UDim2.fromOffset(254, 18)
	plus.Size = UDim2.fromOffset(UITheme.Size.BtnDuffelPlus.X, UITheme.Size.BtnDuffelPlus.Y)
	plus.BackgroundTransparency = 1
	plus.Image = UITheme.Assets.BtnDuffelPlus
	plus.AutoButtonColor = false
	plus.ZIndex = 5
	plus.Parent = root

	return { root = root, header = header, fill = fill, amount = amount, plus = plus }
end

-- Edge-triggered fill tween. The three lump-sum locations grant cash in one
-- discrete jump, so assigning fill.Size directly made the bar snap; tweening
-- it reads as filling. Guarded the same way timerShown/duffelShown are
-- elsewhere in this file: a Tween is created ONLY when the ratio actually
-- changed, because this runs every RenderStepped frame and minting ~60
-- identical tweens a second would both waste allocations and have them fight
-- each other for the same property. The per-widget handle plus cancel-before-
-- replace mirrors UITransitions' own activeTweens/cancelActive discipline, so
-- a rapid re-trigger supersedes the stale tween instead of layering onto it.
local FILL_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setFillRatio(widget, ratio: number)
	if widget._lastRatio == ratio then return end
	widget._lastRatio = ratio
	if widget._fillTween then
		pcall(function() widget._fillTween:Cancel() end)
		widget._fillTween = nil
	end
	local tween = TweenService:Create(widget.fill, FILL_TWEEN_INFO, { Size = UDim2.new(ratio, 0, 1, 0) })
	widget._fillTween = tween
	tween:Play()
end

-- Roblox has no thousands separator; the redesign shows "6,420 / 15,000".
local function commas(value: number): string
	local digits = tostring(math.max(0, math.floor(value)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local timerWidgets = {}
local duffelWidgets = {}
local getawayWidgets = {}
for _, location in ipairs(LOCATIONS) do
	local timerRoot = imagePanel(location .. "Timer", "TimerNormal", TIMER_POSITION)

	-- The hourglass is gone: the redesign replaces it with a baked accent edge,
	-- and the "TIME REMAINING" caption is baked too. Only the clock is live.
	local timerText = Instance.new("TextLabel")
	timerText.Name = "Time"
	timerText.BackgroundTransparency = 1
	timerText.Position = UDim2.fromOffset(34, 12)
	timerText.Size = UDim2.fromOffset(190, 32)
	timerText.FontFace = UITheme.Font.Display
	timerText.TextSize = 28
	timerText.TextXAlignment = Enum.TextXAlignment.Left
	timerText.TextColor3 = UITheme.Color.accent
	timerText.Text = ""
	timerText.ZIndex = 2
	timerText.Parent = timerRoot

	-- Getaway widget (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19). Built
	-- inline with the same imagePanel helper the timer uses, rather than in its
	-- own duffelWidget-style function, because it has only TWO live children:
	-- the accent edge, the "STUDS" suffix and the "GET AWAY" caption are all
	-- baked into the 240x76 slice.
	local getawayRoot = imagePanel(location .. "Getaway", "GetawayNormal", GETAWAY_POSITION)

	-- Right-aligned, unlike the timer's left-aligned clock: the number grows
	-- leftward into the panel so its last digit stays pinned a constant 6px
	-- clear of the baked "STUDS" suffix at x184, instead of colliding with it
	-- as the count goes from 3 digits to 2 to 1.
	local getawayStuds = Instance.new("TextLabel")
	getawayStuds.Name = "Studs"
	getawayStuds.BackgroundTransparency = 1
	getawayStuds.Position = UDim2.fromOffset(34, 12)
	getawayStuds.Size = UDim2.fromOffset(144, 32)
	getawayStuds.FontFace = UITheme.Font.Display
	getawayStuds.TextSize = 28
	getawayStuds.TextXAlignment = Enum.TextXAlignment.Right
	getawayStuds.TextColor3 = UITheme.Color.accent
	getawayStuds.Text = ""
	getawayStuds.ZIndex = 2
	getawayStuds.Parent = getawayRoot

	-- Track band matches the baked slice exactly: (34,64) 190x6, r3. The track
	-- is the CLIPPING PARENT so the fill inside it can be sized in Scale --
	-- that is precisely what lets setFillRatio drive this widget unchanged,
	-- since it writes UDim2.new(ratio, 0, 1, 0) into widget.fill.
	local getawayTrack = Instance.new("Frame")
	getawayTrack.Name = "BarTrack"
	getawayTrack.Position = UDim2.fromOffset(34, 64)
	getawayTrack.Size = UDim2.fromOffset(GETAWAY_BAR_WIDTH, 6)
	getawayTrack.BackgroundTransparency = 1
	getawayTrack.BorderSizePixel = 0
	getawayTrack.ClipsDescendants = true
	getawayTrack.ZIndex = 2
	getawayTrack.Parent = getawayRoot
	local getawayTrackCorner = Instance.new("UICorner")
	getawayTrackCorner.CornerRadius = UDim.new(0, 3)
	getawayTrackCorner.Parent = getawayTrack

	-- Top-left anchored (no AnchorPoint) with a full-height Scale size, same as
	-- the duffel's own fill: AnchorPoint and Position must agree, and (0, 0.5)
	-- here would put the bar's centre on the track's top edge.
	local getawayFill = Instance.new("Frame")
	getawayFill.Name = "BarFill"
	getawayFill.Position = UDim2.fromOffset(0, 0)
	getawayFill.Size = UDim2.new(0, 0, 1, 0)
	getawayFill.BackgroundColor3 = UITheme.Color.accent
	getawayFill.BorderSizePixel = 0
	getawayFill.ZIndex = 3
	getawayFill.Parent = getawayTrack
	local getawayFillCorner = Instance.new("UICorner")
	getawayFillCorner.CornerRadius = UDim.new(0, 3)
	getawayFillCorner.Parent = getawayFill

	timerWidgets[location] = { root = timerRoot, time = timerText }
	duffelWidgets[location] = duffelWidget(location .. "Duffel")
	-- Keyed root/studs/fill deliberately: setFillRatio reads widget.fill and
	-- stores its own _lastRatio/_fillTween on the table, so it drives this
	-- widget with no change of its own.
	getawayWidgets[location] = { root = getawayRoot, studs = getawayStuds, fill = getawayFill }
end

-- Duffel capacity upgrade dialog (spec addendum, 2026-09-12). The "+" on each
-- location's duffel widget opens it; both tier buttons hand off to Roblox's own
-- purchase prompt and close. The "+" handler and the dialog it drives are kept
-- together here deliberately rather than split across two files.
--
-- Nothing further is needed client-side once a purchase completes, confirmed by
-- reading rather than assumed: GamepassManager:Init() (called by HeistServer)
-- connects PromptGamePassPurchaseFinished -> _setCached(userId, id, true), and
-- BankInstance:GetDuffelCap is `config.DuffelCap * self.duffelCapMultiplier(player)`
-- -- recomputed on EVERY call, never cached per session. So a purchase that
-- completes mid-robbery is reflected on the very next accrual tick.
local upgradeGui = player:WaitForChild("PlayerGui"):WaitForChild("DuffelUpgradeGui", 10)
local upgradeFrame = upgradeGui and upgradeGui:WaitForChild("DialogFrame", 10)
-- Must match DialogFrame's authored Position: UITransitions derives both the
-- off-screen start and the slide-out target from the resting position it is given.
local UPGRADE_POSITION = UDim2.new(0.5, 0, 0.5, 0)

local function closeUpgradeDialog()
	if upgradeFrame then
		-- "Right" deliberately: Top/Bottom are reserved for the toast and the
		-- notification stack, so this must not read as the same kind of element.
		UITransitions.SlideOut(upgradeFrame, UPGRADE_POSITION, "Right")
	end
end

local function promptCapacityPurchase(tierName: string)
	local config = GamepassManager.GamepassConfig[tierName]
	local id = config and config.Id
	if not id or id == 0 then
		-- TODO(project owner): every Id in GamepassManager.GamepassConfig is still
		-- the placeholder 0. Real Gamepasses must be created in the Creator
		-- Dashboard and their Ids filled in before a purchase can complete -- a
		-- monetization decision, not a technical one. Fails soft until then.
		warn(string.format(
			"[HeistClient] %s still has placeholder Id 0 -- create the real Gamepass before it can be purchased",
			tierName))
		return
	end
	-- pcall'd regardless: PromptGamePassPurchase can throw on a bad/unpublished Id
	-- and must never take the rest of the HUD down with it.
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, id)
	end)
	if not ok then
		warn("[HeistClient] PromptGamePassPurchase failed: " .. tostring(err))
	end
end

if upgradeFrame then
	local x2Button = upgradeFrame:WaitForChild("X2Button", 10)
	local x4Button = upgradeFrame:WaitForChild("X4Button", 10)
	local upgradeExit = upgradeFrame:WaitForChild("ExitButton", 10)
	if x2Button then
		x2Button.Activated:Connect(function()
			promptCapacityPurchase("DuffelCapacityX2")
			closeUpgradeDialog()
		end)
	end
	if x4Button then
		x4Button.Activated:Connect(function()
			promptCapacityPurchase("DuffelCapacityX4")
			closeUpgradeDialog()
		end)
	end
	if upgradeExit then
		upgradeExit.Activated:Connect(closeUpgradeDialog)
	end
else
	warn("[HeistClient] DuffelUpgradeGui not found -- the duffel upgrade button will do nothing")
end

for _, location in ipairs(LOCATIONS) do
	duffelWidgets[location].plus.Activated:Connect(function()
		if upgradeFrame then
			UITransitions.SlideIn(upgradeFrame, UPGRADE_POSITION, "Right")
		end
	end)
end

-- World-space status badges (spec addendum, 2026-09-12; re-skinned to exported
-- art 2026-09-18): one always-visible BillboardGui above each location,
-- showing that location's session state. This used to recolour a UIStroke;
-- it now swaps between three pre-rendered sprites, because each state's badge
-- carries its own coloured outer glow and a runtime tint cannot produce one.
--
-- Each location's markers folder is named independently rather than derived
-- from the location name: the Bank's is "HeistMarkers", not "BankMarkers",
-- because that whole location's tag family is Heist* rather than Bank*.
local MARKER_FOLDERS = {
	Bank = "HeistMarkers",
	SlowFoods = "SlowFoodsMarkers",
	Gas2Go = "Gas2GoMarkers",
	NewsStation = "NewsStationMarkers",
}
-- Three separate bakes rather than a recolour: each sprite carries its own
-- coloured outer glow, which no runtime tint reproduces.
local BILLBOARD_STATE_IMAGES = {
	Idle = UITheme.Assets.StatusIdle,
	Active = UITheme.Assets.StatusActive,
	Cooldown = UITheme.Assets.StatusCooldown,
}
-- Resolved once, up front. A bounded WaitForChild rather than an unbounded one
-- on purpose: this script also owns the timer, duffel, toast, lockpick and safe
-- GUIs, so a missing or renamed badge must degrade to "no badge colouring"
-- rather than yielding forever and taking the entire HUD down with it.
local billboardImages = {}
-- The anchor Part itself, retained alongside the badge image (spec:
-- Getaway-Distance-Claim-And-GUI, 2026-09-19). This walk already resolved it
-- on the way down to StatusImage and then threw it away. Getaway distance is
-- measured from exactly this Part because it is the very same one
-- LocationServer and HeistServer hand to the server's own Getaway service --
-- one anchor, so the rendered countdown and the authoritative gate agree.
local locationAnchors = {}
for _, location in ipairs(LOCATIONS) do
	local folder = workspace:WaitForChild(MARKER_FOLDERS[location], 10)
	local anchor = folder and folder:WaitForChild("StatusBillboardAnchor", 10)
	local gui = anchor and anchor:WaitForChild("StatusBillboard", 10)
	local badge = gui and gui:WaitForChild("Badge", 10)
	billboardImages[location] = badge and badge:WaitForChild("StatusImage", 10)
	locationAnchors[location] = anchor
	if not billboardImages[location] then
		warn(string.format("[HeistClient] %s status billboard not found -- badge state disabled for it", location))
	end
	if not anchor then
		warn(string.format("[HeistClient] %s has no StatusBillboardAnchor -- getaway distance disabled for it", location))
	end
end

-- Per-location EscapeDistance, read from the SAME config module the server's
-- own Getaway service was constructed from (spec:
-- Getaway-Distance-Claim-And-GUI, 2026-09-19). Deliberately NOT a hardcoded
-- 200 here: the number lives in the four configs precisely so the rendered
-- countdown and the server's authoritative gate can never drift apart.
--
-- Each location's shared folder is named independently, exactly like
-- MARKER_FOLDERS above and for the same reason -- the Bank's is "HeistShared",
-- not "BankShared", because that location's whole family is Heist* not Bank*.
local CONFIG_FOLDERS = {
	Bank = "HeistShared",
	SlowFoods = "RestaurantShared",
	Gas2Go = "Gas2GoShared",
	NewsStation = "NewsStationShared",
}
local escapeDistances = {}
for _, location in ipairs(LOCATIONS) do
	-- Bounded waits and a pcall'd require, the same degrade-with-a-warn
	-- discipline as the billboard walk above: a missing or malformed config
	-- must cost this one location its getaway widget, never yield forever and
	-- take the whole HUD down with it.
	local folder = ReplicatedStorage:WaitForChild(CONFIG_FOLDERS[location], 10)
	local module = folder and folder:WaitForChild("Config", 10)
	local ok, config = pcall(function() return require(module) end)
	local distance = ok and type(config) == "table" and config.EscapeDistance or nil
	if type(distance) == "number" and distance > 0 then
		escapeDistances[location] = distance
	else
		warn(string.format("[HeistClient] %s has no usable EscapeDistance -- getaway widget disabled for it", location))
	end
end
local toastRoot = imagePanel("Toast", "Toast", TOAST_POSITION)
local toastLabel = Instance.new("TextLabel")
toastLabel.Name = "Message"
toastLabel.BackgroundTransparency = 1
toastLabel.Position = UDim2.fromOffset(0, 0)
toastLabel.Size = UDim2.fromScale(1, 1)
toastLabel.FontFace = UITheme.Font.UI
toastLabel.TextSize = 18
toastLabel.TextColor3 = UITheme.Color.accent
toastLabel.Text = ""
toastLabel.ZIndex = 2
toastLabel.Parent = toastRoot

-- Cash burst + flying-cash-GUI on claim (spec addendum, 2026-09-09,
-- corrected 2026-09-10 to originate from the claim-confirmation toast
-- rather than screen center): the toast's own resting CENTER, computed from
-- its anchor/position/size -- not its live AbsolutePosition, which would be
-- mid-slide-in (and off-screen) at the exact moment a claim fires, since
-- Toast and RobberySuccess are two independent remotes with no ordering
-- guarantee between them.
local TOAST_CENTER = UDim2.new(
	TOAST_POSITION.X.Scale, TOAST_POSITION.X.Offset - TOAST_ANCHOR.X * TOAST_SIZE.X.Offset + TOAST_SIZE.X.Offset / 2,
	TOAST_POSITION.Y.Scale, TOAST_POSITION.Y.Offset - TOAST_ANCHOR.Y * TOAST_SIZE.Y.Offset + TOAST_SIZE.Y.Offset / 2
)
local cashClaimVFX = CashClaimVFX.new({ player = player, burstOrigin = TOAST_CENTER })

local sessionStates = {}
local duffelStates = {}
-- Per-location "is THIS player physically inside this location's zone right
-- now" (spec addendum, 2026-09-06), server-authoritative via the new
-- ZoneOccupancy remote. The heist timer requires this AND RobberyActive
-- together -- "a heist is active somewhere" is no longer sufficient on its
-- own.
local zoneOccupancy = {}
-- Edge-triggered show/hide state: RenderStepped below recomputes "should
-- this be visible right now" every frame, but SlideIn/SlideOut must only
-- fire once PER TRANSITION, not once per frame while already shown/hidden.
local timerShown = {}
local duffelShown = {}
local getawayShown = {}
-- Studs still to run before THIS location's bag banks, or nil when the player
-- is not in a position to bank it at all (no bag, still inside, no character,
-- no session). Recomputed for every location each frame by the render loop,
-- then read back once the loop has closed to pick the single most urgent one
-- -- see the comment at that selection for why only one may ever be shown.
local getawayRemaining = {}
-- Fire-once-per-session cap notification, per location.
local duffelFullPlayed = {}
for _, location in ipairs(LOCATIONS) do
	sessionStates[location] = { state = "Idle", endsAt = nil, cooldownEndsAt = nil }
	duffelStates[location] = { base = 0, rate = 0, since = 0, cap = 0 }
	zoneOccupancy[location] = false
	timerShown[location] = false
	duffelShown[location] = false
	getawayShown[location] = false
	duffelFullPlayed[location] = false
end

-- How long a toast ("Banked 12,000") stays on screen before sliding out. The message is short and
-- the claim already has its own cash burst and sound, so it does not need to linger.
local TOAST_SECONDS = 2.5
local toastUntil = 0
local toastShown = false

-- UI-only cues: no server validation needed, so these are played straight
-- off client-visible state/remote traffic rather than a dedicated remote.
-- Pre-placed under StarterCharacterScripts (spec addendum, 2026-08-28) --
-- Roblox clones one set into every spawned character, so this never
-- constructs a Sound instance itself, only references and plays the one
-- that already exists on the current character.
local function playCue(name: string)
	local character = player.Character
	local sound = character and character:FindFirstChild(name)
	if not sound then
		warn("[HeistClient] " .. name .. " missing from character -- check StarterCharacterScripts")
		return
	end
	local ok, err = pcall(function() sound:Play() end)
	if not ok then warn("[HeistClient] " .. name .. " play failed: " .. tostring(err)) end
end

remotes:WaitForChild("HeistState").OnClientEvent:Connect(function(payload)
	local location = payload.location
	if not location or not sessionStates[location] then return end
	if payload.state == "Active" and sessionStates[location].state ~= "Active" then
		duffelFullPlayed[location] = false
	end
	sessionStates[location] = payload
end)

remotes:WaitForChild("DuffelState").OnClientEvent:Connect(function(payload)
	local location = payload.location
	if not location or not duffelStates[location] then return end
	duffelStates[location] = payload
end)

remotes:WaitForChild("ZoneOccupancy").OnClientEvent:Connect(function(payload)
	local location = payload.location
	if not location or zoneOccupancy[location] == nil then return end
	zoneOccupancy[location] = payload.inside
end)

-- DuffelInitiateSound ("bag ready") is triggered server-side, on actual
-- Vault-zone entry (spec addendum, 2026-08-28) -- not derived from
-- client-visible duffel state. See HeistServer's playDuffelReadyCue.
remotes:WaitForChild("PlayCue").OnClientEvent:Connect(function(name)
	playCue(name)
end)

remotes:WaitForChild("RobberySuccess").OnClientEvent:Connect(function()
	cashClaimVFX:PlaySequence()
end)

remotes:WaitForChild("Toast").OnClientEvent:Connect(function(message)
	toastLabel.Text = message
	toastUntil = workspace:GetServerTimeNow() + TOAST_SECONDS
	toastShown = true
	UITransitions.SlideIn(toastRoot, TOAST_POSITION, "Bottom")
	-- Toast already targets only the relevant player (server calls
	-- net:Toast(player, ...)), so this naturally never plays for anyone else.
	if string.find(message, "^Banked ") then
		playCue("CashOutSuccessSound")
	end
end)

-- Safe combination-entry GUI (spec addendum, 2026-09-16): four individual
-- digit-slot TextBoxes -- the FIRST TextBoxes in this project (no existing
-- keypad/digit-entry template to clone or extend, confirmed) -- built in the
-- same raw-Instance.new/dark-panel/GothamBold/UICorner(8) style as every
-- other element in this file.
local safeFrame = Instance.new("ImageLabel")
safeFrame.Name = "SafeCodeEntry"
safeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
safeFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
safeFrame.Size = UDim2.fromOffset(UITheme.Size.SafeCode.X, UITheme.Size.SafeCode.Y)
safeFrame.BackgroundTransparency = 1
safeFrame.Image = UITheme.Assets.SafeCode
safeFrame.Visible = false
-- This ScreenGui's ZIndexBehavior is Global (confirmed live, not the
-- Sibling default), meaning ZIndex is compared across the WHOLE hierarchy,
-- not just among direct siblings -- a parent CAN render on top of its own
-- children if its ZIndex is higher (root cause of the reported washed-out/
-- highlight-bleed-through bug: this was left at a stray 10 while every
-- child below defaulted to 1). Backdrop stays at the lowest ZIndex in this
-- panel; every child below is explicitly given a higher one.
safeFrame.ZIndex = 1
safeFrame.Parent = modalGui
-- Title, panel, digit-box outlines and the SUBMIT pill are all baked into the
-- slice now; only the four typed digits stay live.

local DIGIT_COUNT = 4
local digitBoxes = {}
do
	-- Geometry mirrors the baked slice exactly: body (24 + i*80, 66), 64x72.
	local o = UITheme.BodyOffset.SafeCode
	for i = 1, DIGIT_COUNT do
		local box = Instance.new("TextBox")
		box.Name = "Digit" .. i
		box.Position = UDim2.fromOffset(o.X + 24 + (i - 1) * 80, o.Y + 66)
		box.Size = UDim2.fromOffset(64, 72)
		box.BackgroundTransparency = 1
		box.TextColor3 = UITheme.Color.white
		box.FontFace = UITheme.Font.Display
		box.TextSize = 30
		box.Text = ""
		box.PlaceholderText = ""
		box.PlaceholderColor3 = UITheme.Color.muted
		box.ClearTextOnFocus = false
		box.ZIndex = 2
		box.Parent = safeFrame
		digitBoxes[i] = box
	end
end

-- Its own slice rather than a transparent target over baked artwork: a hover /
-- press tween needs something visible to move (see UI.Effects for why an
-- overlay cannot work).
local submitButton = Instance.new("ImageButton")
submitButton.Name = "Submit"
submitButton.Position = UDim2.fromOffset(UITheme.BodyOffset.SafeCode.X + 24, UITheme.BodyOffset.SafeCode.Y + 160)
submitButton.Size = UDim2.fromOffset(UITheme.Size.BtnSafeCodeSubmit.X, UITheme.Size.BtnSafeCodeSubmit.Y)
submitButton.BackgroundTransparency = 1
submitButton.Image = UITheme.Assets.BtnSafeCodeSubmit
submitButton.AutoButtonColor = false
submitButton.ZIndex = 2
submitButton.Parent = safeFrame

local currentSafeId: number? = nil

local function closeSafeGui()
	safeFrame.Visible = false
	for _, box in ipairs(digitBoxes) do
		box.Text = ""
	end
	currentSafeId = nil
end

-- Fires immediately on submit rather than waiting for a server response
-- (spec: "close the GUI immediately" for a wrong code; success is
-- communicated by the existing world-space burst/bounce/sound at the safe
-- itself, same as every other robbable object, plus a Toast either way) --
-- the server is the sole authority on whether the code was actually right.
local function submitSafeCode()
	if not currentSafeId then return end
	local digits = ""
	for _, box in ipairs(digitBoxes) do
		digits ..= box.Text
	end
	remotes:WaitForChild("SubmitSafeCode"):FireServer(currentSafeId, digits)
	closeSafeGui()
end

-- Digits only, one character per slot, auto-advances focus to the next slot
-- as soon as one fills (Enter also submits) -- purely client-side polish;
-- the server treats whatever ends up in each box as an untrusted string
-- regardless of any filtering done here.
for i, box in ipairs(digitBoxes) do
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local filtered = box.Text:gsub("%D", ""):sub(1, 1)
		if filtered ~= box.Text then
			box.Text = filtered
		end
		if filtered ~= "" and i < DIGIT_COUNT then
			digitBoxes[i + 1]:CaptureFocus()
		end
	end)
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			submitSafeCode()
		end
	end)
end
submitButton.MouseButton1Click:Connect(submitSafeCode)

-- Server -> this client only (spec: opens "for the triggering player only").
remotes:WaitForChild("OpenSafeGui").OnClientEvent:Connect(function(safeId)
	currentSafeId = safeId
	for _, box in ipairs(digitBoxes) do
		box.Text = ""
	end
	safeFrame.Visible = true
	digitBoxes[1]:CaptureFocus()
end)

-- Force-close on anything that makes an open GUI stale (regression found via
-- adversarial review, 2026-09-16): the Bank's session ending (timer expiry)
-- or this character dying/respawning while the digit-entry frame is still up
-- -- previously nothing closed it in either case, so it could hang open
-- indefinitely showing a prompt the server would now just reject as
-- "inactive". A second, independent HeistState listener (not the one further
-- below) is the simplest way to react to this without threading GUI state
-- through the existing per-location session-tracking loop.
remotes:WaitForChild("HeistState").OnClientEvent:Connect(function(payload)
	if payload.location == "Bank" and payload.state ~= "Active" and safeFrame.Visible then
		closeSafeGui()
	end
end)
player.CharacterRemoving:Connect(function()
	if safeFrame.Visible then closeSafeGui() end
end)

-- Supplies Robbery: the supplier's CONVERSATION no longer lives here. It moved to
-- StarterPlayerScripts.SupplierDialogueController, which drives it through the same DialogModule /
-- QuestResponsesGui billboard engine the "FPS System" place's quest givers use -- the supplier is
-- mechanically a mini-quest, so it now presents like one. SubmitSupplierChoice/SupplierResult are
-- unchanged and still server-authoritative; only the presentation moved.
--
-- The Drop button and the carry poll stay here: they are ambient HUD tied to carry state, not part
-- of the conversation.

-- Drop button: shown only while the character has an equipped Carry-State
-- Tool -- polled every frame (same convention as the duffel GUI's own
-- wantDuffel recompute) via an attribute rather than hardcoded tool names,
-- so a future third supply type needs no client change.
-- Fully static, so the whole button (pill + "DROP SUPPLIES") is one slice and
-- this is an ImageButton with no text of its own.
local dropButton = Instance.new("ImageButton")
dropButton.Name = "DropSuppliesButton"
dropButton.AnchorPoint = Vector2.new(0.5, 1)
dropButton.Position = UDim2.new(0.5, 0, 1, -40)
dropButton.Size = UDim2.fromOffset(UITheme.Size.DropSupplies.X, UITheme.Size.DropSupplies.Y)
dropButton.BackgroundTransparency = 1
dropButton.Image = UITheme.Assets.DropSupplies
dropButton.AutoButtonColor = false
dropButton.Visible = false
dropButton.Parent = gui

dropButton.MouseButton1Click:Connect(function()
	remotes:WaitForChild("DropSupplies"):FireServer()
end)

local function isCarryingSupplies(): boolean
	local character = player.Character
	if not character then return false end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("IsSupplyCarryTool") then
			return true
		end
	end
	return false
end

-- Backpack/hotbar CoreGui (spec addendum, 2026-09-2X): entirely hidden
-- while carrying, not merely functionally blocked -- reinforces "too busy
-- carrying this to switch gear" with no visual hint other gear even
-- exists. Purely a client-facing visibility toggle -- it does NOT replace
-- CarryState's own server-side Unequipped-based safeguard (still the
-- authoritative gate; a hidden CoreGui alone would trust the client).
-- Edge-triggered off the SAME poll already driving the Drop button, not a
-- second poll, and only fires SetCoreGuiEnabled on an actual transition
-- (StarterGui:SetCoreGuiEnabled is a client-only API -- can't be driven
-- from CarryState/SuppliesServer server-side).
local wasCarrying = false
RunService.RenderStepped:Connect(function()
	local carrying = isCarryingSupplies()
	dropButton.Visible = carrying
	if carrying ~= wasCarrying then
		wasCarrying = carrying
		-- City (phase 3 G10): the Backpack core GUI stays disabled; Custom Inventory replaces it.
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end
end)

-- Force-close on death/respawn, same established convention as the Safe
-- GUI's own force-close hook. Also unconditionally restores the Backpack
-- CoreGui -- a player who disconnects/dies mid-carry must never respawn
-- with it stuck hidden.
player.CharacterRemoving:Connect(function()
	dropButton.Visible = false
	if wasCarrying then
		wasCarrying = false
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- city: never re-enabled (phase 3 G10)
	end
end)

-- LockedDoor lockpicking (spec addendum, 2026-09-2X): the GUI is a REAL,
-- pre-designed Studio object under StarterGui (LockpickGui), same "Studio-
-- authored, script only references it" precedent as SupplierDialogGui.
-- Rotary needle mechanic (fully replaces the earlier sequential-pin/line
-- system): a needle rotates continuously around a ring at a constant
-- angular speed; the player clicks to catch it inside a randomly-placed,
-- progressively-narrowing success zone arc, filling a vertical progress bar.
local lockpickGui = player.PlayerGui:WaitForChild("LockpickGui")
local lockpickTrack = lockpickGui.Track
local lockpickStopButton = lockpickTrack:WaitForChild("StopButton")
local lockpickExitButton = lockpickTrack:WaitForChild("ExitButton")
local lockpickRing = lockpickTrack:WaitForChild("Ring")
-- The ring is a WHITE exported sprite tinted via ImageColor3 (it replaced a
-- UIStroke). White matters: ImageColor3 multiplies, so only a white source can
-- be flashed red on a miss -- a coloured one could only ever be darkened.
local lockpickRingTrack = lockpickRing:WaitForChild("RingTrack")
local lockpickNeedle = lockpickRing:WaitForChild("Needle")
local lockpickZone = lockpickRing:WaitForChild("Zone")
local lockpickPercent = lockpickRing:WaitForChild("PercentLabel")
local lockpickProgressFill = lockpickTrack:WaitForChild("ProgressBar"):WaitForChild("ProgressFill")

-- Matches Ring's own authored Size (180px, see the Studio-build script) --
-- the zone notch sits at this radius along the ring's circumference. A
-- chord-length approximation for the zone's on-screen width (arc length ~=
-- radius * angularWidth), not a true curved arc segment -- that would need
-- an image asset or an advanced masking technique, neither verifiable
-- without screen capture this session.
-- 100, not 90: the redesigned ring sprite is 200px across. This constant and
-- the Ring frame's own size are load-bearing together -- change one without
-- the other and the needle orbits off the ring.
local LOCKPICK_RING_RADIUS = 100
local RING_IDLE_COLOR = UITheme.Color.line
local RING_MISS_COLOR = UITheme.Color.danger
local ZONE_IDLE_COLOR = UITheme.Color.accent
local ZONE_HIT_COLOR = Color3.fromRGB(180, 255, 120)
-- The zone sprite is a full 200x200 ring-sized image with the arc drawn at
-- Figma's 0 rad, which is 3 o'clock. Roblox angle 0 points UP, so every zone
-- angle is offset by a quarter turn to line the two conventions up.
local ZONE_SPRITE_BASE_DEG = -90
-- The success zone narrows as progress climbs; an arc cannot be scaled without
-- distorting, so one pre-rendered arc PER SERVER LEVEL is swapped instead.
--
-- These widths mirror LockedDoor.ZONE_WIDTHS exactly (60/45/32/22 degrees) and
-- must stay in lockstep with it. The earlier version used three eyeballed arcs
-- picked by `zoneWidth >= threshold` with thresholds of 0.34/0.22/0.00 -- every
-- real width is above 0.34, so the widest arc was ALWAYS chosen, and it was
-- narrower than the true level-1 zone. The player could click outside the
-- visible arc and still score a hit, which is why a "wrong" click played the
-- success cue instead of the error one.
local ZONE_LEVELS = {
	{ width = math.rad(60), asset = UITheme.Assets.ZoneL1 },
	{ width = math.rad(45), asset = UITheme.Assets.ZoneL2 },
	{ width = math.rad(32), asset = UITheme.Assets.ZoneL3 },
	{ width = math.rad(22), asset = UITheme.Assets.ZoneL4 },
}

-- Nearest match rather than a threshold ladder: the server owns the widths, so
-- the client picks whichever rendered arc is closest to what it was told,
-- and a future tweak to ZONE_WIDTHS degrades to the nearest arc instead of
-- silently selecting the wrong end of the list.
local function zoneAssetFor(zoneWidth: number): string
	local best, bestDelta = ZONE_LEVELS[1].asset, math.huge
	for _, level in ipairs(ZONE_LEVELS) do
		local delta = math.abs(zoneWidth - level.width)
		if delta < bestDelta then
			bestDelta, best = delta, level.asset
		end
	end
	return best
end
local FLASH_DURATION = 0.3 -- seconds -- tunable placeholder, not specified by the project owner

-- UI-cue sounds (spec addendum, 2026-09-2X): non-positional -- cloned ONCE,
-- here, from HeistShared.SoundTemplates into SoundService (a per-player,
-- non-spatial playback context, not tied to any world position), then
-- just :Play()'d directly on every fail/success -- this is a client-only
-- UI feedback cue, not something nearby players need to hear.
local soundTemplates = shared:WaitForChild("SoundTemplates")
local lockpickFailSound = soundTemplates:WaitForChild("LockpickFailSound"):Clone()
lockpickFailSound.Parent = SoundService
local lockpickSuccessSound = soundTemplates:WaitForChild("LockpickSuccessSound"):Clone()
lockpickSuccessSound.Parent = SoundService

-- GUI shake on fail (spec addendum, 2026-09-2X): a quick, decaying jolt to
-- discourage mindless click-spamming -- jumps to a small horizontal
-- offset then Elastic-eases back to the captured resting position, the
-- same "springy overshoot-and-settle" technique DuffelBagAttachment's own
-- pop-in/pop-out already uses elsewhere in this project, reused here
-- rather than hand-chaining several discrete tweens for the same effect.
local SHAKE_OFFSET = 8 -- pixels -- tunable placeholder, not specified
local SHAKE_DURATION = 0.35 -- seconds -- tunable placeholder, not specified
local lockpickTrackRestingPosition = lockpickTrack.Position
local lockpickShakeTween = nil
local function shakeLockpickTrack()
	if lockpickShakeTween then
		pcall(function() lockpickShakeTween:Cancel() end)
		lockpickShakeTween = nil
	end
	lockpickTrack.Position = lockpickTrackRestingPosition + UDim2.new(0, SHAKE_OFFSET, 0, 0)
	lockpickShakeTween = TweenService:Create(
		lockpickTrack,
		TweenInfo.new(SHAKE_DURATION, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Position = lockpickTrackRestingPosition })
	lockpickShakeTween:Play()
end

-- angle=0 points straight up, matching the needle's own resting Rotation=0
-- -- both the needle (every frame, in the render loop below) and the zone
-- (once per state-change event here) use this exact same angle-to-screen
-- mapping, so a zone at a given angle always visually lines up with the
-- needle crossing it at that same angle.
-- The zone image covers the whole ring, so it is ROTATED in place rather than
-- moved around the circumference -- that keeps it a true arc following the
-- ring's curve instead of the flat chord the old Frame approximated.
local function applyZoneTransform(angle: number, zoneWidth: number)
	lockpickZone.Rotation = math.deg(angle) + ZONE_SPRITE_BASE_DEG
	local asset = zoneAssetFor(zoneWidth)
	if lockpickZone.Image ~= asset then lockpickZone.Image = asset end
end

local function applyProgress(progress: number)
	local p = math.clamp(progress, 0, 1)
	-- Anchored to the bottom so it fills upward, matching the redesign.
	lockpickProgressFill.AnchorPoint = Vector2.new(0, 1)
	lockpickProgressFill.Position = UDim2.fromScale(0, 1)
	lockpickProgressFill.Size = UDim2.new(1, 0, p, 0)
	lockpickPercent.Text = string.format("%d%%", math.floor(p * 100 + 0.5))
end

-- Brief, self-reverting flash -- fired once per hit/miss update, never left
-- in the flashed state (a stray leftover flash could otherwise persist
-- across a puzzle close/reopen if the player exits mid-flash).
-- Both flashes now drive ImageColor3. That MULTIPLIES, which is exactly why
-- the ring and zone sprites are exported white -- a coloured source could only
-- ever be darkened, never flashed red or bright green. Sounds are untouched.
local function flashZoneGreen()
	lockpickZone.ImageColor3 = ZONE_HIT_COLOR
	lockpickSuccessSound:Play()
	task.delay(FLASH_DURATION, function()
		lockpickZone.ImageColor3 = ZONE_IDLE_COLOR
	end)
end
local function flashRingRed()
	lockpickRingTrack.ImageColor3 = RING_MISS_COLOR
	lockpickFailSound:Play()
	task.delay(FLASH_DURATION, function()
		lockpickRingTrack.ImageColor3 = RING_IDLE_COLOR
	end)
end

-- {location, progress, zoneAngle, zoneWidth, angularSpeed, startTime}, or
-- nil while no attempt is in flight -- the render loop below is a no-op
-- whenever this is nil.
local lockpickState = nil

local function closeLockpickGui()
	lockpickGui.Enabled = false
	lockpickState = nil
end

remotes:WaitForChild("OpenLockpickGui").OnClientEvent:Connect(function(payload)
	lockpickState = payload
	lockpickGui.Enabled = true
	lockpickRingTrack.ImageColor3 = RING_IDLE_COLOR
	lockpickZone.ImageColor3 = ZONE_IDLE_COLOR
	applyProgress(payload.progress)
	applyZoneTransform(payload.zoneAngle, payload.zoneWidth)
end)

-- Either a hit (progress advanced, zone re-randomized and narrowed -- flash
-- green) or a miss (progress reduced, zone left exactly where it was --
-- flash red) -- the render loop is stateless per-frame, so no
-- special-casing is needed here beyond the cosmetic flash.
remotes:WaitForChild("LockpickUpdate").OnClientEvent:Connect(function(payload)
	if not lockpickState then return end -- GUI already closed locally; ignore a stray update
	lockpickState = payload
	applyProgress(payload.progress)
	applyZoneTransform(payload.zoneAngle, payload.zoneWidth)
	if payload.outcome == "hit" then
		flashZoneGreen()
	elseif payload.outcome == "miss" then
		flashRingRed()
		-- Shake and the needle's own reset-to-start (a natural consequence of
		-- lockpickState.startTime having changed, already handled by the
		-- render loop with no extra code needed here) both fire off this same
		-- miss event -- they overlap freely, no serialization required.
		shakeLockpickTrack()
	end
end)

remotes:WaitForChild("LockpickSolved").OnClientEvent:Connect(function()
	closeLockpickGui()
end)

-- Stop-input: click/touch only (spec correction, 2026-09-2X) -- no keyboard
-- shortcut of any kind. A GuiButton's .Activated fires correctly for both
-- mouse click AND touch with zero platform branching, unlike the earlier
-- raw InputBegan(MouseButton1/Touch) + a separate Space-key binding this
-- replaces. Sends ONE lag-compensation timestamp (spec correction,
-- 2026-09-2X): this client's own local workspace:GetServerTimeNow() at the
-- exact moment of the click -- the server never trusts this as a position
-- or success claim, only as WHEN to evaluate its own still fully
-- server-computed formula, bounded to a small recent window (see
-- LockedDoor's own MAX_LATENCY_COMPENSATION comment).
lockpickStopButton.Activated:Connect(function()
	if not lockpickGui.Enabled then return end
	remotes:WaitForChild("LockpickStopRequested"):FireServer(workspace:GetServerTimeNow())
end)

-- Exit ("X") button (spec addendum, 2026-09-2X): a clean, no-penalty
-- bail-out. Hides the GUI and halts the render loop immediately 
-- (lockpickState = nil), then tells the server to drop its own attempt
-- state too -- the door stays closed, the physical prompt is untouched
-- (never disabled by opening a puzzle in the first place), and the player
-- can re-trigger it fresh later.
lockpickExitButton.Activated:Connect(function()
	closeLockpickGui()
	remotes:WaitForChild("LockpickExitRequested"):FireServer()
end)

-- The render loop: the needle animates locally every frame using the
-- identical deterministic formula the server itself validates stops
-- against (spec: "the client rendering its own locally-smooth animation
-- based on the same formula/start-time rather than being told the angle
-- every frame") -- zero extra network traffic per frame. angle=0 points
-- straight up, matching applyZoneTransform's own convention above.
--
-- Orbit fix (spec correction, 2026-09-2X): the needle is a small point
-- that TRAVELS AROUND the ring's circumference at a fixed radius, not a
-- long radial hand rotating around the ring's center -- its Position is
-- recomputed every frame via the exact same sin/cos orbit formula
-- applyZoneTransform already uses for the zone notch, so the two always
-- agree on what a given angle looks like on screen. Rotation is set to
-- the SAME angle so the pill stays tangent to the ring as it travels
-- (correct because the needle's authored resting pose, Rotation=0, is a
-- vertical pill -- exactly the tangent direction at angle=0's position,
-- the top of the ring; the tangent direction rotates at the same rate as
-- the radial direction, so no separate offset is needed).
RunService.RenderStepped:Connect(function()
	if not lockpickState then return end
	local elapsed = workspace:GetServerTimeNow() - lockpickState.startTime
	local angle = (elapsed * lockpickState.angularSpeed) % (2 * math.pi)
	lockpickNeedle.Position = UDim2.new(0.5, LOCKPICK_RING_RADIUS * math.sin(angle), 0.5, -LOCKPICK_RING_RADIUS * math.cos(angle))
	lockpickNeedle.Rotation = math.deg(angle)
end)

-- Force-close on death/respawn or the SAME location's session ending, same
-- established convention as the Safe GUI/Supplier dialog's own force-close
-- hooks. Location-scoped (spec correction, 2026-09-2X) -- LockedDoor's own
-- OpenLockpickGui/LockpickUpdate payloads now carry a location field
-- (mirrored straight into lockpickState), so this only closes when the
-- state change actually belongs to the SAME location the open puzzle is
-- for -- fixes a real regression where ANY location's session ending force-
-- closed a puzzle GUI open at a totally different, unrelated location
-- (the same class of missing-location-check bug this project has already
-- hit once with OpenCloseBarrier). Matches the Safe GUI's own equivalent
-- check a few lines above (payload.location == "Bank"), except LockedDoor
-- exists at TWO locations, so it compares against the CURRENT attempt's own
-- location instead of a single hardcoded string.
remotes:WaitForChild("HeistState").OnClientEvent:Connect(function(payload)
	if payload.state ~= "Active" and lockpickGui.Enabled and lockpickState and payload.location == lockpickState.location then
		closeLockpickGui()
	end
end)
player.CharacterRemoving:Connect(function()
	if lockpickGui.Enabled then closeLockpickGui() end
end)

local function formatClock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	-- The location whose heavy loot (the ripped ATM, the gold bar) this character carries, or nil.
	local liveCharacter = player.Character
	local carryLocation = liveCharacter and liveCharacter:GetAttribute(CARRY_GETAWAY_ATTRIBUTE)

	for _, location in ipairs(LOCATIONS) do
		local session = sessionStates[location]
		local timer = timerWidgets[location]
		local timerLabel = timer.root

		-- Read once per location per frame, alongside the other per-location state
		-- above (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19): the duffel
		-- widget and the getaway distance further down both consume it, and neither
		-- should call extrapolate a second time to reach it.
		local duffel = duffelStates[location]
		-- Heist layers 2026-11-17: a bonus (BankInstance:AddBonus) can put the bag over its cap;
		-- extrapolate clamps at the cap, so keep the real base. The fill ratio below still clamps.
		local amount = math.max(duffel.base, extrapolate(duffel.base, duffel.rate, duffel.since, now, duffel.cap))

		-- WHICH location's timer is on screen is decided once, after this loop has
		-- closed, in the same pass that picks the getaway widget's location -- see
		-- the comment there for why exactly one may ever be visible. This block only
		-- keeps every location's clock face current; a hidden one costs a string
		-- format and nothing else.
		if session.state == "Active" and session.endsAt then
			local remaining = session.endsAt - now
			timer.time.Text = formatClock(remaining)
			-- Under a minute swaps the WHOLE slice, not just the text colour: the
			-- accent edge and the "TIME REMAINING" caption are baked into the
			-- image, so they can only go red by swapping to the urgent bake.
			-- Guarded on an actual change -- this runs every frame, and
			-- reassigning ImageLabel.Image re-triggers a texture fetch.
			local urgent = remaining < 60
			local wantImage = urgent and UITheme.Assets.TimerUrgent or UITheme.Assets.TimerNormal
			if timerLabel.Image ~= wantImage then
				timerLabel.Image = wantImage
				timer.time.TextColor3 = urgent and UITheme.Color.danger or UITheme.Color.accent
			end
		end

		local widget = duffelWidgets[location]
		-- Unlike the timer, duffel visibility is NOT zone-gated: the bag now
		-- banks a fixed distance clear of the building, so the whole escape that
		-- decides whether it pays out is spent OUTSIDE every zone. A zone-gated
		-- duffel would blank out for exactly that stretch, hiding the running
		-- total at the moment it matters most.
		local wantDuffel = amount > 0 or duffel.rate > 0
		if wantDuffel and not duffelShown[location] then
			duffelShown[location] = true
			UITransitions.SlideIn(widget.root, DUFFEL_POSITION, "Left")
		elseif not wantDuffel and duffelShown[location] then
			duffelShown[location] = false
			UITransitions.SlideOut(widget.root, DUFFEL_POSITION, "Left")
		end
		if wantDuffel then
			-- Guard the divide: cap is 0 until the first SendDuffel arrives.
			local ratio = duffel.cap > 0 and math.clamp(amount / duffel.cap, 0, 1) or 0
			setFillRatio(widget, ratio)
			-- The >= comparison, and the fire-once guard around the cue, are
			-- byte-for-byte the original behaviour -- only the presentation
			-- moved from one label's Text to the header/bar/amount trio.
			-- The FULL state swaps to a second slice rather than recolouring: its
			-- "DUFFEL FULL" header is baked in gold, so no runtime tint reproduces
			-- it. Guarded on an actual change, same reason as the timer above.
			-- The >= comparison and the fire-once cue guard are byte-for-byte the
			-- original behaviour.
			local full = amount >= duffel.cap
			local wantImage = full and UITheme.Assets.DuffelFull or UITheme.Assets.DuffelPanel
			if widget.root.Image ~= wantImage then
				widget.root.Image = wantImage
				widget.fill.BackgroundColor3 = full and UITheme.Color.gold or UITheme.Color.accent
				widget.amount.TextColor3 = full and UITheme.Color.gold or UITheme.Color.accent
			end
			if full then
				widget.amount.Text = string.format("%s / %s", commas(amount), commas(duffel.cap))
				if not duffelFullPlayed[location] then
					duffelFullPlayed[location] = true
					playCue("DuffelFullSound")
				end
			else
				widget.amount.Text = string.format("%s / %s", commas(amount), commas(duffel.cap))
			end
		end

		-- Getaway distance (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19).
		-- Computed locally every frame from the same inputs the server's own
		-- Getaway service uses, rather than pushed per-tick -- same reasoning
		-- as the lockpick needle's local animation.
		--
		-- HORIZONTAL only, Y zeroed on both vectors: every StatusBillboardAnchor
		-- floats 40-120 studs above its building so the badge reads from ground
		-- level, and a 3D distance would credit that height as escape progress.
		-- Getaway.horizontalDistance drops Y for precisely this reason; so does
		-- this, or the two would disagree by the anchor's height.
		--
		-- `not zoneOccupancy[location]` is this client's mirror of the server's
		-- isInsideBuilding gate. Every location broadcasts that flag from the very
		-- same expression its Getaway service is handed -- including the Bank's
		-- three-role Lobby/Vault/BankVaultZone union -- so what is rendered here
		-- cannot disagree with the gate that actually banks the bag.
		local anchor = locationAnchors[location]
		local escapeDistance = escapeDistances[location]
		local character = player.Character
		local characterRoot = character and character.PrimaryPart

		-- A heavy carry counts like a bag here (2026-11-18): CarryGetaway banks it at the same distance from the
		-- same anchor once out of the building, with or without an Active session, so the widget follows it.
		local remaining = nil
		local hasLoot = (session.state == "Active" and amount > 0) or carryLocation == location
		if anchor and characterRoot and escapeDistance and hasLoot and not zoneOccupancy[location] then
			local here = Vector3.new(characterRoot.Position.X, 0, characterRoot.Position.Z)
			local there = Vector3.new(anchor.Position.X, 0, anchor.Position.Z)
			remaining = math.max(0, escapeDistance - (here - there).Magnitude)
		end
		getawayRemaining[location] = remaining

		-- Status badge ring: a plain colour swap off the same session.state this
		-- loop already reads. No tween by spec -- the slide animation belongs to
		-- the notification cards, not these.
		local badgeImage = billboardImages[location]
		if badgeImage then
			local asset = BILLBOARD_STATE_IMAGES[session.state]
			if asset and badgeImage.Image ~= asset then
				badgeImage.Image = asset
			end
		end
	end

	-- Exactly ONE getaway widget may be driven at a time (spec:
	-- Getaway-Distance-Claim-And-GUI, 2026-09-19). Every location's HUD elements
	-- rest at the same on-screen slot as each other, and escaping is BY
	-- DEFINITION outside every zone, so two concurrent sessions would stack two
	-- getaway widgets on the same pixels. The nearest one to banking wins, since
	-- that is the one whose number is about to matter. The timer resolved just
	-- below inherits this choice, for exactly the same reason -- see there.
	local urgentLocation, urgentRemaining = nil, math.huge
	for _, location in ipairs(LOCATIONS) do
		local remaining = getawayRemaining[location]
		if remaining ~= nil and remaining < urgentRemaining then
			urgentLocation, urgentRemaining = location, remaining
		end
	end

	-- Exactly ONE timer may be visible either, and for the very same reason:
	-- every location's timer rests at TIMER_POSITION, so two would stack on the
	-- same pixels. That used to come for free from gating on zoneOccupancy alone,
	-- since a player can only be physically inside one location's zone -- but the
	-- 2026-09-19 escape requirement needs the clock to stay up while they are
	-- OUTSIDE every zone, and a bare "or amount > 0" would have rendered one timer
	-- per location the player happened to be carrying a bag from.
	--
	-- So the two rules of the escape HUD are resolved together, here: standing
	-- inside a zone wins, because that is the robbery the player is physically at
	-- and physics already makes it unique; otherwise the timer follows the getaway
	-- widget's own choice, so the clock and the studs-remaining always describe the
	-- SAME robbery instead of two different ones.
	--
	-- The Active/endsAt conditions are unchanged from before. endsAt is re-checked
	-- on the urgentLocation branch because the getaway pass above does not look at
	-- it. And cooldown is still never displayed (spec addendum, 2026-09-06): the
	-- OpenCloseBarrier is what tells the player a location is sealed, and "a heist
	-- is active somewhere" remains insufficient on its own to put a clock up.
	local timerLocation = nil
	for _, location in ipairs(LOCATIONS) do
		local session = sessionStates[location]
		if session.state == "Active" and session.endsAt ~= nil and zoneOccupancy[location] then
			timerLocation = location
			break
		end
	end
	if timerLocation == nil and urgentLocation ~= nil then
		local session = sessionStates[urgentLocation]
		if session.state == "Active" and session.endsAt ~= nil then
			timerLocation = urgentLocation
		end
	end

	for _, location in ipairs(LOCATIONS) do
		-- Edge-triggered exactly as before: SlideIn/SlideOut fire once PER
		-- TRANSITION, never once per frame while already shown/hidden. Only the
		-- decision feeding them moved.
		local wantTimer = (location == timerLocation)
		if wantTimer and not timerShown[location] then
			timerShown[location] = true
			UITransitions.SlideIn(timerWidgets[location].root, TIMER_POSITION, "Top")
		elseif not wantTimer and timerShown[location] then
			timerShown[location] = false
			UITransitions.SlideOut(timerWidgets[location].root, TIMER_POSITION, "Top")
		end
	end

	for _, location in ipairs(LOCATIONS) do
		local widget = getawayWidgets[location]
		-- Same edge-triggered guard the timer and duffel use for their own SLIDE
		-- transitions: SlideIn/SlideOut must fire once PER TRANSITION, never once
		-- per frame while already shown/hidden, or the tween restarts every frame
		-- and never finishes. The fill bar has a separate edge guard of its own,
		-- inside setFillRatio -- see the quantisation below, without which that one
		-- would never fire here.
		local wantGetaway = (location == urgentLocation)
		if wantGetaway and not getawayShown[location] then
			getawayShown[location] = true
			-- Empty the bar on the SHOW edge, immediately before the slide-in.
			-- setFillRatio is never called for a widget that is not the urgent one,
			-- so _lastRatio and the fill's Size would otherwise keep whatever they
			-- last held -- 1.0 after a successful bank -- and this session would
			-- slide in showing a FULL bar that then drains over 0.25s, reading as
			-- "you have already escaped". Resetting here rather than on the hide
			-- edge makes it invisible BY CONSTRUCTION: the widget is still parked
			-- off-screen at this point, where on the hide edge it is mid-slide-out
			-- and still on screen. Written straight to Size rather than through
			-- setFillRatio so it does not tween, and any in-flight fill tween is
			-- cancelled first -- same discipline as setFillRatio's own
			-- cancel-before-replace, or it would keep running and overwrite this.
			if widget._fillTween then
				pcall(function() widget._fillTween:Cancel() end)
				widget._fillTween = nil
			end
			widget._lastRatio = 0
			widget.fill.Size = UDim2.new(0, 0, 1, 0)
			UITransitions.SlideIn(widget.root, GETAWAY_POSITION, "Left")
		elseif not wantGetaway and getawayShown[location] then
			getawayShown[location] = false
			UITransitions.SlideOut(widget.root, GETAWAY_POSITION, "Left")
		end
		if wantGetaway then
			local escapeDistance = escapeDistances[location]
			-- CEIL, not the floor commas() would otherwise apply: the server banks at
			-- travelled >= escapeDistance, i.e. remaining <= 0, so flooring puts a "0"
			-- on screen under a full bar for the last stud of the run while no payout
			-- has happened, and the player reads that as broken. Ceiling holds it at 1
			-- until the bank actually fires. commas() still does the grouping.
			widget.studs.Text = commas(math.ceil(urgentRemaining))
			-- Progress COVERED, not progress left, so the bar fills as they run.
			-- Guard the divide: escapeDistance is only ever nil here if that
			-- location's config failed to resolve, which already warned above.
			local ratio = (escapeDistance and escapeDistance > 0)
				and math.clamp(1 - urgentRemaining / escapeDistance, 0, 1)
				or 0
			-- The bar is GETAWAY_BAR_WIDTH px wide, so quantise to its pixel
			-- resolution: a change smaller than one pixel cannot be seen, and passing
			-- it through would defeat setFillRatio's edge guard -- unlike the duffel,
			-- whose ratio is constant between discrete grants, this input varies
			-- continuously with distance, so the raw value differs on almost every
			-- frame the player moves and the guard would never fire: ~60 Tween
			-- Instances a second for the whole escape run instead of at most
			-- GETAWAY_BAR_WIDTH for the entire thing.
			ratio = math.floor(ratio * GETAWAY_BAR_WIDTH) / GETAWAY_BAR_WIDTH
			setFillRatio(widget, ratio)
			-- Near-complete swaps the WHOLE slice, not just the text colour, for
			-- the same reason the timer's urgent state does: the accent edge and
			-- the baked caption can only change with the bake. Guarded on an
			-- actual change -- this runs every frame, and reassigning
			-- ImageLabel.Image re-triggers a texture fetch.
			local near = escapeDistance ~= nil and urgentRemaining <= escapeDistance * 0.25
			local wantImage = near and UITheme.Assets.GetawayNear or UITheme.Assets.GetawayNormal
			if widget.root.Image ~= wantImage then
				widget.root.Image = wantImage
				widget.studs.TextColor3 = near and UITheme.Color.gold or UITheme.Color.accent
				widget.fill.BackgroundColor3 = near and UITheme.Color.gold or UITheme.Color.accent
			end
		end
	end

	-- Edge-triggered, same as timer/duffel above: Visible stays true for the
	-- WHOLE slide-out animation (SlideOut only flips it false on completion),
	-- so calling SlideOut unconditionally every frame while expired would
	-- cancel-and-restart the tween every frame and it would never finish.
	if toastShown and now > toastUntil then
		toastShown = false
		UITransitions.SlideOut(toastRoot, TOAST_POSITION, "Bottom")
	end
end)
