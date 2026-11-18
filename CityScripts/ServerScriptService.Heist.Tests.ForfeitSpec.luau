local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Forfeit = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Forfeit)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("Forfeit")

	local function makeClock(start)
		local t = start or 1000
		return function() return t end
	end

	local function makeForfeit()
		local record = { teleports = {}, notices = {} }
		local f = Forfeit.new({
			teleport = function(player, cf) table.insert(record.teleports, player) end,
			notify = function(player, cause) table.insert(record.notices, { player = player, cause = cause }) end,
			exitCFrame = function() return CFrame.new(0, 0, 0) end,
			log = function() end,
		})
		return f, record
	end

	local function activeInstance(now)
		local inst = BankInstance.new({ config = Config, now = now })
		inst:TryStart("starter")
		return inst
	end

	-- Forced eject (session ended, e.g. timer expiry, while the player is
	-- still alive AND still on the premises): forfeits AND physically moves
	-- them out.
	suite:test("Eject (isInside=true) zeroes the bag, teleports, and notifies", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		inst:Accrue("p1", 10)

		local applied = forfeit:Eject(inst, "p1", "timer_expired", true)

		expect.truthy(applied, "applied")
		expect.equal(inst:GetDuffel("p1"), 0, "bag destroyed")
		expect.falsy(inst:IsParticipant("p1"), "off the roster")
		expect.equal(#record.teleports, 1, "teleported once")
		expect.equal(record.notices[1].cause, "timer_expired", "cause passed through")
	end)

	-- Corrected, 2026-09-11: a player who already left the premises before
	-- timer expiry must still lose the bag (the run genuinely ended without a
	-- successful claim) but must NOT be yanked back to ExitSpawn from
	-- wherever they actually are.
	suite:test("Eject (isInside=false) zeroes the bag and notifies, but does not teleport", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		inst:Accrue("p1", 10)

		local applied = forfeit:Eject(inst, "p1", "timer_expired", false)

		expect.truthy(applied, "still applied -- forfeiture is unconditional")
		expect.equal(inst:GetDuffel("p1"), 0, "bag still destroyed")
		expect.falsy(inst:IsParticipant("p1"), "off the roster")
		expect.equal(#record.teleports, 0, "never teleported -- not on the premises")
		expect.equal(record.notices[1].cause, "timer_expired", "still notified")
	end)

	-- Death (Humanoid.Died, any cause -- laser, guard, death pit): forfeits
	-- only. The player's own death/respawn is Roblox's problem, never this
	-- system's -- so Die must NEVER call teleport, under any cause.
	suite:test("Die zeroes the bag and notifies, but never teleports", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		inst:Accrue("p1", 10)

		local applied = forfeit:Die(inst, "p1", "died")

		expect.truthy(applied, "applied")
		expect.equal(inst:GetDuffel("p1"), 0, "bag destroyed")
		expect.falsy(inst:IsParticipant("p1"), "off the roster")
		expect.equal(#record.teleports, 0, "never teleported")
		expect.equal(record.notices[1].cause, "died", "cause passed through")
	end)

	suite:test("Die never teleports regardless of cause label (laser, guard, death_pit)", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		for _, cause in ipairs({ "laser", "guard", "death_pit" }) do
			local inst = activeInstance(now)
			inst:AddParticipant("p1")
			forfeit:Die(inst, "p1", cause)
		end
		expect.equal(#record.teleports, 0, "zero teleports across every death cause")
	end)

	suite:test("the idempotency latch also blocks a second Eject regardless of its own isInside value", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")

		expect.truthy(forfeit:Eject(inst, "p1", "timer_expired", false), "first: applies, no teleport (outside)")
		expect.falsy(forfeit:Eject(inst, "p1", "timer_expired", true), "second: no-op even though isInside=true this time")
		expect.equal(#record.teleports, 0, "the no-op second call must not teleport just because it passed isInside=true")
	end)

	-- The idempotency latch is shared: it must not matter which of the two
	-- entry points reaches a given player first in a run -- e.g. DeathVolume's
	-- Die racing the generic Humanoid.Died handler's Die for the SAME death,
	-- or (in principle) a Die and an Eject landing in the same tick. Only the
	-- first call of either kind may act; the loser must never additionally
	-- teleport just because it happened to be the Eject-flavoured one.
	suite:test("Die then Eject in the same run: Eject is a no-op and never teleports", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")

		expect.truthy(forfeit:Die(inst, "p1", "death_pit"), "first: Die lands")
		expect.falsy(forfeit:Eject(inst, "p1", "timer_expired", true), "second: Eject is a no-op")
		expect.equal(#record.teleports, 0, "the losing Eject must not teleport")
	end)

	suite:test("Eject then Die in the same run: Die is a no-op, one teleport total", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")

		expect.truthy(forfeit:Eject(inst, "p1", "timer_expired", true), "first: Eject lands")
		expect.falsy(forfeit:Die(inst, "p1", "died"), "second: Die is a no-op")
		expect.equal(#record.teleports, 1, "exactly one teleport, from the winning Eject")
	end)

	suite:test("a later run re-applies Eject independently", function(expect)
		local t = 1000
		local now = function() return t end
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		forfeit:Eject(inst, "p1", "timer_expired", true)
		t += 600; inst:Step()
		t += 1800; inst:Step()
		expect.equal(inst:GetState(), "Idle", "cycled back")
		inst:TryStart("p1")
		inst:AddParticipant("p1")
		expect.truthy(forfeit:Eject(inst, "p1", "timer_expired", true), "new run, new forfeiture")
		expect.equal(#record.teleports, 2, "two teleports total")
	end)

	suite:test("Forget clears the latch so the same run can forfeit this player again", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		expect.truthy(forfeit:Die(inst, "p1", "died"), "first lands")
		forfeit:Forget("p1")
		inst:AddParticipant("p1")
		expect.truthy(forfeit:Die(inst, "p1", "laser"), "second lands after Forget")
		expect.equal(#record.teleports, 0, "still never teleported")
	end)

	suite:test("Forget clears the latch so a later Eject can apply again", function(expect)
		local now = makeClock()
		local forfeit, record = makeForfeit()
		local inst = activeInstance(now)
		inst:AddParticipant("p1")
		expect.truthy(forfeit:Eject(inst, "p1", "timer_expired", false), "first lands, outside so no teleport")
		forfeit:Forget("p1")
		inst:AddParticipant("p1")
		expect.truthy(forfeit:Eject(inst, "p1", "timer_expired", true), "second lands after Forget, inside this time")
		expect.equal(#record.teleports, 1, "exactly one teleport, from the second (inside) call")
	end)

	-- Final review I2 (2026-11-18, controller ruling): the timer's eject never moves loot. A heavy carry (an
	-- object with a speedCap: the gold bar, the ripped ATM) held by a player the seal ejects is lost.
	local function makeCarry()
		local cs = { carried = {} }
		function cs:GetCarried(p) return self.carried[p] end
		function cs:Consume(p)
			local obj = self.carried[p]
			if not obj then return false, nil end
			self.carried[p] = nil
			return true, obj
		end
		return cs
	end

	suite:test("Eject from inside consumes a heavy carry; from outside, or a light carry, it is kept", function(expect)
		local carry = makeCarry()
		local forfeit = Forfeit.new({ teleport = function() end, exitCFrame = function() return CFrame.new() end,
			log = function() end, carryState = carry })
		local inst = activeInstance(makeClock())
		local heavy, light = { speedCap = 12 }, {}
		for _, p in ipairs({ "inHeavy", "outHeavy", "inLight" }) do inst:AddParticipant(p) end
		carry.carried.inHeavy, carry.carried.outHeavy, carry.carried.inLight = heavy, heavy, light
		forfeit:Eject(inst, "inHeavy", "timer_expired", true)
		forfeit:Eject(inst, "outHeavy", "timer_expired", false)
		forfeit:Eject(inst, "inLight", "timer_expired", true)
		expect.equal(carry.carried.inHeavy, nil, "a heavy carry inside is lost")
		expect.equal(carry.carried.outHeavy, heavy, "outside: kept")
		expect.equal(carry.carried.inLight, light, "a light carry: kept")
	end)

	suite:test("a gold holder inside the vault at seal ends with no carry and no payout", function(expect)
		local CarryGetaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.CarryGetaway)
		local anchor = Instance.new("Part")
		anchor.Anchored = true
		anchor.Position = Vector3.new(0, 7000, 0)
		anchor.Parent = workspace
		local character = Instance.new("Model")
		local root = Instance.new("Part")
		root.Anchored = true
		root.Position = Vector3.new(300, 7000, 0) -- past EscapeDistance once out of the building
		root.Parent = character
		character.PrimaryPart = root
		character.Parent = workspace
		local robber = { UserId = 1, Character = character }
		local inside = { [robber] = true }
		local carry = makeCarry()
		local t = 1000
		local forfeit = Forfeit.new({
			teleport = function(p) inside[p] = false end, -- the eject puts them outside
			exitCFrame = function() return CFrame.new() end,
			log = function() end,
			carryState = carry,
		})
		local inst
		inst = BankInstance.new({ config = Config, now = function() return t end,
			onForfeit = function(p, cause) forfeit:Eject(inst, p, cause, inside[p] == true) end })
		inst:TryStart(robber)
		inst:AddParticipant(robber)
		local bar = { speedCap = 12 }
		carry.carried[robber] = bar
		local credited = {}
		local getaway = CarryGetaway.new({
			escapeDistance = 200,
			anchor = anchor,
			isInsideBuilding = function(p) return inside[p] == true end,
			matches = function(obj) return obj == bar end,
			value = 8000,
			carryState = carry,
			currency = { Add = function(_, _, amount) table.insert(credited, amount) end },
			net = { Toast = function() end, NotifyRobberySuccess = function() end },
			getPlayers = function() return { robber } end,
		})
		t += Config.SessionDuration + 1
		inst:Step() -- the timer seals; the robber, still in the vault, is ejected
		getaway:Step()
		local state, carried = inst:GetState(), carry.carried[robber]
		anchor:Destroy()
		character:Destroy()
		expect.equal(state, "Cooldown", "sealed")
		expect.equal(carried, nil, "the bar is gone")
		expect.equal(#credited, 0, "no payout")
	end)

	return suite:run()
end
