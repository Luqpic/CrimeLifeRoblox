local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Net = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Net)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("Net")

	suite:test("extrapolation grows linearly with elapsed time", function(expect)
		expect.equal(Net.extrapolate(0, 100, 10, 10, 10000), 0, "no time elapsed")
		expect.equal(Net.extrapolate(0, 100, 10, 11, 10000), 100, "one second")
		expect.equal(Net.extrapolate(500, 100, 10, 12, 10000), 700, "two seconds on top of a base")
	end)

	suite:test("extrapolation clamps at the cap so a full duffel cannot overshoot", function(expect)
		expect.equal(Net.extrapolate(9950, 133, 0, 100, 10000), 10000, "clamped")
	end)

	suite:test("extrapolation never goes backwards on a clock skew", function(expect)
		expect.equal(Net.extrapolate(500, 100, 10, 5, 10000), 500, "negative elapsed is ignored")
	end)

	suite:test("a zero rate holds the value steady", function(expect)
		expect.equal(Net.extrapolate(400, 0, 0, 999, 10000), 400, "static")
	end)

	suite:test("setup creates every display/cue remote", function(expect)
		local net = Net.setup()
		local folder = game.ReplicatedStorage.HeistShared:FindFirstChild("Remotes")
		expect.truthy(folder ~= nil, "Remotes folder exists")
		-- LocationOpened/RobberyTriggered added with the global notification
		-- popups: both are ToClient broadcasts in the same display/cue family as
		-- the rest of this list, so they are pinned here rather than left to
		-- drift unverified.
		for _, name in ipairs({ "HeistState", "DuffelState", "Toast", "PlayCue", "ZoneOccupancy", "RobberySuccess",
			"LocationOpened", "RobberyTriggered", "BroadcastHijacked" }) do
			local remote = folder:FindFirstChild(name)
			expect.truthy(remote ~= nil, name .. " exists")
			expect.truthy(remote:IsA("RemoteEvent"), name .. " is a RemoteEvent")
		end
	end)

	suite:test("setup is idempotent and does not duplicate remotes", function(expect)
		Net.setup()
		Net.setup()
		local folder = game.ReplicatedStorage.HeistShared.Remotes
		local count = 0
		for _, child in ipairs(folder:GetChildren()) do
			if child.Name == "HeistState" then count += 1 end
		end
		expect.equal(count, 1, "one HeistState only")
	end)

	-- NotifyRobberySuccess itself (like PlayCue/Toast/SendDuffel) is not
	-- invocation-tested here: FireClient requires a real Player instance,
	-- which doesn't exist in this Edit-mode server test context -- the
	-- "setup creates every display/cue remote" test above already covers
	-- RobberySuccess structurally (exists, is a RemoteEvent), matching how
	-- every other outbound remote in this suite is verified.

	suite:test("there is no inbound remote at all", function(expect)
		local net = Net.setup()
		expect.equal(net:InboundRemoteCount(), 0,
			"the client must never be able to tell the server anything about currency, " ..
			"position, or time — see spec 6.8")
	end)

	suite:test("no RemoteFunction exists anywhere under HeistShared", function(expect)
		for _, d in ipairs(game.ReplicatedStorage.HeistShared:GetDescendants()) do
			expect.falsy(d:IsA("RemoteFunction"),
				"a RemoteFunction would give the client a request/response channel")
		end
	end)

	return suite:run()
end
