-- shoulderMath (2026-11-20): the pure pieces of the third-person shoulder camera (Blaster.Scripts.ShoulderCamera,
-- ported from OBT's GunEngine.Camera) and of the server's aim-pitch relay (ServerScriptService.Blaster.Scripts.AimPitch).
-- Tested by ServerStorage.UnitTest.Cases.ShoulderMath_Test.
local shoulderMath = {}

-- The shoulder's sideways offset after the wall clamp: as far as wanted, never past the clearance, same side.
function shoulderMath.clampSide(wantX: number, clearance: number): number
	return math.sign(wantX) * math.min(math.abs(wantX), math.max(clearance, 0))
end

-- The aim pitch (radians) of a camera look vector, clamped to +-maxPitch.
function shoulderMath.pitchOf(lookY: number, maxPitch: number): number
	return math.clamp(math.asin(math.clamp(lookY, -1, 1)), -maxPitch, maxPitch)
end

-- The server's reading of a reported pitch: a finite number, clamped to +-maxPitch; nil for anything else.
function shoulderMath.acceptPitch(value: any, maxPitch: number): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.clamp(value, -maxPitch, maxPitch)
end

-- Whether a report at `now` may be taken, `interval` seconds after the last one taken at `last` (nil: none yet).
function shoulderMath.due(last: number?, now: number, interval: number): boolean
	return last == nil or now - last >= interval
end

-- Smoothstep of a 0..1 blend (clamped): the zoom and offset ease in from wherever the camera was.
function shoulderMath.smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

return shoulderMath
