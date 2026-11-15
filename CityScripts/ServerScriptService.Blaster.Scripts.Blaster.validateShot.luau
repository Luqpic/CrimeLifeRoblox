local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)

local TIMESTAMP_BUFFER_CONSTANT = 1
local POSITION_BUFFER_CONSTANT = 5
local POSITION_BUFFER_FACTOR = 0.4

local function validateShot(player: Player, timestamp: number, blaster: Tool, origin: CFrame): boolean
	-- Validate timestamp
	local now = Workspace:GetServerTimeNow()
	if timestamp > now then
		return false
	end
	if timestamp < now - TIMESTAMP_BUFFER_CONSTANT then
		return false
	end

	-- Make sure the character exists, is alive, and has a PrimaryPart
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	local primaryPart = character.PrimaryPart
	if not primaryPart then
		return false
	end

	-- Make sure the blaster is equipped
	if blaster.Parent ~= character then
		return false
	end

	-- Make sure the blaster is not being reloaded
	local isReloading = blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE)
	if isReloading then
		return false
	end

	-- Make sure the blaster has enough ammo. This is the server's own check, independent of the
	-- client's canShoot(), so an infinite-ammo weapon has to be exempted here too or it stops
	-- resolving shots as soon as its _ammo attribute would reach 0.
	if not blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) then
		local ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
		if ammo <= 0 then
			return false
		end
	end

	-- Make sure the origin position is within a reasonable distance from the character
	local distance = (primaryPart.Position - origin.Position).Magnitude
	local maxDistance = POSITION_BUFFER_CONSTANT + primaryPart.AssemblyLinearVelocity.Magnitude * POSITION_BUFFER_FACTOR
	if distance > maxDistance then
		return false
	end

	return true
end

return validateShot
