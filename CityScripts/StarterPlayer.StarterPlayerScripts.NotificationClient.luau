--!strict
-- Global robbery notifications (spec addendum), shown to EVERY player when a location re-opens, when
-- someone triggers a robbery, and when the News Station broadcast is hijacked.
--
-- Since 2026-11-18 they are drawn by the city's one notification stack (Modules.NotificationController):
-- same card, colours, timing, stacking and panel-open queue as every other toast. The heist's own
-- card (StarterGui.HeistNotificationGui) is in ServerStorage.CityQuarantine.ReplacedByUnifiedNotifications.
-- Each message keeps its text; the heist card's red "Alarm Triggered!" box became the card title
-- "ALARM TRIGGERED", and its generic "Notification!" header the city's "NOTICE".
--
-- Purely presentational: the remotes are ToClient-only and nothing here talks back to the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NotificationController = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("NotificationController"))
local HeistConfig = require(ReplicatedStorage:WaitForChild("HeistShared"):WaitForChild("Config"))

local remotes = ReplicatedStorage.HeistShared:WaitForChild("Remotes")

local ALARM_TITLE = "ALARM TRIGGERED"
-- BroadcastHijacked is created by the server's Net at run time; a bounded wait degrades to "no hijack
-- card" with a warning instead of a silent infinite yield.
local REMOTE_WAIT_SECONDS = 30

-- player.Name is always alphanumeric/underscore, so this cannot currently be escaped-into, but the
-- message label is RichText and composing untrusted-ish text into markup without escaping is the kind
-- of thing that only stays safe by accident.
local function escapeRichText(s: string): string
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function phraseFor(location: string): string
	return HeistConfig.LocationPhrase[location] or location
end

local function capitalize(s: string): string
	return (s:gsub("^%l", string.upper))
end

local function listen(name: string, handler: (...any) -> ())
	task.spawn(function()
		local remote = remotes:WaitForChild(name, REMOTE_WAIT_SECONDS)
		if not remote then
			warn(`[NotificationClient] {name} not found after {REMOTE_WAIT_SECONDS} s; those cards will not show`)
			return
		end
		(remote :: RemoteEvent).OnClientEvent:Connect(handler)
	end)
end

listen("LocationOpened", function(location)
	if type(location) ~= "string" then return end
	NotificationController.show(string.format("<b>%s</b> is open.", escapeRichText(capitalize(phraseFor(location)))))
end)

listen("RobberyTriggered", function(payload)
	if type(payload) ~= "table" then return end
	local location, playerName = payload.location, payload.playerName
	if type(location) ~= "string" or type(playerName) ~= "string" then return end
	NotificationController.show(string.format("<b>%s</b> is robbing %s.",
		escapeRichText(playerName), escapeRichText(phraseFor(location))), ALARM_TITLE)
end)

-- Heist layers 2026-11-17: the News Station broadcast hijack, an alarm card.
listen("BroadcastHijacked", function(playerName)
	if type(playerName) ~= "string" then return end
	NotificationController.show(string.format("<b>%s</b> hijacked the News Station broadcast!",
		escapeRichText(playerName)), ALARM_TITLE)
end)
