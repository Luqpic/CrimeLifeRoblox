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
	local inactive = {} -- stand-ins that are dead or gone
	local function testAttackerActive(player) return not inactive[player] end
	deps.attackerActive = testAttackerActive
	local function testSeen(player) return seen[player] == true end
	-- The drain cases below pin the 8 s rule alone: no search window unless a case sets one (fix round 1).
	deps.searchSeconds = 0
	local robbing = {}
	deps.activeRobbery = function(player) return robbing[player] == true end
	-- Stand-ins are tables (no Parent): in the game unless a case marks them gone (final review 2026-11-17).
	local gone = {}
	deps.inGame = function(player) return not gone[player] end

	-- Every test below runs inside this pcall, so the injected deps are restored even if building a case throws.
	local ok, err = pcall(function()

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

	-- Final review 2026-11-17: the real default witness check (Witnesses.sees through the real Sight probe),
	-- 9,000 studs above the map where no placed witness reaches. The attacker's character is unparented (only
	-- its root's position is read); witnesses are tagged models in Workspace, destroyed at the end.
	local function part(model: Model, name: string, position: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = Vector3.new(2, 2, 1)
		p.Position = position
		p.Parent = model
	end
	local function attackerAt(position: Vector3)
		local p = standIn()
		local character = Instance.new("Model")
		part(character, "HumanoidRootPart", position)
		p.Character = character
		return p, character
	end
	local function witnessAt(position: Vector3)
		local humanoid, model = victim(nil, "Witness")
		part(model, "Head", position)
		model.Parent = workspace
		return humanoid, model
	end

	t.test("the real default witness check: a kill far from any witness gives nothing; a witness beside the attacker, +0.5", function()
		local testWitness = deps.witness
		deps.witness = saved.witness
		local base = Vector3.new(0, 9000, 0)
		local p, character = attackerAt(base)
		local gang = victim("Gang Member")
		local alone, beside
		local ok = pcall(function()
			WantedService.onEliminated(p, gang)
			alone = WantedService.getHeat(p)
			local _, bystander = witnessAt(base + Vector3.new(20, 0, 0))
			WantedService.onEliminated(p, gang)
			beside = WantedService.getHeat(p)
			bystander:Destroy()
		end)
		deps.witness = testWitness
		character:Destroy()
		WantedService.clear(p)
		expect.truthy(ok)
		expect.equal(alone, 0)
		expect.equal(beside, 0.5)
	end)

	t.test("a hurt victim is not its own witness (real default): the civilian alone gives nothing; another witness, +0.25", function()
		local testWitness = deps.witness
		deps.witness = saved.witness
		local base = Vector3.new(0, 9000, 400)
		local p, character = attackerAt(base)
		local alone, withOther
		local ok = pcall(function()
			local humanoid, civilian = witnessAt(base + Vector3.new(10, 0, 0))
			clock = 18000
			WantedService.onDamaged(p, humanoid, 10)
			alone = WantedService.getHeat(p)
			local _, other = witnessAt(base + Vector3.new(-10, 0, 0))
			WantedService.onDamaged(p, humanoid, 10)
			withOther = WantedService.getHeat(p)
			civilian:Destroy()
			other:Destroy()
		end)
		deps.witness = testWitness
		character:Destroy()
		WantedService.clear(p)
		expect.truthy(ok)
		expect.equal(alone, 0)
		expect.equal(withOther, 0.25)
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

	t.test("start()'s filter ignores an NPC attacker and a non-Humanoid victim", function()
		-- The handlers start() connects to Damaged and Eliminated, called directly. Needs the real Play player
		-- (a Player instance, alive): the stand-ins are tables and the filter rightly rejects them.
		local real = game:GetService("Players"):GetPlayers()[1]
		expect.truthy(real)
		deps.attackerActive = saved.attackerActive
		local cop = victim("Police")
		local npc = Instance.new("Model")
		clock = 8000
		WantedService._onDamagedEvent(npc, cop, 10)
		WantedService._onEliminatedEvent(npc, cop)
		WantedService._onDamagedEvent(real, Instance.new("Part"), 10)
		WantedService._onEliminatedEvent(real, "not a humanoid")
		local ignored = WantedService.getHeat(real)
		-- and the same handler does pass a live Player on a Humanoid
		WantedService._onDamagedEvent(real, cop, 10)
		local passed = WantedService.getHeat(real)
		WantedService.clear(real)
		deps.attackerActive = testAttackerActive
		expect.equal(ignored, 0)
		expect.equal(passed, 0.25)
	end)

	t.test("PlayerRemoving clears heat; a hit from the departed player afterwards gives nothing", function()
		local p = standIn()
		WantedService.addHeat(p, 2, "test")
		WantedService._onPlayerRemoving(p)
		check(p, 0)
		inactive[p] = true -- gone: no Parent, no character
		clock = 8100
		WantedService.onDamaged(p, victim("Police"), 10)
		WantedService.onEliminated(p, victim("Police"))
		check(p, 0)
	end)

	t.test("a dead attacker's hit or kill gives nothing", function()
		local p = standIn()
		inactive[p] = true
		clock = 8200
		local cop = victim("Police")
		WantedService.onDamaged(p, cop, 10)
		WantedService.onEliminated(p, cop)
		witnessed = true
		WantedService.onEliminated(p, victim("Gang Member"))
		witnessed = false
		check(p, 0)
	end)

	t.test("a throwing seen provider counts as not seen and does not stop the drain", function()
		local p = standIn()
		clock = 9000
		WantedService.onAlarm("Bank", { p })
		WantedService.setSeenProvider(function() error("seen provider test throw") end)
		clock = 9008
		local stepped = pcall(WantedService._step)
		WantedService.setSeenProvider(testSeen)
		expect.truthy(stepped)
		check(p, 2)
		WantedService.clear(p)
	end)

	t.test("unseen right after an alarm does not drain at 8 s; it drains at 28 s (search window 20 s)", function()
		deps.searchSeconds = Constants.SEARCH_SECONDS
		expect.equal(Constants.SEARCH_SECONDS, 20)
		local p = standIn()
		clock = 10000
		WantedService.onAlarm("Bank", { p })
		local at8, at27_5
		for i = 1, 56 do -- 2 Hz, as WantedRunner steps
			clock = 10000 + i * 0.5
			WantedService._step()
			if clock == 10008 then at8 = WantedService.getHeat(p) end
			if clock == 10027.5 then at27_5 = WantedService.getHeat(p) end
		end
		deps.searchSeconds = 0
		expect.equal(at8, 3)
		expect.equal(at27_5, 3)
		check(p, 2) -- at 10028
		WantedService.clear(p)
	end)

	t.test("an active robbery keeps heat however long; after it the 8 s drain runs", function()
		local p = standIn()
		clock = 11000
		robbing[p] = true
		WantedService.onAlarm("SlowFoods", { p })
		for i = 1, 600 do
			clock = 11000 + i * 0.5
			WantedService._step()
		end
		check(p, 1)
		expect.truthy(WantedService.knowsWhere(p))
		robbing[p] = nil
		clock = 11307.9; WantedService._step()
		check(p, 1)
		clock = 11308; WantedService._step()
		check(p, 0)
	end)

	t.test("knowsWhere: during the search window and an active robbery only", function()
		deps.searchSeconds = Constants.SEARCH_SECONDS
		local p = standIn()
		clock = 12000
		WantedService.addHeat(p, 1, "test")
		clock = 12019; local inside = WantedService.knowsWhere(p)
		clock = 12021; local after = WantedService.knowsWhere(p)
		robbing[p] = true; local robbingNow = WantedService.knowsWhere(p); robbing[p] = nil
		deps.searchSeconds = 0
		WantedService.clear(p)
		expect.equal(inside, true)
		expect.equal(after, false)
		expect.equal(robbingNow, true)
	end)

	t.test("addActiveRobbery: a registered robbery makes its participant active until disconnected", function()
		local p, q = standIn(), standIn()
		local conn = WantedService.addActiveRobbery(function(player) return player == p end)
		local yes, no = saved.activeRobbery(p), saved.activeRobbery(q)
		conn:Disconnect()
		local after = saved.activeRobbery(p)
		expect.equal(yes, true)
		expect.equal(no, false)
		expect.equal(after, false)
	end)

	-- Fix round 2: the robbery keeps a participant "seen" only near the robbery, through the location's own
	-- Getaway (Getaway:IsNear = inside the building, or horizontally closer than EscapeDistance to the anchor).
	-- The registered check is the one LocationServer and HeistServer register: Active and participant and near.
	local Getaway = require(ServerScriptService.Heist.Services.Getaway)
	local function robberyAt(p, inside: boolean, position: Vector3)
		local getaway = Getaway.new({
			escapeDistance = 200,
			getAnchorPosition = function() return Vector3.new(0, 80, 0) end,
			isInsideBuilding = function() return inside end,
			getDuffel = function() return 0 end,
			onEscaped = function() end,
			getPlayers = function() return {} end,
			getPosition = function() return position end,
		})
		return WantedService.addActiveRobbery(function(player)
			return player == p and getaway:IsNear(player)
		end)
	end

	t.test("an active robbery: a participant inside the building counts as seen", function()
		local p = standIn()
		local conn = robberyAt(p, true, Vector3.new(500, 0, 0))
		local active = saved.activeRobbery(p)
		conn:Disconnect()
		expect.equal(active, true)
	end)

	t.test("an active robbery: a participant at EscapeDistance + 1 (outside) does not", function()
		local p = standIn()
		local conn = robberyAt(p, false, Vector3.new(201, 0, 0))
		local far = saved.activeRobbery(p)
		conn:Disconnect()
		conn = robberyAt(p, false, Vector3.new(199, 0, 0))
		local near = saved.activeRobbery(p)
		conn:Disconnect()
		expect.equal(far, false)
		expect.equal(near, true)
	end)

	t.test("a participant who banked and stands 300 studs away drains after the search window", function()
		deps.searchSeconds = Constants.SEARCH_SECONDS
		deps.activeRobbery = saved.activeRobbery
		local p = standIn()
		local conn = robberyAt(p, false, Vector3.new(300, 0, 0))
		clock = 13000
		WantedService.onAlarm("SlowFoods", { p })
		local at27_5
		for i = 1, 56 do
			clock = 13000 + i * 0.5
			WantedService._step()
			if clock == 13027.5 then at27_5 = WantedService.getHeat(p) end
		end
		conn:Disconnect()
		deps.searchSeconds = 0
		deps.activeRobbery = function(player) return robbing[player] == true end
		expect.equal(at27_5, 1)
		check(p, 0) -- at 13028
	end)

	-- Task 4: the star meter reads WantedSeen (pulse) and WantedDraining (blink), both set at each step.
	t.test("WantedSeen follows the seen provider and the active-robbery bypass; cleared at 0", function()
		local p = standIn()
		clock = 14000
		WantedService.addHeat(p, 2, "test")
		seen[p] = true; clock = 14001; WantedService._step()
		local whileSeen = p:GetAttribute("WantedSeen")
		seen[p] = nil; clock = 14002; WantedService._step()
		local unseen = p:GetAttribute("WantedSeen")
		robbing[p] = true; clock = 14003; WantedService._step()
		local inRobbery = p:GetAttribute("WantedSeen")
		WantedService.clear(p)
		robbing[p] = nil
		expect.equal(whileSeen, true)
		expect.equal(unseen, false)
		expect.equal(inRobbery, true)
		expect.equal(p:GetAttribute("WantedSeen"), false)
	end)

	t.test("WantedDraining: false in the search window and while seen, true once the unseen timer runs; false at 0", function()
		deps.searchSeconds = Constants.SEARCH_SECONDS
		local p = standIn()
		clock = 15000
		WantedService.addHeat(p, 1.5, "test")
		clock = 15020; WantedService._step() -- the window's last step (20 s): the timer restarts here
		local inWindow = p:GetAttribute("WantedDraining")
		clock = 15021; WantedService._step()
		local after = p:GetAttribute("WantedDraining")
		seen[p] = true; clock = 15022; WantedService._step(); seen[p] = nil
		local whileSeen = p:GetAttribute("WantedDraining")
		clock = 15030; WantedService._step() -- 1.5 -> 1, still draining
		local stepped = p:GetAttribute("WantedDraining")
		local heatAt30 = WantedService.getHeat(p)
		clock = 15038; WantedService._step() -- 1 -> 0
		deps.searchSeconds = 0
		expect.equal(inWindow, false)
		expect.equal(after, true)
		expect.equal(whileSeen, false)
		expect.equal(stepped, true)
		expect.equal(heatAt30, 1)
		check(p, 0)
		expect.equal(p:GetAttribute("WantedDraining"), false)
		expect.equal(p:GetAttribute("WantedSeen"), false)
	end)

	t.test("a rise in heat (addHeat or an alarm) sets WantedDraining false at once, before the next step", function()
		local p = standIn()
		clock = 16000
		WantedService.addHeat(p, 2, "test")
		clock = 16001; WantedService._step()
		local before = p:GetAttribute("WantedDraining")
		WantedService.addHeat(p, 0.25, "test")
		local afterHit = p:GetAttribute("WantedDraining")
		clock = 16002; WantedService._step()
		local again = p:GetAttribute("WantedDraining")
		WantedService.onAlarm("Bank", { p })
		local afterAlarm = p:GetAttribute("WantedDraining")
		WantedService.clear(p)
		expect.equal(before, true)
		expect.equal(afterHit, false)
		expect.equal(again, true)
		expect.equal(afterAlarm, false)
	end)

	-- Final review 2026-11-17: a departed player (Parent not Players) is never given heat, and an entry left
	-- by a player who departed is dropped at the next step instead of being stepped forever.
	t.test("a departed player: addHeat and an alarm give nothing; a wanted player who departs is dropped at the next step", function()
		local p = standIn()
		gone[p] = true
		clock = 19000
		WantedService.addHeat(p, 2, "test")
		WantedService.onAlarm("Bank", { p })
		local given = WantedService.getHeat(p)
		local attribute = p:GetAttribute("WantedHeat")
		local q = standIn()
		WantedService.addHeat(q, 2, "test")
		gone[q] = true
		clock = 19001; WantedService._step()
		local left = WantedService.getHeat(q)
		gone[p], gone[q] = nil, nil
		WantedService.clear(q)
		expect.equal(given, 0)
		expect.equal(attribute, nil)
		expect.equal(left, 0)
	end)

	end)
	for key, value in saved do deps[key] = value end
	deps.searchSeconds, deps.activeRobbery, deps.inGame = saved.searchSeconds, saved.activeRobbery, saved.inGame
	if not ok then error(err, 0) end
end
