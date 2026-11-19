-- HeistPolice (heist police and Bank guards, 2026-11-20): the wave schedule of the Bank, its vault and NewsStation,
-- the caps, the waves into the building, the target filter, the steering, Seal and the squad hold.
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local HeistPolice = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.HeistPolice)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local BankConfig = require(game.ReplicatedStorage.HeistShared.Config)
	local NewsConfig = require(game.ReplicatedStorage.NewsStationShared.Config)
	local SCATTER = require(game.ReplicatedStorage.Wanted.Constants).HEIST_POLICE_SCATTER
	local suite = TestRunner.new("HeistPolice")

	-- Officers alive `elapsed` seconds into `plan` when none die and the police room never binds.
	local function aliveAt(plan, elapsed)
		local alive = 0
		for index = 1, HeistPolice.wavesDue(plan, elapsed) do
			alive += HeistPolice.waveSize(plan, index, alive, math.huge)
		end
		return alive
	end

	local function expectRows(expect, plan, rows)
		for _, row in ipairs(rows) do
			expect.equal(aliveAt(plan, row[1]), row[2], string.format("alive at %d s", row[1]))
		end
	end

	suite:test("Bank: 0 police at 1:59, 3 at 2:00, 5 at 3:30, 7 at 5:00, 8 at 6:30 and never more", function(expect)
		local plan = BankConfig.HeistPolice
		expect.equal(plan.template, "Police", "plain police from the start")
		expectRows(expect, plan, { { 0, 0 }, { 119, 0 }, { 120, 3 }, { 209, 3 }, { 210, 5 }, { 300, 7 }, { 390, 8 }, { 600, 8 } })
	end)

	suite:test("NewsStation: 0 at 1:59, 2 at 2:00, 3 at 3:30, 4 at 5:00 and never more", function(expect)
		local plan = NewsConfig.HeistPolice
		expect.equal(plan.template, "Police", "plain police")
		expectRows(expect, plan, { { 119, 0 }, { 120, 2 }, { 209, 2 }, { 210, 3 }, { 300, 4 }, { 600, 4 } })
	end)

	suite:test("Bank vault: 4 Armed Police at the opening, 6 at 60 s, 8 at 120 s, still 8 at 180 s", function(expect)
		local plan = BankConfig.HeistPoliceVault
		expect.equal(plan.template, "Armed Police", "armed")
		expectRows(expect, plan, { { 0, 4 }, { 59, 4 }, { 60, 6 }, { 120, 8 }, { 180, 8 } })
	end)

	suite:test("a wave sends its size, never past the plan's cap or the free POLICE_CAP room", function(expect)
		local plan = BankConfig.HeistPolice
		expect.equal(HeistPolice.waveSize(plan, 1, 0, 24), 3, "the first wave")
		expect.equal(HeistPolice.waveSize(plan, 2, 3, 24), 2, "a later wave")
		expect.equal(HeistPolice.waveSize(plan, 4, 7, 24), 1, "one short of the cap")
		expect.equal(HeistPolice.waveSize(plan, 5, 8, 24), 0, "at the cap")
		expect.equal(HeistPolice.waveSize(plan, 1, 0, 2), 2, "only the free room")
		expect.equal(HeistPolice.waveSize(plan, 1, 0, -3), 0, "no room")
	end)

	-- ===== the component =====

	local function standIn(stars, position)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = position or Vector3.new(0, 5000, 0)
		root.Parent = model
		Instance.new("Humanoid").Parent = model
		model.Parent = workspace
		local player = { Character = model, stars = stars or 0 }
		function player:GetAttribute(name)
			if name == "WantedStars" then return self.stars end
			return nil
		end
		return player
	end

	-- A Bank session with stub officers: spawn records what it was asked for, nothing enters the world.
	local function fixture(opts)
		local f = { clock = 1000, inside = {}, spawned = {}, room = opts.room or 24, reaches = true }
		f.bank = BankInstance.new({ config = BankConfig, now = function() return f.clock end })
		f.marker = Instance.new("Part")
		f.marker.Position = Vector3.new(100, 5000, 0)
		f.police = HeistPolice.new({
			bank = f.bank,
			plan = BankConfig.HeistPolice,
			vaultPlan = if opts.vault then BankConfig.HeistPoliceVault else nil,
			markers = { f.marker },
			isInside = function(player) return f.inside[player] == true end,
			now = function() return f.clock end,
			players = function() return opts.players end,
			room = function() return f.room end,
			reaches = function() return f.reaches end,
			wait = function() end,
			addSquadHold = function(fn) f.hold = fn end,
			addActiveRobbery = function(fn) f.active = fn end,
			spawn = function(template, position, filter)
				local ai = { template = template, position = position, filter = filter, state = "Patrol", destroyed = false }
				function ai:destroy() self.destroyed = true end
				function ai:investigate(goal) self.went = goal end
				table.insert(f.spawned, ai)
				return nil, ai
			end,
		})
		f.bank:RegisterComponent(f.police)
		function f.at(t)
			f.clock = t
			f.police:Update()
		end
		function f.count(template)
			local n = 0
			for _, ai in ipairs(f.spawned) do
				if ai.template == template and not ai.destroyed then n += 1 end
			end
			return n
		end
		return f
	end

	suite:test("waves go in while a robber is inside, at the markers; a wave due with nobody inside is skipped; Seal removes them all", function(expect)
		local robber = standIn(3)
		local f = fixture({ players = { robber } })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1119)
		expect.equal(#f.spawned, 0, "nobody at 1:59")
		f.at(1120)
		expect.equal(f.count("Police"), 3, "3 police at 2:00")
		for _, ai in ipairs(f.spawned) do
			local offset = ai.position - f.marker.Position
			expect.truthy(math.abs(offset.X) <= SCATTER and math.abs(offset.Z) <= SCATTER and offset.Y == 0, "stands up at the marker")
		end
		f.inside[robber] = false
		f.at(1210)
		expect.equal(f.count("Police"), 3, "the 3:30 wave skipped: nobody inside")
		f.inside[robber] = true
		f.at(1300)
		expect.equal(f.count("Police"), 5, "+2 at 5:00")
		f.bank:_seal("timer_expired")
		expect.equal(f.count("Police"), 0, "Seal removes every officer")
		f.bank:_rearm()
		f.bank:TryStart(robber)
		f.at(f.clock + 119)
		expect.equal(f.count("Police"), 0, "a new session starts the schedule over")
		f.at(f.clock + 1)
		expect.equal(f.count("Police"), 3, "its first wave")
		robber.Character:Destroy()
	end)

	suite:test("dead officers are not replaced before the next wave, and a wave tops up only to the cap", function(expect)
		local robber = standIn(3)
		local f = fixture({ players = { robber } })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1120)
		f.spawned[1].state = "Dead"
		f.at(1121)
		expect.equal(#f.spawned, 3, "no replacement between waves")
		for t = 1210, 1480, 90 do
			f.at(t)
		end
		local alive = 0
		for _, ai in ipairs(f.spawned) do
			if ai.state ~= "Dead" and not ai.destroyed then alive += 1 end
		end
		expect.equal(alive, 8, "8 alive at most")
		robber.Character:Destroy()
	end)

	suite:test("the vault plan starts at the vault door's opening, once a session, beside the timed plan", function(expect)
		local robber = standIn(3)
		local f = fixture({ players = { robber }, vault = true })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1050)
		expect.equal(#f.spawned, 0, "nothing before the opening")
		f.police:OnVaultOpened()
		f.at(1050)
		expect.equal(f.count("Armed Police"), 4, "4 Armed Police at the opening")
		f.police:OnVaultOpened()
		f.at(1109)
		expect.equal(f.count("Armed Police"), 4, "a second opening does not restart the plan")
		f.at(1110)
		expect.equal(f.count("Armed Police"), 6, "+2 at 60 s")
		f.at(1120)
		expect.equal(f.count("Police"), 3, "the timed plan runs beside it")
		f.at(1170)
		f.at(1230)
		expect.equal(f.count("Armed Police"), 8, "8 armed at most")
		robber.Character:Destroy()
	end)

	suite:test("a wave takes only the free POLICE_CAP room, re-checked for every officer", function(expect)
		local robber = standIn(3)
		local f = fixture({ players = { robber }, room = 1 })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1120)
		expect.equal(#f.spawned, 1, "one free place: one officer")
		robber.Character:Destroy()
	end)

	suite:test("officers target this robbery's participants and wanted players inside, never bystanders", function(expect)
		local robber = standIn(3)
		local f = fixture({ players = { robber } })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1120)
		local filter = f.spawned[1].filter
		local participant, wantedInside, wantedOutside, bystander = standIn(0), standIn(1), standIn(4), standIn(0)
		f.bank:AddParticipant(participant)
		f.inside[wantedInside], f.inside[bystander] = true, true
		expect.truthy(filter(participant), "a participant, wherever")
		expect.truthy(filter(wantedInside), "a wanted player in the building")
		expect.falsy(filter(wantedOutside), "a wanted player outside: the squads' job")
		expect.falsy(filter(bystander), "a bystander in the building")
		for _, p in ipairs({ robber, participant, wantedInside, wantedOutside, bystander }) do p.Character:Destroy() end
	end)

	suite:test("officers without a target are sent to the robber when a path from the marker leads there", function(expect)
		local robber = standIn(3, Vector3.new(130, 5000, 0))
		local f = fixture({ players = { robber } })
		f.bank:TryStart(robber)
		f.inside[robber] = true
		f.at(1120)
		expect.equal(f.spawned[1].went, robber.Character.HumanoidRootPart.Position, "sent to the robber")
		f.spawned[2].state = "Attack"
		f.reaches = false
		robber.Character.HumanoidRootPart.Position = Vector3.new(160, 5000, 0)
		f.at(1121)
		expect.equal(f.spawned[1].went, Vector3.new(130, 5000, 0), "no path: not sent")
		f.reaches = true
		f.spawned[2].went = nil
		f.at(1122)
		expect.equal(f.spawned[1].went, Vector3.new(160, 5000, 0), "a path again: sent")
		expect.equal(f.spawned[2].went, nil, "one already fighting is left to its own chase")
		robber.Character:Destroy()
	end)

	suite:test("squad hold: the squad of a participant or of anyone in the building waits until the first wave", function(expect)
		local f = fixture({ players = {} })
		local participant, insider, outsider = standIn(3), standIn(3), standIn(3)
		expect.truthy(f.hold ~= nil, "registered with the dispatcher")
		expect.falsy(f.hold(participant), "no session: no hold")
		f.bank:TryStart(participant)
		f.bank:AddParticipant(participant)
		f.inside[insider] = true
		f.clock = 1119
		expect.truthy(f.hold(participant), "a participant at 1:59")
		expect.truthy(f.hold(insider), "the trigger player still in the lobby")
		expect.falsy(f.hold(outsider), "nobody else")
		expect.truthy(f.active ~= nil and f.active(insider), "a held robber is an active robbery: the alarm's stars hold")
		f.clock = 1120
		expect.falsy(f.hold(participant), "released with the first wave")
		expect.falsy(f.active(insider), "and no longer an active robbery through the hold")
		f.clock = 1010
		f.bank:_seal("timer_expired")
		expect.falsy(f.hold(participant), "released at the seal")
		for _, p in ipairs({ participant, insider, outsider }) do p.Character:Destroy() end
	end)

	return suite:run()
end
