--!strict
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

-- Screen-space cash burst + flying-cash-to-GUI sequence (spec addendum,
-- 2026-09-09), shared verbatim between the Bank and SlowFoods claim flows --
-- both fire the same Net:NotifyRobberySuccess trigger, so one client
-- listener (HeistClient) drives this one module regardless of location.
local CashClaimVFX = {}
CashClaimVFX.__index = CashClaimVFX

-- Real cash/money decal (spec addendum, 2026-09-10), replacing the earlier
-- procedurally-built gold-chip placeholder now that a real asset exists.
-- The first supplied ID (18885492728) failed to load in this environment
-- (confirmed via ContentProvider:GetAssetFetchStatus returning Failure, for
-- both ImageLabel.Image and Decal.Texture) -- this replacement ID was
-- confirmed to load successfully the same way before being wired in here.
-- Swapped to the redesign's accent coin (2026-09-18), exported from the same
-- Figma slice set as the rest of the chrome so the burst matches the HUD it
-- flies into. The previous decal stays documented here because it was itself a
-- replacement for an ID that failed to load: "rbxassetid://18885492705".
-- Read from UITheme rather than duplicated here, so a re-upload of the slice
-- set cannot leave this one ID pointing at a stale (or, as in the v1 batch,
-- non-transparent) asset while every other surface moves on.
local COIN_IMAGE_ID = nil :: string?

local DEFAULT_BURST_COUNT = 20
local DEFAULT_SCATTER_TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local DEFAULT_FLY_TWEEN = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local SCATTER_RADIUS_MIN, SCATTER_RADIUS_MAX = 70, 160
-- Randomized per-icon delay before the fly phase starts, so icons land in a
-- trickling sequence rather than all arriving in the same instant -- this is
-- what gives the counter its "ticking up" feel rather than a single jump.
local DEFAULT_FLY_STAGGER_MAX = 0.25
-- Default burst origin (screen center) when no confirmation-GUI position is
-- supplied (e.g. in tests) -- production always passes deps.burstOrigin,
-- the real claim-confirmation toast's on-screen center (spec addendum,
-- 2026-09-10).
local DEFAULT_BURST_ORIGIN = UDim2.new(0.5, 0, 0.5, 0)
-- Root-caused live, 2026-09-10: leaderstats.Cash's property replication was
-- observed consistently arriving and firing the passive listener BEFORE the
-- RobberySuccess RemoteEvent -- even though the server fires the property
-- write first and the remote second, property replication and RemoteEvents
-- are separate channels with no ordering guarantee between them. This grace
-- window lets the passive listener stand aside long enough for a same-claim
-- RobberySuccess to arrive and take ownership via _animating -- confirmed
-- live to be more than enough margin (RobberySuccess arrived within one
-- frame of the property change in every observed case).
local PASSIVE_LISTENER_GRACE = 0.05

-- Anchored top-right, matching the rest of this project's HUD corner
-- conventions. Kept as named constants (not just baked into _buildPersistentGui)
-- since _targetPosition needs this frame's own on-screen CENTER to fly icons
-- toward, and the two must never drift apart.
local CASH_FRAME_ANCHOR = Vector2.new(1, 0)
local CASH_FRAME_POSITION = UDim2.new(1, -12, 0, 12)
-- 268x76 -- the adopted CashHUD slice from the FPS library, reused verbatim
-- rather than rebuilt, so the merged game has ONE cash widget.
local CASH_FRAME_SIZE = UDim2.new(0, 268, 0, 76)

-- Icon + value layout inside the card. Offsets only, so they stay put at any
-- viewport size -- same treatment as the duffel widget's own internals.
-- Matches the baked slice exactly: the money-stack icon sits at (18,20) and
-- the "CASH" caption at (68,42), both painted into the image. Only the value
-- above them is live.
local CASH_VALUE_INSET = 68
local CASH_VALUE_TOP = 10

-- Roblox has no built-in thousands-separator formatting. Reverse, group every
-- three digits, reverse back, then drop the comma the grouping leaves on a
-- length-divisible-by-3 value ("123" -> ",123").
local function formatWithCommas(value: number): string
	local digits = tostring(math.max(0, math.floor(value)))
	local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (grouped:gsub("^,", ""))
end

local function defaultGetCash(player)
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	return (cash and cash.Value) or 0
end

