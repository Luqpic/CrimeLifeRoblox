-- Announces Spraypaint gains through the shared notification module.
--
-- Client-side and driven by replicated attributes, so no remote is needed: a balance already reaches
-- every client as a player attribute, and NotificationController is a client module.
--
-- The balance is now per weapon rather than one player attribute, so there is no single signal left
-- to watch. One connection per catalogued weapon instead -- the same pattern
-- WeaponaryShopController already uses for the four loadout slots -- plus one more for the shared
-- bucket, which gains only from a level-up with nothing equipped (see SpraypaintService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Spraypaint.Constants)
local NotificationController = require(ReplicatedStorage.Modules.NotificationController)

local player = Players.LocalPlayer
local catalog = ReplicatedStorage.Weapons:WaitForChild("Catalog")

-- Only gains are announced. A purchase is a deduction the player just chose, and telling them they
-- spent it is noise at the moment they are looking at what they bought.
local function announce(gained: number, weaponName: string?)
	if gained <= 0 then
		return
	end
	local label = if weaponName then ("+" .. gained .. " " .. weaponName .. " Spraypaint") else ("+" .. gained .. " Spraypaint")
	NotificationController.show(label, "SPRAYPAINT")
end

for _, entry in catalog:GetChildren() do
	local weaponName = entry.Name
	local attributeName = Constants.balanceAttributeFor(weaponName)
	local previous = player:GetAttribute(attributeName) or 0
	player:GetAttributeChangedSignal(attributeName):Connect(function()
		local current = player:GetAttribute(attributeName) or 0
		local gained = current - previous
		previous = current
		announce(gained, weaponName)
	end)
end

local previousShared = player:GetAttribute(Constants.SHARED_ATTRIBUTE) or 0
player:GetAttributeChangedSignal(Constants.SHARED_ATTRIBUTE):Connect(function()
	local current = player:GetAttribute(Constants.SHARED_ATTRIBUTE) or 0
	local gained = current - previousShared
	previousShared = current
	announce(gained, nil)
end)
