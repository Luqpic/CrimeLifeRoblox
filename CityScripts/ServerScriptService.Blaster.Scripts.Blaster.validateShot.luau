local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local validateFireInterval = require(script.Parent.validateFireInterval)

-- player -> weapon NAME -> claimed timestamp of the last accepted shot. Keyed by name, not by Tool
-- instance: SetLoadoutSlotRequest hands out a fresh Tool on every call, which would start a fresh clock.
local lastShotAt: { [Player]: { [string]: number } } = {}
game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
	lastShotAt[player] = nil
end)

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

	-- Rate of fire, checked last so only a shot that passed everything else is recorded.
	local shotsByTool = lastShotAt[player]
	local rateOfFire = blaster:GetAttribute(Constants.RATE_OF_FIRE_ATTRIBUTE)
	if not validateFireInterval(shotsByTool and shotsByTool[blaster.Name], timestamp, rateOfFire) then
		return false
	end
	if not shotsByTool then
		shotsByTool = {}
		lastShotAt[player] = shotsByTool
	end
	shotsByTool[blaster.Name] = timestamp

	return true
end

return validateShot
