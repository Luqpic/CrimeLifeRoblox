local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Heist layers 2026-11-17 (Task 4): Gas2Go's ATM offers "Rob ATM" (into the bag) and
-- "Rip Out ATM" (carried, banked by CarryGetaway). Using either closes the other for the run.
return function()
	local ATMRipOut = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.ATMRipOut)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.Gas2GoShared.Config)
	local suite = TestRunner.new("Gas2GoRip")

	local function makeClock()
		local t = 1000
		return function() return t end, function(dt) t += dt end
	end

	local function prompt(action, hold)
		local p = Instance.new("ProximityPrompt")
		p.ActionText = action
		p.HoldDuration = hold
		return p
	end

	local function tempModel()
		local model = Instance.new("Model")
		model.Name = "ATM"
		for i = -2, 2 do
			local part = Instance.new("Part")
			part.Anchored = true
			part.Position = Vector3.new(i, 0, 0)
			part.Parent = model
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 0
			emitter.Parent = part
		end
		Instance.new("Highlight").Parent = model
		model.Parent = workspace
		return model
	end

	local function prompts(model)
		local byText = {}
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then byText[d.ActionText] = d end
		end
		return byText
	end

	local function visible(model): boolean
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency == 1 then return false end
		end
		return true
	end

	local function makeRig()
		local now, advance = makeClock()
		local bank = BankInstance.new({ config = Config, now = now })
		local model = tempModel()
		local rig = { bank = bank, model = model, advance = advance, pickups = {} }
		rig.atm = ATMRipOut.new(model, {
			bank = bank,
			robPromptTemplate = prompt("Rob ATM machine", 8),
			ripPromptTemplate = prompt("Rip Out ATM", Config.ATMRipHold),
			repickupPromptTemplate = prompt("Pick Up ATM", 0),
			robAmount = Config.ATMRobAmount,
			ripAmount = Config.ATMRipAmount,
			clock = now,
			onPickup = function(player, obj) table.insert(rig.pickups, { player, obj }) end,
		})
		bank:RegisterComponent(rig.atm)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		return rig
	end

	-- A server-timed hold on the rip prompt: began, ATMRipHold seconds, triggered.
	local function rip(rig, player)
		rig.atm.rip:_onHoldBegan(player)
		rig.advance(Config.ATMRipHold)
		rig.atm.rip:_onPromptTriggered(player)
	end

	suite:test("config carries the rip-out values", function(expect)
		expect.equal(Config.ATMRipAmount, 9000, "ATMRipAmount")
		expect.equal(Config.ATMRipHold, 10, "ATMRipHold")
	end)

	suite:test("the rip-out prompt template says Rip Out ATM with hold ATMRipHold", function(expect)
		local templates = game.ReplicatedStorage.Gas2GoShared:FindFirstChild("PromptTemplates")
		local ripTemplate = templates and templates:FindFirstChild("RipOutATMPrompt")
		expect.truthy(ripTemplate and ripTemplate:IsA("ProximityPrompt"), "RipOutATMPrompt exists")
		if ripTemplate then
			expect.equal(ripTemplate.ActionText, "Rip Out ATM", "ActionText")
			expect.equal(ripTemplate.HoldDuration, Config.ATMRipHold, "HoldDuration")
		end
	end)

	suite:test("both prompts are armed at session start and the ATM is visible", function(expect)
		local rig = makeRig()
		local byText = prompts(rig.model)
		expect.truthy(byText["Rob ATM machine"] ~= nil, "rob prompt")
		expect.truthy(byText["Rip Out ATM"] ~= nil, "rip prompt")
		expect.truthy(visible(rig.model), "visible")
		rig.model:Destroy()
	end)

	suite:test("rob first closes the rip prompt", function(expect)
		local rig = makeRig()
		rig.atm.rob:_tryRob("p1")
		if rig.atm.rob._bounceTween then rig.atm.rob._bounceTween:Cancel() end
		expect.equal(rig.bank:GetDuffel("p1"), Config.ATMRobAmount, "3000 into the bag")
		local byText = prompts(rig.model)
		expect.equal(byText["Rip Out ATM"], nil, "rip prompt closed")
		expect.equal(byText["Rob ATM machine"], nil, "rob prompt gone")
		rip(rig, "p1")
		expect.equal(#rig.pickups, 0, "no rip after a rob")
		rig.model:Destroy()
	end)

	suite:test("rip first closes the rob prompt and hands the carry over", function(expect)
		local rig = makeRig()
		rip(rig, "p1")
		expect.equal(#rig.pickups, 1, "picked up")
		expect.equal(rig.pickups[1][2], rig.atm.rip, "the rip-out object")
		expect.equal(prompts(rig.model)["Rob ATM machine"], nil, "rob prompt closed")
		expect.falsy(visible(rig.model), "ATM hidden while carried")
		rig.atm.rob:_tryRob("p1")
		expect.equal(rig.bank:GetDuffel("p1"), 0, "no rob after a rip")
		rig.model:Destroy()
	end)

	suite:test("the rip hold is timed on the server", function(expect)
		local rig = makeRig()
		rig.atm.rip:_onPromptTriggered("p1")
		expect.equal(#rig.pickups, 0, "a trigger with no hold seen is refused")
		rig.atm.rip:_onHoldBegan("p1")
		rig.advance(2)
		rig.atm.rip:_onPromptTriggered("p1")
		expect.equal(#rig.pickups, 0, "a 2 s hold is refused")
		rip(rig, "p1")
		expect.equal(#rig.pickups, 1, "a full hold is honoured")
		rig.model:Destroy()
	end)

	suite:test("the rip-out object is bank-only and slows to 12", function(expect)
		local rig = makeRig()
		expect.equal(rig.atm.rip.bankOnly, true, "bankOnly")
		expect.equal(rig.atm.rip.speedCap, 12, "speedCap")
		expect.equal(rig.atm.rip.cashOutAmount, Config.ATMRipAmount, "value")
		rig.model:Destroy()
	end)

	suite:test("an ATM nobody ripped stays standing through Seal and Rearm", function(expect)
		local rig = makeRig()
		rig.atm:Seal()
		expect.truthy(visible(rig.model), "visible after Seal")
		expect.equal(next(prompts(rig.model)), nil, "no prompts after Seal")
		rig.atm:Rearm()
		expect.truthy(visible(rig.model), "visible after Rearm")
		expect.equal(next(prompts(rig.model)), nil, "no prompts at Idle")
		rig.model:Destroy()
	end)

	suite:test("a ripped ATM is gone through the cooldown and back at Rearm", function(expect)
		local rig = makeRig()
		local origin = rig.model:GetPivot()
		rip(rig, "p1")
		rig.atm.rip:DropAt(origin + Vector3.new(30, 0, 0))
		rig.atm:Seal()
		expect.falsy(visible(rig.model), "hidden after Seal")
		rig.atm:Rearm()
		expect.truthy(visible(rig.model), "visible at Rearm")
		expect.truthy((rig.model:GetPivot().Position - origin.Position).Magnitude < 0.01, "back on its spot")
		expect.equal(next(prompts(rig.model)), nil, "no prompts at Idle")
		expect.falsy(rig.atm.rip.highlight.Enabled, "highlight off at Idle")
		rig.atm:OnSessionStart()
		expect.truthy(prompts(rig.model)["Rip Out ATM"] ~= nil, "rip prompt next session")
		expect.truthy(prompts(rig.model)["Rob ATM machine"] ~= nil, "rob prompt next session")
		rig.model:Destroy()
	end)

	return suite:run()
end
