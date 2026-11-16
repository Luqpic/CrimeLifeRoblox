--!strict
-- Global robbery notifications (spec addendum): a bottom-right stack of
-- toast-style cards, shown to EVERY player when a location re-opens or when
-- someone successfully triggers a robbery. Drives the pre-built
-- StarterGui.HeistNotificationGui (authored once via execute_luau, matching this
-- project's "never runtime Instance.new() for custom GUIs" convention) by
-- cloning its hidden NotificationTemplate card.
--
-- Its own file rather than more growth in HeistClient.lua, matching the recent
-- one-LocalScript-per-feature precedent (WordScrambleClient).
--
-- Purely presentational: both remotes are ToClient-only and nothing here ever
-- talks back to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITransitions = require(ReplicatedStorage.SharedSystems.UITransitions)
local HeistConfig = require(ReplicatedStorage.HeistShared.Config)

local shared = ReplicatedStorage:WaitForChild("HeistShared")
local remotes = shared:WaitForChild("Remotes")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = playerGui:WaitForChild("HeistNotificationGui") -- renamed in the city (phase 3 G6): the city builds its own NotificationGui
local template = gui:WaitForChild("NotificationTemplate")

-- Matches the existing Toast's own 5-second dwell (HeistClient sets
-- toastUntil = now + 5) so the two feedback channels agree.
local DISPLAY_DURATION = 5

local TextService = game:GetService("TextService")

local CARD_WIDTH = template.Size.X.Offset
local CARD_GAP = 8

-- Layout constants matching the exported chrome slice. The baked accent edge
-- occupies x 14..20, so content starts at 28.
local BODY_X, BODY_W = 28, 330
local BODY_TOP = 48
local ALARM_GAP, ALARM_H = 6, 26
local BOTTOM_PAD = 18

-- Adaptive height (2026-09-18): the card used to have exactly two hardcoded
-- heights, so a long location name simply overflowed. It is now measured from
-- the body text it actually has to render.
local function measureBody(plainText: string): number
	local params = Instance.new("GetTextBoundsParams")
	params.Text = plainText
	params.Font = template.Body.FontFace
	params.Size = template.Body.TextSize
	params.Width = BODY_W
	local ok, bounds = pcall(function() return TextService:GetTextBoundsAsync(params) end)
	if ok and bounds then
		return math.max(24, math.ceil(bounds.Y))
	end
	return 24 -- measurement is best-effort; never let it take the notification down
end

-- RichText markup inflates a measurement, so tags are stripped before sizing.
local function stripTags(s: string): string
	return (s:gsub("<[^>]->", ""))
end

-- Both variants (with and without AlarmBox) are now sized from their own
-- content inside show() below, so the old fixed height pair is gone -- having
-- exactly two hardcoded heights is what made a long body overflow its card.
local INSET_X = 16
-- Cleared vertically above DropSuppliesButton rather than merely beside it.
-- That button is bottom-CENTRE (AnchorPoint 0.5,1 at Y = 1,-40, 160x40), so a
-- right-anchored 300px stack misses it on a wide viewport but WOULD collide on
-- a narrow one. Sitting above its top edge (1,-80) is resolution-independent.
-- City (phase 3 Task 4): 90 -> 108, so the stack's bottom sits on the top edge of the city
-- NotificationGui.Container (anchored 1,1 at 1,-24, 84 tall: top at 1,-108) at every screen size.
local INSET_Y = 108

-- Newest first: index 1 is the card closest to the corner, older cards are
-- pushed upward as new ones arrive.
local cards: { Frame } = {}

-- Accumulates each card's OWN height rather than assuming one shared constant.
-- With two variants of different heights, a fixed CARD_HEIGHT would overlap or
-- gap the stack depending purely on the order the two kinds arrived in.
local function restingPosition(index: number): UDim2
	local offset = 0
	for i = 1, index - 1 do
		offset += cards[i].Size.Y.Offset + CARD_GAP
	end
	return UDim2.new(1, -INSET_X, 1, -INSET_Y - offset)
