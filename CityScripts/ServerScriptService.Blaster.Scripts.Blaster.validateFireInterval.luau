-- The server's rate-of-fire rule. rateOfFire is rounds per minute: BlasterController waits 60 / rateOfFire
-- between Shoot events in every fire mode (Semi, Auto, Burst); a shotgun's pellets ride one Shoot and a melee
-- swing is one. A shot has to keep pace on two clocks, each with a 10% margin (0.9 of that interval):
--   * its CLAIMED timestamp (validateShot has already bounded it to the last second of server time) comes at
--     least 0.9 of an interval after the last accepted claim, so Shoot events bunched together by lag are
--     still judged by when they were fired;
--   * its server RECEIVE time keeps the same pace, give or take ARRIVAL_SLACK. Without this a client that
--     idled could back-date a whole second of shots and send them at once (12 AK47 rounds passed).
local INTERVAL_TOLERANCE = 0.9
-- Seconds a shot may reach the server ahead of its due time: covers network jitter (+-30 ms needs 0.06).
-- Idle time banks no more than this, so after idling at most 1 + floor(ARRIVAL_SLACK / (0.9 x interval))
-- shots arrive at once: 1 at 90 rpm, 2 at 600 rpm, 3 at 1200 rpm (MP9).
local ARRIVAL_SLACK = 0.1

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
	local spacing = INTERVAL_TOLERANCE * 60 / rateOfFire
	if last then
		if timestamp - last.claimed < spacing or receivedAt < last.due - ARRIVAL_SLACK then
			return nil
		end
		return { claimed = timestamp, due = math.max(last.due, receivedAt) + spacing }
	end
	return { claimed = timestamp, due = receivedAt + spacing }
end

return validateFireInterval
