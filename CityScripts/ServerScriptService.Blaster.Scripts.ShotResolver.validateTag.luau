local ReplicatedStorage = game:GetService("ReplicatedStorage")

local castRays = require(ReplicatedStorage.Blaster.Utility.castRays)
local canDamageHumanoid = require(ReplicatedStorage.Blaster.Utility.canDamageHumanoid)

local DIRECTION_BUFFER_CONSTANT = 10
local WALL_DISTANCE_BUFFER_CONSTANT = 5
-- A body overlapping the shooter (walked into) has its pivot a little behind the ray's start.
local BEHIND_BUFFER_CONSTANT = 3

local function validateTag(
	player: Player,
	taggedHumanoid: Humanoid,
	position: Vector3,
	direction: Vector3,
	rayResult: castRays.RayResult
): boolean
	-- Make sure the player is actually allowed to damage this humanoid. No team killing!
	if not canDamageHumanoid(player, taggedHumanoid) then
		return false
	end

	local character = taggedHumanoid:FindFirstAncestorOfClass("Model")
	if not character then
		return false
	end

	local pivot = character:GetPivot()
	local characterOffset = pivot.Position - position
	local characterDistance = characterOffset.Magnitude
	local rayDistance = (position - rayResult.position).Magnitude

	-- If the server's version of the ray hits static geometry before the player, then we know the shot
	-- the client reported could not be made.
	if rayDistance < characterDistance - WALL_DISTANCE_BUFFER_CONSTANT then
		return false
	end

	-- The ray has to pass within DIRECTION_BUFFER_CONSTANT studs of the character's pivot, measured sideways from the
	-- ray line, with the pivot at most BEHIND_BUFFER_CONSTANT studs behind the ray's start. This stops a client from
	-- passing in arbitrary humanoids, only allowing them to damage what they could conceivably be aiming at.
	--
	-- Hit registration fix (2026-11-20): this used to be an angle, atan(DIRECTION_BUFFER_CONSTANT / distance) to the
	-- pivot. Far away the two agree; up close the angle refused real hits on a body's edge or on an enemy the player
	-- was walking into (measured while moving: 2 of 8 claimed hits refused, at 4.9 and 7.0 studs, 71 and 73 degrees).
	local along = characterOffset:Dot(direction.Unit)
	local sideways = (characterOffset - direction.Unit * along).Magnitude
	if along < -BEHIND_BUFFER_CONSTANT or sideways > DIRECTION_BUFFER_CONSTANT then
		return false
	end

	return true
end

return validateTag