end

-- Re-targets EVERY live card, not just the new one. UITransitions.SlideIn only
-- snaps to its off-screen start when the frame is not already Visible, so an
-- on-screen card handed a new resting position tweens smoothly from where it
-- currently is -- which is exactly the "shift up to make room" / "close the
-- gap" motion, with no extra animation code here.
local function reflow()
	for index, card in ipairs(cards) do
		UITransitions.SlideIn(card, restingPosition(index), "Bottom")
	end
end

local function dismiss(card: Frame)
	local index = table.find(cards, card)
	if not index then return end -- already dismissed
	table.remove(cards, index)

	-- Slid out from wherever it currently rests, then destroyed only once the
	-- module has actually finished hiding it (SlideOut flips Visible on the
	-- tween's own completion, never mid-slide). Read off the card itself rather
	-- than recomputed: it has just been removed from `cards`, and with variable
	-- heights a recomputed index no longer describes where this card actually is.
	local restingAtDismissal = card.Position
	UITransitions.SlideOut(card, restingAtDismissal, "Bottom")

	local connection
	connection = card:GetPropertyChangedSignal("Visible"):Connect(function()
		if card.Visible then return end
		connection:Disconnect()
		card:Destroy()
	end)

	-- The survivors close the gap immediately rather than waiting for the
	-- departing card's slide-out to finish.
	reflow()
end

-- player.Name is always alphanumeric/underscore, so this cannot currently be
-- escaped-into, but the body label is RichText and composing untrusted-ish
-- text into markup without escaping is the kind of thing that only stays safe
-- by accident.
local function escapeRichText(s: string): string
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function show(bodyRichText: string, withAlarmBox: boolean?)
	local card = template:Clone()
	card.Name = "Notification"
	card.Visible = false
	local body = card:FindFirstChild("Body") :: TextLabel
	body.Text = bodyRichText
	body.TextWrapped = true

	-- Measure, then lay the card out around the text rather than forcing the
	-- text into a fixed box.
	local bodyHeight = measureBody(stripTags(bodyRichText))
	body.Position = UDim2.fromOffset(BODY_X, BODY_TOP)
	body.Size = UDim2.fromOffset(BODY_W, bodyHeight)

	local cardHeight
	local alarmBox = card:FindFirstChild("AlarmBox")
	if withAlarmBox and alarmBox then
		alarmBox.Visible = true
		alarmBox.Position = UDim2.fromOffset(BODY_X, BODY_TOP + bodyHeight + ALARM_GAP)
		alarmBox.Size = UDim2.fromOffset(BODY_W, ALARM_H)
		cardHeight = BODY_TOP + bodyHeight + ALARM_GAP + ALARM_H + BOTTOM_PAD
	else
		if alarmBox then alarmBox.Visible = false end
		cardHeight = BODY_TOP + bodyHeight + BOTTOM_PAD
	end
	card.Size = UDim2.fromOffset(CARD_WIDTH, cardHeight)

	card.Parent = gui

	table.insert(cards, 1, card)
	reflow()

	task.delay(DISPLAY_DURATION, function()
		dismiss(card)
	end)
end

local function phraseFor(location: string): string
	return HeistConfig.LocationPhrase[location] or location
end

local function capitalize(s: string): string
	return (s:gsub("^%l", string.upper))
end

remotes:WaitForChild("LocationOpened").OnClientEvent:Connect(function(location)
	if type(location) ~= "string" then return end
	local phrase = capitalize(phraseFor(location))
	show(string.format("<b>%s</b> is open.", escapeRichText(phrase)))
end)

remotes:WaitForChild("RobberyTriggered").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	local location, playerName = payload.location, payload.playerName
	if type(location) ~= "string" or type(playerName) ~= "string" then return end
	show(string.format("<b>%s</b> is robbing %s.",
		escapeRichText(playerName), escapeRichText(phraseFor(location))), true)
end)
