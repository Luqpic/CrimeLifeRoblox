-- WantedService: alarms, the unseen drain, death, and which hits and kills give heat
-- (police and wanted, Task 1, 2026-11-17).
--
-- Stand-in players as ProfileAdoption_Test builds them (a real Player cannot be constructed). The clock,
-- the seen provider, the witness check and the character-to-player lookup are injected through
-- WantedService._deps and restored at the end; the drain is driven through _step, never by waiting.
-- Victims are real (unparented) Models, since the service reads their attributes and tags.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local CollectionService = game:GetService("CollectionService")
	local WantedService = require(ServerScriptService.Wanted.WantedService)
	local Constants = require(ReplicatedStorage.Wanted.Constants)
	local expect = t.expect

	local deps = WantedService._deps
	local saved = table.clone(deps)

	local clock = 1000
	local seen = {}
	local witnessed = false
	local playerOfCharacter = {}
	deps.now = function() return clock end
	WantedService.setSeenProvider(function(player) return seen[player] == true end)
	deps.witness = function() return witnessed end
	deps.playerFromCharacter = function(character) return playerOfCharacter[character] end

	local function standIn()
		local attributes = {}
		return {
			Name = "StandIn",
			UserId = -math.random(1000, 999999),
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
			FindFirstChildOfClass = function() return nil end,
			_attributes = attributes,
		}
	end

	local function victim(template: string?, tag: string?)
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		if template then model:SetAttribute("EnemyTemplate", template) end
		if tag then CollectionService:AddTag(model, tag) end
		return humanoid, model
	end

	-- heat, both attributes, all agreeing (a stand-in never touched has no attributes: start() sets 0 on
	-- real players at join)
	local function check(player, heat)
		expect.equal(WantedService.getHeat(player), heat)
		expect.equal(player:GetAttribute("WantedHeat") or 0, heat)
		expect.equal(player:GetAttribute("WantedStars") or 0, math.floor(heat))
	end

	t.test("an alarm sets the location's level: Bank 3, Gas2Go 1", function()
		local a, b = standIn(), standIn()
		WantedService.onAlarm("Bank", { a })
		WantedService.onAlarm("Gas2Go", { b })
		check(a, 3)
		check(b, 1)
		WantedService.clear(a)
		WantedService.clear(b)
	end)

	t.test("every participant gets the alarm; an unknown location gives nothing", function()
		local a, b, c = standIn(), standIn(), standIn()
		WantedService.onAlarm("NewsStation", { a, b })
		WantedService.onAlarm("TestLoc", { c })
		check(a, 2)
		check(b, 2)
		expect.equal(WantedService.getHeat(c), 0)
		WantedService.clear(a)
		WantedService.clear(b)
	end)

	t.test("a second, lower alarm does not lower heat", function()
		local p = standIn()
		WantedService.onAlarm("Bank", { p })
		WantedService.onAlarm("SlowFoods", { p })
		check(p, 3)
		WantedService.clear(p)
	end)

	t.test("unseen for 8 s drops one step; seen at 7 s restarts the timer", function()
		local p = standIn()
		clock = 2000
		WantedService.onAlarm("Bank", { p })
		clock = 2007.9; WantedService._step()
		check(p, 3)
		clock = 2008; WantedService._step()
		check(p, 2)
		-- seen 7 s into the next 8: the timer restarts there
		clock = 2015; seen[p] = true; WantedService._step()
		seen[p] = nil
		clock = 2022.9; WantedService._step()
		check(p, 2)
		clock = 2023; WantedService._step()
		check(p, 1)
		clock = 2031; WantedService._step()
		check(p, 0)
	end)

	t.test("a fractional heat drains to the integer below first", function()
		local p = standIn()
		clock = 3000
		WantedService.addHeat(p, 2.75, "test")
		check(p, 2.75)
		clock = 3008; WantedService._step()
		check(p, 2)
		WantedService.clear(p)
	end)

	t.test("raising heat restarts the drain timer", function()
		local p = standIn()
		clock = 4000
		WantedService.addHeat(p, 1, "test")
		clock = 4006; WantedService.addHeat(p, 0.25, "test")
		clock = 4013; WantedService._step()
		check(p, 1.25)
		clock = 4014; WantedService._step()
		check(p, 1)
		WantedService.clear(p)
	end)

	t.test("death clears heat", function()
		local p = standIn()
		-- Died fires only for a humanoid with a body (measured: a bare Model's humanoid never fires it), so a
		-- root and a head, welded, high above the map; ChangeState(Dead) is what fires it on the server.
		local humanoid, model = victim()
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 1)
		root.Position = Vector3.new(0, 5000, 0)
		root.Parent = model
		model.PrimaryPart = root
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(1, 1, 1)
		head.Position = Vector3.new(0, 5002, 0)
		head.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, head
		weld.Parent = root
		model.Parent = workspace
		WantedService._watchCharacter(p, model)
		WantedService.onAlarm("Bank", { p })
		humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		local waited = 0
		while WantedService.getHeat(p) > 0 and waited < 1 do waited += task.wait() end
		model:Destroy()
		check(p, 0)
	end)

	t.test("clear sets heat and both attributes to 0", function()
		local p = standIn()
		WantedService.addHeat(p, 4.5, "test")
		WantedService.clear(p)
		check(p, 0)
	end)

	t.test("a hit on police +0.25, a police kill +1 (Police and Armed Police)", function()
		local p = standIn()
		local cop = victim("Police")
		local armed = victim("Armed Police")
		clock = 5000
		WantedService.onDamaged(p, cop, 10)
		check(p, 0.25)
		clock = 5001
		WantedService.onDamaged(p, armed, 10)
		check(p, 0.5)
		WantedService.onEliminated(p, cop)
		check(p, 1.5)
		WantedService.onEliminated(p, armed)
		check(p, 2.5)
		WantedService.clear(p)
	end)

	t.test("the pellets of one shot on one officer count as one hit", function()
		local p = standIn()
		local cop = victim("Police")
		clock = 6000
		for _ = 1, 8 do WantedService.onDamaged(p, cop, 5) end
		check(p, 0.25)
		clock = 6000 + Constants.HIT_MERGE_WINDOW
		WantedService.onDamaged(p, cop, 5)
		check(p, 0.5)
		WantedService.clear(p)
	end)

	t.test("a player-on-player hit or kill adds nothing, even witnessed", function()
		local attacker, other = standIn(), standIn()
		local humanoid, character = victim(nil, "Witness")
		playerOfCharacter[character] = other
		witnessed = true
		WantedService.onDamaged(attacker, humanoid, 30)
		WantedService.onEliminated(attacker, humanoid)
		witnessed = false
		playerOfCharacter[character] = nil
		check(attacker, 0)
	end)

	t.test("killing an NPC gives +0.5 only when witnessed", function()
		local p = standIn()
		local gang = victim("Gang Member")
		WantedService.onEliminated(p, gang)
		check(p, 0)
		witnessed = true
		WantedService.onEliminated(p, gang)
		witnessed = false
		check(p, 0.5)
		WantedService.clear(p)
	end)

	t.test("hurting a heist civilian gives +0.25 only when witnessed; hurting a gang member never", function()
		local p = standIn()
		local civilian = victim(nil, "Witness")
		local gang = victim("Gang Member")
		WantedService.onDamaged(p, civilian, 10)
		check(p, 0)
		witnessed = true
		WantedService.onDamaged(p, gang, 10)
		check(p, 0)
		WantedService.onDamaged(p, civilian, 10)
		witnessed = false
		check(p, 0.25)
		WantedService.clear(p)
	end)

	t.test("the default witness check is the stub: false", function()
		expect.equal(saved.witness(standIn()), false)
	end)

	t.test("Changed fires with player, heat and stars", function()
		local p = standIn()
		local got
		local conn = WantedService.Changed:Connect(function(player, heat, stars)
			if player == p then got = { heat, stars } end
		end)
		WantedService.addHeat(p, 2.5, "test")
		conn:Disconnect()
		WantedService.clear(p)
		expect.deepEqual(got, { 2.5, 2 })
	end)

	for key, value in saved do deps[key] = value end
end
