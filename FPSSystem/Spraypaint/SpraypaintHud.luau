-- Announces Spraypaint gains through the shared notification module.
--
-- Client-side and driven by the replicated attribute, so no remote is needed: the balance already
-- reaches every client as a player attribute, and NotificationController is a client module.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Spraypaint.Constants)
local NotificationController = require(ReplicatedStorage.Modules.NotificationController)

local player = Players.LocalPlayer
local previous = player:GetAttribute(Constants.ATTRIBUTE) or 0

player:GetAttributeChangedSignal(Constants.ATTRIBUTE):Connect(function()
	local current = player:GetAttribute(Constants.ATTRIBUTE) or 0
	local gained = current - previous
	previous = current
	-- Only gains are announced. A purchase is a deduction the player just chose, and telling them
	-- they spent it is noise at the moment they are looking at what they bought.
	if gained > 0 then
		NotificationController.show("+" .. gained .. " Spraypaint", "SPRAYPAINT")
	end
end)
