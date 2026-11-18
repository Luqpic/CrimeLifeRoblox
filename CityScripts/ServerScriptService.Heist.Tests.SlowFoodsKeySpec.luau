local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Open items pass 2026-11-18: SlowFoods' key, door and safe wiring (Heist.Services.SlowFoodsKey, built by
-- SlowFoodsServer) with a real FleeingManager, BankInstance and storage-safe RobbableObject. Take Key gives the
-- key attribute, Use Key opens the door for the key holder, the safe pays the holder over the bag cap; a Seal
-- mid-chase, after the catch or after the escape pays nothing; the safe refuses a carrier, a hold the server
-- did not time, and a trigger out of reach. Players are tables with a real character (Use Key measures it);
-- the door, net and carry state are recording stubs (LockedDoor:Open is pinned in LockedDoorSpec).
return function()
	local SlowFoodsKey = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.SlowFoodsKey)
	local FleeingManager = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.FleeingManager)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.RestaurantShared.Config)
	local suite = TestRunner.new("SlowFoodsKey")

	local SAFE_HOLD = 8
	local ORIGIN = Vector3.new(0, 500, 0)

	local function part(position: Vector3, parent: Instance?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Position = position
		p.Parent = parent or workspace
		return p
	end

	local function makePlayer(name: string, offset: Vector3)
		local character = Instance.new("Model")
		character.Name = name
		local root = part(ORIGIN + offset, character)
		root.Name = "HumanoidRootPart"
		part(ORIGIN + offset + Vector3.new(0, 2, 0), character).Name = "Head"
		Instance.new("Humanoid").Parent = character
		character.PrimaryPart = root
		character.Parent = workspace
		local attributes = {}
		return {
			Name = name,
			Character = character,
			SetAttribute = function(_, key, value) attributes[key] = value end,
			GetAttribute = function(_, key) return attributes[key] end,
		}
	end

	local function safeModel()
		local model = Instance.new("Model")
		model.Name = "StorageSafe"
		for i = 1, 3 do
			local p = part(ORIGIN + Vector3.new(i, 0, 20), model)
			local emitter = Instance.new("ParticleEmitter")
			emitter.Rate = 0
			emitter.Parent = p
		end
		Instance.new("Highlight").Parent = model
		model.Parent = workspace
		return model
	end

	local function setup()
		local rig = { clock = { t = 0 }, toasts = {}, refusals = {}, carrying = {}, safeDistances = {}, managerDistances = {} }
		local now = function() return rig.clock.t end
		rig.bank = BankInstance.new({ config = Config, now = now })
		local net = { Toast = function(_, player, message) table.insert(rig.toasts, { player, message }) end }
		rig.door = { opened = {}, isOpen = false }
		function rig.door:Open(player)
			if self.isOpen then return false end
			self.isOpen = true
			table.insert(self.opened, player)
			return true
		end
		local handle = part(ORIGIN)
		rig.useKeyPrompt = Instance.new("ProximityPrompt")
		rig.useKeyPrompt.MaxActivationDistance = 10
		rig.useKeyPrompt.Enabled = false
		rig.useKeyPrompt.Parent = handle
		local safePrompt = Instance.new("ProximityPrompt")
		safePrompt.HoldDuration = SAFE_HOLD
		safePrompt.MaxActivationDistance = 10

		local managerModel = Instance.new("Model")
		managerModel.Name = "Manager"
		local managerRoot = part(ORIGIN + Vector3.new(5, 0, 0), managerModel)
		managerRoot.Name = "HumanoidRootPart"
		Instance.new("Humanoid").Parent = managerModel
		managerModel.PrimaryPart = managerRoot
		managerModel.Parent = workspace
		local escape = part(ORIGIN + Vector3.new(100, 0, 0))

		rig.layer = SlowFoodsKey.new({
			bank = rig.bank,
			net = net,
			carryState = { IsCarrying = function(_, player) return rig.carrying[player] == true end },
			notifyRefused = function(player, reason) table.insert(rig.refusals, { player, reason }) end,
			door = rig.door,
			useKeyPrompt = rig.useKeyPrompt,
			safeModel = safeModel(),
			safePromptTemplate = safePrompt,
			safeAmount = Config.ManagerSafeAmount,
			measure = function(player) return rig.safeDistances[player] end,
			clock = now,
		})
		rig.manager = FleeingManager.new(managerModel, {
			bank = rig.bank,
			config = Config,
			escapePoint = escape,
			measure = function(player) return rig.managerDistances[player] end,
			onKeyTaken = function(player) rig.layer:Give(player) end,
			pathTo = function() end,
			clock = now,
		})
		-- SlowFoodsServer's order: the Manager, the door, then the layer and its safe.
		rig.bank:RegisterComponent(rig.manager)
		rig.bank:RegisterComponent(rig.layer)
		rig.bank:RegisterComponent(rig.layer.storageSafe)

		rig.p1 = makePlayer("Robber1", Vector3.new(0, 0, 3))
		rig.p2 = makePlayer("Robber2", Vector3.new(0, 0, -3))
		rig.bank:TryStart(rig.p1)
		rig.bank:AddParticipant(rig.p1)
		rig.bank:AddParticipant(rig.p2)
		rig.cleanup = function()
			local safe = rig.layer.storageSafe
			if safe._bounceTween then safe._bounceTween:Cancel() end
			rig.manager:Destroy()
			rig.layer:Destroy()
		end
		return rig
	end

	local function takeKey(rig, player)
		rig.managerDistances[player] = 5
		rig.manager:_onHoldBegan(player)
		rig.clock.t += Config.ManagerKeyHold
		rig.manager:_onPromptTriggered(player)
	end

	local function robSafe(rig, player)
		local safe = rig.layer.storageSafe
		safe:_onHoldBegan(player)
		rig.clock.t += SAFE_HOLD
		safe:_onPromptTriggered(player)
	end

	local function seal(rig)
		rig.clock.t += Config.effective("SessionDuration") + 1
		rig.bank:Step()
	end

	local function lastToast(rig, player)
		for i = #rig.toasts, 1, -1 do
			if rig.toasts[i][1] == player then return rig.toasts[i][2] end
		end
		return nil
	end

	suite:test("Take Key gives the key, Use Key opens the door, the storage safe pays 3000 over the cap through AddBonus", function(expect)
		local rig = setup()
		expect.truthy(rig.useKeyPrompt.Enabled, "Use Key shown from session start")
		takeKey(rig, rig.p1)
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), true, "key attribute set")
		expect.equal(lastToast(rig, rig.p1), "You took the manager's key.", "toast")
		expect.equal(rig.manager.state, "caught", "the Manager is caught")

		rig.layer:UseKey(rig.p1)
		expect.equal(rig.door.opened[1], rig.p1, "the key holder opened the door")
		expect.falsy(rig.useKeyPrompt.Enabled, "Use Key hidden once the door is open")

		rig.bank:TryAddDuffel(rig.p1, Config.DuffelCap)
		rig.safeDistances[rig.p1] = 0
		robSafe(rig, rig.p1)
		expect.equal(rig.bank:GetDuffel(rig.p1), Config.DuffelCap + Config.ManagerSafeAmount, "paid over the cap")
		expect.truthy(rig.layer.storageSafe.model:GetAttribute("Robbed"), "safe robbed")
		rig.cleanup()
	end)

	suite:test("without the key: Use Key and the safe say the key message, nothing opens or pays", function(expect)
		local rig = setup()
		takeKey(rig, rig.p1)
		rig.layer:UseKey(rig.p2)
		expect.equal(#rig.door.opened, 0, "door shut")
		expect.equal(lastToast(rig, rig.p2), SlowFoodsKey.NO_KEY_MESSAGE, "Use Key: key message")
		rig.safeDistances[rig.p2] = 0
		robSafe(rig, rig.p2)
		expect.equal(rig.bank:GetDuffel(rig.p2), 0, "no pay")
		expect.equal(lastToast(rig, rig.p2), SlowFoodsKey.NO_KEY_MESSAGE, "safe: key message")
		rig.cleanup()
	end)

	suite:test("a bystander's Use Key is told to join; a press from out of reach is ignored", function(expect)
		local rig = setup()
		local bystander = makePlayer("Bystander", Vector3.new(3, 0, 0))
		rig.layer:UseKey(bystander)
		expect.equal(rig.refusals[1] and rig.refusals[1][2], "not_participant", "told to join")
		takeKey(rig, rig.p1)
		rig.p1.Character:PivotTo(CFrame.new(ORIGIN + Vector3.new(0, 0, 40)))
		rig.layer:UseKey(rig.p1)
		expect.equal(#rig.door.opened, 0, "40 studs away: ignored")
		rig.cleanup()
	end)

	suite:test("Seal mid-chase pays nothing and leaves no key", function(expect)
		local rig = setup()
		expect.equal(rig.manager.state, "fleeing", "fleeing")
		seal(rig)
		expect.equal(rig.manager.state, "idle", "the Manager stops")
		expect.falsy(rig.useKeyPrompt.Enabled, "Use Key hidden")
		local ok = rig.manager:TryTakeKey(rig.p1)
		expect.falsy(ok, "no key after the Seal")
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), nil, "no key attribute")
		rig.safeDistances[rig.p1] = 0
		robSafe(rig, rig.p1)
		expect.equal(rig.bank:GetDuffel(rig.p1), 0, "no pay")
		expect.equal(#rig.door.opened, 0, "door shut")
		rig.cleanup()
	end)

	suite:test("Seal after the catch clears the key and pays nothing", function(expect)
		local rig = setup()
		takeKey(rig, rig.p1)
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), true, "key before the Seal")
		seal(rig)
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), nil, "key cleared")
		expect.falsy(rig.layer:HasKey(rig.p1), "no holder")
		expect.equal(rig.manager.state, "idle", "caught -> idle")
		rig.safeDistances[rig.p1] = 0
		robSafe(rig, rig.p1)
		rig.layer:UseKey(rig.p1)
		expect.equal(rig.bank:GetDuffel(rig.p1), 0, "no pay")
		expect.equal(#rig.door.opened, 0, "door shut")
		rig.cleanup()
	end)

	suite:test("Seal after the escape: no key was ever given, nothing paid", function(expect)
		local rig = setup()
		rig.manager:_escape()
		expect.equal(rig.manager.state, "escaped", "escaped")
		rig.managerDistances[rig.p1] = 5
		expect.falsy(rig.manager:TryTakeKey(rig.p1), "no key from an escaped Manager")
		rig.safeDistances[rig.p1] = 0
		robSafe(rig, rig.p1)
		expect.equal(rig.bank:GetDuffel(rig.p1), 0, "no pay before the Seal")
		seal(rig)
		expect.equal(rig.manager.state, "escaped", "still gone until Rearm")
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), nil, "no key")
		expect.equal(rig.bank:GetDuffel(rig.p1), 0, "no pay")
		rig.cleanup()
	end)

	suite:test("the storage safe refuses a carrier, an untimed or short hold, and a trigger out of reach", function(expect)
		local rig = setup()
		takeKey(rig, rig.p1)
		local safe = rig.layer.storageSafe
		local reach = safe._prompt.MaxActivationDistance + 6

		rig.carrying[rig.p1] = true
		rig.safeDistances[rig.p1] = 0
		robSafe(rig, rig.p1)
		local carrierPaid = rig.bank:GetDuffel(rig.p1)
		local carrierReason = rig.refusals[#rig.refusals] and rig.refusals[#rig.refusals][2]
		rig.carrying[rig.p1] = nil

		safe:_onPromptTriggered(rig.p1)
		local untimedPaid = rig.bank:GetDuffel(rig.p1)
		safe:_onHoldBegan(rig.p1)
		rig.clock.t += 1
		safe:_onPromptTriggered(rig.p1)
		local shortPaid = rig.bank:GetDuffel(rig.p1)

		rig.safeDistances[rig.p1] = reach + 0.5
		robSafe(rig, rig.p1)
		local farPaid = rig.bank:GetDuffel(rig.p1)

		rig.safeDistances[rig.p1] = reach
		robSafe(rig, rig.p1)
		expect.equal(carrierPaid, 0, "a carrier is refused")
		expect.equal(carrierReason, "carrying_supplies", "told to drop the carry")
		expect.equal(untimedPaid, 0, "a trigger with no hold the server saw is refused")
		expect.equal(shortPaid, 0, "1 s of an 8 s hold is refused")
		expect.equal(farPaid, 0, "out of reach is refused")
		expect.equal(rig.bank:GetDuffel(rig.p1), Config.ManagerSafeAmount, "a full hold within reach pays")
		rig.cleanup()
	end)

	suite:test("the key holder's death or leave clears the key", function(expect)
		local rig = setup()
		takeKey(rig, rig.p1)
		-- A humanoid on an anchored root never dies (measured: Health 0 and ChangeState(Dead) fire no Died); a
		-- loose, server-owned body does, within a frame.
		local character = rig.p1.Character
		local root, head = character:FindFirstChild("HumanoidRootPart"), character:FindFirstChild("Head")
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, head
		weld.Parent = root
		root.Anchored, head.Anchored = false, false
		pcall(function() root:SetNetworkOwner(nil) end)
		task.wait(0.1)
		character:FindFirstChildOfClass("Humanoid").Health = 0
		local started = os.clock()
		while rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE) ~= nil and os.clock() - started < 1 do task.wait() end
		expect.equal(rig.p1:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), nil, "cleared on death")
		expect.falsy(rig.layer:HasKey(rig.p1), "no holder after the death")
		rig.layer:Give(rig.p2)
		rig.layer:Forget(rig.p2)
		expect.equal(rig.p2:GetAttribute(SlowFoodsKey.KEY_ATTRIBUTE), nil, "cleared on leave")
		expect.falsy(rig.layer:HasKey(rig.p2), "no holder after the leave")
		rig.cleanup()
	end)

	return suite:run()
end
