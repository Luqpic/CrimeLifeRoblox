local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Open items pass 2026-11-18: NewsStation's broadcast wiring (Heist.Services.BroadcastHooks) on a real
-- BroadcastDesk and BankInstance. Go Live raises every participant to the 3-star heat floor and alerts every
-- guard; completion pays each participant at the desk once, over the bag cap. Wanted, guards and net are
-- recording stubs; players are tables with a Name.
return function()
	local BroadcastHooks = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.BroadcastHooks)
	local BroadcastDesk = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.BroadcastDesk)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.NewsStationShared.Config)
	local suite = TestRunner.new("BroadcastHooks")

	local function setup()
		local clock = { t = 0 }
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

		local rig = { heat = {}, added = {}, alerts = 0, hijacked = {}, toasts = {}, distances = {} }
		local bank = BankInstance.new({ config = Config, now = function() return clock.t end })
		local guards = {}
		for _ = 1, 3 do
			table.insert(guards, { Alert = function() rig.alerts += 1 end })
		end
		local hooks = BroadcastHooks.new({
			bank = bank,
			config = Config,
			net = {
				NotifyBroadcastHijacked = function(_, name) table.insert(rig.hijacked, name) end,
				Toast = function(_, player, message) table.insert(rig.toasts, { player, message }) end,
			},
			wanted = {
				getHeat = function(player) return rig.heat[player] or 0 end,
				addHeat = function(player, amount, reason)
					rig.heat[player] = (rig.heat[player] or 0) + amount
					table.insert(rig.added, { player, amount, reason })
				end,
			},
			guardPosts = function() return guards end,
		})
		local desk = BroadcastDesk.new(model, {
			bank = bank,
			config = Config,
			now = function() return clock.t end,
			measure = function(player) return rig.distances[player] end,
			onLive = hooks.onLive,
			onComplete = hooks.onComplete,
		})
		bank:RegisterComponent(desk)
		rig.bank, rig.desk, rig.clock = bank, desk, clock
		rig.cleanup = function()
			desk:Destroy()
			model:Destroy()
		end
		return rig
	end

	local p1, p2, p3 = { Name = "Robber1" }, { Name = "Robber2" }, { Name = "Robber3" }

	suite:test("Go Live raises every participant to the heat floor, leaves higher heat alone, alerts every guard", function(expect)
		local rig = setup()
		rig.bank:TryStart(p1)
		rig.bank:AddParticipant(p1)
		rig.bank:AddParticipant(p2)
		rig.bank:AddParticipant(p3)
		rig.heat[p1], rig.heat[p2], rig.heat[p3] = 1, 0, 4
		rig.distances[p1] = 5
		rig.desk:Arm()
		local ok = rig.desk:TryGoLive(p1)
		expect.truthy(ok, "live")
		expect.equal(rig.hijacked[1], "Robber1", "the city card names who went live")
		expect.equal(rig.heat[p1], Config.BroadcastHeatFloor, "1 star raised to the floor")
		expect.equal(rig.heat[p2], Config.BroadcastHeatFloor, "0 stars raised to the floor")
		expect.equal(rig.heat[p3], 4, "4 stars left alone")
		expect.equal(#rig.added, 2, "two raises")
		expect.equal(rig.added[1][3], "broadcast", "reason")
		expect.equal(rig.alerts, 3, "every guard alerted once")
		rig.cleanup()
	end)

	suite:test("completion pays each participant at the desk once, over the cap; one away and a bystander get nothing", function(expect)
		local rig = setup()
		rig.bank:TryStart(p1)
		rig.bank:AddParticipant(p1)
		rig.bank:AddParticipant(p2)
		rig.bank:AddParticipant(p3)
		rig.bank:TryAddDuffel(p1, Config.DuffelCap)
		rig.distances[p1], rig.distances[p2], rig.distances[p3] = 5, 11, 30
		local bystander = { Name = "Bystander" }
		rig.distances[bystander] = 1
		rig.desk:Arm()
		rig.desk:TryGoLive(p1)
		rig.clock.t = Config.BroadcastSeconds + 1
		rig.desk:Update()
		rig.clock.t = Config.BroadcastSeconds + 30
		rig.desk:Update()
		expect.equal(rig.bank:GetDuffel(p1), Config.DuffelCap + Config.BroadcastPayout, "p1 paid once, over the cap")
		expect.equal(rig.bank:GetDuffel(p2), Config.BroadcastPayout, "p2 at 11 studs paid once")
		expect.equal(rig.bank:GetDuffel(p3), 0, "p3 at 30 studs not paid")
		expect.equal(rig.bank:GetDuffel(bystander), 0, "a bystander is not paid")
		expect.equal(#rig.toasts, 2, "one toast per payee")
		expect.equal(rig.toasts[1][2], string.format("Broadcast complete: %d added to your bag.", Config.BroadcastPayout), "toast text")
		rig.cleanup()
	end)

	return suite:run()
end
