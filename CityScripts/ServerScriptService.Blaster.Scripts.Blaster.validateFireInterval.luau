-- The server's rate-of-fire rule. rateOfFire is rounds per minute: BlasterController waits 60 / rateOfFire
-- between Shoot events in every fire mode (Semi, Auto, Burst); a shotgun's pellets ride one Shoot and a melee
-- swing is one. A shot has to keep pace on two clocks, each with a 10% margin (0.9 of that interval):
--   * its CLAIMED timestamp (validateShot has already bounded it to the last second of server time) comes at
--     least 0.9 of an interval after the last accepted claim, so Shoot events bunched together by lag are
--     still judged by when they were fired;
--   * its server RECEIVE time keeps the same pace, give or take ARRIVAL_SLACK. Without this a client that
--     idled could back-date a whole second of shots and send them at once (12 AK47 rounds passed).
-- Both numbers live in Blaster.Constants (INTERVAL_TOLERANCE 0.9, ARRIVAL_SLACK 0.25 s).
local Constants = require(game:GetService("ReplicatedStorage").Blaster.Constants)

-- The last accepted shot of one weapon: its claimed timestamp, and the server time the next one is due.
export type Record = { claimed: number, due: number }

-- Returns the new record when the shot is accepted, nil when it is refused.
local function validateFireInterval(last: Record?, timestamp: number, rateOfFire: number?, receivedAt: number): Record?
	if typeof(timestamp) ~= "number" or timestamp ~= timestamp then
		return nil
	end
	if typeof(rateOfFire) ~= "number" or not (rateOfFire > 0) then
		-- No rate declared: nothing to enforce. Every Tool in ServerStorage.Weapons declares one, and the
		-- client cannot fire a weapon without it (BlasterController divides by it).
		return { claimed = timestamp, due = receivedAt }
	end
	local spacing = Constants.INTERVAL_TOLERANCE * 60 / rateOfFire
	if last then
		if timestamp - last.claimed < spacing or receivedAt < last.due - Constants.ARRIVAL_SLACK then
			return nil
		end
		return { claimed = timestamp, due = math.max(last.due, receivedAt) + spacing }
	end
	return { claimed = timestamp, due = receivedAt + spacing }
end

return validateFireInterval
