-- Bottom-right stacked-card notification toast. `show` clones the template, arrives it as the
-- front card, then re-seats every older card one layer back so the stack always reads like a
-- physical pile of cards rather than a list. There is no UIListLayout here on purpose: a list
-- owns the position (and often the size) of what it stacks, which would fight every re-seat tween
-- below on the very next layout pass.
--
-- The ScreenGui and container are built once, the first time any client requires this module; Luau
-- caches the module table per client, so every later require anywhere shares the same stack without
-- the callers having to coordinate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Panels = require(ReplicatedStorage.UI:WaitForChild("Panels"))

local HOLD_TIME = 4 -- unchanged from the old list version: time a card stays fully readable
local ARRIVAL_TIME = 0.22
local RESEAT_TIME = 0.18
local EXPIRE_TIME = 0.18
local MAX_VISIBLE = 3
-- 420x100 was sized for copy this card never carries: a gain toast is one title word and one short
-- line ("+7 Spraypaint"). 280x64 is the smallest size the Notification template's labels still read
-- well at -- checked live against TitleLabel/MessageLabel's own layout.
local CARD_WIDTH = 280
local CARD_HEIGHT = 64
local DEPTH_Y_STEP = 10 -- each older card sits this much higher than the one in front of it
local DEPTH_INSET_STEP = 14 -- ...and this much narrower on each side
local ARRIVAL_OFFSET_X = 40 -- new/expiring cards travel this far past their resting X
local RIGHT_MARGIN = 20
-- The ammo/weapon HUD moved to middle-right (see GuiController), so bottom-right belongs to this
-- stack alone now -- the margin only has to clear the screen edge, not dodge another HUD element.
local BOTTOM_MARGIN = 24

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local gui = Instance.new("ScreenGui")
gui.Name = "NotificationGui"
-- Every GUI in this game opts out of respawn reset. It matters more here than most: this module is
-- required once and holds a reference to the container below, which a reset would destroy and leave
-- every later notification parented to nothing.
gui.ResetOnSpawn = false
gui.Parent = playerGui

-- UIScaleController skips any ScreenGui that already ships its own UIScale ("a GUI that already
-- ships its own UIScale owns its own scaling policy") -- this card is already sized to read well,
-- so it opts out rather than being blown up to match its widest offset-sized sibling on wide screens.
local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = gui

local container = Instance.new("Frame")
container.Name = "Container"
container.BackgroundTransparency = 1
container.AnchorPoint = Vector2.new(1, 1)
container.Position = UDim2.new(1, -RIGHT_MARGIN, 1, -BOTTOM_MARGIN)
container.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT + DEPTH_Y_STEP * (MAX_VISIBLE - 1))
container.Parent = gui

