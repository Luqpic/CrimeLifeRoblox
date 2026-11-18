-- Tests for Blaster.validateFireInterval, the server's rate-of-fire rule. rateOfFire is rounds per minute
-- (BlasterController waits 60 / rateOfFire between Shoot events in every fire mode). A shot is refused when
-- its CLAIMED timestamp comes less than 0.9 of an interval after the last accepted one, or when it REACHES
-- the server more than the arrival slack (0.25 s, Blaster.Constants) ahead of the pace the accepted shots set
-- on the server clock.
return function(t)
	local validateFireInterval = require(game:GetService("ServerScriptService").Blaster.Scripts.Blaster.validateFireInterval)
	local expect = t.expect
	local RATE = 600 -- AK47: one round every 0.1 s
	local interval = 60 / RATE

	-- The last accepted shot, claimed and received at 100.
	local function first()
		return validateFireInterval(nil, 100, RATE, 100)
	end
	-- The next shot claims `timestamp` and arrives one interval later: only the claimed clock can refuse it.
	local function second(timestamp)
		return validateFireInterval(first(), timestamp, RATE, 100 + interval)
	end
	-- `count` shots claiming timestamps spread evenly over the second before `now`, all arriving at `now`.
	-- Returns how many were accepted, and the record after them.
	local function burst(record, now, count, rate)
		local accepted = 0
		for k = 0, count - 1 do
			local result = validateFireInterval(record, now - 1 + k / (count - 1), rate, now)
			if result then
				accepted += 1
				record = result
			end
		end
		return accepted, record
	end
	-- An honest client: claims exactly one interval apart, each Shoot arriving 50 ms later +- `jitter`, in
	-- order (a RemoteEvent is ordered). Returns how many of 100 shots were refused.
	local function honestRefusals(rate, jitter)
		local random = Random.new(7)
		local record, refused, arrivedAt = nil, 0, 0
		for i = 0, 99 do
			local claimed = 100 + i * 60 / rate
			arrivedAt = math.max(arrivedAt, claimed + 0.05 + random:NextNumber(-jitter, jitter))
			local result = validateFireInterval(record, claimed, rate, arrivedAt)
			if result then
				record = result
			else
				refused += 1
			end
		end
		return refused
	end
	-- The same honest client through a stall (a phone hitch or a connection pause) of `stall` seconds that
	-- starts 0.01 s before shot 20: every Shoot sent during it reaches the server together when it ends, 50 ms
	-- later. Returns how many of 100 shots were refused.
	local function stallRefusals(rate, stall)
		local stallFrom = 100 + 20 * 60 / rate - 0.01
		local record, refused, arrivedAt = nil, 0, 0
		for i = 0, 99 do
			local claimed = 100 + i * 60 / rate
			local sent = if claimed >= stallFrom and claimed < stallFrom + stall then stallFrom + stall else claimed
			arrivedAt = math.max(arrivedAt, sent + 0.05)
			local result = validateFireInterval(record, claimed, rate, arrivedAt)
			if result then
				record = result
			else
				refused += 1
			end
		end
		return refused
	end

	t.test("the first shot passes", function()
		expect.truthy(first())
	end)
	t.test("a shot one interval after the last passes", function()
		expect.truthy(second(100 + interval))
	end)
	t.test("a shot 0.85 of an interval after the last is refused", function()
		expect.falsy(second(100 + 0.85 * interval))
	end)
	t.test("a shot half an interval after the last is refused", function()
		expect.falsy(second(100 + 0.5 * interval))
	end)
	t.test("a second shot with the same timestamp is refused", function()
		expect.falsy(second(100))
	end)
	t.test("a NaN timestamp is refused", function()
		expect.falsy(validateFireInterval(nil, 0 / 0, RATE, 100))
		expect.falsy(second(0 / 0))
	end)
	t.test("a weapon with no rate of fire is not limited", function()
		local record = validateFireInterval(nil, 100, nil, 100)
		expect.truthy(validateFireInterval(record, 100, nil, 100))
	end)
	t.test("after 2 s idle, 12 shots claiming the last second: 3 pass at 600 rpm, and again after the next idle second", function()
		-- 1 + floor(0.25 / 0.09). Without the arrival clock all 12 would pass.
		local accepted, record = burst(first(), 102, 12, RATE)
		expect.equal(accepted, 3)
		expect.equal((burst(record, 103, 12, RATE)), 3)
	end)
	t.test("after 2 s idle, the fastest gun (MP9, 1200 rpm) gets 6 of 12 through", function()
		expect.equal((burst(validateFireInterval(nil, 100, 1200, 100), 102, 12, 1200)), 6)
	end)
	t.test("an honest client at full rate with +-30 ms of jitter is never refused", function()
		expect.equal(honestRefusals(RATE, 0.03), 0)
		expect.equal(honestRefusals(1200, 0.03), 0)
		expect.equal(honestRefusals(90, 0.03), 0)
	end)
	t.test("an honest 600 rpm stream through a 250 ms stall and its bunched arrival loses no shot", function()
		expect.equal(stallRefusals(RATE, 0.25), 0)
	end)
	t.test("a 600 ms stall at 600 rpm costs 4 shots (the accepted loss)", function()
		expect.equal(stallRefusals(RATE, 0.6), 4)
	end)
	t.test("a melee swing stamped at the press survives a 100 ms hitch on the swing before", function()
		-- Knife: 90 rpm, swingDelay 0.2. The first swing's hit resolves 0.1 s late; the next press comes one
		-- interval after the first. Stamped at the press both pass; stamped at contact the second is refused.
		local swing = 60 / 90
		local atPress = validateFireInterval(nil, 100, 90, 100.3)
		expect.truthy(validateFireInterval(atPress, 100 + swing, 90, 100 + swing + 0.2))
		local atContact = validateFireInterval(nil, 100.3, 90, 100.3)
		expect.falsy(validateFireInterval(atContact, 100 + swing + 0.2, 90, 100 + swing + 0.2))
	end)
end
