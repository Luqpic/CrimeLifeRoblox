local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local GuardPost = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.GuardPost)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local Combat = require(game.ReplicatedStorage.Enemy.Combat)
	local suite = TestRunner.new("Guard")
	-- The session-only lifecycle (the Bank's before 2026-11-20, still the one without GuardsAlwaysPosted).
	local sessionOnly = table.clone(Config)
	sessionOnly.GuardsAlwaysPosted = nil

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
			config = sessionOnly, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			shoot = function() end,
		})
		expect.equal(spawned, 0, "construction does not spawn")
		expect.falsy(post:IsAlive(), "no guard yet")
		marker:Destroy()
	end)

	suite:test("a session start spawns exactly one guard", function(expect)
		local marker = tempMarker()
		local spawned = 0
		local post = GuardPost.new(marker, {
			config = sessionOnly, bank = activeBank(),
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
			shoot = function() end,
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
			shoot = function() end,
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
			config = sessionOnly, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			shoot = function() end,
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
			config = sessionOnly, bank = activeBank(),
			now = function() return 100 end,
			spawnGuard = function() spawned += 1; return nil end,
			onGuardDied = function() end,
			shoot = function() end,
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
			config = sessionOnly, bank = activeBank(),
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
			shoot = function() end,
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

	-- Heist layers 2026-11-17 (Task 2): Alert() engages a guard at once, without a player in activation range.
	suite:test("Alert: a mayTarget player in sight range but out of activation range is shot only after Alert()", function(expect)
		local function run(alert)
			local marker = tempMarker()
			local shots = {}
			local clock = 100
			local postedConfig = { GuardsAlwaysPosted = true, GuardSpawnLift = 0, GuardRespawnSeconds = 60, Tags = {},
				GuardActivationRange = 60, GuardSightRange = 120, GuardFireInterval = 0.9, GuardDamage = 6 }
			local bank = activeBank()
			local robber = { GetAttribute = function() return nil end }
			bank:AddParticipant(robber)
			local post = GuardPost.new(marker, {
				config = postedConfig, bank = bank,
				now = function() return clock end,
				tokens = Combat.newTokens(2, function() return clock end),
				showTell = function() return function() end end,
				spawnGuard = function()
					local model = Instance.new("Model")
					Instance.new("Humanoid").Parent = model
					local root = Instance.new("Part")
					root.Name = "HumanoidRootPart"
					root.Anchored = true
					root.Parent = model
					model.PrimaryPart = root
					model.Parent = workspace
					return model
				end,
				shoot = function(_post, target) table.insert(shots, { target = target }) end,
			})
			-- 90 studs: past GuardActivationRange (60), inside GuardSightRange (120).
			post._candidates = function() return { { player = robber, position = Vector3.new(90, 0, 0), visible = true } } end
			if alert then post:Alert() end
			post:Update()
			clock += Combat.reactionTime(false) -- the wind-up before a first shot (combat balance 2026-11-20)
			post:Update()
			post:Destroy()
			marker:Destroy()
			return shots, robber
		end
		local quiet = run(false)
		expect.equal(#quiet, 0, "without Alert the guard holds")
		local shots, robber = run(true)
		expect.equal(#shots, 1, "after Alert it fires")
		expect.equal(shots[1] and shots[1].target, robber, "at the robber")
	end)

	suite:test("Alert on a dead guard is a no-op", function(expect)
		local marker = tempMarker()
		local post = GuardPost.new(marker, { config = Config, bank = activeBank(), now = function() return 100 end,
			spawnGuard = function() return nil end })
		post:Alert()
		expect.falsy(post._activated, "no guard: latch untouched")
		post:Destroy()
		marker:Destroy()
	end)

	-- Heist police and Bank guards (2026-11-20).
	local function rig(anchored)
		local model = Instance.new("Model")
		Instance.new("Humanoid").Parent = model
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = anchored == true
		root.Parent = model
		model.PrimaryPart = root
		model.Parent = workspace
		return model
	end

	suite:test("the Bank's posts stand from boot and alternate Security and Police by post number", function(expect)
		expect.truthy(Config.GuardsAlwaysPosted, "the Bank's guards stand at all times")
		expect.equal(GuardPost.templateFor("GuardPost1", Config.GuardTemplates), "Security", "post 1")
		expect.equal(GuardPost.templateFor("GuardPost2", Config.GuardTemplates), "Police", "post 2")
		expect.equal(GuardPost.templateFor("GuardPost3", Config.GuardTemplates), "Security", "post 3")
		expect.equal(GuardPost.templateFor("GuardPost4", Config.GuardTemplates), "Police", "post 4")
		expect.equal(GuardPost.templateFor("GuardPost2", nil), nil, "no list: the plain GuardTemplate (NewsStation)")
		local marker = tempMarker()
		marker.Name = "GuardPost4"
		local asked
		local post = GuardPost.new(marker, { config = Config, bank = BankInstance.new({ config = Config, now = function() return 1000 end }),
			now = function() return 100 end, spawnGuard = function(_cframe, _lift, template) asked = template return nil end })
		expect.equal(asked, "Police", "the post's spawn is asked for its template")
		post:Destroy()
		marker:Destroy()
	end)

	suite:test("a Bank post builds its guard from EnemyTemplates: health, held weapon, witness and guard, rooted at its post", function(expect)
		local CollectionService = game:GetService("CollectionService")
		for _, case in ipairs({ { "GuardPost1", "Security", 80 }, { "GuardPost2", "Police", 100 } }) do
			local marker = tempMarker(Vector3.new(0, 4000, 0))
			marker.Name = case[1]
			local post = GuardPost.new(marker, { config = Config, now = function() return 100 end,
				bank = BankInstance.new({ config = Config, now = function() return 1000 end }) })
			local guard = post._guard
			expect.truthy(guard ~= nil and guard.Parent ~= nil, case[1] .. " stands from construction")
			if guard then
				local humanoid = guard:FindFirstChildOfClass("Humanoid")
				expect.equal(guard:GetAttribute("EnemyTemplate"), case[2], case[1] .. " template")
				expect.equal(humanoid and humanoid.MaxHealth, case[3], case[2] .. " health from the template")
				expect.truthy(guard:FindFirstChildOfClass("Tool") ~= nil, case[2] .. " holds the template's weapon")
				expect.truthy(CollectionService:HasTag(guard, "Witness") and guard:GetAttribute("WitnessRole") == "Guard", "a witness and a guard")
				expect.truthy(guard.PrimaryPart and guard.PrimaryPart.Anchored, "rooted at its post")
				local want = marker.Position + Vector3.new(0, Config.GuardSpawnLift, 0)
				expect.truthy(guard.PrimaryPart and (guard.PrimaryPart.Position - want).Magnitude < 0.05, "root GuardSpawnLift above the post")
			end
			post:Destroy()
			marker:Destroy()
		end
	end)

	suite:test("an always-posted guard is counted again at a session start; a dead one is replaced at once", function(expect)
		local postedConfig = { GuardsAlwaysPosted = true, GuardSpawnLift = 0, GuardRespawnSeconds = 60, Tags = {},
			GuardActivationRange = 60, GuardSightRange = 120, GuardFireInterval = 0.9, GuardDamage = 6 }
		local function build()
			local marker = tempMarker()
			local bank = BankInstance.new({ config = Config, now = function() return 1000 end })
			local counts = { spawned = 0, counted = 0 }
			local post = GuardPost.new(marker, { config = postedConfig, bank = bank, now = function() return 100 end,
				spawnGuard = function() counts.spawned += 1 return rig(true) end,
				onGuardSpawned = function() counts.counted += 1 end })
			bank:RegisterComponent(post)
			return bank, post, counts, marker
		end
		local bank, post, counts, marker = build()
		bank:TryStart("starter")
		expect.equal(counts.spawned, 1, "the standing guard is kept")
		expect.equal(counts.counted, 2, "and counted again for the session (TryStart zeroed the count)")
		post:Destroy()
		marker:Destroy()
		bank, post, counts, marker = build()
		post:_handleDeath()
		bank:TryStart("starter")
		expect.equal(counts.spawned, 2, "a guard dead before the start is replaced at the start")
		expect.truthy(post:IsAlive(), "alive for the session")
		post:Destroy()
		marker:Destroy()
	end)

	suite:test("outside a session a guard is passive; one a player hurt shoots that player for GuardProvokeSeconds", function(expect)
		local marker = tempMarker()
		local clock = 100
		local shots = {}
		local function standIn() return { GetAttribute = function() return nil end } end
		local attacker, bystander = standIn(), standIn()
		local post = GuardPost.new(marker, { config = Config, now = function() return clock end,
			bank = BankInstance.new({ config = Config, now = function() return 1000 end }),
			spawnGuard = function() return rig(true) end,
			tokens = Combat.newTokens(2, function() return clock end),
			showTell = function() return function() end end,
			shoot = function(_post, target) table.insert(shots, target) end })
		post._candidates = function()
			return {
				{ player = bystander, position = Vector3.new(10, 0, 0), visible = true },
				{ player = attacker, position = Vector3.new(20, 0, 0), visible = true },
			}
		end
		post:Update()
		expect.equal(#shots, 0, "a player walking past at 10 studs is left alone")
		post:Provoke(attacker)
		post:Update()
		expect.equal(#shots, 0, "provoked: winds up first")
		clock += Combat.reactionTime(false)
		post:Update()
		expect.equal(#shots, 1, "provoked: fires")
		expect.equal(shots[1], attacker, "at the attacker, past the nearer bystander")
		clock = 100 + Config.GuardProvokeSeconds - 0.1
		post:Update()
		expect.equal(#shots, 2, "still provoked just before GuardProvokeSeconds")
		clock = 100 + Config.GuardProvokeSeconds
		post:Update()
		expect.equal(#shots, 2, "calm again after GuardProvokeSeconds")
		post:Destroy()
		marker:Destroy()
	end)

	-- Combat balance (2026-11-20): guards fire like every NPC shooter (tokens, wind-up with the aim line, bursts), and a
	-- guard holding a melee weapon strikes only within its reach.
	local function armedPost(clock, tokens, record, tool)
		local marker = tempMarker()
		local bank = activeBank()
		local robber = { GetAttribute = function() return nil end }
		bank:AddParticipant(robber)
		local post = GuardPost.new(marker, { config = Config, bank = bank, now = function() return clock.t end,
			spawnGuard = function()
				local model = rig(true)
				if tool then tool.Parent = model end
				return model
			end,
			tokens = tokens,
			showTell = function()
				record.tells += 1
				record.showing = true
				return function() record.showing = false end
			end,
			shoot = function(_post, target) table.insert(record.shots, { target = target, t = clock.t }) end })
		post._candidates = function() return { { player = robber, position = Vector3.new(20, 0, 0), visible = true } } end
		return post, robber, marker
	end

	suite:test("a gun guard shows the aim line for the wind-up, fires a burst, lets its token go and pauses", function(expect)
		local clock = { t = 100 }
		local tokens = Combat.newTokens(2, function() return clock.t end)
		local record = { tells = 0, shots = {}, showing = false }
		local post, robber, marker = armedPost(clock, tokens, record)
		post:Update()
		expect.equal(record.tells, 1, "the aim line goes up at once")
		expect.truthy(record.showing, "and stays up through the wind-up")
		expect.equal(tokens:count(robber), 1, "the guard holds one of the robber's tokens")
		clock.t = 100 + Combat.reactionTime(false) - 0.05
		post:Update()
		expect.equal(#record.shots, 0, "no shot before the wind-up ends")
		clock.t = 100 + Combat.reactionTime(false)
		post:Update()
		expect.equal(#record.shots, 1, "the first shot ends the wind-up")
		expect.falsy(record.showing, "and takes the line down")
		while tokens:count(robber) > 0 and #record.shots < 10 do
			clock.t += Config.GuardFireInterval
			post:Update()
		end
		local burst = #record.shots
		expect.truthy(burst >= Combat.BURST_SHOTS_MIN and burst <= Combat.BURST_SHOTS_MAX, "a burst of 3 to 5")
		expect.equal(tokens:count(robber), 0, "the token is back after the burst")
		clock.t += Combat.BURST_PAUSE_MIN - 0.05
		post:Update()
		expect.equal(#record.shots, burst, "no shot in the pause")
		clock.t += Combat.BURST_PAUSE_MAX
		post:Update()
		expect.equal(#record.shots, burst + 1, "after the pause it fires again")
		expect.equal(record.tells, 1, "without a second wind-up on the same target")
		post:Destroy()
		expect.equal(tokens:count(robber), 0, "a removed guard holds no token")
		marker:Destroy()
	end)

	suite:test("a gun guard waits while two others fire at the robber", function(expect)
		local clock = { t = 100 }
		local tokens = Combat.newTokens(2, function() return clock.t end)
		local record = { tells = 0, shots = {}, showing = false }
		local post, robber, marker = armedPost(clock, tokens, record)
		local a, b = {}, {}
		tokens:acquire(robber, a)
		tokens:acquire(robber, b)
		post:Update()
		clock.t += 2
		post:Update()
		expect.equal(record.tells, 0, "no aim line without a token")
		expect.equal(#record.shots, 0, "and no shot")
		tokens:release(robber, a)
		post:Update()
		expect.equal(record.tells, 1, "a free token: it winds up")
		post:Destroy()
		marker:Destroy()
	end)

	suite:test("a guard with a melee weapon strikes only within its reach, and not at a staggered target", function(expect)
		local clock = { t = 100 }
		local tokens = Combat.newTokens(2, function() return clock.t end)
		local record = { tells = 0, shots = {}, showing = false }
		local baton = Instance.new("Tool")
		baton:SetAttribute("meleeHitEffect", "MeleeImpact")
		baton:SetAttribute("range", 6)
		local post, robber, marker = armedPost(clock, tokens, record, baton)
		local body = rig(true)
		robber.Character = body
		local guardRoot = post._guard.PrimaryPart
		-- Facing away from the robber with the muzzle 5 studs ahead: in reach only once the guard has turned.
		post._guard:PivotTo(CFrame.lookAt(guardRoot.Position, guardRoot.Position - Vector3.xAxis))
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Anchored = true
		handle.CFrame = guardRoot.CFrame * CFrame.new(0, 0, -5)
		Instance.new("Attachment", handle).Name = "MuzzleAttachment"
		handle.Parent = baton
		body.PrimaryPart.Position = guardRoot.Position + Vector3.new(15, 0, 0)
		post:Update()
		expect.equal(#record.shots, 0, "15 studs: out of the Baton's reach")
		body.PrimaryPart.Position = guardRoot.Position + Vector3.new(4, 0, 0)
		clock.t += 1
		post:Update()
		expect.equal(#record.shots, 1, "4 studs: it strikes")
		expect.equal(record.tells, 0, "a swing has no aim line")
		body.PrimaryPart:SetAttribute("StunnedUntil", os.clock() + 5)
		clock.t += 2
		post:Update()
		expect.equal(#record.shots, 1, "not while the target is still staggered")
		post:Destroy()
		body:Destroy()
		marker:Destroy()
	end)

	return suite:run()
end
