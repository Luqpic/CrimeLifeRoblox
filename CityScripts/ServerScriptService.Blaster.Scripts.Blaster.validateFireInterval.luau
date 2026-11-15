-- The server's rate-of-fire rule, judged on the CLAIMED timestamps (validateShot has already bounded
-- each to the last second of server time), so Shoot events bunched together by lag are not dropped.
--
-- rateOfFire is rounds per minute: BlasterController waits 60 / rateOfFire between Shoot events in
-- every fire mode (Semi, Auto, Burst); a shotgun's pellets ride one Shoot and a melee swing is one.
-- A shot is refused when it comes less than 0.9 of that interval after the last accepted shot.
local INTERVAL_TOLERANCE = 0.9

local function validateFireInterval(lastTimestamp: number?, timestamp: number, rateOfFire: number): boolean
	if typeof(timestamp) ~= "number" or timestamp ~= timestamp then
		return false
	end
	if lastTimestamp == nil then
		return true
	end
	if typeof(rateOfFire) ~= "number" or not (rateOfFire > 0) then
		-- No rate declared: nothing to enforce. Every Tool in ServerStorage.Weapons declares one, and the
		-- client cannot fire a weapon without it (BlasterController divides by it).
		return true
	end
	return timestamp - lastTimestamp >= INTERVAL_TOLERANCE * 60 / rateOfFire
end

return validateFireInterval
