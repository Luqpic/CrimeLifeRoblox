local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local GuardPost = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.GuardPost)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("Guard")

	local function activeBank(now)
		local inst = BankInstance.new({ config = Config, now = now or function() return 1000 end })
		inst:TryStart("starter")
		return inst
	end

	local function tempMarker(pos)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Transparency = 1
		part.Size = Vector3.new(2, 1, 2)
		part.CFrame = CFrame.new(pos or Vector3.new(0, 0, 0))
		part.Parent = workspace
		return part
	end

	-- assignCover

	suite:test("a guard claims the nearest unclaimed cover point", function(expect)
		local cover = { Vector3.new(50, 0, 0), Vector3.new(5, 0, 0), Vector3.new(20, 0, 0) }
		local index, position = GuardPost.assignCover(Vector3.new(0, 0, 0), cover, {})
		expect.equal(index, 2, "nearest")
		expect.equal(position, cover[2], "position returned")
	end)

	suite:test("a claimed cover point is skipped", function(expect)
		local cover = { Vector3.new(50, 0, 0), Vector3.new(5, 0, 0), Vector3.new(20, 0, 0) }
		local index = GuardPost.assignCover(Vector3.new(0, 0, 0), cover, { [2] = true })
		expect.equal(index, 3, "next nearest")
	end)

	suite:test("no cover left returns nil rather than erroring", function(expect)
		local cover = { Vector3.new(5, 0, 0) }
		local index = GuardPost.assignCover(Vector3.new(0, 0, 0), cover, { [1] = true })
		expect.equal(index, nil, "nil when everything is taken")
	end)

	-- selectTarget

	suite:test("the closest visible player is targeted", function(expect)
		local target = GuardPost.selectTarget(Vector3.new(0, 0, 0), {
			{ player = "far", position = Vector3.new(80, 0, 0), visible = true },
			{ player = "near", position = Vector3.new(10, 0, 0), visible = true },
		}, 120)
		expect.equal(target, "near", "closest")
	end)

	suite:test("an invisible player is never targeted, however close", function(expect)
		local target = GuardPost.selectTarget(Vector3.new(0, 0, 0), {
			{ player = "hidden", position = Vector3.new(2, 0, 0), visible = false },
			{ player = "exposed", position = Vector3.new(60, 0, 0), visible = true },
		}, 120)
		expect.equal(target, "exposed", "cover works — that is the point of the room")
	end)

	suite:test("players beyond sight range are ignored", function(expect)
		local target = GuardPost.selectTarget(Vector3.new(0, 0, 0), {
			{ player = "distant", position = Vector3.new(500, 0, 0), visible = true },
		}, 120)
		expect.equal(target, nil, "out of range")
	end)

	suite:test("no candidates yields no target", function(expect)
		expect.equal(GuardPost.selectTarget(Vector3.new(0, 0, 0), {}, 120), nil, "nil")
	end)

	-- shouldActivate

	suite:test("a guard holds its post until a player is within range", function(expect)
		local post = Vector3.new(0, 0, 0)
		expect.falsy(GuardPost.shouldActivate(post, { Vector3.new(200, 0, 0) }, 60), "far away")
		expect.falsy(GuardPost.shouldActivate(post, {}, 60), "nobody in the room")
		expect.truthy(GuardPost.shouldActivate(post, { Vector3.new(30, 0, 0) }, 60), "player breached")
	end)

	suite:test("activation range is inclusive at the boundary", function(expect)
		local post = Vector3.new(0, 0, 0)
		expect.truthy(GuardPost.shouldActivate(post, { Vector3.new(60, 0, 0) }, 60), "exactly at range")
		expect.falsy(GuardPost.shouldActivate(post, { Vector3.new(60.1, 0, 0) }, 60), "just outside")
	end)

	-- shouldFire

	suite:test("the first shot is always allowed", function(expect)
		expect.truthy(GuardPost.shouldFire(100, nil, 0.9), "no previous shot")
	end)

	suite:test("firing respects the interval", function(expect)
		expect.falsy(GuardPost.shouldFire(100.5, 100, 0.9), "too soon")
		expect.truthy(GuardPost.shouldFire(100.9, 100, 0.9), "interval elapsed")
	end)

	-- Lifecycle

	suite:test("no guard exists until a session starts", function(expect)
		local marker = tempMarker()
		local spawned = 0
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			damage = function() end,
		})
		expect.equal(spawned, 0, "construction does not spawn")
		expect.falsy(post:IsAlive(), "no guard yet")
		marker:Destroy()
	end)

	suite:test("a session start spawns exactly one guard", function(expect)
		local marker = tempMarker()
		local spawned = 0
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function()
				spawned += 1
				local model = Instance.new("Model")
				local hum = Instance.new("Humanoid")
				hum.Parent = model
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = workspace
				return model
			end,
			onGuardDied = function() end,
			damage = function() end,
		})
		post:OnSessionStart()
		post:OnSessionStart()
		expect.equal(spawned, 1, "one guard per post per session, even if start fires twice")
		expect.truthy(post:IsAlive(), "alive")
		post:Destroy()
		marker:Destroy()
	end)

	suite:test("guard death reports upward exactly once", function(expect)
		local marker = tempMarker()
		local deaths = 0
		local model, humanoid
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function()
				model = Instance.new("Model")
				humanoid = Instance.new("Humanoid")
				humanoid.Parent = model
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = workspace
				return model
			end,
			onGuardDied = function() deaths += 1 end,
			damage = function() end,
		})
		post:OnSessionStart()
		post:_handleDeath()
		post:_handleDeath()
		expect.equal(deaths, 1, "one report")
		expect.falsy(post:IsAlive(), "no longer alive")
		post:Destroy()
		marker:Destroy()
	end)

	suite:test("a killed guard does not respawn within the same session", function(expect)
		local marker = tempMarker()
		local spawned = 0
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			damage = function() end,
		})
		post:OnSessionStart()
		post:_handleDeath()
		post:Update()
		post:OnSessionStart()
		expect.equal(spawned, 1, "spawned once for the whole session")
		marker:Destroy()
	end)

	suite:test("Rearm allows a fresh guard next session", function(expect)
		local marker = tempMarker()
		local spawned = 0
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			damage = function() end,
		})
		post:OnSessionStart()
		post:_handleDeath()
		post:Seal()
		post:Rearm()
		post:OnSessionStart()
		expect.equal(spawned, 2, "a new guard for the new session")
		marker:Destroy()
	end)

	suite:test("Seal despawns the guard", function(expect)
		local marker = tempMarker()
		local model
		local post = GuardPost.new(marker, {
			config = Config, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function()
				model = Instance.new("Model")
				local hum = Instance.new("Humanoid")
				hum.Parent = model
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = workspace
				return model
			end,
			onGuardDied = function() end,
			damage = function() end,
		})
		post:OnSessionStart()
		post:Seal()
		expect.falsy(model.Parent ~= nil, "guard removed from the world")
		expect.falsy(post:IsAlive(), "not alive")
		marker:Destroy()
	end)

	-- Police and wanted Task 3 (2026-11-17): NewsStation's posted guards.
	suite:test("GuardsAlwaysPosted: a guard from construction, kept at Seal, a fresh one at Rearm; no cover; lift passed", function(expect)
		local marker = tempMarker()
		local models, lifts = {}, {}
		local postedConfig = { GuardsAlwaysPosted = true, GuardSpawnLift = 0, Tags = {},
			GuardActivationRange = 60, GuardSightRange = 120, GuardFireInterval = 0.9, GuardDamage = 0 }
		local post = GuardPost.new(marker, {
			config = postedConfig, bank = BankInstance.new({ config = Config, now = function() return 1000 end }),
			now = function() return 100 end,
			spawnGuard = function(_cframe, lift)
				table.insert(lifts, lift)
				local model = Instance.new("Model")
				Instance.new("Humanoid").Parent = model
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = workspace
				table.insert(models, model)
				return model
			end,
		})
		expect.equal(#models, 1, "standing before any session")
		expect.equal(lifts[1], 0, "config.GuardSpawnLift handed to spawnGuard")
		post:OnSessionStart()
		expect.equal(#models, 1, "no second guard when the session starts")
		post:_moveToCover() -- Tags without HeistCoverPoint: holds the post, does not error
		post:Seal()
		expect.truthy(models[1].Parent ~= nil and post:IsAlive(), "a live guard stays at Seal")
		post:Rearm()
		expect.equal(#models, 2, "a fresh guard at Rearm")
		expect.falsy(models[1].Parent ~= nil, "the old one removed")
		post:Destroy()
		marker:Destroy()
	end)

	-- Police and wanted Task 3 fix round 1: guards shoot only robbers and wanted players.
	suite:test("a visible bystander is not targeted; a participant is; a wanted bystander is", function(expect)
		local function standIn(stars)
			return { GetAttribute = function(_, name) if name == "WantedStars" then return stars end return nil end }
		end
		local bystander, robber, wanted = standIn(nil), standIn(0), standIn(1)
		local bank = activeBank()
		bank:AddParticipant(robber)
		local function may(player) return GuardPost.mayTarget(bank, player) end
		local near = { player = bystander, position = Vector3.new(5, 0, 0), visible = true }
		expect.equal(GuardPost.selectTarget(Vector3.zero, { near }, 120, may), nil, "the bystander alone: nobody")
		expect.equal(GuardPost.selectTarget(Vector3.zero, {
			near, { player = robber, position = Vector3.new(50, 0, 0), visible = true },
		}, 120, may), robber, "the participant, past the nearer bystander")
		expect.equal(GuardPost.selectTarget(Vector3.zero, {
			near, { player = wanted, position = Vector3.new(60, 0, 0), visible = true },
		}, 120, may), wanted, "a wanted bystander")
	end)

	suite:test("GuardsAlwaysPosted: a guard dead outside a session is back at its post after GuardRespawnSeconds, not during one", function(expect)
		local marker = tempMarker()
		local clock = 100
		local spawned = 0
		local postedConfig = { GuardsAlwaysPosted = true, GuardSpawnLift = 0, GuardRespawnSeconds = 60, Tags = {},
			GuardActivationRange = 60, GuardSightRange = 120, GuardFireInterval = 0.9, GuardDamage = 12 }
		local bank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local post = GuardPost.new(marker, {
			config = postedConfig, bank = bank,
			now = function() return clock end,
			spawnGuard = function()
				spawned += 1
				local model = Instance.new("Model")
				Instance.new("Humanoid").Parent = model
				local root = Instance.new("Part")
				root.Name = "HumanoidRootPart"
				root.Parent = model
				model.PrimaryPart = root
				model.Parent = workspace
				return model
			end,
		})
		post:_handleDeath()
		clock = 159
		post:Update()
		expect.equal(spawned, 1, "still dead at 59 s")
		clock = 160
		post:Update()
		expect.equal(spawned, 2, "back at 60 s")
		expect.truthy(post:IsAlive(), "alive again")
		bank:TryStart("starter")
		post:_handleDeath()
		clock = 500
		post:Update()
		expect.equal(spawned, 2, "no respawn while the session is Active")
		post:Destroy()
		marker:Destroy()
	end)

	return suite:run()
end
