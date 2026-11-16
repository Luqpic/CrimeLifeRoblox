local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Safe = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.Safe)
	local MasterComputer = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.MasterComputer)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("NewsStationSafe")

	local AMOUNT = 5000

	local function makeClock()
		local t = 1000
		return function() return t end, function(dt) t += dt end
	end

	local function tempPromptTemplate()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Crack Safe"
		prompt.ObjectText = "Safe"
		prompt.HoldDuration = 8
		return prompt
	end

	-- Same shape as SafeSpec's own tempModel: multi-part, no PrimaryPart,
	-- matching the real NewsStation Safe.Safe models.
	local function tempSafeModel()
		local model = Instance.new("Model")
		model.Name = "Safe"
		for i = 1, 5 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Position = Vector3.new(i, 0, 0)
			part.Parent = model
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 0
			emitter.Parent = part
		end
		local highlight = Instance.new("Highlight")
		highlight.Parent = model
		model.Parent = workspace
		return model
	end

	local function tempComputerModel()
		local model = Instance.new("Model")
		model.Name = "MasterComputer"
		for i = 1, 3 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Position = Vector3.new(100 + i, 0, 0)
			part.Parent = model
		end
		-- Polish pass (Fix 1): MasterComputer.new now requires a pre-placed
		-- Highlight, same convention as tempSafeModel's own above.
		local highlight = Instance.new("Highlight")
		highlight.Parent = model
		model.Parent = workspace
		return model
	end

	local function stubNet()
		return {
			OpenWordScrambleGui = function() end,
			WordScrambleResult = function() end,
			RevealHackCode = function() end,
			OnWordScrambleGuessSubmitted = function() end,
			OnWordScrambleExitRequested = function() end,
			-- "Randomise Word" (spec addendum): MasterComputer.new wires this
			-- listener alongside the two above, so this stub must answer it even
			-- though these safe tests never exercise the puzzle itself.
			OnRandomizeWordRequested = function() end,
		}
	end

	-- Same "one shared code, independently-crackable safes" shape as the
	-- Bank's own SafeCode/Safe pairing (see SafeSpec's own precedent) --
	-- except the code source here is MasterComputer itself, not a dedicated
	-- SafeCode instance (there is no separate physical code-combination
	-- display at NewsStation to own it).
	local function makeRig(now)
		local bank = BankInstance.new({ config = Config, now = now or select(1, makeClock()) })
		local mc = MasterComputer.new(tempComputerModel(), { bank = bank, net = stubNet() })
		bank:RegisterComponent(mc)

		local safes = {}
		for i = 1, 3 do
			local safe = Safe.new(tempSafeModel(), {
				bank = bank,
				promptTemplate = tempPromptTemplate(),
				amount = AMOUNT,
				getCode = function() return mc:GetCode() end,
				onOpenGui = function() end,
				-- Fake string players have no real Character/HumanoidRootPart --
				-- same stub-out as SafeSpec's own measure override.
				measure = function() return 0 end,
			})
			bank:RegisterComponent(safe)
			table.insert(safes, safe)
		end
		return bank, mc, safes
	end

	suite:test("all 3 safes read the same code from MasterComputer once a session starts", function(expect)
		local bank, mc, safes = makeRig()
		bank:TryStart("owner")

		local code = mc:GetCode()
		expect.truthy(type(code) == "string" and #code == 4, "code is a 4-digit string")
		for i, safe in ipairs(safes) do
			expect.equal(safe.getCode(), code, "safe " .. i .. " reads the shared code")
		end
	end)

	suite:test("cracking one safe does not mark the others robbed, and all 3 accept the SAME code independently", function(expect)
		local bank, mc, safes = makeRig()
		bank:TryStart("owner")
		local code = mc:GetCode()
		-- TryAddDuffel (the actual grant underneath a correct guess) requires
		-- the player be a registered participant -- same requirement as every
		-- other robbable object in this codebase, not something Safe.lua
		-- re-derives on its own.
		bank:AddParticipant("p1")
		bank:AddParticipant("p2")
		bank:AddParticipant("p3")

		safes[1]._pending["p1"] = true
		local ok1 = safes[1]:TrySubmitCode("p1", code)
		expect.truthy(ok1, "safe 1 cracked with the real code")
		expect.truthy(safes[1].model:GetAttribute("Robbed"), "safe 1 marked robbed")
		expect.falsy(safes[2].model:GetAttribute("Robbed"), "safe 2 untouched")
		expect.falsy(safes[3].model:GetAttribute("Robbed"), "safe 3 untouched")

		safes[2]._pending["p2"] = true
		local ok2 = safes[2]:TrySubmitCode("p2", code)
		expect.truthy(ok2, "safe 2 independently cracked with the SAME code")
		expect.truthy(safes[2].model:GetAttribute("Robbed"), "safe 2 marked robbed")
		expect.falsy(safes[3].model:GetAttribute("Robbed"), "safe 3 still untouched")

		safes[3]._pending["p3"] = true
		local ok3 = safes[3]:TrySubmitCode("p3", code)
		expect.truthy(ok3, "safe 3 independently cracked with the SAME code")
		expect.truthy(safes[3].model:GetAttribute("Robbed"), "safe 3 marked robbed")
	end)

	suite:test("a wrong guess against any safe is rejected without marking it robbed", function(expect)
		local bank, mc, safes = makeRig()
		bank:TryStart("owner")
		local code = mc:GetCode()
		local wrong = (code == "0000") and "1111" or "0000"

		safes[1]._pending["p1"] = true
		local ok, reason = safes[1]:TrySubmitCode("p1", wrong)
		expect.falsy(ok, "wrong guess rejected")
		expect.equal(reason, "wrong_code", "reason")
		expect.falsy(safes[1].model:GetAttribute("Robbed"), "not marked robbed")
	end)

	suite:test("a submission while the session is sealed is rejected as inactive", function(expect)
		local now, advance = makeClock()
		local bank, mc, safes = makeRig(now)
		bank:TryStart("owner")
		local code = mc:GetCode()

		-- Prompt hold happens before seal (sets _pending), submission
		-- arrives just after -- same real gap Safe.lua's own header comment
		-- calls out.
		safes[1]._pending["p1"] = true
		advance(Config.SessionDuration + 1)
		bank:Step() -- -> Cooldown, Seal dispatched to mc + all 3 safes

		local ok, reason = safes[1]:TrySubmitCode("p1", code)
		expect.falsy(ok, "rejected once sealed")
		expect.equal(reason, "inactive", "reason")
	end)

	suite:test("a fresh session issues a new shared code and re-arms all 3 safes", function(expect)
		local now, advance = makeClock()
		local bank, mc, safes = makeRig(now)
		bank:TryStart("owner")
		bank:AddParticipant("p1")
		local firstCode = mc:GetCode()

		safes[1]._pending["p1"] = true
		safes[1]:TrySubmitCode("p1", firstCode)
		expect.truthy(safes[1].model:GetAttribute("Robbed"), "cracked in session 1")

		advance(Config.SessionDuration + 1)
		bank:Step() -- -> Cooldown
		advance(Config.CooldownDuration + 1)
		bank:Step() -- -> Idle
		bank:TryStart("owner2") -- -> Active, fresh OnSessionStart for every component

		expect.falsy(safes[1].model:GetAttribute("Robbed"), "safe 1 reset for the new session")
		local secondCode = mc:GetCode()
		expect.truthy(type(secondCode) == "string" and #secondCode == 4, "fresh 4-digit code issued")
		for i, safe in ipairs(safes) do
			expect.equal(safe.getCode(), secondCode, "safe " .. i .. " reads the NEW shared code")
		end
	end)

	-- City (phase 3 Task 5): a prompt's HoldDuration is enforced only on the client, so a script
	-- could re-trigger a safe and guess twice a second. NewsStation safes opt in to a server-side
	-- floor between one player's attempts equal to the prompt's own HoldDuration (8 on the
	-- template here), shared across the location's safes. A refused attempt keeps the try.
	local function makeHoldRig()
		local t = 0
		local bank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local mc = MasterComputer.new(tempComputerModel(), { bank = bank, net = stubNet() })
		bank:RegisterComponent(mc)
		local safes = {}
		for _ = 1, 2 do
			local safe = Safe.new(tempSafeModel(), {
				bank = bank,
				promptTemplate = tempPromptTemplate(),
				amount = AMOUNT,
				getCode = function() return mc:GetCode() end,
				onOpenGui = function() end,
				measure = function() return 0 end,
				enforceHold = true,
				clock = function() return t end,
			})
			bank:RegisterComponent(safe)
			table.insert(safes, safe)
		end
		return bank, mc, safes, function(dt) t += dt end
	end

	suite:test("an attempt inside the prompt's hold time is refused without consuming the try; after it, accepted", function(expect)
		local bank, mc, safes, advance = makeHoldRig()
		bank:TryStart("owner")
		bank:AddParticipant("h1")
		local code = mc:GetCode()
		local wrong = (code == "0000") and "1111" or "0000"

		safes[1]._pending["h1"] = true
		local _, firstReason = safes[1]:TrySubmitCode("h1", wrong)

		safes[1]._pending["h1"] = true -- a re-trigger with the hold skipped
		advance(7.9)
		local okEarly, earlyReason = safes[1]:TrySubmitCode("h1", code)
		local pendingKept = safes[1]._pending["h1"] == true

		advance(0.1) -- exactly the template's HoldDuration after the first attempt
		local okLater = safes[1]:TrySubmitCode("h1", code)

		expect.equal(firstReason, "wrong_code", "first attempt counted")
		expect.falsy(okEarly, "refused inside the hold time")
		expect.equal(earlyReason, "too_soon", "reason")
		expect.truthy(pendingKept, "the try was not consumed")
		expect.truthy(okLater, "accepted once the hold time has passed")
	end)

	suite:test("the hold floor is per player across the location's safes", function(expect)
		local bank, mc, safes, advance = makeHoldRig()
		bank:TryStart("owner")
		local code = mc:GetCode()
		local wrong = (code == "0000") and "1111" or "0000"

		safes[1]._pending["h2"] = true
		safes[1]:TrySubmitCode("h2", wrong)
		advance(1)
		safes[2]._pending["h2"] = true
		local _, otherSafeReason = safes[2]:TrySubmitCode("h2", wrong)
		safes[2]._pending["h3"] = true
		local _, otherPlayerReason = safes[2]:TrySubmitCode("h3", wrong)

		expect.equal(otherSafeReason, "too_soon", "a second safe does not reset the floor")
		expect.equal(otherPlayerReason, "wrong_code", "another player is not held back")
	end)

	return suite:run()
end
