local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17 (Task 5): the NewsStation broadcast desk. Armed by the first
-- MasterComputer breach; "Go Live" once; air time counts while a living participant is within
-- BroadcastRange (pauses, never resets); at BroadcastSeconds the participants at the desk are paid.
return function()
	local BroadcastDesk = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.BroadcastDesk)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.NewsStationShared.Config)
	local suite = TestRunner.new("BroadcastDesk")

	local function makeModel()
		local model = Instance.new("Model")
		model.Name = "BroadcastDesk"
		local part = Instance.new("Part")
		part.Anchored = true
		part.Position = Vector3.new(0, 500, 0)
		part.Parent = model
		Instance.new("Highlight").Parent = model
		local gui = Instance.new("BillboardGui")
		gui.Parent = part
		Instance.new("TextLabel").Parent = gui
		model.Parent = workspace
		return model
	end

	-- distances[player] is what measure() returns (nil = dead or no character); clock.t is now().
	local function setup()
		local clock = { t = 0 }
		local model = makeModel()
		local bank = BankInstance.new({ config = Config, now = function() return clock.t end })
		local distances, lives, completes = {}, {}, {}
		local desk = BroadcastDesk.new(model, {
			bank = bank,
			config = Config,
			now = function() return clock.t end,
			measure = function(player) return distances[player] end,
			onLive = function(player) table.insert(lives, player) end,
			onComplete = function(players) table.insert(completes, players) end,
		})
		bank:RegisterComponent(desk)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:AddParticipant("p2")
		local label = model:FindFirstChildWhichIsA("TextLabel", true)
		return desk, bank, distances, lives, completes, clock, label, function()
			desk:Destroy()
			model:Destroy()
		end
	end

	suite:test("Config carries the spec's broadcast values", function(expect)
		expect.equal(Config.BroadcastSeconds, 45, "BroadcastSeconds")
		expect.equal(Config.BroadcastRange, 12, "BroadcastRange")
		expect.equal(Config.BroadcastPayout, 6000, "BroadcastPayout")
		expect.equal(Config.BroadcastHeatFloor, 3, "BroadcastHeatFloor")
	end)

	suite:test("locked until Arm: Go Live refused, prompt and highlight off", function(expect)
		local desk, _, distances, lives, _, _, _, cleanup = setup()
		distances.p1 = 5
		expect.equal(desk.state, "locked", "state")
		local ok, reason = desk:TryGoLive("p1")
		expect.falsy(ok, "refused")
		expect.equal(reason, "not_armed", "reason")
		expect.falsy(desk.prompt.Enabled, "prompt off")
		expect.falsy(desk.highlight.Enabled, "highlight off")
		desk:Arm()
		expect.equal(desk.state, "armed", "armed")
		expect.truthy(desk.prompt.Enabled, "prompt on")
		expect.truthy(desk.highlight.Enabled, "highlight on")
		expect.equal(#lives, 0, "no onLive yet")
		cleanup()
	end)

	suite:test("Go Live by a participant within range: live, onLive once, second press refused", function(expect)
		local desk, _, distances, lives, _, _, _, cleanup = setup()
		distances.p1, distances.p2 = 5, 3
		desk:Arm()
		expect.truthy(desk:TryGoLive("p1"), "p1 goes live")
		expect.equal(desk.state, "live", "live")
		expect.equal(#lives, 1, "onLive once")
		expect.equal(lives[1], "p1", "onLive gets the presser")
		local ok, reason = desk:TryGoLive("p2")
		expect.falsy(ok, "second press refused")
		expect.equal(reason, "already_live", "reason")
		expect.equal(#lives, 1, "still one onLive")
		desk:Arm()
		expect.equal(desk.state, "live", "Arm does not reset a live desk")
		cleanup()
	end)

	suite:test("Go Live refused for a non-participant, out of range, or dead", function(expect)
		local desk, _, distances, lives, _, _, _, cleanup = setup()
		desk:Arm()
		distances.p3 = 2
		local ok, reason = desk:TryGoLive("p3")
		expect.falsy(ok, "non-participant refused")
		expect.equal(reason, "not_participant", "not_participant")
		distances.p1 = 12.5
		ok, reason = desk:TryGoLive("p1")
		expect.equal(reason, "too_far", "beyond 12 studs")
		distances.p1 = nil
		ok, reason = desk:TryGoLive("p1")
		expect.equal(reason, "too_far", "no living character")
		expect.equal(desk.state, "armed", "still armed")
		expect.equal(#lives, 0, "no onLive")
		cleanup()
	end)

	suite:test("air time counts only while a living participant is in range: pauses, never resets", function(expect)
		local desk, _, distances, _, completes, clock, label, cleanup = setup()
		distances.p1 = 5
		desk:Arm()
		desk:TryGoLive("p1")
		expect.equal(label.Text, "LIVE 0:45", "label at go-live")
		clock.t = 10; desk:Update()
		expect.near(desk.airSeconds, 10, 1e-6, "10 s on air")
		expect.equal(label.Text, "LIVE 0:35", "label counts down")
		distances.p1 = 20
		clock.t = 20; desk:Update()
		clock.t = 30; desk:Update()
		expect.near(desk.airSeconds, 10, 1e-6, "paused while nobody is in range")
		distances.p1 = nil
		distances.p2 = 4
		clock.t = 30; desk:Update()
		clock.t = 35; desk:Update()
		expect.near(desk.airSeconds, 15, 1e-6, "resumed, not reset, by another participant")
		distances.p3 = 1 -- not a participant
		distances.p2 = nil
		clock.t = 40; desk:Update()
		expect.near(desk.airSeconds, 15, 1e-6, "a non-participant does not hold the studio")
		expect.equal(desk.state, "live", "still live")
		expect.equal(#completes, 0, "not complete")
		cleanup()
	end)

	suite:test("at 45 s: done, onComplete gets exactly the participants in range, once", function(expect)
		local desk, _, distances, _, completes, clock, label, cleanup = setup()
		distances.p1, distances.p2 = 5, 30
		desk:Arm()
		desk:TryGoLive("p1")
		clock.t = 44.9; desk:Update()
		expect.equal(desk.state, "live", "not yet")
		clock.t = 45.1; desk:Update()
		expect.equal(desk.state, "done", "done")
		expect.equal(desk.airSeconds, 45, "air time clamped")
		expect.equal(#completes, 1, "onComplete once")
		expect.equal(#completes[1], 1, "one payee")
		expect.equal(completes[1][1], "p1", "the participant at the desk")
		expect.falsy(desk.prompt.Enabled, "prompt off")
		expect.falsy(label.Text:find("LIVE"), "label no longer LIVE")
		clock.t = 60; desk:Update()
		expect.equal(#completes, 1, "no second onComplete")
		local ok, reason = desk:TryGoLive("p1")
		expect.falsy(ok, "refused after done")
		expect.equal(reason, "done", "reason")
		desk:Arm()
		expect.equal(desk.state, "done", "one broadcast per session")
		cleanup()
	end)

	suite:test("two participants at the desk are both paid", function(expect)
		local desk, _, distances, _, completes, clock, _, cleanup = setup()
		distances.p1, distances.p2 = 5, 11
		desk:Arm()
		desk:TryGoLive("p2")
		clock.t = 46; desk:Update()
		expect.equal(#completes[1], 2, "both paid")
		cleanup()
	end)

	suite:test("Seal while live: no onComplete; OnSessionStart resets for the next session", function(expect)
		local desk, bank, distances, _, completes, clock, _, cleanup = setup()
		distances.p1 = 5
		desk:Arm()
		desk:TryGoLive("p1")
		clock.t = 30; desk:Update()
		desk:Seal()
		clock.t = 100; desk:Update()
		expect.equal(#completes, 0, "no payout after seal")
		expect.falsy(desk.prompt.Enabled, "prompt off")
		expect.falsy(desk.highlight.Enabled, "highlight off")
		desk:Arm()
		expect.falsy(desk.state == "armed", "a sealed desk cannot be armed")
		desk:OnSessionStart()
		expect.equal(desk.state, "locked", "locked again")
		expect.equal(desk.airSeconds, 0, "air time reset")
		expect.equal(bank:GetState(), "Active", "bank still active in this rig")
		desk:Arm()
		expect.equal(desk.state, "armed", "armable in the new session")
		cleanup()
	end)

	suite:test("the prompt honours a trigger only after a hold the server timed", function(expect)
		local desk, _, distances, lives, _, clock, _, cleanup = setup()
		distances.p1 = 5
		desk:Arm()
		desk:_onPromptTriggered("p1")
		expect.equal(desk.state, "armed", "no hold seen: ignored")
		desk:_onHoldBegan("p1")
		clock.t = 0.3
		desk:_onPromptTriggered("p1")
		expect.equal(desk.state, "armed", "short hold: ignored")
		desk:_onHoldBegan("p1")
		desk:Forget("p1")
		clock.t = 2
		desk:_onPromptTriggered("p1")
		expect.equal(desk.state, "armed", "Forget drops the hold")
		desk:_onHoldBegan("p1")
		clock.t = 3
		desk:_onPromptTriggered("p1")
		expect.equal(desk.state, "live", "timed hold: live")
		expect.equal(#lives, 1, "onLive once")
		cleanup()
	end)

	return suite:run()
end
