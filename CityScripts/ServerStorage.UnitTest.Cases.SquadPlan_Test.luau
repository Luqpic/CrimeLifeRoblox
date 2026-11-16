-- SquadPlan: the squad target by stars and the share of the police cap (police and wanted, Task 2, 2026-11-17).
-- Pure: players are plain tables. In Solo there is only one real player, so the cap shared between several
-- wanted players is pinned here only.
return function(t)
	local SquadPlan = require(game:GetService("ReplicatedStorage").Wanted.SquadPlan)
	local expect = t.expect

	t.test("target follows the spec table for 0 to 5 stars", function()
		local want = { [0] = { 0, 0 }, { 2, 0 }, { 4, 0 }, { 4, 2 }, { 4, 4 }, { 4, 6 } }
		for stars = 0, 5 do
			local police, armed = SquadPlan.target(stars)
			expect.equal(police, want[stars][1])
			expect.equal(armed, want[stars][2])
		end
	end)

	t.test("allocate: 5, 3 and 1 stars under a cap of 24 each get their target, none for 0 stars", function()
		local a, b, c, d = { n = "a" }, { n = "b" }, { n = "c" }, { n = "d" }
		local out = SquadPlan.allocate({
			{ player = c, stars = 1, alive = 0 },
			{ player = a, stars = 5, alive = 0 },
			{ player = d, stars = 0, alive = 0 },
			{ player = b, stars = 3, alive = 0 },
		}, 24)
		expect.equal(out[a], 10)
		expect.equal(out[b], 6)
		expect.equal(out[c], 2)
		expect.equal(out[d] or 0, 0)
	end)

	t.test("allocate: when the cap binds the 5-star player is served first, and the total never passes it", function()
		local a, b, c = {}, {}, {}
		local out = SquadPlan.allocate({
			{ player = c, stars = 1, alive = 0 },
			{ player = b, stars = 3, alive = 0 },
			{ player = a, stars = 5, alive = 0 },
		}, 12)
		expect.equal(out[a], 10)
		expect.equal(out[b], 2)
		expect.equal(out[c], 0)
	end)

	t.test("allocate: officers already alive count against the target and the cap", function()
		local a, b = {}, {}
		local out = SquadPlan.allocate({
			{ player = a, stars = 5, alive = 8 },
			{ player = b, stars = 3, alive = 12 }, -- above its target of 6 (adopted officers)
		}, 24)
		expect.equal(out[a], 2)
		expect.equal(out[b], 0)
		local full = SquadPlan.allocate({ { player = a, stars = 5, alive = 2 } }, 3)
		expect.equal(full[a], 1)
		local total = 0
		for _, n in SquadPlan.allocate({ { player = a, stars = 5, alive = 0 }, { player = b, stars = 5, alive = 0 }, { player = {}, stars = 5, alive = 0 } }, 24) do
			total += n
		end
		expect.equal(total, 24)
	end)
end
