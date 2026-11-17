local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local SupplyObject = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.SupplyObject)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("SupplyObject")

	local function makeClock()
		local t = 1000
		return function() return t end, function(dt) t += dt end
	end

	local function tempPromptTemplate()
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal Supplies"
		prompt.ObjectText = "Supplies"
		prompt.HoldDuration = 3
		return prompt
	end

	-- Multi-part, no-PrimaryPart model, matching the real SupplyFoodBox/
	-- Barrels models -- findAttachPart picks whichever part is closest to
	-- GetPivot().
	local ORIGIN = CFrame.new(10, 0, 0)
	local function tempModel()
		local model = Instance.new("Model")
		model.Name = "Supply"
		for i = 1, 4 do
			local part = Instance.new("Part")
			part.Name = "Part"
			part.Anchored = true
			part.CanCollide = true
			part.Transparency = 0
			part.Parent = model
		end
		local highlight = Instance.new("Highlight")
		highlight.Parent = model
		model.Parent = workspace
		model:PivotTo(ORIGIN)
		return model
	end

	local function allPartsHidden(model): boolean
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Transparency ~= 1 or d.CanCollide ~= false then return false end
			end
		end
		return true
	end

	local function allPartsVisible(model): boolean
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Transparency ~= 0 or d.CanCollide ~= true then return false end
			end
		end
		return true
	end

	local function allPartsUnanchored(model): boolean
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Anchored then return false end
		end
		return true
	end

	local function allPartsAnchored(model): boolean
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and not d.Anchored then return false end
		end
		return true
	end

	local function makeBankAndSupply(now, overrides)
		overrides = overrides or {}
		local bank = BankInstance.new({ config = Config, now = now })
		local model = tempModel()
		local refusals = {}
		local pickups = {}
		local supply = SupplyObject.new(model, {
			bank = bank,
			promptTemplate = overrides.promptTemplate or tempPromptTemplate(),
			repickupPromptTemplate = overrides.repickupPromptTemplate or tempPromptTemplate(),
			onRefused = function(player, reason) table.insert(refusals, { player = player, reason = reason }) end,
			isBlocked = overrides.isBlocked,
			hasDuffel = overrides.hasDuffel,
			despawnTime = overrides.despawnTime,
			startHidden = overrides.startHidden,
			bankOnly = overrides.bankOnly,
			speedCap = overrides.speedCap,
			-- Per-location cash-out generalization (spec addendum, 2026-09-2X):
			-- now a required dep -- defaulted here so every EXISTING test that
			-- doesn't care about the exact value keeps working unchanged.
			cashOutAmount = overrides.cashOutAmount or 100,
			onPickup = overrides.onPickup or function(player, self) table.insert(pickups, { player = player, self = self }) end,
		})
		bank:RegisterComponent(supply)
		return bank, supply, model, refusals, pickups
	end

	suite:test("construction requires bank, promptTemplate, repickupPromptTemplate, onPickup, and a pre-placed Highlight", function(expect)
		local now = select(1, makeClock())
		local bank = BankInstance.new({ config = Config, now = now })
		local template = tempPromptTemplate()
		local repickupTemplate = tempPromptTemplate()

		expect.throws(function() SupplyObject.new(tempModel(), { promptTemplate = template, repickupPromptTemplate = repickupTemplate, onPickup = function() end }) end, "missing bank")
		expect.throws(function() SupplyObject.new(tempModel(), { bank = bank, repickupPromptTemplate = repickupTemplate, onPickup = function() end }) end, "missing promptTemplate")
		expect.throws(function() SupplyObject.new(tempModel(), { bank = bank, promptTemplate = template, onPickup = function() end }) end, "missing repickupPromptTemplate")
		expect.throws(function() SupplyObject.new(tempModel(), { bank = bank, promptTemplate = template, repickupPromptTemplate = repickupTemplate }) end, "missing onPickup")
		expect.throws(function()
			SupplyObject.new(tempModel(), { bank = bank, promptTemplate = template, repickupPromptTemplate = repickupTemplate, onPickup = function() end })
		end, "missing cashOutAmount")

		local noHighlight = Instance.new("Model")
		Instance.new("Part").Parent = noHighlight
		noHighlight.Parent = workspace
		expect.throws(function()
			SupplyObject.new(noHighlight, { bank = bank, promptTemplate = template, repickupPromptTemplate = repickupTemplate, onPickup = function() end })
		end, "missing Highlight")
		noHighlight:Destroy()
	end)

	suite:test("OnSessionStart reveals the object at its original position and arms a live prompt", function(expect)
		local now = select(1, makeClock())
		local template = tempPromptTemplate()
		local bank, supply, model = makeBankAndSupply(now, { promptTemplate = template })
		bank:TryStart("p1")

		expect.truthy(supply._prompt ~= nil, "prompt cloned")
		expect.equal(supply._prompt.ActionText, template.ActionText, "matches the template")
		expect.truthy(supply.highlight.Enabled, "highlight on")
		expect.truthy(allPartsVisible(model), "fully visible")
		model:Destroy()
	end)

	suite:test("triggering the prompt hides the model, tears down the prompt, and fires onPickup", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, _, pickups = makeBankAndSupply(now)
		bank:TryStart("p1")

		supply:_onTriggered("p1")
		expect.equal(#pickups, 1, "onPickup fired once")
		expect.equal(pickups[1].player, "p1", "for the triggering player")
		expect.equal(pickups[1].self, supply, "passes itself")
		expect.equal(supply._prompt, nil, "prompt torn down")
		expect.falsy(supply.highlight.Enabled, "highlight off")
		expect.truthy(allPartsHidden(model), "fully hidden")
		model:Destroy()
	end)

	suite:test("isBlocked refuses the pickup via onRefused with reason carrying_supplies, leaving the object untouched", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, refusals, pickups = makeBankAndSupply(now, { isBlocked = function() return true end })
		bank:TryStart("p1")

		supply:_onTriggered("p1")
		expect.equal(#pickups, 0, "onPickup never fired")
		expect.equal(#refusals, 1, "onRefused fired once")
		expect.equal(refusals[1].reason, "carrying_supplies", "reason")
		expect.truthy(supply._prompt ~= nil, "prompt survives")
		expect.truthy(allPartsVisible(model), "still fully visible")
		model:Destroy()
	end)

	suite:test("DropAt reappears the object at the given CFrame, visible and re-armed", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		supply:_onTriggered("p1") -- picked up, hidden

		local dropCFrame = CFrame.new(50, 5, 50)
		supply:DropAt(dropCFrame)
		expect.equal(model:GetPivot().Position, dropCFrame.Position, "moved to the drop location")
		expect.truthy(allPartsVisible(model), "visible again")
		expect.truthy(supply._prompt ~= nil, "re-armed with a live prompt")
		expect.truthy(supply.highlight.Enabled, "highlight back on")
		model:Destroy()
	end)

	suite:test("DropAt makes the object physics-active (unanchored, collidable) and starts the countdown display at despawnTime", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")

		supply:DropAt(CFrame.new(50, 5, 50))
		expect.truthy(allPartsUnanchored(model), "unanchored -- falls under gravity")
		expect.truthy(allPartsVisible(model), "collidable (allPartsVisible already checks CanCollide==true)")
		expect.truthy(supply.countdownGui.Enabled, "countdown shown")
		expect.equal(supply.countdownLabel.Text, "9999s", "starts at the full despawnTime")
		model:Destroy()
	end)

	suite:test("re-picking up a dropped object immediately re-anchors it and hides the countdown", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(50, 5, 50))

		supply:_onTriggered("p2") -- re-picked-up before the 9999s timer could ever fire
		expect.truthy(allPartsAnchored(model), "re-anchored immediately, not left physics-active")
		expect.falsy(supply.countdownGui.Enabled, "countdown hidden immediately, not on the next tick")
		model:Destroy()
	end)

	suite:test("the countdown ticks down over real time and auto-hides/re-anchors when it reaches 0", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 2 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))
		expect.equal(supply.countdownLabel.Text, "2s", "starts at 2")

		task.wait(1.2)
		expect.equal(supply.countdownLabel.Text, "1s", "ticked down to 1 after ~1s")
		expect.truthy(allPartsUnanchored(model), "still physics-active mid-countdown")

		task.wait(1.2)
		expect.truthy(allPartsHidden(model), "hidden once the countdown reaches 0")
		expect.truthy(allPartsAnchored(model), "re-anchored once the countdown reaches 0")
		expect.falsy(supply.countdownGui.Enabled, "countdown hidden once expired")
		model:Destroy()
	end)

	suite:test("an unclaimed drop despawns (hides again) after despawnTime elapses", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))
		expect.truthy(allPartsVisible(model), "visible right after dropping")

		-- Wait past despawnTime AND the ~0.35s implosion that now plays before
		-- the object actually hides, not just despawnTime alone.
		task.wait(0.5)
		expect.truthy(allPartsHidden(model), "hidden again once the despawn timer and implosion finish")
		expect.equal(supply._prompt, nil, "prompt torn down")
		model:Destroy()
	end)

	suite:test("re-picking up a drop before it despawns cancels the pending timer -- a later drop is not hidden by the stale one", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20)) -- first drop, despawn timer A scheduled

		supply:_onTriggered("p2") -- picked back up before timer A fires -- invalidates it
		local secondDrop = CFrame.new(99, 0, 99)
		supply:DropAt(secondDrop) -- second drop, at a different spot, despawn timer B scheduled

		-- Long enough for timer A to have fired (if it wasn't invalidated) AND
		-- for timer B's own despawnTime + ~0.35s implosion to fully complete.
		task.wait(0.5)
		expect.truthy(allPartsHidden(model), "timer B fired, hiding it")
		-- If timer A had wrongly fired mid-flight it would have hidden the
		-- object while it still visually sat at secondDrop -- the real
		-- assertion that matters is that this test doesn't require any
		-- special-casing: the generation counter makes A a complete no-op.
		model:Destroy()
	end)

	-- Real session-lifecycle driven resets (same shape as Safe/RobbableObject
	-- Spec's own "fresh session after Seal" tests): TryStart -> Step through
	-- SessionDuration (Active -> Cooldown, fires Seal) -> Step through
	-- CooldownDuration (Cooldown -> Idle) -> TryStart again (fires the NEXT
	-- session's OnSessionStart).
	suite:test("OnSessionStart resets to the original position/visible/armed regardless of prior state: carried", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, supply, model = makeBankAndSupply(now)
		bank:TryStart("p1")
		supply:_onTriggered("p1") -- carried off, hidden

		t += Config.SessionDuration
		bank:Step()
		t += Config.CooldownDuration
		bank:Step()
		bank:TryStart("p2")

		expect.equal(model:GetPivot().Position, ORIGIN.Position, "back at the original position")
		expect.truthy(allPartsVisible(model), "visible")
		expect.truthy(supply._prompt ~= nil, "armed")
		model:Destroy()
	end)

	suite:test("OnSessionStart resets to the original position/visible/armed regardless of prior state: dropped elsewhere", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(77, 0, 77))

		t += Config.SessionDuration
		bank:Step()
		t += Config.CooldownDuration
		bank:Step()
		bank:TryStart("p2")

		expect.equal(model:GetPivot().Position, ORIGIN.Position, "back at the original position")
		expect.truthy(allPartsVisible(model), "visible")
		expect.truthy(allPartsAnchored(model), "re-anchored -- not left physics-active from the mid-session drop")
		expect.falsy(supply.countdownGui.Enabled, "countdown hidden")
		model:Destroy()
	end)

	suite:test("OnSessionStart resets to the original position/visible/armed regardless of prior state: despawned", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(77, 0, 77))
		task.wait(0.15) -- fully despawned/hidden now

		t += Config.SessionDuration
		bank:Step()
		t += Config.CooldownDuration
		bank:Step()
		bank:TryStart("p2")

		expect.equal(model:GetPivot().Position, ORIGIN.Position, "back at the original position")
		expect.truthy(allPartsVisible(model), "visible")
		expect.truthy(supply._prompt ~= nil, "armed")
		model:Destroy()
	end)

	suite:test("Seal hides the model, disables the highlight, and tears down the prompt", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now)
		bank:TryStart("p1")

		supply:Seal()
		expect.equal(supply._prompt, nil, "prompt gone")
		expect.falsy(supply.highlight.Enabled, "highlight off")
		expect.truthy(allPartsHidden(model), "hidden")
		model:Destroy()
	end)

	suite:test("Seal called mid-drop re-anchors the object and hides the countdown", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(30, 0, 30)) -- physics-active, countdown running

		supply:Seal()
		expect.truthy(allPartsHidden(model), "hidden")
		expect.truthy(allPartsAnchored(model), "re-anchored, not left physics-active into cooldown")
		expect.falsy(supply.countdownGui.Enabled, "countdown hidden")
		model:Destroy()
	end)

	suite:test("DropAt re-arms with the instant re-pickup template (HoldDuration 0), distinct from OnSessionStart's own template", function(expect)
		local now = select(1, makeClock())
		local originalTemplate = tempPromptTemplate() -- HoldDuration = 3
		local repickupTemplate = tempPromptTemplate()
		repickupTemplate.HoldDuration = 0
		local bank, supply, model = makeBankAndSupply(now, {
			promptTemplate = originalTemplate,
			repickupPromptTemplate = repickupTemplate,
			despawnTime = 9999,
		})
		bank:TryStart("p1")
		expect.equal(supply._prompt.HoldDuration, 3, "OnSessionStart arms with the original template's hold duration")

		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))
		expect.equal(supply._prompt.HoldDuration, 0, "DropAt re-arms with the instant re-pickup template")
		model:Destroy()
	end)

	suite:test("pickup/drop succeed even when SupplyPickupSound/SupplyDropSound aren't present on the attach part", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, _, pickups = makeBankAndSupply(now, { despawnTime = 9999 })
		bank:TryStart("p1")
		-- Temp test models never have SupplyPickupSound/SupplyDropSound children
		-- (only the real world objects do) -- both lookups must be nil-safe
		-- no-ops, not hard failures, when the Sound is simply absent. If the
		-- lookup weren't defensive, these calls would error and this whole test
		-- case would fail via the suite's own pcall.
		supply:_onTriggered("p1")
		expect.equal(#pickups, 1, "pickup still succeeded with no SupplyPickupSound present")

		local dropCFrame = CFrame.new(5, 0, 5)
		supply:DropAt(dropCFrame)
		expect.equal(model:GetPivot().Position, dropCFrame.Position, "drop still succeeded with no SupplyDropSound present")
		model:Destroy()
	end)

	suite:test("natural despawn plays a collapse-inward implosion, then hides/re-anchors and resets scale to 1", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))

		task.wait(0.08) -- despawnTime (0.05s) elapsed -- implosion should have just started
		expect.truthy(supply._implosionTween ~= nil, "implosion tween started at despawn")
		expect.truthy(allPartsVisible(model), "still visible/physics-active while the implosion plays")

		task.wait(0.5) -- implosion tween (0.35s) has had time to complete
		expect.truthy(allPartsHidden(model), "hidden once the implosion completes")
		expect.truthy(allPartsAnchored(model), "re-anchored once the implosion completes")
		expect.equal(model:GetScale(), 1, "scale reset to 1, ready for the next reveal")
		model:Destroy()
	end)

	suite:test("Seal called mid-implosion cancels the tween and lands in a clean hidden/scale-1 state", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))
		task.wait(0.08) -- implosion now in flight
		expect.truthy(supply._implosionTween ~= nil, "implosion in flight before Seal")

		supply:Seal()
		expect.equal(supply._implosionTween, nil, "implosion tween cancelled")
		expect.truthy(allPartsHidden(model), "hidden")
		expect.truthy(allPartsAnchored(model), "re-anchored")
		expect.equal(model:GetScale(), 1, "scale forced back to 1, not left stuck mid-shrink")
		model:Destroy()
	end)

	suite:test("OnSessionStart called mid-implosion cancels the tween and resets cleanly", function(expect)
		local t = 1000
		local now = function() return t end
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))
		task.wait(0.08) -- implosion now in flight

		t += Config.SessionDuration
		bank:Step()
		t += Config.CooldownDuration
		bank:Step()
		bank:TryStart("p2")

		expect.equal(supply._implosionTween, nil, "implosion tween cancelled")
		expect.equal(model:GetPivot().Position, ORIGIN.Position, "back at the original position")
		expect.truthy(allPartsVisible(model), "visible again (fresh session)")
		expect.equal(model:GetScale(), 1, "scale correct, not left stuck mid-shrink")
		model:Destroy()
	end)

	suite:test("the Highlight stays enabled through the entire implosion, only turning off in the same step as the rest of the hide sequence", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { despawnTime = 0.05 })
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20))

		task.wait(0.08) -- despawnTime elapsed, implosion just started
		expect.truthy(supply._implosionTween ~= nil, "implosion in flight")
		expect.truthy(supply.highlight.Enabled, "highlight still on while the implosion plays -- regression: this used to turn off the instant the countdown hit 0, before the tween even started")

		task.wait(0.15) -- implosion (0.35s) still in flight, not yet complete
		expect.truthy(supply.highlight.Enabled, "still on partway through the shrink")

		task.wait(0.3) -- implosion now complete
		expect.falsy(supply.highlight.Enabled, "off only once the object is actually gone")
		expect.truthy(allPartsHidden(model), "hidden in the same step")
		model:Destroy()
	end)

	suite:test("construction captures whatever scale the live world model is authored at as its own baseline, never forcing a hardcoded 1", function(expect)
		local t = 1000
		local now = function() return t end
		local bank = BankInstance.new({ config = Config, now = now })
		local model = tempModel()
		-- Spec correction, 2026-09-2X: an earlier round force-set ScaleTo(1) at
		-- construction, assuming 1 was always correct -- WRONG. The real
		-- SupplyFoodBox has been deliberately hand-scaled to 0.437 in Studio
		-- (its true/original geometry was oversized); Barrels correctly stays at
		-- 1. Construction must respect whatever is currently authored, not
		-- overwrite it -- this is what actually fixed the "despawn implosion
		-- looks like it grows first" / "respawned supplies are larger than
		-- original" reports (both were the SAME leftover-corruption symptom,
		-- not caused by this component ever hardcoding 1).
		model:ScaleTo(0.437)
		expect.truthy(math.abs(model:GetScale() - 0.437) < 0.001, "authored at 0.437 before construction, as a sanity check on the repro itself")

		local supply = SupplyObject.new(model, {
			bank = bank,
			promptTemplate = tempPromptTemplate(),
			repickupPromptTemplate = tempPromptTemplate(),
			cashOutAmount = 100,
			onPickup = function() end,
		})
		expect.truthy(math.abs(model:GetScale() - 0.437) < 0.001, "construction leaves the authored scale untouched")
		expect.truthy(math.abs(supply.originalScale - 0.437) < 0.001, "captured as this object's own baseline")

		-- Full pickup -> drop -> natural-despawn cycle must land back at THIS
		-- object's own baseline (0.437), not a hardcoded 1 -- proves every
		-- ScaleTo reset in the module actually reads self.originalScale.
		bank:TryStart("p1")
		supply:_onTriggered("p1")
		supply:DropAt(CFrame.new(20, 0, 20)) -- physics-active, mid-drop

		-- Advance past the session (Active -> Cooldown, fires Seal) and the
		-- cooldown (Cooldown -> Idle), then start a fresh session -- fires
		-- OnSessionStart while the object was still mid-drop, same shape as
		-- this file's other "regardless of prior state" tests.
		t += Config.SessionDuration
		bank:Step()
		t += Config.CooldownDuration
		bank:Step()
		bank:TryStart("p2")

		expect.truthy(math.abs(model:GetScale() - 0.437) < 0.001, "still at the authored baseline after a full reset cycle, not reset to 1")
		model:Destroy()
	end)

	suite:test("hasDuffel refuses the pickup via onRefused with reason has_duffel, leaving the object untouched -- both the original and re-pickup trigger", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, refusals, pickups = makeBankAndSupply(now, { hasDuffel = function() return true end })
		bank:TryStart("p1")

		supply:_onTriggered("p1")
		expect.equal(#pickups, 0, "onPickup never fired")
		expect.equal(#refusals, 1, "onRefused fired once")
		expect.equal(refusals[1].reason, "has_duffel", "reason")
		expect.truthy(supply._prompt ~= nil, "prompt survives")
		expect.truthy(allPartsVisible(model), "still fully visible")
		model:Destroy()
	end)

	suite:test("cashOutAmount is stored verbatim from construction -- the per-location generalization this object is required to carry", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { cashOutAmount = 20000 })
		expect.equal(supply.cashOutAmount, 20000, "matches whatever this specific object was constructed with, e.g. NewsStation's 20000 vs SlowFoods/Gas2Go's 10000")
		model:Destroy()
	end)

	suite:test("the default no-op hasDuffel preserves existing pickup behavior", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, refusals, pickups = makeBankAndSupply(now) -- no hasDuffel override
		bank:TryStart("p1")

		supply:_onTriggered("p1")
		expect.equal(#pickups, 1, "pickup succeeds when nothing overrides hasDuffel")
		expect.equal(#refusals, 0, "no refusal")
		model:Destroy()
	end)

	-- Heist layers 2026-11-17: bank-only heavy loot, handed over by code rather than a prompt.
	local function promptCount(model): number
		local n = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then n += 1 end
		end
		return n
	end

	suite:test("bankOnly and speedCap are stored as fields", function(expect)
		local now = select(1, makeClock())
		local _, supply, model = makeBankAndSupply(now, { bankOnly = true, speedCap = 12 })
		expect.equal(supply.bankOnly, true, "bankOnly")
		expect.equal(supply.speedCap, 12, "speedCap")
		model:Destroy()
	end)

	suite:test("startHidden stays hidden with no prompt at OnSessionStart", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model = makeBankAndSupply(now, { startHidden = true })
		bank:TryStart("p1")
		expect.equal(promptCount(model), 0, "no steal prompt")
		expect.equal(supply._prompt, nil, "no prompt held")
		expect.truthy(allPartsHidden(model), "model hidden")
		expect.falsy(supply.highlight.Enabled, "highlight off")
		model:Destroy()
	end)

	suite:test("GiveTo hands a hidden object over once through onPickup", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, _, pickups = makeBankAndSupply(now, { startHidden = true })
		bank:TryStart("p1")
		expect.truthy(supply:GiveTo("p1"), "first GiveTo succeeds")
		expect.equal(#pickups, 1, "onPickup once")
		expect.equal(pickups[1].player, "p1", "to the player")
		expect.equal(pickups[1].self, supply, "with the object")
		expect.falsy(supply:GiveTo("p2"), "second GiveTo refused")
		expect.equal(#pickups, 1, "still one pickup")
		model:Destroy()
	end)

	suite:test("GiveTo honours isBlocked and hasDuffel and refuses a visible object", function(expect)
		local now = select(1, makeClock())
		local bank, supply, model, refusals, pickups = makeBankAndSupply(now, {
			startHidden = true,
			isBlocked = function(p) return p == "blocked" end,
			hasDuffel = function(p) return p == "bagged" end,
		})
		expect.falsy(supply:GiveTo("p1"), "refused before any session")
		bank:TryStart("p1")
		expect.falsy(supply:GiveTo("blocked"), "blocked refused")
		expect.falsy(supply:GiveTo("bagged"), "duffel refused")
		expect.equal(refusals[1].reason, "carrying_supplies", "blocked reason")
		expect.equal(refusals[2].reason, "has_duffel", "duffel reason")
		expect.equal(#pickups, 0, "no pickup")
		expect.truthy(supply:GiveTo("p1"), "still available after refusals")
		model:Destroy()

		local bank2, visible, model2, _, pickups2 = makeBankAndSupply(now)
		bank2:TryStart("p1")
		expect.falsy(visible:GiveTo("p1"), "a visible (prompted) object is not given by code")
		expect.equal(#pickups2, 0, "no pickup")
		model2:Destroy()
	end)

	suite:test("Close removes the prompt until the next OnSessionStart", function(expect)
		local now, advance = makeClock()
		local bank, supply, model = makeBankAndSupply(now)
		bank:TryStart("p1")
		expect.equal(promptCount(model), 1, "armed")
		supply:Close()
		expect.equal(promptCount(model), 0, "prompt gone")
		expect.falsy(supply.highlight.Enabled, "highlight off")
		supply:OnSessionStart()
		expect.equal(promptCount(model), 1, "re-armed at the next session start")
		model:Destroy()
	end)

	return suite:run()
end
