-- Announces Spraypaint gains through the shared notification module.
--
-- Client-side and driven by the replicated attribute, so no remote is needed: the balance already
-- reaches every client as a player attribute, and NotificationController is a client module.
--
-- Back to ONE attribute watch. The per-weapon version (one connection per catalogued weapon plus one
-- for the shared bucket) is reverted along with the balance itself -- see Schema.VERSION and
-- ProfileGateway.migrate's v2 -> v3 step.
--
-- The same card also carries the XP that came with it, on a second line. Spraypaint and XP are both
-- granted by the server's Eliminated handlers in one frame, but they replicate as separate attributes
-- (Spraypaint, Level, XP) whose change signals fire one by one -- so every change only schedules a
-- read, and the read a moment later sees all of them together and shows one card, not two.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Spraypaint.Constants)
local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)
local NotificationController = require(ReplicatedStorage.Modules.NotificationController)

local SETTLE_TIME = 0.1 -- long enough for one kill's attributes to all land, short enough to feel instant
local XP_COLOR = Color3.fromHex("61f0ee") -- the HUD XP bar's fill, so the line reads as XP at a glance
local SPRAYPAINT_COLOR = Color3.fromHex("cbf23c") -- the accent the shop and Skins card tint this icon with

local player = Players.LocalPlayer

local function readSpraypaint(): number
	return player:GetAttribute(Constants.ATTRIBUTE) or 0
end

-- Lifetime XP, not the XP attribute: that one resets on level-up, so a levelling kill would read as a loss.
local function readTotalXp(): number
	return LevelingConstants.totalXp(player:GetAttribute("Level") or 1, player:GetAttribute("XP") or 0)
end

local previousSpraypaint = readSpraypaint()
local previousXp = readTotalXp()
local pending = false
-- Victims of the kills that landed in this settle window, from the server's KillConfirmed. The card
-- already carries both rewards, so its title names what earned them instead of repeating "SPRAYPAINT".
local killsThisWindow: { string } = {}

local function titleFor(kills: { string }): string
	if #kills == 0 then
		return "SPRAYPAINT" -- a gain with no kill behind it, e.g. the level-up bonus from a quest
	end
	local title = "KILLED " .. string.upper(kills[#kills])
	return if #kills > 1 then title .. " \u{00D7}" .. #kills else title
end

local function announce()
	pending = false
	local spraypaint, xp = readSpraypaint(), readTotalXp()
	local gained, xpGained = spraypaint - previousSpraypaint, xp - previousXp
	previousSpraypaint, previousXp = spraypaint, xp
	-- Consumed on every read, card or not, so a kill that paid no Spraypaint (PvP) can never lend its
	-- name to a later, unrelated card.
	local kills = killsThisWindow
	killsThisWindow = {}
	-- Only gains are announced. A purchase is a deduction the player just chose, and telling them
	-- they spent it is noise at the moment they are looking at what they bought. XP rides along on
	-- the Spraypaint card only; XP on its own (a quest reward, a PvP kill) keeps its existing feedback.
	if gained > 0 then
		local detail = if xpGained > 0
			then { text = "+" .. xpGained .. " EXP", icon = LevelingConstants.XP_ICON_ID, iconColor = XP_COLOR }
			else nil
		-- Both lines lead with their currency's icon, so the pair reads as one set rather than one
		-- icon-led line under a bare one.
		NotificationController.show(
			{ text = "+" .. gained .. " Spraypaint", icon = Constants.ICON_ASSET_ID, iconColor = SPRAYPAINT_COLOR },
			titleFor(kills),
			detail
		)
	end
end

-- False until the server says the saved balance is restored: every change before that is the join-time
-- restore, so it re-seeds the baseline instead of announcing (the QuestsRestored pattern). Seeded at the
-- change itself, not at announce, so a flag that lands within the settle window cannot turn it into a gain.
local restored = player:GetAttribute(Constants.RESTORED_ATTRIBUTE) == true
player:GetAttributeChangedSignal(Constants.RESTORED_ATTRIBUTE):Connect(function()
	restored = player:GetAttribute(Constants.RESTORED_ATTRIBUTE) == true
end)

local function schedule()
	if not restored then
		previousSpraypaint, previousXp = readSpraypaint(), readTotalXp()
		return
	end
	if not pending then
		pending = true
		task.delay(SETTLE_TIME, announce)
	end
end

ReplicatedStorage:WaitForChild("Blaster"):WaitForChild("Remotes"):WaitForChild("KillConfirmed").OnClientEvent:Connect(
	function(victimName: string)
		if typeof(victimName) == "string" then
			table.insert(killsThisWindow, victimName)
			schedule()
		end
	end
)
player:GetAttributeChangedSignal(Constants.ATTRIBUTE):Connect(schedule)
player:GetAttributeChangedSignal("XP"):Connect(schedule)
player:GetAttributeChangedSignal("Level"):Connect(schedule)
