-- The shot origin in third person. The camera sits behind and off the shoulder, and a long gun's muzzle
-- sits past the 5 studs validateShot allows between the origin and the root part, so neither can be the
-- origin. The shot leaves the head instead, aimed at the point the crosshair's ray hits; the tracer and
-- the flash still start at the muzzle.
--
-- The crosshair ray starts level with the head, not at the camera, so nothing between the camera and the
-- character is taken for what the player aims at. `cast(from, direction)` returns the first hit position
-- or nil (injected, so this stays pure). With nothing hit within `range` (or no range), it aims at a far
-- point along the camera's look, so only the direction counts: aiming at the end of a melee range would
-- tilt the swing about 26 degrees toward the camera's shoulder offset.
local Constants = require(script.Parent.Parent.Constants)

local function thirdPersonAim(camera: CFrame, head: Vector3, range: number?, cast: (Vector3, Vector3) -> Vector3?): CFrame
	local look = camera.LookVector
	local from = camera.Position + look * math.max((head - camera.Position):Dot(look), 0)
	local hit = if range and range > 0 then cast(from, look * range) else nil
	local target = hit or from + look * Constants.CROSSHAIR_FAR_DISTANCE
	-- The camera's up as the roll hint keeps a straight-up or straight-down look well defined.
	if (target - head):Dot(look) <= 0 then
		-- A hit level with the head (a wall touching the character): no forward aim point, so keep the
		-- camera's own direction.
		return CFrame.lookAt(head, head + look, camera.UpVector)
	end
	return CFrame.lookAt(head, target, camera.UpVector)
end

return thirdPersonAim
