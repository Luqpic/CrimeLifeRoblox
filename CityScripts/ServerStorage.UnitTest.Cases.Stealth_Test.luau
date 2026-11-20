-- Crouch stealth (2026-11-20): the pure parts of ServerScriptService.Movement.Scripts.Stealth.
return function(t)
	local Stealth = require(game:GetService("ServerScriptService").Movement.Scripts.Stealth)
	local expect = t.expect

	t.test("decide: crouched among objects is Hidden (25), in the open Crouched (70); standing, sprinting, rolling, fast or exposed is normal", function()
		local state, range = Stealth.decide(true, false, false, 4, false, 3)
		expect.equal(state, "Hidden")
		expect.equal(range, 25)
		state, range = Stealth.decide(true, false, false, 4, false, 2)
		expect.equal(state, "Crouched")
		expect.equal(range, 70)
		expect.equal(Stealth.decide(false, false, false, 0, false, 8), nil)
		expect.equal(Stealth.decide(true, true, false, 4, false, 8), nil)
		expect.equal(Stealth.decide(true, false, true, 4, false, 8), nil)
		expect.equal(Stealth.decide(true, false, false, 12, false, 8), nil)
		expect.equal(Stealth.decide(true, false, false, 4, true, 8), nil)
	end)

	t.test("coverSides counts the blocked ones of 8 flat directions, each COVER_DISTANCE long", function()
		local seen = {}
		local blocked = Stealth.coverSides(Vector3.zero, function(_origin, direction)
			table.insert(seen, direction)
			return direction.X > 0.1
		end)
		expect.equal(#seen, 8)
		expect.equal(blocked, 3)
		expect.near(seen[1].Magnitude, Stealth.COVER_DISTANCE, 1e-6)
	end)

	t.test("noticeRange: the shorter of the watcher's range and the character's StealthRange", function()
		local model = Instance.new("Model")
		expect.equal(Stealth.noticeRange(model, 120), 120)
		model:SetAttribute("StealthRange", 25)
		expect.equal(Stealth.noticeRange(model, 120), 25)
		expect.equal(Stealth.noticeRange(model, 10), 10)
		expect.equal(Stealth.noticeRange(nil, 150), 150)
	end)
end
