local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local MasterComputer = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.MasterComputer)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("MasterComputer")

	local ROUND_COUNT = 3
	local WORDS = {
		"THEFT", "ALIBI", "SUSPECT", "WITNESS", "EVIDENCE", "BURGLAR", "MOTIVE",
		"ROBBERY", "DETECTIVE", "FELONY", "VERDICT", "GETAWAY", "ARREST",
		"WARRANT", "CRIMINAL", "SMUGGLER", "HOSTAGE", "RANSOM", "FRAUD",
		"FORGERY", "TRESPASS", "VANDALISM", "KIDNAP", "BRIBERY",
	}

	local function makeClock()
		local t = 1000
		return function() return t end, function(dt) t += dt end
	end

	-- Same multi-part, no-PrimaryPart shape as SafeSpec/RobbableObjectSpec's
	-- own tempModel -- findAttachPart picks whichever part is closest to
	-- GetPivot().
	local function tempModel()
		local model = Instance.new("Model")
		model.Name = "MasterComputer"
		for i = 1, 5 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Position = Vector3.new(i, 0, 0)
			part.Parent = model
		end
		-- Polish pass (Fix 1): a required pre-placed Highlight, same "off until
		-- armed" construction-time convention as RobbableObject/SupplyObject.
		local highlight = Instance.new("Highlight")
		highlight.Parent = model
		model.Parent = workspace
		return model
	end

	-- Records every call so assertions can inspect exactly what was sent to
	-- "the client" without a real remote/GUI in play.
	local function stubNet()
		local net = { calls = {} }
		net.OpenWordScrambleGui = function(_, player, payload)
			table.insert(net.calls, { "OpenWordScrambleGui", player, payload })
		end
		net.WordScrambleResult = function(_, player, outcome)
			table.insert(net.calls, { "WordScrambleResult", player, outcome })
		end
		net.RevealHackCode = function(_, player, code)
			table.insert(net.calls, { "RevealHackCode", player, code })
		end
		net.OnWordScrambleGuessSubmitted = function() end
		net.OnWordScrambleExitRequested = function() end
		-- "Randomise Word" (spec addendum): MasterComputer.new wires this the
		-- same way as the two listeners above, so the stub must answer it or
		-- construction errors.
		net.OnRandomizeWordRequested = function() end
		return net
	end

	-- Last call of a given kind, for asserting what the client was most
	-- recently told.
	local function lastCall(net, kind)
		for i = #net.calls, 1, -1 do
			if net.calls[i][1] == kind then return net.calls[i] end
		end
		return nil
	end

	local function countCalls(net, kind)
		local n = 0
		for _, c in ipairs(net.calls) do
			if c[1] == kind then n += 1 end
		end
		return n
	end

	local function letterMultiset(word: string)
		local counts = {}
		for i = 1, #word do
			local ch = string.sub(word, i, i)
			counts[ch] = (counts[ch] or 0) + 1
		end
		return counts
	end

	-- scramble() uses Fisher-Yates, which COULD coincidentally reproduce the
	-- input -- this is exactly why a re-shuffle guard exists in the
	-- implementation. Run many iterations across every word length in WORDS
	-- to prove the guard actually holds, not just that the function runs.
	suite:test("scramble never returns the original word unchanged, across many iterations", function(expect)
		for _, word in ipairs(WORDS) do
			for iteration = 1, 50 do
				local scrambled = MasterComputer._scramble(word)
				expect.truthy(scrambled ~= word, "word '" .. word .. "' iteration " .. iteration .. ": scrambled differs from original")
			end
		end
	end)

	suite:test("scramble always produces a valid anagram (same letter multiset) of the input", function(expect)
		for _, word in ipairs(WORDS) do
			for iteration = 1, 20 do
				local scrambled = MasterComputer._scramble(word)
				expect.equal(#scrambled, #word, "word '" .. word .. "': same length")
				local original, result = letterMultiset(word), letterMultiset(scrambled)
				for ch, count in pairs(original) do
					expect.equal(result[ch], count, "word '" .. word .. "': letter '" .. ch .. "' count preserved")
				end
			end
		end
	end)

	suite:test("pickWord never repeats an already-used word across a simulated full 3-round attempt", function(expect)
		for trial = 1, 30 do
			local used = {}
			for round = 1, ROUND_COUNT do
				local word = MasterComputer._pickWord(used)
				expect.truthy(word ~= nil, "trial " .. trial .. " round " .. round .. ": a word was picked")
				expect.falsy(used[word], "trial " .. trial .. " round " .. round .. ": word not already used this attempt")
				used[word] = true
			end
		end
	end)

	suite:test("_onTriggered opens round 1 only while Active and not already hacked", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)

		mc:_onTriggered("p1") -- bank is still Idle
		expect.falsy(mc._attempts["p1"], "no attempt opened while Idle")

		bank:TryStart("owner")
		mc:_onTriggered("p1")
		local attempt = mc._attempts["p1"]
		expect.truthy(attempt, "attempt opened once Active")
		expect.equal(attempt.roundIndex, 1, "starts at round 1")
		expect.truthy(attempt.currentWord ~= nil, "a current word was picked")
		expect.truthy(attempt.usedWords[attempt.currentWord], "current word marked used")

		local last = net.calls[#net.calls]
		expect.equal(last[1], "OpenWordScrambleGui", "OpenWordScrambleGui fired")
		expect.equal(last[3].roundIndex, 1, "payload roundIndex")
		expect.equal(last[3].roundCount, ROUND_COUNT, "payload roundCount")
		expect.truthy(last[3].scrambled ~= attempt.currentWord, "payload sends scrambled letters, not the true word plainly")
	end)

	suite:test("a correct guess (case-insensitive, whitespace-tolerant) advances the round with a new word", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		local firstWord = mc._attempts["p1"].currentWord

		mc:_onSubmitGuess("p1", string.lower(firstWord)) -- lowercase guess
		local attempt = mc._attempts["p1"]
		expect.truthy(attempt, "attempt survives a correct guess before round 3")
		expect.equal(attempt.roundIndex, 2, "advanced to round 2")
		expect.truthy(attempt.currentWord ~= firstWord, "a genuinely different word was picked")

		local secondWord = attempt.currentWord
		mc:_onSubmitGuess("p1", "  " .. secondWord .. "  ") -- whitespace-padded guess
		attempt = mc._attempts["p1"]
		expect.equal(attempt.roundIndex, 3, "advanced to round 3")
		expect.truthy(attempt.currentWord ~= secondWord, "yet another different word was picked")
	end)

	suite:test("an incorrect guess leaves roundIndex/currentWord unchanged and does not error", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		local attempt = mc._attempts["p1"]
		local word, roundIndex = attempt.currentWord, attempt.roundIndex

		local ok = pcall(function() mc:_onSubmitGuess("p1", "ZZZZZZZZZZ") end)
		expect.truthy(ok, "an incorrect guess does not error")
		attempt = mc._attempts["p1"]
		expect.equal(attempt.roundIndex, roundIndex, "roundIndex unchanged")
		expect.equal(attempt.currentWord, word, "currentWord unchanged")

		local last = net.calls[#net.calls]
		expect.equal(last[1], "WordScrambleResult", "WordScrambleResult fired")
		expect.equal(last[3], "incorrect", "outcome")
	end)

	suite:test("completing all 3 rounds marks hackedBy and reveals the real code; a hacked player can't retrigger", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		for round = 1, ROUND_COUNT do
			local attempt = mc._attempts["p1"]
			expect.truthy(attempt, "attempt exists at round " .. round)
			expect.equal(attempt.roundIndex, round, "correct roundIndex")
			mc:_onSubmitGuess("p1", attempt.currentWord)
		end

		expect.truthy(mc._hackedBy["p1"], "hackedBy set after 3 correct rounds")
		expect.falsy(mc._attempts["p1"], "attempt cleared after completion")
		local last = net.calls[#net.calls]
		expect.equal(last[1], "RevealHackCode", "RevealHackCode fired")
		expect.equal(last[3], mc:GetCode(), "revealed code matches GetCode()")
		local secondToLast = net.calls[#net.calls - 1]
		expect.equal(secondToLast[1], "WordScrambleResult", "WordScrambleResult fired just before RevealHackCode")
		expect.equal(secondToLast[3], "breached", "final outcome is breached")

		mc:_onTriggered("p1")
		expect.falsy(mc._attempts["p1"], "hackedBy blocks re-triggering")
	end)

	suite:test("the shared session code stays stable across rounds and players within one session", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")
		local code = mc:GetCode()
		expect.truthy(type(code) == "string" and #code == 4, "4-digit string code")

		mc:_onTriggered("p1")
		local attempt = mc._attempts["p1"]
		mc:_onSubmitGuess("p1", attempt.currentWord) -- advances to round 2
		expect.equal(mc:GetCode(), code, "code unchanged after advancing a round")

		mc:_onTriggered("p2")
		expect.equal(mc:GetCode(), code, "code unchanged for a second player")
	end)

	suite:test("Seal disables the prompt and clears attempts but preserves hackedBy; OnSessionStart clears both and regenerates the code", function(expect)
		local now, advance = makeClock()
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")
		expect.truthy(mc.prompt.Enabled, "prompt enabled once Active")

		mc:_onTriggered("p1")
		for _ = 1, ROUND_COUNT do
			local attempt = mc._attempts["p1"]
			mc:_onSubmitGuess("p1", attempt.currentWord)
		end
		expect.truthy(mc._hackedBy["p1"], "hacked before seal")

		local firstCode = mc:GetCode()
		advance(Config.SessionDuration + 1)
		bank:Step() -- -> Cooldown, dispatches Seal to every registered component
		expect.falsy(mc.prompt.Enabled, "prompt disabled after Seal")
		expect.truthy(mc._hackedBy["p1"], "hackedBy survives Seal")
		expect.equal(mc:GetCode(), firstCode, "code survives Seal (stays showing through Cooldown)")

		advance(Config.CooldownDuration + 1)
		bank:Step() -- -> Idle (Rearm)
		bank:TryStart("owner2") -- -> Active, fresh OnSessionStart
		expect.truthy(mc.prompt.Enabled, "prompt re-enabled")
		expect.falsy(mc._hackedBy["p1"], "hackedBy cleared by the new session's OnSessionStart")
		local secondCode = mc:GetCode()
		expect.truthy(type(secondCode) == "string" and #secondCode == 4, "fresh 4-digit code issued")
	end)

	suite:test("exiting mid-attempt clears state; re-triggering restarts at round 1 with a freshly picked word", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		local firstAttempt = mc._attempts["p1"]
		local firstWord = firstAttempt.currentWord
		mc:_onSubmitGuess("p1", firstWord)
		expect.equal(mc._attempts["p1"].roundIndex, 2, "advanced to round 2")

		mc:_onExitRequested("p1")
		expect.falsy(mc._attempts["p1"], "attempt cleared on exit")

		mc:_onTriggered("p1")
		local newAttempt = mc._attempts["p1"]
		expect.truthy(newAttempt, "re-triggering opens a new attempt")
		expect.equal(newAttempt.roundIndex, 1, "restarts at round 1, not resumed at round 2")
	end)

	suite:test("a player who already hacked this session skips the puzzle on retrigger and gets the code directly", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		for _ = 1, ROUND_COUNT do
			local attempt = mc._attempts["p1"]
			mc:_onSubmitGuess("p1", attempt.currentWord)
		end
		expect.truthy(mc._hackedBy["p1"], "hacked after 3 rounds")

		local callsBefore = #net.calls
		mc:_onTriggered("p1")
		expect.falsy(mc._attempts["p1"], "no attempt created on a repeat view")

		local newCalls = {}
		for i = callsBefore + 1, #net.calls do table.insert(newCalls, net.calls[i]) end
		expect.equal(#newCalls, 1, "exactly one net call fired on the repeat view")
		expect.equal(newCalls[1][1], "RevealHackCode", "fires RevealHackCode directly, no OpenWordScrambleGui/breached result")
		expect.equal(newCalls[1][3], mc:GetCode(), "reveals the real code")
	end)

	suite:test("Highlight.Enabled toggles true on OnSessionStart and false on Seal, independent of per-player hacks", function(expect)
		local now, advance = makeClock()
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)

		expect.falsy(mc.highlight.Enabled, "highlight off before any session (construction-time default)")
		bank:TryStart("owner")
		expect.truthy(mc.highlight.Enabled, "highlight on once Active")

		mc:_onTriggered("p1")
		for _ = 1, ROUND_COUNT do
			local attempt = mc._attempts["p1"]
			mc:_onSubmitGuess("p1", attempt.currentWord)
		end
		expect.truthy(mc.highlight.Enabled, "highlight stays on after a player's own successful hack -- not a one-shot Register/ATM/Safe-style highlight")

		advance(Config.SessionDuration + 1)
		bank:Step() -- -> Cooldown, dispatches Seal
		expect.falsy(mc.highlight.Enabled, "highlight off after Seal")
	end)

	suite:test("Forget clears both per-player maps", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		mc._hackedBy["p1"] = true
		mc:Forget("p1")
		expect.falsy(mc._attempts["p1"], "attempt forgotten")
		expect.falsy(mc._hackedBy["p1"], "hackedBy forgotten")
	end)

	-- ---- "Randomise Word" (spec addendum) ----

	suite:test("randomising swaps to a different unused word, decrements the budget, and does NOT advance the round", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		local before = mc._attempts["p1"]
		local originalWord = before.currentWord
		expect.equal(before.randomizesRemaining, 3, "a fresh attempt starts with 3 chances")
		expect.equal(before.roundIndex, 1, "starts on round 1")

		mc:_onRandomizeRequested("p1")
		local after = mc._attempts["p1"]
		expect.truthy(after.currentWord ~= originalWord, "word actually changed")
		expect.equal(after.randomizesRemaining, 2, "budget decremented 3 -> 2")
		expect.equal(after.roundIndex, 1, "roundIndex untouched -- randomising is not progress")
		expect.truthy(after.usedWords[originalWord], "the discarded word is marked used")
		expect.truthy(after.usedWords[after.currentWord], "the replacement is marked used too")

		local call = lastCall(net, "OpenWordScrambleGui")
		expect.equal(call[3].roundIndex, 1, "payload still reports round 1")
		expect.equal(call[3].randomizesRemaining, 2, "payload carries the decremented budget")
		expect.truthy(call[3].scrambled ~= after.currentWord, "payload carries scrambled letters, never the true word")
	end)

	suite:test("a randomised-away word never resurfaces later in the same attempt, across rounds", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		local discarded = {}

		-- Spend all 3 randomises in round 1, recording each discarded word.
		for _ = 1, 3 do
			table.insert(discarded, mc._attempts["p1"].currentWord)
			mc:_onRandomizeRequested("p1")
		end
		expect.equal(#discarded, 3, "three words were discarded")

		-- Now play out the remaining rounds and confirm none of the discarded
		-- words is ever handed back as the live word.
		local seen = {}
		for _ = 1, ROUND_COUNT do
			local attempt = mc._attempts["p1"]
			if not attempt then break end
			table.insert(seen, attempt.currentWord)
			mc:_onSubmitGuess("p1", attempt.currentWord)
		end

		for _, gone in ipairs(discarded) do
			for _, live in ipairs(seen) do
				expect.truthy(live ~= gone, "discarded word '" .. gone .. "' never came back as a live word")
			end
		end
	end)

	suite:test("randomising at 0 remaining is a silent no-op -- no net call, no state change, no error", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		for _ = 1, 3 do mc:_onRandomizeRequested("p1") end
		expect.equal(mc._attempts["p1"].randomizesRemaining, 0, "budget fully spent")

		local wordAtZero = mc._attempts["p1"].currentWord
		local roundAtZero = mc._attempts["p1"].roundIndex
		local callsBefore = countCalls(net, "OpenWordScrambleGui")

		mc:_onRandomizeRequested("p1") -- the server backstop, independent of any client gate
		mc:_onRandomizeRequested("p1")

		expect.equal(countCalls(net, "OpenWordScrambleGui"), callsBefore, "no further client push")
		expect.equal(mc._attempts["p1"].currentWord, wordAtZero, "word unchanged")
		expect.equal(mc._attempts["p1"].roundIndex, roundAtZero, "roundIndex unchanged")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 0, "budget does not go negative")

		-- And with no attempt at all (never triggered / already exited).
		mc:_onRandomizeRequested("never-triggered")
		expect.falsy(mc._attempts["never-triggered"], "no attempt conjured for an untriggered player")
	end)

	suite:test("the budget resets to 3 on a fresh attempt and is tracked independently per player", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		mc:_onRandomizeRequested("p1")
		mc:_onRandomizeRequested("p1")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 1, "p1 spent two")

		-- A second player's budget is entirely their own.
		mc:_onTriggered("p2")
		expect.equal(mc._attempts["p2"].randomizesRemaining, 3, "p2 starts fresh at 3, unaffected by p1")
		mc:_onRandomizeRequested("p2")
		expect.equal(mc._attempts["p2"].randomizesRemaining, 2, "p2 decremented independently")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 1, "p1 untouched by p2's randomise")

		-- Exit and re-trigger restores the full budget.
		mc:_onExitRequested("p1")
		expect.falsy(mc._attempts["p1"], "attempt cleared on exit")
		mc:_onTriggered("p1")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 3, "re-triggering restores all 3 chances")
		expect.equal(mc._attempts["p1"].roundIndex, 1, "and restarts at round 1")
	end)

	-- The single most important property of this feature, and the one most
	-- likely to be silently reverted by a future change that "helpfully"
	-- refreshes the budget each round. 3 chances TOTAL per attempt, shared
	-- across all 3 rounds -- not 3 per round.
	suite:test("the 3 chances are per ATTEMPT, not per round -- spending them in round 1 leaves fewer for rounds 2 and 3", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		mc:_onRandomizeRequested("p1")
		mc:_onRandomizeRequested("p1")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 1, "2 of 3 spent during round 1")

		-- Advance to round 2 by answering correctly.
		mc:_onSubmitGuess("p1", mc._attempts["p1"].currentWord)
		expect.equal(mc._attempts["p1"].roundIndex, 2, "now on round 2")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 1,
			"budget CARRIES OVER at 1 -- it must NOT refresh to 3 for the new round")
		expect.equal(lastCall(net, "OpenWordScrambleGui")[3].randomizesRemaining, 1,
			"and the round-advance payload reports the carried-over budget")

		-- Spend the last one in round 2.
		mc:_onRandomizeRequested("p1")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 0, "final chance spent in round 2")
		expect.equal(mc._attempts["p1"].roundIndex, 2, "still round 2 -- randomising never advances")

		-- Advance to round 3: still zero, and randomising is refused.
		mc:_onSubmitGuess("p1", mc._attempts["p1"].currentWord)
		expect.equal(mc._attempts["p1"].roundIndex, 3, "now on round 3")
		expect.equal(mc._attempts["p1"].randomizesRemaining, 0,
			"round 3 begins with 0 chances -- they were all spent earlier in this same attempt")

		local wordInRound3 = mc._attempts["p1"].currentWord
		mc:_onRandomizeRequested("p1")
		expect.equal(mc._attempts["p1"].currentWord, wordInRound3, "refused -- round 3's word cannot be randomised")

		-- The chain still completes normally despite the spent budget.
		mc:_onSubmitGuess("p1", mc._attempts["p1"].currentWord)
		expect.truthy(mc._hackedBy["p1"], "all 3 rounds still complete and mark hackedBy")
		expect.truthy(lastCall(net, "RevealHackCode"), "and the code is still revealed")
	end)

	-- Heist layers 2026-11-17 (Task 2): onBreached.
	suite:test("onBreached(p) runs once at the breach, not again when p re-triggers", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local net = stubNet()
		local breached = {}
		local mc = MasterComputer.new(tempModel(), { bank = bank, net = net,
			onBreached = function(player) table.insert(breached, player) end })
		bank:RegisterComponent(mc)
		bank:TryStart("owner")

		mc:_onTriggered("p1")
		for _ = 1, ROUND_COUNT - 1 do
			mc:_onSubmitGuess("p1", mc._attempts["p1"].currentWord)
		end
		expect.equal(#breached, 0, "not before the last round")
		mc:_onSubmitGuess("p1", mc._attempts["p1"].currentWord)
		expect.equal(#breached, 1, "once at the breach")
		expect.equal(breached[1], "p1", "with the breacher")
		mc:_onTriggered("p1")
		mc:_onSubmitGuess("p1", "anything")
		expect.equal(#breached, 1, "a re-trigger does not call it again")
	end)

	return suite:run()
end