local COIN_SIZE: Vector2? = nil

local function makeCoin(parent: Instance, position: UDim2)
	if not COIN_IMAGE_ID then
		local UITheme = require(script.Parent:WaitForChild("UITheme"))
		COIN_IMAGE_ID = UITheme.Assets.Coin
		-- Size comes from the theme too. It was hardcoded at 40 while the theme said 48 -- the
		-- exact kind of drift that put stale panel art on screen earlier in this project.
		COIN_SIZE = UITheme.Size.Coin
	end
	local coin = Instance.new("ImageLabel")
	coin.AnchorPoint = Vector2.new(0.5, 0.5)
	coin.Position = position
	coin.Size = UDim2.fromOffset((COIN_SIZE :: Vector2).X, (COIN_SIZE :: Vector2).Y)
	coin.BackgroundTransparency = 1
	coin.Image = COIN_IMAGE_ID
	coin.Parent = parent
	return coin
end

-- deps.player: optional -- only needed to derive a default playerGui/getCash
-- and to drive the passive leaderstats listener (initial load / any non-
-- claim change). Tests can omit it and supply playerGui/getCash directly.
-- deps.playerGui: defaults to player:WaitForChild("PlayerGui").
-- deps.getCash: defaults to reading player.leaderstats.Cash.Value; always
-- the SERVER-AUTHORITATIVE source of truth PlaySequence animates toward --
-- never computed by adding the claimed amount client-side, so the displayed
-- total can never drift from the real balance.
function CashClaimVFX.new(deps)
	deps = deps or {}
	local player = deps.player or Players.LocalPlayer
	local playerGui = deps.playerGui or (player and player:WaitForChild("PlayerGui"))
	assert(playerGui, "CashClaimVFX requires deps.playerGui (or deps.player to derive it from)")
	local getCash = deps.getCash or function()
		assert(player, "CashClaimVFX requires deps.getCash or deps.player")
		return defaultGetCash(player)
	end

	local self = setmetatable({
		player = player,
		playerGui = playerGui,
		getCash = getCash,
		burstCount = deps.burstCount or DEFAULT_BURST_COUNT,
		scatterTweenInfo = deps.scatterTweenInfo or DEFAULT_SCATTER_TWEEN,
		flyTweenInfo = deps.flyTweenInfo or DEFAULT_FLY_TWEEN,
		flyStaggerMax = deps.flyStaggerMax or DEFAULT_FLY_STAGGER_MAX,
		burstOrigin = deps.burstOrigin or DEFAULT_BURST_ORIGIN,
		passiveListenerGrace = deps.passiveListenerGrace or PASSIVE_LISTENER_GRACE,
		_displayedValue = 0,
		_animating = false,
	}, CashClaimVFX)

	self:_buildPersistentGui()
	self._displayedValue = getCash()
	self:_render()

	if player then
		local cash = self:_findCashValue()
		if cash then
			self._cashConn = cash:GetPropertyChangedSignal("Value"):Connect(function()
				local value = cash.Value
				-- Grace window (see PASSIVE_LISTENER_GRACE above): give a
				-- same-claim RobberySuccess a chance to arrive and claim
				-- ownership via _animating before this applies an instant,
				-- unanimated jump. Re-checks _animating AFTER waiting, not
				-- before, so it actually observes whatever PlaySequence does
				-- in the meantime.
				task.wait(self.passiveListenerGrace)
				if self._animating then return end
				if self._displayedValue == value then return end
				self._displayedValue = value
				self:_render()
			end)
		end
	end

	return self
end

function CashClaimVFX:_findCashValue()
	if not self.player then return nil end
	local stats = self.player:FindFirstChild("leaderstats")
	return stats and stats:FindFirstChild("Cash")
end

-- City (phase 3 G5): one cash display, the city's PlayerGui["Custom Inventory"].cashDisplay
-- (driven by StarterPlayerScripts.CashHud). This module no longer builds its own CashDisplay;
-- it only finds the city frame (10 s timeout, without blocking the constructor) to fly coins to.
function CashClaimVFX:_buildPersistentGui()
	task.spawn(function()
		local inventory = self.playerGui:WaitForChild("Custom Inventory", 10)
		self._cashTarget = inventory and inventory:WaitForChild("cashDisplay", 10) :: GuiObject?
	end)
