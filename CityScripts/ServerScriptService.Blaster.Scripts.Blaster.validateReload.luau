local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Blaster.Constants)

local function validateReload(player: Player, blaster: Tool): boolean
	local character = player.Character
	if not character then
		return false
	end

	if blaster.Parent ~= character then
		return false
	end

	if blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE) then
		return false
	end

	return true
end

return validateReload