local ARRIVE_INFO = TweenInfo.new(ARRIVAL_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local RESEAT_INFO = TweenInfo.new(RESEAT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EXPIRE_INFO = TweenInfo.new(EXPIRE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In)

-- Newest-first: stack[1] is always the front card (depth 0, full detail, highest ZIndex).
local stack = {}

-- Depth 0 is the front card at full width; each step back is narrower (inset on both sides) and
-- higher (peeking out above the card in front), with `dim` fading the whole card -- background and
-- content together (see reseat) -- so a receded card reads as fainter, never as a blank plate with
-- its text switched off underneath a background that is still most of the way opaque.
local function depthGeometry(depth: number)
	local inset = DEPTH_INSET_STEP * depth
	local position = UDim2.new(1, -inset, 1, -DEPTH_Y_STEP * depth)
	local size = UDim2.fromOffset(CARD_WIDTH - inset * 2, CARD_HEIGHT)
	local dim = math.min(depth * 0.3, 0.6)
	return position, size, dim
end

local function reseat(card, depth: number, tweenInfo: TweenInfo)
	local position, size, dim = depthGeometry(depth)
	-- ZIndex isn't tweenable and doesn't need to be: siblings under the same parent (the
	-- container) already draw in ZIndex order, so setting it once here is enough.
	card.instance.ZIndex = MAX_VISIBLE + 1 - depth

	-- Content shares the background's own `dim` instead of snapping straight to hidden. Live-measured
	-- (two cards fired back to back): the old snap left a depth-1 card at 70% opaque with title and
	-- message both at full transparency -- a large, blank-looking plate. That is the reported bug.
	local contentTransparency = dim

	TweenService:Create(card.instance, tweenInfo, {
		Position = position,
		Size = size,
		BackgroundTransparency = dim,
	}):Play()
	TweenService:Create(card.titleLabel, tweenInfo, { TextTransparency = contentTransparency }):Play()
	TweenService:Create(card.messageLabel, tweenInfo, { TextTransparency = contentTransparency }):Play()
	TweenService:Create(card.accentEdge, tweenInfo, { BackgroundTransparency = contentTransparency }):Play()
end

-- Re-seats every card except `skipIndex` (the one arriving or leaving under its own tween).
local function reflow(tweenInfo: TweenInfo, skipIndex: number?)
	for index, card in ipairs(stack) do
		if index ~= skipIndex then
			reseat(card, index - 1, tweenInfo)
		end
	end
end

local function expireAndDestroy(card)
	if card.dead then
		return
	end
	card.dead = true

	local position = card.instance.Position + UDim2.fromOffset(ARRIVAL_OFFSET_X, 0)
	local tween = TweenService:Create(card.instance, EXPIRE_INFO, {
		Position = position,
		BackgroundTransparency = 1,
	})
	TweenService:Create(card.titleLabel, EXPIRE_INFO, { TextTransparency = 1 }):Play()
	TweenService:Create(card.messageLabel, EXPIRE_INFO, { TextTransparency = 1 }):Play()
	TweenService:Create(card.accentEdge, EXPIRE_INFO, { BackgroundTransparency = 1 }):Play()
	tween.Completed:Connect(function()
		card.instance:Destroy()
	end)
	tween:Play()
end

local NotificationController = {}

-- `title` is the acid headline on the plate. It is optional so every existing single-argument call
-- keeps working unchanged; the Figma plate always shows one, so there is a default rather than a
-- blank line. Split out of the old `show` so `show` itself can queue instead of drawing while a
-- panel is open, with callers none the wiser.
local function displayNow(message: string, title: string?)
	local template = guiTemplates:WaitForChild("Notification")
	local instance = template:Clone()
	instance.Name = "Card"
	instance.AnchorPoint = Vector2.new(1, 1)
	instance.MessageLabel.Text = message
	instance.TitleLabel.Text = title or "NOTICE"
	instance.Parent = container

	local card = {
		instance = instance,
		titleLabel = instance.TitleLabel,
		messageLabel = instance.MessageLabel,
		accentEdge = instance.AccentEdge,
		dead = false,
		expireThread = nil,
	}

	-- Start off-screen to the right and fully transparent -- content included, so it doesn't
	-- flash into view a frame before the tween below catches up with it.
	local restPosition, restSize = depthGeometry(0)
	instance.Position = restPosition + UDim2.fromOffset(ARRIVAL_OFFSET_X, 0)
	instance.Size = restSize
	instance.BackgroundTransparency = 1
	card.titleLabel.TextTransparency = 1
	card.messageLabel.TextTransparency = 1
	card.accentEdge.BackgroundTransparency = 1

	table.insert(stack, 1, card)
	reseat(card, 0, ARRIVE_INFO)
	reflow(RESEAT_INFO, 1)

	-- A fourth card pushes the oldest (now past MAX_VISIBLE, at the tail) out immediately --
	-- always the tail, since every card shares the same HOLD_TIME and so always expires FIFO.
	while #stack > MAX_VISIBLE do
		local evicted = table.remove(stack)
		if evicted.expireThread then
			task.cancel(evicted.expireThread)
			evicted.expireThread = nil
		end
		expireAndDestroy(evicted)
	end

	card.expireThread = task.delay(ARRIVAL_TIME + HOLD_TIME, function()
		card.expireThread = nil
		local index = table.find(stack, card)
		if not index then
			return
		end
		table.remove(stack, index)
		reflow(RESEAT_INFO)
		expireAndDestroy(card)
	end)
end

-- Held back while a panel is open -- the weapon shop's own BUY button sits directly under this
-- stack (measured, not guessed). Capped so a long shopping trip cannot grow this unbounded; the
-- OLDEST is dropped on overflow, since a player who shopped for ten minutes wants their recent
-- gains shown, not the first ones from when they walked in.
local QUEUE_CAP = 8
local FLUSH_STAGGER = 0.12 -- seconds between cards on flush, so they arrive in sequence, not a dump
local queue: { { message: string, title: string? } } = {}
local flushThread: thread? = nil

local function stopFlush()
	if flushThread then
		task.cancel(flushThread)
		flushThread = nil
	end
end

local function flushQueue()
	stopFlush()
	flushThread = task.spawn(function()
		while #queue > 0 do
			local entry = table.remove(queue, 1)
			displayNow(entry.message, entry.title)
			if #queue > 0 then
				task.wait(FLUSH_STAGGER)
			end
		end
		flushThread = nil
	end)
end

-- A panel reopening mid-flush cancels this thread via stopFlush; whatever flushQueue had not yet
-- pulled off `queue` is simply still sitting there, so it re-flushes on the next close for free.
Panels.onChanged(function(current: string?)
	if current == nil then
		flushQueue()
	else
		stopFlush()
	end
end)

function NotificationController.show(message: string, title: string?)
	if Panels.current() ~= nil then
		table.insert(queue, { message = message, title = title })
		if #queue > QUEUE_CAP then
			table.remove(queue, 1) -- oldest dropped, newest kept -- see cap comment above
		end
		return
	end
	displayNow(message, title)
end

return NotificationController
