local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local RobbableObject = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.RobbableObject)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("RobbableObject")

	local AMOUNT = 500

	local function makeClock()
		local t = 1000
		return function() return t end, function(dt) t += dt end
	end

	local function tempPromptTemplate()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Rob Thing"
		prompt.ObjectText = "Thing"
		prompt.HoldDuration = 3
		return prompt
	end

	-- Multi-part model with no PrimaryPart and no distinctly-named "main"
	-- part, matching every real robbable object in this system (cash
	-- registers, ATMs) -- findAttachPart picks whichever part is closest to
	-- the model's own GetPivot(), which for a PrimaryPart-less model is its
	-- bounding-box center, not necessarily the first part created.
	local function tempModel()
		local model = Instance.new("Model")
		model.Name = "Robbable"
		for i = 1, 5 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.Position = Vector3.new(i, 0, 0)
			part.Parent = model
			-- On every part, not just whichever one findAttachPart ends up
			-- picking (the bounding-box-center heuristic isn't this fixture's
			-- concern to replicate exactly).
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 0
			emitter.Parent = part
		end
		local highlight = Instance.new("Highlight")
		highlight.Parent = model
		model.Parent = workspace
		return model
	end

	-- Every successful rob now starts a real, real-time bounce tween (spec
	-- addendum, 2026-09-14) -- must be cancelled before a test destroys the
	-- model, or it keeps running orphaned in the background against a
	-- CFrameValue whose target model no longer exists (same discipline as
	-- VaultDoorSpec's own real-tween cleanup).
	local function cancelBounce(object)
		if object._bounceTween then object._bounceTween:Cancel() end
	end

	local function makeBankAndObject(now, overrides)
		overrides = overrides or {}
		local bank = BankInstance.new({ config = Config, now = now })
		local model = tempModel()
		local refusals = {}
		local soundCalls = {}
		local object = RobbableObject.new(model, {
			bank = bank,
			promptTemplate = overrides.promptTemplate or tempPromptTemplate(),
			amount = overrides.amount or AMOUNT,
			onRefused = function(player, reason) table.insert(refusals, { player = player, reason = reason }) end,
			playRobSound = function(part) table.insert(soundCalls, part) end,
			deferUnlock = overrides.deferUnlock,
			isBlocked = overrides.isBlocked,
			blockedReason = overrides.blockedReason,
			onRobbed = overrides.onRobbed,
		})
		bank:RegisterComponent(object)
		return bank, object, model, refusals, soundCalls
	end

	suite:test("before a robbery is active, no ProximityPrompt exists at all", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		-- Bug fix, 2026-09-17: FindFirstChildOfClass has no recursive-search
		-- overload (unlike FindFirstChild) -- the old "true" second argument
		-- was silently ignored, making this assertion a tautology (always nil,
		-- regardless of whether a prompt actually existed somewhere under the
		-- object). GetDescendants actually searches the whole tree.
		local found = false
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then found = true break end
		end
		expect.falsy(found, "no prompt anywhere under the object")
		model:Destroy()
	end)

	suite:test("OnSessionStart clones the prompt template onto the object", function(expect)
		local now = select(1, makeClock())
		local template = tempPromptTemplate()
		local bank, object, model = makeBankAndObject(now, { promptTemplate = template })
		bank:TryStart("p1")
		expect.truthy(object._prompt ~= nil, "prompt cloned")
		expect.equal(object._prompt.ActionText, template.ActionText, "matches the template")
		expect.truthy(object._prompt:IsDescendantOf(model), "parented under the object")
		model:Destroy()
	end)

	suite:test("a successful rob credits the flat amount and marks the object robbed", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		object:_tryRob("p1")
		expect.equal(bank:GetDuffel("p1"), AMOUNT, "credited")
		expect.truthy(model:GetAttribute("Robbed"), "marked robbed")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("a successful rob calls playRobSound with the object's attach part", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, _, soundCalls = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		object:_tryRob("p1")
		expect.equal(#soundCalls, 1, "sound played once")
		expect.equal(soundCalls[1], object.part, "played on the object's own attach part")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("a rejected rob (cap exceeded) does not call playRobSound", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, _, soundCalls = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:TryAddDuffel("p1", Config.DuffelCap)

		object:_tryRob("p1")
		expect.equal(#soundCalls, 0, "a refused rob must not also trigger the sound cue")
		model:Destroy()
	end)

	suite:test("a successful rob destroys its own prompt (one-time-per-object)", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		local prompt = object._prompt
		object:_tryRob("p1")
		expect.equal(object._prompt, nil, "no prompt reference left")
		expect.falsy(prompt.Parent ~= nil, "the old prompt instance is destroyed")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("an already-robbed object rejects a second trigger even if the prompt still somehow exists", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		model:SetAttribute("Robbed", true) -- simulate the race: robbed, prompt not yet torn down
		object:_tryRob("p1")
		expect.equal(bank:GetDuffel("p1"), 0, "the authoritative Robbed flag blocked it -- never trust prompt-existence alone")
		model:Destroy()
	end)

	suite:test("rejects (cap exceeded) without marking the object robbed, so it can be retried later", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:TryAddDuffel("p1", Config.DuffelCap)

		object:_tryRob("p1")
		expect.falsy(model:GetAttribute("Robbed"), "NOT marked robbed")
		expect.truthy(object._prompt ~= nil, "prompt survives -- retriable later")
		model:Destroy()
	end)

	suite:test("the surfaced refusal reason is cap_exceeded", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, refusals = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:TryAddDuffel("p1", Config.DuffelCap)

		object:_tryRob("p1")
		expect.equal(#refusals, 1, "one refusal")
		expect.equal(refusals[1].reason, "cap_exceeded", "reason")
		model:Destroy()
	end)

	suite:test("Seal clears the Robbed flag and tears down any remaining prompt", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		object:_tryRob("p1") -- robs it, destroying the prompt

		object:Seal()
		expect.falsy(model:GetAttribute("Robbed"), "Robbed cleared")
		expect.equal(object._prompt, nil, "no leftover prompt reference")
		model:Destroy()
	end)

	suite:test("a fresh session after Seal re-clones a prompt and resets Robbed", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		object:_tryRob("p1")

		t += Config.SessionDuration
		bank:Step() -- Active -> Cooldown, fires Seal via _eachComponent
		t += Config.CooldownDuration
		bank:Step() -- Cooldown -> Idle

		bank:TryStart("p2")
		expect.truthy(object._prompt ~= nil, "a fresh prompt was cloned in")
		expect.falsy(model:GetAttribute("Robbed"), "Robbed reset for the new session")
		model:Destroy()
	end)

	suite:test("independent objects: robbing one leaves the others robbable", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local modelA, modelB = tempModel(), tempModel()
		local objectA = RobbableObject.new(modelA, { bank = bank, promptTemplate = tempPromptTemplate(), amount = AMOUNT })
		local objectB = RobbableObject.new(modelB, { bank = bank, promptTemplate = tempPromptTemplate(), amount = AMOUNT })
		bank:RegisterComponent(objectA)
		bank:RegisterComponent(objectB)

		bank:TryStart("p1")
		bank:AddParticipant("p1")
		objectA:_tryRob("p1")

		expect.truthy(modelA:GetAttribute("Robbed"), "A robbed")
		expect.falsy(modelB:GetAttribute("Robbed"), "B untouched")
		expect.truthy(objectB._prompt ~= nil, "B's prompt still live")
		expect.equal(bank:GetDuffel("p1"), AMOUNT, "only one grant credited")

		cancelBounce(objectA)
		modelA:Destroy()
		modelB:Destroy()
	end)

	suite:test("wired through BankInstance's real TryStart/_seal lifecycle at the exact trigger points", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, object, model = makeBankAndObject(now)

		expect.equal(object._prompt, nil, "no prompt before the robbery starts")
		bank:TryStart("p1")
		expect.truthy(object._prompt ~= nil, "prompt appears the instant RobberyActive becomes true")

		t += Config.SessionDuration
		bank:Step()
		expect.equal(bank:GetState(), "Cooldown", "session ended")
		expect.equal(object._prompt, nil, "prompt torn down at session end")
		expect.falsy(model:GetAttribute("Robbed"), "flag cleared")

		model:Destroy()
	end)

	-- Highlight lifecycle: enabled exactly when the prompt exists and is
	-- available, disabled the moment it isn't -- the same two trigger points
	-- already handling the prompt clone/destroy.
	suite:test("the Highlight starts disabled before any robbery, then enables the instant the prompt is cloned in", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		expect.falsy(object.highlight.Enabled, "disabled before the robbery starts")

		bank:TryStart("p1")
		expect.truthy(object.highlight.Enabled, "enabled the instant the prompt is cloned in")
		model:Destroy()
	end)

	suite:test("a successful rob disables the Highlight at the same moment the prompt is destroyed", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		object:_tryRob("p1")
		expect.falsy(object.highlight.Enabled, "no longer flagged as available once robbed")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("a rejected rob (cap exceeded) leaves the Highlight enabled -- still available, retriable later", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:TryAddDuffel("p1", Config.DuffelCap)

		object:_tryRob("p1")
		expect.truthy(object.highlight.Enabled, "still available -- the rob was refused, not completed")
		model:Destroy()
	end)

	suite:test("Seal disables the Highlight regardless of whether the object was robbed", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")

		object:Seal()
		expect.falsy(object.highlight.Enabled, "disabled at session end -- must not linger into cooldown")
		model:Destroy()
	end)

	suite:test("a fresh session after Seal re-enables the Highlight", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")

		t += Config.SessionDuration
		bank:Step() -- Active -> Cooldown, fires Seal
		expect.falsy(object.highlight.Enabled, "off during cooldown")
		t += Config.CooldownDuration
		bank:Step() -- Cooldown -> Idle

		bank:TryStart("p2")
		expect.truthy(object.highlight.Enabled, "re-enabled for the new session")
		model:Destroy()
	end)

	suite:test("construction requires bank, promptTemplate, and a positive amount", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local model = tempModel()

		expect.throws(function() RobbableObject.new(model, { promptTemplate = tempPromptTemplate(), amount = AMOUNT }) end, "missing bank")
		expect.throws(function() RobbableObject.new(model, { bank = bank, amount = AMOUNT }) end, "missing promptTemplate")
		expect.throws(function() RobbableObject.new(model, { bank = bank, promptTemplate = tempPromptTemplate(), amount = 0 }) end, "amount must be positive")
		model:Destroy()
	end)

	suite:test("construction requires a pre-placed Highlight", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = model
		model.Parent = workspace

		expect.throws(function()
			RobbableObject.new(model, { bank = bank, promptTemplate = tempPromptTemplate(), amount = AMOUNT })
		end, "missing Highlight")
		model:Destroy()
	end)

	suite:test("construction requires a pre-placed ParticleEmitter on the attach part", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local model = Instance.new("Model")
		local part = Instance.new("Part")
		part.Parent = model
		Instance.new("Highlight").Parent = model
		model.Parent = workspace

		expect.throws(function()
			RobbableObject.new(model, { bank = bank, promptTemplate = tempPromptTemplate(), amount = AMOUNT })
		end, "missing ParticleEmitter")
		model:Destroy()
	end)

	-- Rob-success feedback (spec addendum, 2026-09-14): a world-space cash
	-- burst plus a decaying bounce/settle, shared by both cash registers and
	-- ATMs. The actual TWEEN runs on real TweenService/engine time, fully
	-- decoupled from the injectable fake clock (same reasoning as VaultDoor's
	-- own tests) -- these only assert on what starts synchronously, and
	-- cancel the tween before teardown so it never keeps running orphaned.
	suite:test("a successful rob resolves burstEmitter to the same instance found on the attach part", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		expect.equal(object.burstEmitter, object.part:FindFirstChildOfClass("ParticleEmitter"),
			"resolved at construction, same instance")
		model:Destroy()
	end)

	suite:test("a successful rob immediately hops the model upward and starts a playing bounce tween", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		local restY = model:GetPivot().Position.Y
		local ok = pcall(function() object:_tryRob("p1") end)
		expect.truthy(ok, "no error")

		expect.truthy(model:GetPivot().Position.Y > restY, "hopped upward immediately, synchronously")
		expect.truthy(object._bounceTween ~= nil, "a bounce tween was started")
		if object._bounceTween then
			expect.equal(object._bounceTween.PlaybackState, Enum.PlaybackState.Playing, "actively playing")
			object._bounceTween:Cancel() -- avoid an orphaned real-time tween outliving this test
		end
		model:Destroy()
	end)

	suite:test("Seal cancels an in-flight bounce and restores the model to its resting position", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		local restCFrame = model:GetPivot()
		object:_tryRob("p1") -- starts the bounce, hops the model up
		expect.truthy(model:GetPivot().Position.Y > restCFrame.Position.Y, "hopped up before Seal")

		object:Seal()
		expect.equal(object._bounceTween, nil, "tween reference cleared")
		expect.equal(model:GetPivot().Position, restCFrame.Position, "snapped back to its exact resting position")
		model:Destroy()
	end)

	-- deferUnlock (spec addendum, 2026-09-17): the Bank's ATM/BankRegister
	-- now defer availability past session start (gated externally on
	-- VaultDoor.isOpen) -- every test above already confirms the DEFAULT
	-- (deferUnlock unset/false) keeps the original "available the instant
	-- the session starts" behavior for SlowFoods/Gas2Go's own registers+ATM.
	suite:test("deferUnlock=true: OnSessionStart resets Robbed but does NOT clone the prompt or enable the Highlight", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now, { deferUnlock = true })

		bank:TryStart("p1")
		expect.equal(object._prompt, nil, "no prompt cloned")
		expect.falsy(object.highlight.Enabled, "highlight stays off")
		expect.falsy(model:GetAttribute("Robbed"), "Robbed still reset to false, same as always")
		model:Destroy()
	end)

	suite:test("deferUnlock=true: Unlock() clones the prompt and enables the Highlight on demand", function(expect)
		local now = select(1, makeClock())
		local template = tempPromptTemplate()
		local bank, object, model = makeBankAndObject(now, { deferUnlock = true, promptTemplate = template })
		bank:TryStart("p1")

		object:Unlock()
		expect.truthy(object._prompt ~= nil, "prompt cloned")
		expect.equal(object._prompt.ActionText, template.ActionText, "matches the template")
		expect.truthy(object.highlight.Enabled, "highlight now on")

		-- Confirms the unlocked object is otherwise a completely normal,
		-- fully-functional RobbableObject -- deferUnlock only changes WHEN it
		-- becomes available, never what happens once it does.
		bank:AddParticipant("p1")
		object:_tryRob("p1")
		expect.equal(bank:GetDuffel("p1"), AMOUNT, "robs normally once unlocked")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("deferUnlock=true: Unlock() is idempotent -- a second call does not clone a second prompt", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now, { deferUnlock = true })
		bank:TryStart("p1")

		object:Unlock()
		local firstPrompt = object._prompt
		object:Unlock()
		expect.equal(object._prompt, firstPrompt, "same prompt instance, not re-cloned")
		local promptCount = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then promptCount += 1 end
		end
		expect.equal(promptCount, 1, "exactly one prompt exists")
		model:Destroy()
	end)

	suite:test("deferUnlock=true: Seal locks it back down, and the next session requires Unlock() again", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, object, model = makeBankAndObject(now, { deferUnlock = true })
		bank:TryStart("p1")
		object:Unlock()
		expect.truthy(object.highlight.Enabled, "unlocked")

		t += Config.SessionDuration
		bank:Step() -- Active -> Cooldown, fires Seal
		expect.falsy(object.highlight.Enabled, "locked again")
		expect.equal(object._prompt, nil, "prompt gone")

		t += Config.CooldownDuration
		bank:Step() -- Cooldown -> Idle
		bank:TryStart("p2") -- next session's OnSessionStart
		expect.equal(object._prompt, nil, "still locked -- OnSessionStart alone does not unlock a deferUnlock object")
		expect.falsy(object.highlight.Enabled, "still off")

		object:Unlock()
		expect.truthy(object.highlight.Enabled, "unlocks again on request, same as the first session")
		model:Destroy()
	end)

	-- isBlocked gate (spec addendum, 2026-09-19): additive dependency for the
	-- Supplies Robbery Carry State -- default (unset) must preserve every
	-- existing caller's behavior unchanged.
	suite:test("isBlocked defaults to a no-op -- a rob succeeds exactly as before when unset", function(expect)
		local now = select(1, makeClock())
		local bank, object, model = makeBankAndObject(now)
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		object:_tryRob("p1")
		expect.truthy(model:GetAttribute("Robbed"), "robbed normally")
		expect.equal(bank:GetDuffel("p1"), AMOUNT, "credited normally")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("a blocking isBlocked refuses the rob via onRefused with reason carrying_supplies, without marking Robbed", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, refusals = makeBankAndObject(now, { isBlocked = function() return true end })
		bank:TryStart("p1")
		bank:AddParticipant("p1")

		object:_tryRob("p1")
		expect.equal(bank:GetDuffel("p1"), 0, "nothing credited")
		expect.falsy(model:GetAttribute("Robbed"), "not marked robbed")
		expect.equal(#refusals, 1, "onRefused fired once")
		expect.equal(refusals[1].reason, "carrying_supplies", "reason")
		expect.truthy(object._prompt ~= nil, "prompt survives -- retriable once no longer blocked")
		model:Destroy()
	end)

	-- Heist layers 2026-11-17 (Task 2): blockedReason, onRobbed, Close.
	suite:test("blockedReason replaces carrying_supplies when isBlocked refuses", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, refusals = makeBankAndObject(now, { isBlocked = function() return true end, blockedReason = "no_key" })
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		object:_tryRob("p1")
		expect.equal(#refusals, 1, "refused once")
		expect.equal(refusals[1].player, "p1", "for p1")
		expect.equal(refusals[1].reason, "no_key", "with the given reason")
		expect.falsy(model:GetAttribute("Robbed"), "not robbed")
		model:Destroy()
	end)

	suite:test("onRobbed(p) runs once after a successful rob, not on a refusal", function(expect)
		local now = select(1, makeClock())
		local robbed = {}
		local bank, object, model = makeBankAndObject(now, { onRobbed = function(player)
			table.insert(robbed, { player = player }) end })
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		bank:AddParticipant("p2")
		bank:TryAddDuffel("p2", Config.DuffelCap)
		object:_tryRob("p2")
		expect.equal(#robbed, 0, "a cap refusal does not call it")
		object:_tryRob("p1")
		object:_tryRob("p1")
		expect.equal(#robbed, 1, "once")
		expect.equal(robbed[1].player, "p1", "with the robber")
		cancelBounce(object)
		model:Destroy()
	end)

	suite:test("Close: no prompt, no highlight, a trigger does nothing, Unlock cannot re-arm it; OnSessionStart re-arms", function(expect)
		local now = select(1, makeClock())
		local bank, object, model, refusals = makeBankAndObject(now, { deferUnlock = true })
		bank:TryStart("p1")
		bank:AddParticipant("p1")
		object:Unlock()
		expect.truthy(object._prompt ~= nil, "armed before Close")
		object:Close()
		expect.equal(object._prompt, nil, "no prompt")
		expect.falsy(object.highlight.Enabled, "highlight off")
		expect.truthy(model:GetAttribute("Robbed"), "Robbed = true")
		object:_tryRob("p1")
		expect.equal(bank:GetDuffel("p1"), 0, "a trigger pays nothing")
		expect.equal(#refusals, 0, "and refuses nothing")
		object:Unlock()
		expect.equal(object._prompt, nil, "a later Unlock in the same session does not re-arm")
		expect.falsy(object.highlight.Enabled, "highlight still off")
		object:OnSessionStart()
		object:Unlock()
		expect.truthy(object._prompt ~= nil, "re-armed after the next OnSessionStart")
		expect.falsy(model:GetAttribute("Robbed"), "Robbed reset")
		model:Destroy()
	end)

	return suite:run()
end