end

-- The readout belongs to the city's CashHud; _displayedValue only paces the claim sequence.
function CashClaimVFX:_render()
end

-- Centre of the city cash frame (AbsolutePosition + AbsoluteSize / 2), as an offset inside
-- `space` (the burst ScreenGui), so inset settings of either ScreenGui cancel out.
-- nil when the frame is absent: the coins then fade where they scattered (no fly-to).
function CashClaimVFX:_targetPosition(space: GuiBase2d?): UDim2?
	local target = self._cashTarget
	if not (target and target.Parent) then return nil end
	local centre = target.AbsolutePosition + target.AbsoluteSize / 2
	local base = space and space.AbsolutePosition or Vector2.zero
	return UDim2.fromOffset(centre.X - base.X, centre.Y - base.Y)
end

-- Plays the full burst -> fly -> incremental-counter sequence, ending with
-- the display at EXACTLY the real leaderstats.Cash.Value -- read fresh here,
-- never computed by adding the claimed amount, so this can never drift from
-- the server-authoritative balance (spec addendum, 2026-09-09).
function CashClaimVFX:PlaySequence()
	-- Guards against a double-fire: RobberySuccess and the passive
	-- leaderstats listener (after its grace window) both call this for the
	-- SAME claim as a deliberate redundancy -- whichever runs first wins and
	-- owns the sequence; the other must no-op rather than stacking a second
	-- burst on top.
	if self._animating then return end

	local newValue = self.getCash()
	local oldValue = self._displayedValue
	if newValue == oldValue then return end -- nothing to animate

	self._animating = true

	local burstGui = Instance.new("ScreenGui")
	burstGui.Name = "CashBurst"
	burstGui.ResetOnSpawn = false
	burstGui.IgnoreGuiInset = true
	burstGui.Parent = self.playerGui

	local origin = self.burstOrigin

	local arrived = 0
	local total = self.burstCount

	for _ = 1, total do
		local coin = makeCoin(burstGui, origin)

		local angle = math.random() * math.pi * 2
		local radius = SCATTER_RADIUS_MIN + math.random() * (SCATTER_RADIUS_MAX - SCATTER_RADIUS_MIN)
		-- Relative to `origin` itself, not hardcoded screen center -- otherwise
		-- a non-center burstOrigin (e.g. the claim-confirmation toast) would
		-- spawn icons at the right spot but immediately misdirect them toward
		-- screen center for the scatter phase instead of outward from where
		-- they actually started.
		local scatterPos = UDim2.new(
			origin.X.Scale, origin.X.Offset + math.cos(angle) * radius,
			origin.Y.Scale, origin.Y.Offset + math.sin(angle) * radius
		)

		local scatterTween = TweenService:Create(coin, self.scatterTweenInfo, {
			Position = scatterPos,
			Rotation = (math.random() - 0.5) * 180,
		})

		local scatterConn
		scatterConn = scatterTween.Completed:Connect(function()
			scatterConn:Disconnect()
			task.delay(math.random() * self.flyStaggerMax, function()
				if not coin.Parent then return end -- burst already torn down (e.g. Destroy() mid-sequence)
				local flyGoal: { [string]: any } = {
					Size = UDim2.new(0, 6, 0, 6),
					ImageTransparency = 1,
				}
				local target = self:_targetPosition(burstGui)
				if target then flyGoal.Position = target end
				local flyTween = TweenService:Create(coin, self.flyTweenInfo, flyGoal)
				local flyConn
				flyConn = flyTween.Completed:Connect(function()
					flyConn:Disconnect()
					coin:Destroy()
					arrived += 1
					self._displayedValue = oldValue + math.floor((newValue - oldValue) * (arrived / total))
					self:_render()

					if arrived >= total then
						-- Force-set to the exact true value, never trusting the
						-- interpolated math above to land exactly on it (integer
						-- division across `total` icons can round short by 1-2).
						self._displayedValue = newValue
						self:_render()
						if burstGui.Parent then burstGui:Destroy() end
						self._animating = false
					end
				end)
				flyTween:Play()
			end)
		end)
		scatterTween:Play()
	end
end

function CashClaimVFX:Destroy()
	if self._cashConn then self._cashConn:Disconnect() end
	if self._gui then self._gui:Destroy() end
end

return CashClaimVFX
