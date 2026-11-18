local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("BankInstance")

	-- A controllable clock. Every test drives time explicitly.
	local function makeClock(start)
		local t = start or 1000
		return function() return t end, function(delta) t += delta end
	end

	-- A component that records what the instance asked of it.
	local function stubComponent()
		local c = { seals = 0, rearms = 0, starts = 0 }
		function c:Seal() self.seals += 1 end
		function c:Rearm() self.rearms += 1 end
		function c:OnSessionStart() self.starts += 1 end
		return c
	end

	local function makeInstance(now, onForfeit)
		return BankInstance.new({ config = Config, now = now, onForfeit = onForfeit })
	end

	suite:test("a fresh bank is Idle with no timers", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		expect.equal(inst:GetState(), "Idle", "initial state")
		expect.equal(inst:GetEndsAt(), nil, "no endsAt")
		expect.equal(inst:GetSecondsRemaining(), 0, "no time remaining")
	end)

	suite:test("starting sets Active and an absolute end timestamp", function(expect)
		local now = makeClock(1000)
		local inst = makeInstance(now)
		local ok, reason = inst:TryStart("playerA")
		expect.truthy(ok, "start succeeded")
		expect.equal(reason, nil, "no reason on success")
		expect.equal(inst:GetState(), "Active", "state")
		expect.equal(inst:GetEndsAt(), 1000 + Config.SessionDuration, "endsAt is absolute, not a duration")
		expect.equal(inst:GetSecondsRemaining(), Config.SessionDuration, "remaining")
	end)

	suite:test("starting increments the run id", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		local first = inst:GetRunId()
		inst:TryStart("playerA")
		expect.truthy(inst:GetRunId() ~= first, "run id changed")
	end)

	suite:test("a second start while Active is refused", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		local ok, reason = inst:TryStart("playerB")
		expect.falsy(ok, "refused")
		expect.equal(reason, "already_active", "reason")
	end)

	suite:test("expiry moves Active to Cooldown and seals every component", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local comp = stubComponent()
		inst:RegisterComponent(comp)
		inst:TryStart("playerA")
		expect.equal(comp.starts, 1, "session start notified")

		advance(Config.SessionDuration - 1)
		inst:Step()
		expect.equal(inst:GetState(), "Active", "still active one second early")
		expect.equal(comp.seals, 0, "not sealed early")

		advance(1)
		inst:Step()
		expect.equal(inst:GetState(), "Cooldown", "sealed at expiry")
		expect.equal(comp.seals, 1, "sealed once")
		expect.equal(comp.rearms, 0, "NOT rearmed at session end — that is stage 2")
		expect.equal(inst:GetCooldownEndsAt(), 1000 + Config.SessionDuration + Config.CooldownDuration, "cooldown end is absolute")
	end)

	suite:test("triggering during cooldown is swallowed", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		advance(Config.SessionDuration); inst:Step()
		local ok, reason = inst:TryStart("playerB")
		expect.falsy(ok, "refused")
		expect.equal(reason, "cooldown", "reason")
	end)

	suite:test("cooldown expiry rearms components and returns to Idle", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local comp = stubComponent()
		inst:RegisterComponent(comp)
		inst:TryStart("playerA")
		advance(Config.SessionDuration); inst:Step()
		advance(Config.CooldownDuration - 1); inst:Step()
		expect.equal(inst:GetState(), "Cooldown", "still cooling one second early")
		expect.equal(comp.rearms, 0, "not rearmed early")
		advance(1); inst:Step()
		expect.equal(inst:GetState(), "Idle", "back to Idle")
		expect.equal(comp.rearms, 1, "rearmed once")
	end)

	suite:test("a clock jump past both deadlines still runs both stages in order", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local order = {}
		local comp = { }
		function comp:Seal() table.insert(order, "seal") end
		function comp:Rearm() table.insert(order, "rearm") end
		inst:RegisterComponent(comp)
		inst:TryStart("playerA")
		advance(999999)
		inst:Step()
		expect.equal(inst:GetState(), "Idle", "landed on Idle")
		expect.equal(#order, 2, "both stages ran")
		expect.equal(order[1], "seal", "seal first")
		expect.equal(order[2], "rearm", "rearm second")
	end)

	suite:test("Seal and Rearm are each called once no matter how often Step runs", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local comp = stubComponent()
		inst:RegisterComponent(comp)
		inst:TryStart("playerA")
		advance(Config.SessionDuration)
		for _ = 1, 50 do inst:Step() end
		expect.equal(comp.seals, 1, "sealed exactly once")
		advance(Config.CooldownDuration)
		for _ = 1, 50 do inst:Step() end
		expect.equal(comp.rearms, 1, "rearmed exactly once")
	end)

	suite:test("a component that throws does not stop the transition", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local bad = { Seal = function() error("boom") end, Rearm = function() error("boom") end }
		local good = stubComponent()
		inst:RegisterComponent(bad)
		inst:RegisterComponent(good)
		inst:TryStart("playerA")
		advance(Config.SessionDuration); inst:Step()
		expect.equal(inst:GetState(), "Cooldown", "session clock survived a broken component")
		expect.equal(good.seals, 1, "healthy component still sealed")
	end)

	suite:test("terminals are per-session, so two players can complete the pair", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		expect.falsy(inst:AreTerminalsComplete(), "incomplete at start")
		expect.truthy(inst:SetTerminal(1), "terminal 1 accepted")
		expect.falsy(inst:AreTerminalsComplete(), "one is not enough")
		expect.truthy(inst:SetTerminal(2), "terminal 2 accepted")
		expect.truthy(inst:AreTerminalsComplete(), "both pressed")
	end)

	suite:test("pressing the same terminal twice is refused", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		expect.truthy(inst:SetTerminal(1), "first press")
		expect.falsy(inst:SetTerminal(1), "second press refused")
	end)

	suite:test("IsTerminalPressed reports individual terminals", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		expect.falsy(inst:IsTerminalPressed(1), "unpressed")
		inst:SetTerminal(1)
		expect.truthy(inst:IsTerminalPressed(1), "pressed")
		expect.falsy(inst:IsTerminalPressed(2), "the other one is independent")
	end)

	suite:test("terminals reset only after the cooldown, not at session end", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		inst:SetTerminal(1); inst:SetTerminal(2)
		advance(Config.SessionDuration); inst:Step()
		expect.truthy(inst:AreTerminalsComplete(), "still complete through the cooldown")
		advance(Config.CooldownDuration); inst:Step()
		expect.falsy(inst:AreTerminalsComplete(), "cleared on rearm")
	end)

	suite:test("VaultBreached starts false, is settable, and survives a seal", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		expect.falsy(inst:IsVaultBreached(), "false at session start")
		inst:SetVaultBreached()
		expect.truthy(inst:IsVaultBreached(), "true once set")
		inst:SetVaultBreached() -- idempotent
		expect.truthy(inst:IsVaultBreached(), "still true")

		advance(Config.SessionDuration); inst:Step()
		expect.truthy(inst:IsVaultBreached(),
			"survives the seal -- a re-entering player should not need to re-plant C4")
	end)

	suite:test("VaultBreached resets only at rearm, not at seal", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		inst:SetVaultBreached()
		advance(Config.SessionDuration); inst:Step()
		advance(Config.CooldownDuration); inst:Step()
		expect.falsy(inst:IsVaultBreached(), "cleared on rearm -- a new robbery requires re-planting")
	end)

	suite:test("VaultBreachedChanged fires exactly once, even across repeated SetVaultBreached calls", function(expect)
		-- Regression coverage for the debug addendum, 2026-08-28: HeistServer
		-- listens to this to refresh the A teleporter's prompt text the instant
		-- the vault actually breaches. A double-fire would just be wasted work
		-- here, but the important thing is that it fires AT ALL -- the original
		-- bug was that nothing did.
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		local fired = 0
		inst.VaultBreachedChanged:Connect(function() fired += 1 end)
		expect.equal(fired, 0, "not fired before breach")
		inst:SetVaultBreached()
		expect.equal(fired, 1, "fired once on breach")
		inst:SetVaultBreached()
		inst:SetVaultBreached()
		expect.equal(fired, 1, "does not re-fire on repeated calls")
	end)

	suite:test("guards populate from actual spawns, not blindly from config, and clearing fires once", function(expect)
		-- Regression test: _guardsRemaining used to be seeded from Config.GuardCount
		-- directly, so a spawn failure left it stuck above zero forever and the
		-- guard barrier could never open. Now it is seeded ONLY by components
		-- calling NotifyGuardSpawned() from their own OnSessionStart, exactly the
		-- way GuardPost does after a real spawn succeeds.
		local now = makeClock()
		local inst = makeInstance(now)
		expect.equal(inst:GuardsRemaining(), 0, "nothing has spawned before any session")
		local cleared = 0
		inst.GuardsCleared:Connect(function() cleared += 1 end)
		local spawner = {}
		function spawner:OnSessionStart()
			-- Simulate two guard posts whose spawns actually succeeded (a third
			-- might have failed and correctly contributes nothing).
			inst:NotifyGuardSpawned()
			inst:NotifyGuardSpawned()
		end
		inst:RegisterComponent(spawner)
		inst:TryStart("playerA")
		expect.equal(inst:GuardsRemaining(), 2, "seeded from guards that actually spawned")
		inst:NotifyGuardDied()
		inst:NotifyGuardDied()
		expect.equal(inst:GuardsRemaining(), 0, "all dead")
		expect.equal(cleared, 1, "fired once")
		inst:NotifyGuardDied()
		expect.equal(inst:GuardsRemaining(), 0, "cannot go negative")
		expect.equal(cleared, 1, "does not re-fire")
	end)

	suite:test("participants join explicitly and are ejected at expiry", function(expect)
		local now, advance = makeClock(1000)
		local ejected = {}
		local inst = makeInstance(now, function(player, cause)
			table.insert(ejected, { player = player, cause = cause })
		end)
		inst:TryStart("playerA")
		expect.falsy(inst:IsParticipant("playerA"), "starting does not join the roster")
		inst:AddParticipant("playerA")
		inst:AddParticipant("playerB")
		expect.truthy(inst:IsParticipant("playerA"), "joined")
		expect.equal(#inst:GetParticipants(), 2, "roster size")

		advance(Config.SessionDuration); inst:Step()
		expect.equal(#ejected, 2, "everyone ejected at expiry")
		expect.equal(ejected[1].cause, "timer_expired", "cause recorded")
		expect.equal(#inst:GetParticipants(), 0, "roster cleared")
	end)

	suite:test("adding a participant twice does not duplicate them", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		inst:AddParticipant("playerA")
		inst:AddParticipant("playerA")
		expect.equal(#inst:GetParticipants(), 1, "roster size")
	end)

	suite:test("the session survives everyone leaving — no early-out", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		inst:AddParticipant("playerA")
		inst:RemoveParticipant("playerA")
		advance(10); inst:Step()
		expect.equal(inst:GetState(), "Active", "still running with nobody inside")
	end)

	suite:test("StateChanged reports both the new and previous state", function(expect)
		local now, advance = makeClock(1000)
		local inst = makeInstance(now)
		local seen = {}
		inst.StateChanged:Connect(function(newState, oldState)
			table.insert(seen, oldState .. "->" .. newState)
		end)
		inst:TryStart("playerA")
		advance(Config.SessionDuration); inst:Step()
		advance(Config.CooldownDuration); inst:Step()
		expect.equal(seen[1], "Idle->Active", "first")
		expect.equal(seen[2], "Active->Cooldown", "second")
		expect.equal(seen[3], "Cooldown->Idle", "third")
	end)

	suite:test("FastLifecycle shortens both phases", function(expect)
		local now, advance = makeClock(1000)
		Config.Debug.FastLifecycle = true
		local inst = makeInstance(now)
		inst:TryStart("playerA")
		expect.equal(inst:GetEndsAt(), 1010, "10s session")
		advance(10); inst:Step()
		expect.equal(inst:GetCooldownEndsAt(), 1030, "20s cooldown")
		Config.Debug.FastLifecycle = false
	end)

	-- Universal gamepass modifiers (spec addendum, 2026-09-03): BankInstance
	-- never requires GamepassManager -- it only ever sees the RESULT via
	-- these injected functions, so this whole suite proves the multiplier
	-- plumbing without ever touching a real MarketplaceService call.
	suite:test("GetDuffelCap and GetAccrualRate default to 1x when no multiplier deps are given", function(expect)
		local now = makeClock()
		local inst = makeInstance(now)
		expect.equal(inst:GetDuffelCap("p1"), Config.DuffelCap, "cap defaults to the base, unmultiplied")
		expect.equal(inst:GetAccrualRate("p1"), Config.AccrualPerSecond, "rate defaults to the base, unmultiplied")
	end)

	suite:test("GetDuffelCap and GetAccrualRate apply the injected per-player multipliers", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({
			config = Config, now = now,
			duffelCapMultiplier = function(player) return player == "whale" and 4 or 1 end,
			accrualRateMultiplier = function(player) return player == "whale" and 1.5 or 1 end,
		})
		expect.equal(inst:GetDuffelCap("whale"), Config.DuffelCap * 4, "whale gets the x4 cap")
		expect.equal(inst:GetDuffelCap("p1"), Config.DuffelCap, "everyone else gets the base cap")
		expect.equal(inst:GetAccrualRate("whale"), Config.AccrualPerSecond * 1.5, "whale gets the boosted rate")
		expect.equal(inst:GetAccrualRate("p1"), Config.AccrualPerSecond, "everyone else gets the base rate")
	end)

	suite:test("Accrue respects the multiplied cap, not the base cap", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({
			config = Config, now = now,
			duffelCapMultiplier = function() return 2 end,
		})
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		inst:Accrue("p1", 100000)
		expect.equal(inst:GetDuffel("p1"), Config.DuffelCap * 2, "clamped at the DOUBLED cap, not the base one")
	end)

	suite:test("Accrue applies the accrual rate multiplier to the per-tick increment", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({
			config = Config, now = now,
			accrualRateMultiplier = function() return 3 end,
		})
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		local added = inst:Accrue("p1", 1)
		expect.near(added, Config.AccrualPerSecond * 3, 0.001, "one second at 3x the base rate")
	end)

	-- TryAddDuffel: discrete lump-sum grant (spec addendum, 2026-09-06,
	-- SlowFoods' cash registers), distinct from Accrue's per-tick clamp.
	suite:test("TryAddDuffel rejects when not Active", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		local ok, reason = inst:TryAddDuffel("p1", 2000)
		expect.falsy(ok, "rejected")
		expect.equal(reason, "inactive", "reason")
		expect.equal(inst:GetDuffel("p1"), 0, "nothing added")
	end)

	suite:test("TryAddDuffel rejects a non-participant", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		local ok, reason = inst:TryAddDuffel("p2", 2000)
		expect.falsy(ok, "rejected")
		expect.equal(reason, "not_participant", "reason")
	end)

	suite:test("TryAddDuffel credits the full flat amount for a valid participant", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		local ok = inst:TryAddDuffel("p1", 2000)
		expect.truthy(ok, "accepted")
		expect.equal(inst:GetDuffel("p1"), 2000, "credited in full")
	end)

	suite:test("TryAddDuffel accumulates across multiple successful grants", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		inst:TryAddDuffel("p1", 2000)
		inst:TryAddDuffel("p1", 2000)
		expect.equal(inst:GetDuffel("p1"), 4000, "both grants credited")
	end)

	suite:test("TryAddDuffel rejects the WHOLE amount outright if it would exceed the cap -- no partial credit", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		-- Push to just under the cap, then attempt a grant that would overshoot.
		local room = Config.DuffelCap - 1
		inst:Accrue("p1", room / Config.AccrualPerSecond)
		local before = inst:GetDuffel("p1")
		local ok, reason = inst:TryAddDuffel("p1", 2000)
		expect.falsy(ok, "rejected")
		expect.equal(reason, "cap_exceeded", "reason")
		expect.equal(inst:GetDuffel("p1"), before, "unchanged -- no partial credit, unlike Accrue's clamp")
	end)

	suite:test("TryAddDuffel respects the multiplied cap, not the base cap", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({
			config = Config, now = now,
			duffelCapMultiplier = function() return 2 end,
		})
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		-- Base cap alone would reject this; the doubled cap must accept it.
		local ok = inst:TryAddDuffel("p1", Config.DuffelCap + 1000)
		expect.truthy(ok, "accepted under the doubled cap")
		expect.equal(inst:GetDuffel("p1"), Config.DuffelCap + 1000, "credited in full")
	end)

	suite:test("TryAddDuffel fires DuffelChanged on success, never on rejection", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")

		local fireCount = 0
		inst.DuffelChanged:Connect(function() fireCount += 1 end)

		inst:TryAddDuffel("p1", 2000)
		expect.equal(fireCount, 1, "fired once on success")

		inst:TryAddDuffel("p1", Config.DuffelCap) -- would exceed, must reject
		expect.equal(fireCount, 1, "still one -- rejection did not fire")
	end)

	-- AddBonus (heist layers 2026-11-17): a signature-layer bonus goes into the bag past the cap.
	suite:test("AddBonus lands on top of a full bag and Claim pays all of it", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		local cap = inst:GetDuffelCap("p1")
		expect.truthy(inst:TryAddDuffel("p1", cap), "bag filled to the cap")

		local fired = {}
		inst.DuffelChanged:Connect(function(p, amount, reason) table.insert(fired, { p, amount, reason }) end)
		local ok, reason = inst:AddBonus("p1", 3000)
		expect.truthy(ok, "bonus accepted past the cap")
		expect.equal(reason, nil, "no reason")
		expect.equal(inst:GetDuffel("p1"), cap + 3000, "bag holds cap + bonus")
		expect.equal(#fired, 1, "DuffelChanged fired once")
		expect.equal(fired[1][2], cap + 3000, "with the new amount")
		expect.equal(fired[1][3], "add", "reason add")
		expect.equal(inst:Claim("p1"), cap + 3000, "Claim pays the whole bag")
	end)

	suite:test("AddBonus refuses a non-participant, an idle bank and a non-positive amount", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		local ok, reason = inst:AddBonus("p1", 3000)
		expect.falsy(ok, "idle refused")
		expect.equal(reason, "inactive", "idle reason")

		inst:TryStart("p1")
		ok, reason = inst:AddBonus("p1", 3000)
		expect.falsy(ok, "non-participant refused")
		expect.equal(reason, "not_participant", "non-participant reason")

		inst:AddParticipant("p1")
		ok, reason = inst:AddBonus("p1", 0)
		expect.equal(reason, "invalid_amount", "zero refused")
		ok, reason = inst:AddBonus("p1", -5)
		expect.falsy(ok, "negative refused")
		expect.equal(reason, "invalid_amount", "negative reason")
		expect.equal(inst:GetDuffel("p1"), 0, "nothing added")
	end)

	-- Leftovers (2026-11-18): bag grants refuse NaN, infinite and absurd amounts (HeistShared.Config.MaxBagGrant).
	suite:test("AddBonus and TryAddDuffel refuse NaN, infinite and absurd amounts", function(expect)
		local now = makeClock()
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		expect.equal(Config.MaxBagGrant, 100000, "the bound")
		for _, amount in ipairs({ 0 / 0, math.huge, -math.huge, (Config.MaxBagGrant or 100000) + 1 }) do
			local okBonus, bonusReason = inst:AddBonus("p1", amount)
			local okAdd, addReason = inst:TryAddDuffel("p1", amount)
			expect.falsy(okBonus or okAdd, tostring(amount) .. " refused")
			expect.equal(bonusReason, "invalid_amount", tostring(amount) .. ": AddBonus reason")
			expect.equal(addReason, "invalid_amount", tostring(amount) .. ": TryAddDuffel reason")
		end
		expect.equal(inst:GetDuffel("p1"), 0, "nothing added")
		expect.truthy(inst:AddBonus("p1", Config.MaxBagGrant or 100000), "the bound itself is accepted")
	end)

	return suite:run()
end
