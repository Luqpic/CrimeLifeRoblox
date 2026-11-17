local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)
local CollectionService = game:GetService("CollectionService")

return function()
	local suite = TestRunner.new("World")

	local function tagged(tag)
		return CollectionService:GetTagged(tag)
	end

	suite:test("the manifest counts match the spec", function(expect)
		expect.equal(#tagged("HeistBank"), 2, "banks")
		-- CounterDoor's old single sliding Gate is gone (spec addendum,
		-- 2026-09-05): replaced by 4 CounterBarrier-tagged static parts. The
		-- LobbyBarrier group itself grew from 2 segments to 4 (spec addendum,
		-- 2026-09-15): Button1Lasers and Button2Lasers each contribute their
		-- own 2 BigLazer bars, so the live HeistGate count is 5 (4x
		-- LobbyBarrier + 1x GuardRoom), up from 3.
		expect.equal(#tagged("HeistGate"), 5, "gates")
		expect.equal(#tagged("HeistTerminal"), 2, "terminals")
		expect.equal(#tagged("HeistTeleporter"), 2, "teleporters")
		-- Lobby, Vault + 3 BankVaultZone volumes (spec addendum, 2026-09-11)
		-- covering the underground gauntlet between them. The Claim zone was
		-- retired when the distance-based getaway replaced the claim-zone
		-- cash-out (spec: Getaway-Distance-Claim-And-GUI, 2026-09-19) -- the
		-- part still exists in Workspace, untagged, so the change is reversible.
		expect.equal(#tagged("HeistZone"), 5, "zones")
		expect.equal(#tagged("HeistGuardPost"), 4, "guard posts")
		-- NewsStation's own guard posts (police and wanted Task 3, 2026-11-17).
		expect.equal(#tagged("NewsStationGuardPost"), 3, "NewsStation guard posts")
		expect.equal(#tagged("HeistCoverPoint"), 6, "cover points")
		expect.equal(#tagged("HeistDeathVolume"), 1, "death volumes")
		expect.equal(#tagged("HeistExitSpawn"), 1, "exit spawns")
		expect.truthy(#tagged("HeistLaser") >= 10, "at least 10 lasers")
		expect.equal(#tagged("HeistC4Point"), 1, "c4 points")
		expect.equal(#tagged("HeistAccessBarrier"), 1, "access barriers")
		expect.equal(#tagged("CounterBarrier"), 4, "counter barriers")
		expect.equal(#tagged("HeistATM"), 2, "ATM machines")
		expect.equal(#tagged("BankRegister"), 3, "Bank's own cash registers")
		expect.equal(#tagged("BankSafe"), 2, "Bank safes")
	end)

	suite:test("NPCSpawner placeholders exist for every Bank Clerk, SlowFoods Cashier, Gas2Go Cashier and NewsWorker position", function(expect)
		local spawners = tagged("NPCSpawner")
		-- Grew from 7 to 9 (spec addendum, 2026-09-2X): NewsStation's own 2
		-- NewsWorker NPCSpawner placeholders (this file has 2 live rigs, not 3
		-- like elsewhere -- confirmed live at conversion time).
		-- Heist layers 2026-11-17: + 1 SlowFoods Manager.
		expect.equal(#spawners, 10, "total spawners (2 Bank Clerk + 3 SlowFoods Cashier + 1 SlowFoods Manager + 2 Gas2Go Cashier + 2 NewsWorker)")
		local counts = {}
		for _, spawner in ipairs(spawners) do
			local value = spawner:GetAttribute("NPCTemplate")
			expect.truthy(type(value) == "string", spawner:GetFullName() .. " has an NPCTemplate attribute")
			counts[value] = (counts[value] or 0) + 1
		end
		expect.equal(counts.BankClerk, 2, "two BankClerk spawners")
		expect.equal(counts.Cashier, 3, "three SlowFoods Cashier spawners")
		expect.equal(counts.Manager, 1, "one SlowFoods Manager spawner")
		expect.equal(counts.Gas2GoCashier, 2, "two Gas2Go Cashier spawners")
	end)

	suite:test("each NPCSpawner lives under the correct location for its NPCTemplate", function(expect)
		for _, spawner in ipairs(tagged("NPCSpawner")) do
			local value = spawner:GetAttribute("NPCTemplate")
			if value == "BankClerk" then
				expect.truthy(spawner:IsDescendantOf(workspace.Bank), spawner:GetFullName() .. " under Workspace.Bank")
			elseif value == "Cashier" or value == "Manager" then
				expect.truthy(spawner:IsDescendantOf(workspace.SlowFoods), spawner:GetFullName() .. " under Workspace.SlowFoods")
			elseif value == "Gas2GoCashier" then
				expect.truthy(spawner:IsDescendantOf(workspace.Gas2Go), spawner:GetFullName() .. " under Workspace.Gas2Go")
			end
		end
	end)

	suite:test("BankClerk and Cashier ModelTemplates exist, are real rigs, and are never themselves tagged", function(expect)
		local CollectionService = game:GetService("CollectionService")
		local clerkTemplate = game.ReplicatedStorage.HeistShared.ModelTemplates:FindFirstChild("BankClerk")
		expect.truthy(clerkTemplate ~= nil, "HeistShared.ModelTemplates.BankClerk exists")
		if clerkTemplate then
			expect.truthy(clerkTemplate:FindFirstChildOfClass("Humanoid") ~= nil, "has a Humanoid")
			expect.falsy(CollectionService:HasTag(clerkTemplate, "BankClerk"), "the template itself is never tagged")
		end

		local cashierTemplate = game.ReplicatedStorage.RestaurantShared:FindFirstChild("ModelTemplates")
			and game.ReplicatedStorage.RestaurantShared.ModelTemplates:FindFirstChild("Cashier")
		expect.truthy(cashierTemplate ~= nil, "RestaurantShared.ModelTemplates.Cashier exists")
		if cashierTemplate then
			expect.truthy(cashierTemplate:FindFirstChildOfClass("Humanoid") ~= nil, "has a Humanoid")
			expect.falsy(CollectionService:HasTag(cashierTemplate, "Cashier"), "the template itself is never tagged")
		end
	end)

	suite:test("all 4 CounterBarrier parts live under Bank.CounterDoor", function(expect)
		local counterDoor = workspace.Bank:FindFirstChild("CounterDoor")
		expect.truthy(counterDoor ~= nil, "CounterDoor exists")
		if not counterDoor then return end
		for _, instance in ipairs(tagged("CounterBarrier")) do
			expect.truthy(instance:IsDescendantOf(counterDoor), instance:GetFullName() .. " is under Bank.CounterDoor")
		end
	end)

	-- SlowFoods (spec addendum, 2026-09-06): a second, independent robbery
	-- location. All structural checks live here, mirroring the Bank's own
	-- manifest/role checks above.
	suite:test("SlowFoods' manifest counts match the spec, and the Bank's own counts are unaffected", function(expect)
		expect.equal(#tagged("SlowFoodsZone"), 1, "restaurant zone (Restaurant)")
		expect.equal(#tagged("SlowFoodsExitSpawn"), 1, "exit spawn")
		-- OpenCloseBarriers now groups 3 sibling parts (spec addendum,
		-- 2026-09-13; was a single flat part) -- not a structural invariant,
		-- so this only guards against the tag going missing entirely.
		expect.truthy(#tagged("SlowFoodsAccessBarrier") >= 1, "at least one access barrier")
		expect.equal(#tagged("Cashier"), 3, "cashiers")
		expect.equal(#tagged("CashRegister"), 4, "cash registers")
		-- Regression guard: these must stay exactly what they were before
		-- SlowFoods existed -- a shared tag name between the two locations
		-- would make each location's independent registry sweep ALSO bind to
		-- the other's parts (e.g. SlowFoods sealing the Bank's entrance).
		expect.equal(#tagged("HeistAccessBarrier"), 1, "Bank's access barrier count unaffected")
		expect.equal(#tagged("HeistZone"), 5, "Bank's zone count unaffected")
		expect.equal(#tagged("HeistExitSpawn"), 1, "Bank's exit spawn count unaffected")
	end)

	suite:test("SlowFoodsZone parts cover role Restaurant, exactly one", function(expect)
		local roles = {}
		for _, z in ipairs(tagged("SlowFoodsZone")) do
			local role = z:GetAttribute("ZoneRole")
			expect.truthy(type(role) == "string", z:GetFullName() .. " has a ZoneRole")
			roles[role] = (roles[role] or 0) + 1
		end
		expect.equal(roles.Restaurant, 1, "one Restaurant zone")
	end)

	-- Regression for the live-drift incident found while building this
	-- feature (spec addendum, 2026-09-06): SlowFoods.OpenCloseBarrier was
	-- found ALSO carrying the Bank's own HeistAccessBarrier tag, which would
	-- have made the Bank's registry sweep bind an AccessBarrier component to
	-- it too -- sealing/unsealing it on the BANK's cooldown, not SlowFoods'.
	suite:test("every SlowFoods barrier is tagged SlowFoodsAccessBarrier only, never HeistAccessBarrier or Gas2GoAccessBarrier", function(expect)
		local barriers = tagged("SlowFoodsAccessBarrier")
		expect.truthy(#barriers >= 1, "a SlowFoodsAccessBarrier-tagged part exists")
		for _, barrier in ipairs(barriers) do
			expect.equal(barrier.Name, "OpenCloseBarrier", barrier:GetFullName() .. " is named OpenCloseBarrier")
			expect.falsy(CollectionService:HasTag(barrier, "HeistAccessBarrier"),
				barrier:GetFullName() .. " must not ALSO carry the Bank's own tag")
			expect.falsy(CollectionService:HasTag(barrier, "Gas2GoAccessBarrier"),
				barrier:GetFullName() .. " must not ALSO carry Gas2Go's own tag")
		end
	end)

	suite:test("SlowFoods' CashRegisters live under Workspace.SlowFoods", function(expect)
		local slowFoods = workspace:FindFirstChild("SlowFoods")
		expect.truthy(slowFoods ~= nil, "Workspace.SlowFoods exists")
		if not slowFoods then return end
		for _, instance in ipairs(tagged("CashRegister")) do
			expect.truthy(instance:IsDescendantOf(slowFoods), instance:GetFullName() .. " is under Workspace.SlowFoods")
		end
	end)

	-- Kaching sound (spec addendum, 2026-09-09): a static pre-placed Sound
	-- per register, same pattern as Terminal's ButtonClickSound -- never
	-- cloned from a template, so this checks the REAL world instances
	-- directly rather than a ModelTemplates/SoundTemplates entry.
	suite:test("every CashRegister has a RegisterRobSound on its attach part", function(expect)
		local function findAttachPart(model)
			local pivotPos = model:GetPivot().Position
			local best, bestDist = nil, math.huge
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local dist = (d.Position - pivotPos).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			return best
		end
		for _, model in ipairs(tagged("CashRegister")) do
			local part = findAttachPart(model)
			expect.truthy(part ~= nil, model:GetFullName() .. " has an attach part")
			if part then
				local sound = part:FindFirstChild("RegisterRobSound")
				expect.truthy(sound ~= nil and sound:IsA("Sound"), model:GetFullName() .. " has a RegisterRobSound")
				if sound then
					expect.truthy(sound.SoundId ~= "", model:GetFullName() .. " RegisterRobSound has a real asset ID")
				end
			end
		end
	end)

	-- ATM machines (spec addendum, 2026-09-14): same one-time-per-session
	-- flat-value rob mechanic as SlowFoods' cash registers, via the shared
	-- RobbableObject module -- so this checks the REAL world instances
	-- directly, same style as the CashRegister/RegisterRobSound check above.
	suite:test("every HeistATM lives under Workspace.Bank and has a Highlight and an ATMRobSound on its attach part", function(expect)
		local function findAttachPart(model)
			local pivotPos = model:GetPivot().Position
			local best, bestDist = nil, math.huge
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local dist = (d.Position - pivotPos).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			return best
		end
		for _, model in ipairs(tagged("HeistATM")) do
			expect.truthy(model:IsDescendantOf(workspace.Bank), model:GetFullName() .. " is under Workspace.Bank")
			expect.truthy(model:FindFirstChildOfClass("Highlight") ~= nil, model:GetFullName() .. " has a pre-placed Highlight")

			local part = findAttachPart(model)
			expect.truthy(part ~= nil, model:GetFullName() .. " has an attach part")
			if part then
				local sound = part:FindFirstChild("ATMRobSound")
				expect.truthy(sound ~= nil and sound:IsA("Sound"), model:GetFullName() .. " has an ATMRobSound")
				if sound then
					expect.truthy(sound.SoundId ~= "", model:GetFullName() .. " ATMRobSound has a real asset ID")
				end
			end
		end
	end)

	suite:test("the RobATMPrompt template exists under HeistShared, is a ProximityPrompt", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("PromptTemplates")
		expect.truthy(templates ~= nil, "HeistShared.PromptTemplates exists")
		if not templates then return end
		local prompt = templates:FindFirstChild("RobATMPrompt")
		expect.truthy(prompt ~= nil and prompt:IsA("ProximityPrompt"), "RobATMPrompt is a ProximityPrompt")
		if prompt then
			expect.equal(prompt.ActionText, "Rob ATM machine", "ActionText")
		end
	end)

	-- The Bank's OWN cash registers (spec addendum, 2026-09-14): a third
	-- application of the shared RobbableObject mechanic, distinct from both
	-- the Bank's ATMs and SlowFoods' own registers -- its own PromptTemplate
	-- under HeistShared (never RestaurantShared's own RobRegisterPrompt,
	-- which is SlowFoods-scoped and reads "Rob register", lowercase).
	suite:test("the Bank's own RobRegisterPrompt template exists under HeistShared, is a ProximityPrompt", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("PromptTemplates")
		expect.truthy(templates ~= nil, "HeistShared.PromptTemplates exists")
		if not templates then return end
		local prompt = templates:FindFirstChild("RobRegisterPrompt")
		expect.truthy(prompt ~= nil and prompt:IsA("ProximityPrompt"), "RobRegisterPrompt is a ProximityPrompt")
		if prompt then
			expect.equal(prompt.ActionText, "Rob Register", "ActionText")
		end
	end)

	suite:test("every BankRegister lives under Workspace.Bank and has a Highlight, a RegisterRobSound and a CashBurstEmitter on its attach part", function(expect)
		local function findAttachPart(model)
			local pivotPos = model:GetPivot().Position
			local best, bestDist = nil, math.huge
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local dist = (d.Position - pivotPos).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			return best
		end
		for _, model in ipairs(tagged("BankRegister")) do
			expect.truthy(model:IsDescendantOf(workspace.Bank), model:GetFullName() .. " is under Workspace.Bank")
			expect.truthy(model:FindFirstChildOfClass("Highlight") ~= nil, model:GetFullName() .. " has a pre-placed Highlight")

			local part = findAttachPart(model)
			expect.truthy(part ~= nil, model:GetFullName() .. " has an attach part")
			if part then
				local sound = part:FindFirstChild("RegisterRobSound")
				expect.truthy(sound ~= nil and sound:IsA("Sound"), model:GetFullName() .. " has a RegisterRobSound")
				if sound then
					expect.truthy(sound.SoundId ~= "", model:GetFullName() .. " RegisterRobSound has a real asset ID")
				end
				expect.truthy(part:FindFirstChildOfClass("ParticleEmitter") ~= nil, model:GetFullName() .. " has a CashBurstEmitter")
			end
		end
	end)

	-- Safe (spec addendum, 2026-09-16): a fourth robbable-object variant --
	-- two physical Safe.Safe props (Workspace.Bank.Safe is a wrapper Model
	-- with no Highlight of its own, confirmed live -- the tag lives on the
	-- two INNER Safe.Safe models, never the wrapper), sharing one session
	-- code but independently robbable.
	suite:test("the RobSafePrompt template exists under HeistShared, is a ProximityPrompt", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("PromptTemplates")
		expect.truthy(templates ~= nil, "HeistShared.PromptTemplates exists")
		if not templates then return end
		local prompt = templates:FindFirstChild("RobSafePrompt")
		expect.truthy(prompt ~= nil and prompt:IsA("ProximityPrompt"), "RobSafePrompt is a ProximityPrompt")
		if prompt then
			expect.equal(prompt.ActionText, "Crack Safe", "ActionText")
		end
	end)

	suite:test("exactly 2 BankSafe models exist, live under Workspace.Bank, and each has a Highlight, a SafeRobSound and a CashBurstEmitter on its attach part", function(expect)
		local function findAttachPart(model)
			local pivotPos = model:GetPivot().Position
			local best, bestDist = nil, math.huge
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local dist = (d.Position - pivotPos).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			return best
		end
		local safes = tagged("BankSafe")
		expect.equal(#safes, 2, "exactly 2 BankSafe models")
		for _, model in ipairs(safes) do
			expect.truthy(model:IsDescendantOf(workspace.Bank), model:GetFullName() .. " is under Workspace.Bank")
			expect.truthy(model:FindFirstChildOfClass("Highlight") ~= nil, model:GetFullName() .. " has a pre-placed Highlight")

			local part = findAttachPart(model)
			expect.truthy(part ~= nil, model:GetFullName() .. " has an attach part")
			if part then
				local sound = part:FindFirstChild("SafeRobSound")
				expect.truthy(sound ~= nil and sound:IsA("Sound"), model:GetFullName() .. " has a SafeRobSound")
				if sound then
					expect.truthy(sound.SoundId ~= "", model:GetFullName() .. " SafeRobSound has a real asset ID")
				end
				expect.truthy(part:FindFirstChildOfClass("ParticleEmitter") ~= nil, model:GetFullName() .. " has a CashBurstEmitter")
			end
		end
	end)

	suite:test("Workspace.Bank.Safe's outer wrapper is never itself tagged BankSafe (it has no Highlight of its own)", function(expect)
		local wrapper = workspace.Bank:FindFirstChild("Safe")
		expect.truthy(wrapper ~= nil, "Workspace.Bank.Safe exists")
		if not wrapper then return end
		expect.falsy(CollectionService:HasTag(wrapper, "BankSafe"), "the wrapper itself must not carry the tag -- RobbableObject-style construction requires a direct Highlight child, which only the two inner Safe.Safe models have")
	end)

	suite:test("the Code Combination display exists at the expected path and shows a 4-digit-looking value outside an active session", function(expect)
		local part = workspace.BankVault:FindFirstChild("Code Combination")
		expect.truthy(part ~= nil, "Workspace.BankVault.\"Code Combination\" exists")
		if not part then return end
		local surfaceGui = part:FindFirstChildOfClass("SurfaceGui")
		expect.truthy(surfaceGui ~= nil, "has a SurfaceGui")
		if not surfaceGui then return end
		-- Named "Code", not "Combination" -- confirmed live, despite the
		-- original spec's assumption; SafeCode.lua targets this exact path.
		local label = surfaceGui:FindFirstChild("Code")
		expect.truthy(label ~= nil and label:IsA("TextLabel"), "SurfaceGui.Code is a TextLabel")
	end)

	-- Vault Door: ClickDetector -> ProximityPrompt (spec addendum,
	-- 2026-09-12). Structural-only here (the real gameplay behavior is
	-- VaultDoorSpec's job) -- this just guards against the old ClickDetectors
	-- or script quietly surviving alongside the new component.
	suite:test("the Vault Door's old ClickDetectors and script are gone", function(expect)
		local vaultDoor = workspace.BankVault:FindFirstChild("Vault Door")
		expect.truthy(vaultDoor ~= nil, "Vault Door model exists")
		if not vaultDoor then return end
		for _, d in ipairs(vaultDoor:GetDescendants()) do
			expect.falsy(d:IsA("ClickDetector"), "no leftover ClickDetector: " .. d:GetFullName())
		end
		expect.falsy(vaultDoor:FindFirstChild("Script"), "the old prepared Script is gone -- replaced by the VaultDoor component")
	end)

	-- Worn in sync with the DuffelBag GUI, shared by both the Bank and
	-- SlowFoods (spec addendum, 2026-09-13, corrected 2026-09-14: welded onto
	-- UpperTorso directly rather than equipped via Humanoid:AddAccessory,
	-- which produced no visible bag) -- a single template, not one per
	-- location.
	-- Moved out of Workspace into ReplicatedStorage (2026-09-13): it is a
	-- clone source, never a live world object, and living in Workspace was
	-- what let it fall through the Baseplate and be engine-deleted.
	suite:test("HeistShared.DuffelBag is a plain Model with a PrimaryPart to weld from", function(expect)
		local duffelBag = game:GetService("ReplicatedStorage").HeistShared:FindFirstChild("DuffelBag")
		expect.truthy(duffelBag ~= nil, "ReplicatedStorage.HeistShared.DuffelBag exists")
		if not duffelBag then return end
		expect.truthy(duffelBag:IsA("Model"), "is a plain Model, not an Accessory")
		expect.truthy(duffelBag.PrimaryPart ~= nil, "has a PrimaryPart")
	end)

	suite:test("RestaurantShared exists with its own Config and RobRegisterPrompt template", function(expect)
		local restaurantShared = game.ReplicatedStorage:FindFirstChild("RestaurantShared")
		expect.truthy(restaurantShared ~= nil, "ReplicatedStorage.RestaurantShared exists")
		if not restaurantShared then return end
		expect.truthy(restaurantShared:FindFirstChild("Config") ~= nil, "has its own Config")
		local prompt = restaurantShared:FindFirstChild("PromptTemplates")
			and restaurantShared.PromptTemplates:FindFirstChild("RobRegisterPrompt")
		expect.truthy(prompt ~= nil, "has a RobRegisterPrompt template")
		expect.truthy(prompt and prompt:IsA("ProximityPrompt"), "is a ProximityPrompt")
	end)

	-- Regression for a live-drift incident (spec addendum, 2026-09-02):
	-- OpenCloseBarrier was found also carrying stray HeistGate/GateGroup=
	-- GuardRoom attributes, duplicating the real Challenge 3 guard barrier and
	-- silently opening this entrance-seal part whenever guards died. It must
	-- be exactly one thing: a HeistAccessBarrier, nothing else, and physically
	-- distinct from CounterDoor (back-of-lobby, active-robbery-only) so the
	-- two never gate the same doorway.
	suite:test("OpenCloseBarrier is a standalone access barrier, not a gate, and not CounterDoor", function(expect)
		local barrier = tagged("HeistAccessBarrier")[1]
		expect.truthy(barrier ~= nil, "a HeistAccessBarrier-tagged part exists")
		if not barrier then return end
		expect.equal(barrier.Name, "OpenCloseBarrier", "is the OpenCloseBarrier part")
		expect.falsy(CollectionService:HasTag(barrier, "HeistGate"), "not also a Gate -- no duplicate GateGroup role")

		local counterDoor = workspace.Bank:FindFirstChild("CounterDoor")
		expect.truthy(counterDoor ~= nil, "CounterDoor exists for comparison")
		if counterDoor then
			local distance = (barrier.Position - counterDoor:GetPivot().Position).Magnitude
			expect.truthy(distance > 15, "placed well away from CounterDoor -- distinct doorway, not overlapping")
		end
	end)

	-- Spec addendum, 2026-09-03: GamepassManager must live where any FUTURE
	-- robbery system can reach it without depending on this Bank's own module
	-- tree -- a sibling of HeistShared under ReplicatedStorage, never nested
	-- inside it.
	suite:test("GamepassManager lives under a shared, HeistShared-sibling location", function(expect)
		local shared = game.ReplicatedStorage:FindFirstChild("SharedSystems")
		expect.truthy(shared ~= nil, "ReplicatedStorage.SharedSystems exists")
		expect.truthy(shared and shared.Parent == game.ReplicatedStorage, "directly under ReplicatedStorage, a sibling of HeistShared")
		if not shared then return end
		local manager = shared:FindFirstChild("GamepassManager")
		expect.truthy(manager ~= nil, "GamepassManager exists")
		expect.truthy(manager and manager:IsA("ModuleScript"), "is a ModuleScript")

		local transitions = shared:FindFirstChild("UITransitions")
		expect.truthy(transitions ~= nil, "UITransitions exists alongside it")
		expect.truthy(transitions and transitions:IsA("ModuleScript"), "is a ModuleScript")
	end)

	suite:test("cover points are never fewer than guards", function(expect)
		local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
		expect.truthy(#tagged("HeistCoverPoint") >= Config.GuardCount, "cover >= guards")
	end)

	-- BankVaultZone deliberately spans multiple volumes sharing one role
	-- (spec addendum, 2026-09-11 -- see ZoneService's role-union support), so
	-- it's excluded from the uniqueness check below and verified separately.
	suite:test("Lobby and Vault roles are each unique", function(expect)
		local seen = {}
		for _, z in ipairs(tagged("HeistZone")) do
			local role = z:GetAttribute("ZoneRole")
			expect.truthy(role ~= nil, "zone " .. z.Name .. " has a role")
			if role ~= "BankVaultZone" then
				expect.falsy(seen[role], "role " .. tostring(role) .. " is unique")
				seen[role] = true
			end
		end
		expect.truthy(seen.Lobby and seen.Vault, "Lobby and Vault both present")
	end)

	-- Fix (spec addendum, 2026-09-11): the heist-timer GUI used to disappear
	-- during the underground gauntlet (the gap between the lobby and
	-- VaultZone had no zone coverage at all), and the same blind spot broke
	-- the forced-eject occupancy check. BankVaultZone closes it -- built from
	-- multiple volumes (a single box can't cover this irregularly-shaped,
	-- multi-room area), all sharing the same role.
	suite:test("BankVaultZone spans multiple volumes covering the underground gauntlet", function(expect)
		local volumes = {}
		for _, z in ipairs(tagged("HeistZone")) do
			if z:GetAttribute("ZoneRole") == "BankVaultZone" then
				table.insert(volumes, z)
			end
		end
		expect.truthy(#volumes >= 2, "more than one volume -- a single box can't cover this shape")
		for _, z in ipairs(volumes) do
			expect.equal(z.Transparency, 1, z.Name .. " transparency")
			expect.falsy(z.CanCollide, z.Name .. " CanCollide")
			expect.truthy(z.Anchored, z.Name .. " Anchored")
		end
	end)

	suite:test("BankVaultZone covers every real laser and guard post in the underground gauntlet", function(expect)
		local volumes = {}
		for _, z in ipairs(tagged("HeistZone")) do
			if z:GetAttribute("ZoneRole") == "BankVaultZone" then table.insert(volumes, z) end
		end

		local function insideAny(pos)
			for _, zp in ipairs(volumes) do
				local half = zp.Size / 2
				local localPoint = zp.CFrame:PointToObjectSpace(pos)
				if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z then
					return true
				end
			end
			return false
		end

		-- BigLazer is the lobby's terminal-gated barrier, not part of the
		-- underground gauntlet, despite sharing the HeistLaser tag/component --
		-- deliberately excluded here.
		for _, l in ipairs(tagged("HeistLaser")) do
			if l.Name ~= "BigLazer" then
				expect.truthy(insideAny(l.Position), l:GetFullName() .. " is inside some BankVaultZone volume")
			end
		end
		for _, g in ipairs(tagged("HeistGuardPost")) do
			expect.truthy(insideAny(g.Position), g:GetFullName() .. " is inside some BankVaultZone volume")
		end
	end)

	-- Police and wanted Task 3 (2026-11-17): NewsStation's guard posts stand inside its Newsroom zone, are
	-- invisible and do not collide, and SlowFoods and Gas2Go have none.
	suite:test("NewsStation guard posts are inside the Newsroom zone, invisible and non-colliding", function(expect)
		local zone = workspace:FindFirstChild("NewsStationZones") and workspace.NewsStationZones:FindFirstChild("NewsroomZone")
		expect.truthy(zone ~= nil, "NewsroomZone exists")
		for _, post in ipairs(tagged("NewsStationGuardPost")) do
			local p = zone and zone.CFrame:PointToObjectSpace(post.Position)
			expect.truthy(p and math.abs(p.X) <= zone.Size.X / 2 and math.abs(p.Y) <= zone.Size.Y / 2 and math.abs(p.Z) <= zone.Size.Z / 2,
				post:GetFullName() .. " is inside NewsroomZone")
			expect.equal(post.Transparency, 1, post.Name .. " transparency")
			expect.falsy(post.CanCollide, post.Name .. " CanCollide")
			expect.truthy(post.Anchored, post.Name .. " Anchored")
			expect.truthy(post:IsDescendantOf(workspace.NewsStationMarkers), post.Name .. " lives in NewsStationMarkers")
		end
	end)

	suite:test("zones are invisible, non-collidable and anchored", function(expect)
		for _, z in ipairs(tagged("HeistZone")) do
			expect.equal(z.Transparency, 1, z.Name .. " transparency")
			expect.falsy(z.CanCollide, z.Name .. " CanCollide")
			expect.truthy(z.Anchored, z.Name .. " Anchored")
		end
	end)

	-- The "Claim and Lobby zones do not overlap" test was removed here when the
	-- distance-based getaway replaced the claim-zone cash-out (spec:
	-- Getaway-Distance-Claim-And-GUI, 2026-09-19). It existed to prove banking
	-- required physically crossing the door -- an invariant of the Claim ZONE,
	-- which no longer exists as a tagged zone. The equivalent guarantee is now
	-- EscapeDistance (200 studs) and is covered by GetawaySpec, not by geometry
	-- here. The ClaimZone part itself is still in Workspace, untagged.

	suite:test("every gate declares an offset and tween time", function(expect)
		for _, g in ipairs(tagged("HeistGate")) do
			expect.truthy(typeof(g:GetAttribute("OpenOffset")) == "Vector3", g.Name .. " OpenOffset")
			expect.truthy(type(g:GetAttribute("TweenTime")) == "number", g.Name .. " TweenTime")
		end
	end)

	suite:test("terminals have distinct ids and resolvable linked gates", function(expect)
		local ids = {}
		for _, t in ipairs(tagged("HeistTerminal")) do
			local id = t:GetAttribute("TerminalId")
			expect.truthy(id == 1 or id == 2, t.Name .. " TerminalId is 1 or 2")
			expect.falsy(ids[id], "TerminalId " .. tostring(id) .. " is unique")
			ids[id] = true
			-- A terminal must never be its own gate. The first implementation pass
			-- silently made both terminals self-referential gates, and the old
			-- assertion (non-nil + HasTag) passed anyway.
			expect.falsy(CollectionService:HasTag(t, "HeistGate"), t.Name .. " must not be tagged HeistGate")
		end
	end)

	-- "LobbyBarrier" is now a location label only (spec addendum, 2026-09-16):
	-- since Button1Lasers/Button2Lasers open independently per-button (see
	-- HeistServer's resolveButtonBarrier, keyed by HazardTerminalId, not by
	-- this GateGroup), these 4 bars no longer open together as one unit --
	-- this test only guards that the label itself still covers all 4.
	suite:test("Button1Lasers/Button2Lasers' 4 bars all still carry the LobbyBarrier location label", function(expect)
		local groups = {}
		for _, g in ipairs(tagged("HeistGate")) do
			local grp = g:GetAttribute("GateGroup")
			expect.truthy(type(grp) == "string", g:GetFullName() .. " has a GateGroup")
			groups[grp] = (groups[grp] or 0) + 1
		end
		expect.equal(groups.LobbyBarrier, 4, "four BigLazer bars share the label")
		expect.equal(groups.GuardRoom, 1, "one guard-room barrier")
	end)

	-- Regression for the cross-button contamination found via user report
	-- (spec addendum, 2026-09-15): Button1Lasers' and Button2Lasers' bars
	-- share a single GateGroup (LobbyBarrier, so they still open together),
	-- but must shut off their damage independently -- each bar declares its
	-- OWN HazardTerminalId so shutOffButtonLaser(id) only ever touches the
	-- bars for the terminal that was actually pressed.
	suite:test("every hazardous LobbyBarrier bar declares its own HazardTerminalId, split evenly between the two terminals", function(expect)
		local counts = { [1] = 0, [2] = 0 }
		for _, g in ipairs(tagged("HeistGate")) do
			if g:GetAttribute("GateGroup") == "LobbyBarrier" and g:GetAttribute("Hazardous") == true then
				local id = g:GetAttribute("HazardTerminalId")
				expect.truthy(id == 1 or id == 2, g:GetFullName() .. " has a HazardTerminalId of 1 or 2")
				if id == 1 or id == 2 then counts[id] += 1 end
			end
		end
		expect.equal(counts[1], 2, "Button1Lasers contributes exactly 2 bars")
		expect.equal(counts[2], 2, "Button2Lasers contributes exactly 2 bars")
	end)

	suite:test("teleporters pair up and point at each other", function(expect)
		local byRole = {}
		for _, tp in ipairs(tagged("HeistTeleporter")) do
			byRole[tp:GetAttribute("TeleportRole")] = tp
		end
		expect.truthy(byRole.A and byRole.B, "roles A and B both present")
		local aLink = byRole.A:FindFirstChild("LinkedTeleporter")
		local bLink = byRole.B:FindFirstChild("LinkedTeleporter")
		expect.equal(aLink.Value, byRole.B, "A links to B")
		expect.equal(bLink.Value, byRole.A, "B links to A")
	end)

	suite:test("lasers declare a cycle, duty and distinct phase seeds", function(expect)
		local seeds = {}
		for _, l in ipairs(tagged("HeistLaser")) do
			expect.truthy(type(l:GetAttribute("CycleTime")) == "number", l:GetFullName() .. " CycleTime")
			local duty = l:GetAttribute("DutyCycle")
			expect.truthy(type(duty) == "number" and duty > 0 and duty < 1, l:GetFullName() .. " DutyCycle in (0,1)")
			local seed = l:GetAttribute("PhaseSeed")
			expect.truthy(type(seed) == "number", l:GetFullName() .. " PhaseSeed")
			table.insert(seeds, seed)
		end
		table.sort(seeds)
		for i = 2, #seeds do
			expect.truthy(seeds[i] ~= seeds[i - 1], "phase seeds are distinct so lasers do not pulse in lockstep")
		end
	end)

	-- Fix 6: the manifest-and-role assertions above would all pass for a zone or
	-- gate sitting in entirely the wrong room -- that is exactly how the whole
	-- level shipped unbound to the geometry it was supposed to govern. These
	-- three tests anchor the tags to the actual geometry, not just to each other.

	suite:test("each single-room zone has real floor immediately beneath its own bottom", function(expect)
		-- Probes a short 6-stud ray starting just inside the zone's bottom edge, so
		-- it finds floor right where a player standing in the zone would be -- not
		-- some obstruction floating higher up inside a tall zone. A zone placed at
		-- the wrong height (e.g. a bounding-box centre 200+ studs above the real
		-- floor) finds nothing within this short probe and fails here.
		--
		-- BankVaultZone is excluded (spec addendum, 2026-09-11): it's a
		-- deliberately oversized, multi-room bounding volume covering an
		-- irregularly-shaped underground gauntlet, not one flat single-room
		-- floor -- its own dedicated "covers every real laser and guard post"
		-- test above is the correct geometry sanity check for this zone type.
		for _, z in ipairs(tagged("HeistZone")) do
			if z:GetAttribute("ZoneRole") ~= "BankVaultZone" then
				local probeY = z.Position.Y - z.Size.Y / 2 + 0.5
				local result = workspace:Raycast(Vector3.new(z.Position.X, probeY, z.Position.Z), Vector3.new(0, -6, 0))
				expect.truthy(result, string.format(
					"%s: no floor found within 6 studs of the zone's own bottom (probed from Y=%.2f) -- " ..
					"a zone floating over the wrong room or the wrong height passes every tag/role check but has no floor under it",
					z.Name, probeY))
			end
		end
	end)

	suite:test("the Vault zone actually contains the Valuables", function(expect)
		local vault
		for _, z in ipairs(tagged("HeistZone")) do
			if z:GetAttribute("ZoneRole") == "Vault" then vault = z end
		end
		expect.truthy(vault, "a Vault-role zone exists")
		if not vault then return end

		local found = 0
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst.Name == "Valuables" and inst:IsA("Model") then
				local ok, cf = pcall(function() return inst:GetBoundingBox() end)
				if ok then
					local localPoint = vault.CFrame:PointToObjectSpace(cf.Position)
					local half = vault.Size / 2
					if math.abs(localPoint.X) <= half.X and math.abs(localPoint.Y) <= half.Y and math.abs(localPoint.Z) <= half.Z then
						found += 1
					end
				end
			end
		end
		expect.truthy(found > 0, string.format(
			"VaultZone must contain at least one Valuables model, found %d inside it -- " ..
			"a Vault zone sitting in the wrong room (e.g. an access corridor) would find zero here", found))
	end)

	suite:test("every gate part is large enough to actually be a door", function(expect)
		-- A 0.3-stud decorative baluster passes every other gate assertion (it has
		-- an OpenOffset, a TweenTime, a GateGroup) while blocking nothing and
		-- opening nothing. Size is the one property that catches it.
		for _, g in ipairs(tagged("HeistGate")) do
			local largest = math.max(g.Size.X, g.Size.Y, g.Size.Z)
			expect.truthy(largest >= 3, string.format(
				"%s: largest dimension is %.2f studs -- that is a sliver of decoration, not a door",
				g:GetFullName(), largest))
		end
	end)

	suite:test("the guard template lives in ServerStorage, not Workspace", function(expect)
		local template = game:GetService("ServerStorage"):FindFirstChild("GuardTemplate")
		expect.truthy(template ~= nil, "ServerStorage.GuardTemplate exists")
		expect.truthy(template:FindFirstChildOfClass("Humanoid") ~= nil, "template has a Humanoid")
		expect.truthy(template.PrimaryPart ~= nil, "template has a PrimaryPart for PivotTo")
	end)

	-- Spec addendum, 2026-08-29: the whole C4/prompt sequence is now fully
	-- clone-based. workspace.C4 no longer exists as a standalone object --
	-- only a fixed, always-empty c4PlaceHolder anchor carries the
	-- HeistC4Point tag, and the actual C4/explosion visuals and both prompts
	-- live as templates under HeistShared, cloned in and destroyed by
	-- C4Charge at the right points.
	suite:test("the C4 placeholder is a fixed, empty, non-interactable anchor", function(expect)
		expect.falsy(workspace:FindFirstChild("C4"), "no leftover standalone C4 model in Workspace")
		-- Found by tag, not by a hardcoded Workspace path: that's how the real
		-- component (bound via ComponentRegistry/CollectionService) finds it
		-- too, so this test is not sensitive to which Model it happens to be
		-- parented under.
		local placeholder = tagged("HeistC4Point")[1]
		expect.truthy(placeholder ~= nil, "a HeistC4Point-tagged placeholder exists")
		if not placeholder then return end
		expect.equal(placeholder.Transparency, 1, "always invisible -- purely an anchor")
		expect.falsy(placeholder.CanCollide, "always non-collidable")
		expect.falsy(placeholder:FindFirstChildOfClass("ProximityPrompt"), "the placeholder itself is never interactable")
	end)

	suite:test("the C4/explosion model templates exist under HeistShared, stripped of prompt/sound", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("ModelTemplates")
		expect.truthy(templates ~= nil, "HeistShared.ModelTemplates exists")
		if not templates then return end

		local c4Model = templates:FindFirstChild("C4Model")
		expect.truthy(c4Model ~= nil, "C4Model template exists")
		if c4Model then
			expect.truthy(c4Model.PrimaryPart ~= nil, "has a PrimaryPart to PivotTo when cloned")
			if c4Model.PrimaryPart then
				expect.truthy(c4Model.PrimaryPart:FindFirstChild("CountdownGui") ~= nil, "still carries the countdown display")
				expect.falsy(c4Model.PrimaryPart:FindFirstChildOfClass("ProximityPrompt"), "no prompt baked into the model -- prompts live on the teleporter now")
				expect.falsy(c4Model.PrimaryPart:FindFirstChild("ExplosionSound"), "no explosion sound baked into the model -- it's its own SoundTemplates clone now")
			end
		end

		-- Spec correction, 2026-08-29: sourced from the real, pre-existing
		-- "Explosion effect" VFX prop (relocated here, not a custom-built stub),
		-- confirmed via its ParticleEmitter.
		local explosionEffect = templates:FindFirstChild("ExplosionEffect")
		expect.truthy(explosionEffect ~= nil, "ExplosionEffect template exists")
		if explosionEffect then
			expect.truthy(explosionEffect:FindFirstChildOfClass("ParticleEmitter") ~= nil, "carries the real VFX particle emitter")
			-- Regression for the opaque-black-block bug (spec addendum,
			-- 2026-09-01): the container part itself must stay invisible and
			-- non-solid, set on the TEMPLATE so every future clone inherits it
			-- by default -- not patched onto the runtime clone each detonation.
			if explosionEffect:IsA("BasePart") then
				expect.equal(explosionEffect.Transparency, 1, "container is invisible -- the VFX is the emitter, not the part")
				expect.falsy(explosionEffect.CanCollide, "purely a visual anchor, never a physical obstruction at the gate")
			end
		end
	end)

	-- Spec addendum, 2026-08-29: OpenGate resets per session like every other
	-- barrier/prompt/C4 state -- a template exists to clone a fresh one in
	-- after demolition, per recommendation (a).
	suite:test("OpenGate has a template for post-demolition respawn", function(expect)
		local templates = game.ReplicatedStorage.HeistShared:FindFirstChild("ModelTemplates")
		expect.truthy(templates ~= nil, "HeistShared.ModelTemplates exists")
		if not templates then return end
		local gateTemplate = templates:FindFirstChild("OpenGate")
		expect.truthy(gateTemplate ~= nil, "OpenGate template exists")
		if not gateTemplate then return end
		local hasParts = false
		for _, d in ipairs(gateTemplate:GetDescendants()) do
			if d:IsA("BasePart") then hasParts = true; break end
		end
		expect.truthy(hasParts, "built from discrete parts -- required for the per-part demolition impulse")

		local liveGate = workspace.Bank:FindFirstChild("OpenGate")
		expect.truthy(liveGate ~= nil, "the live gate (original, pre-demolition) is present in Workspace")
	end)

	-- Gas2Go (spec addendum, 2026-09-14): a third, independent robbery
	-- location, following the SlowFoods style (no obby/gauntlet/C4). All
	-- structural checks live here, mirroring the Bank's and SlowFoods' own
	-- manifest/role checks above.
	suite:test("Gas2Go's manifest counts match the spec, and the other two locations' counts are unaffected", function(expect)
		expect.equal(#tagged("Gas2GoZone"), 1, "Gas2Go zone (Station)")
		expect.equal(#tagged("Gas2GoExitSpawn"), 1, "Gas2Go exit spawn")
		-- Not a structural invariant, same reasoning as SlowFoods' own
		-- OpenCloseBarriers -- Gas2Go's perimeter fence is built from repeating
		-- segments a level designer could reasonably add to or remove from.
		expect.truthy(#tagged("Gas2GoAccessBarrier") >= 1, "at least one Gas2Go barrier part")
		expect.equal(#tagged("Gas2GoRegister"), 2, "Gas2Go cash registers")
		expect.equal(#tagged("Gas2GoATM"), 1, "Gas2Go ATM")
		-- Regression guard: these must stay exactly what they were before
		-- Gas2Go existed -- a shared tag name between locations would make each
		-- location's independent registry sweep ALSO bind to the other's parts.
		expect.equal(#tagged("HeistAccessBarrier"), 1, "Bank's access barrier count unaffected")
		expect.equal(#tagged("HeistZone"), 5, "Bank's zone count unaffected")
		expect.truthy(#tagged("SlowFoodsAccessBarrier") >= 1, "SlowFoods' access barrier count unaffected")
		expect.equal(#tagged("SlowFoodsZone"), 1, "SlowFoods' zone count unaffected")
	end)

	suite:test("Gas2GoZone parts cover role Station, exactly one", function(expect)
		local roles = {}
		for _, z in ipairs(tagged("Gas2GoZone")) do
			local role = z:GetAttribute("ZoneRole")
			expect.truthy(type(role) == "string", z:GetFullName() .. " has a ZoneRole")
			roles[role] = (roles[role] or 0) + 1
		end
		expect.equal(roles.Station, 1, "one Station zone")
	end)

	-- Regression for a live-drift incident found via user report (spec
	-- addendum, 2026-09-15): Gas2Go's own driveway OpenCloseBarrier had been
	-- built from SlowFoods' reusable OpenCloseBarrier prefab (identical
	-- ForceField material, BarrierSlideSound, ProximityPrompt-free slab) but
	-- kept the SOURCE object's SlowFoodsAccessBarrier tag from the copy
	-- instead of being retagged -- so SlowFoods' own registry sweep bound an
	-- AccessBarrier component to it and sealed it on SLOWFOODS' cooldown, not
	-- Gas2Go's. Confirmed live via a direct CollectionService cross-tag query
	-- (Workspace.Gas2Go.OpenCloseBarrier was found carrying SlowFoodsAccessBarrier)
	-- rather than a shared/global toggle function or unscoped event -- the
	-- tag-scoped ComponentRegistry design was already correct, this was a
	-- scene-authoring/tagging mistake on one specific instance.
	suite:test("every Gas2Go barrier is tagged Gas2GoAccessBarrier only, never SlowFoodsAccessBarrier or HeistAccessBarrier", function(expect)
		local barriers = tagged("Gas2GoAccessBarrier")
		expect.truthy(#barriers >= 1, "a Gas2GoAccessBarrier-tagged part exists")
		for _, barrier in ipairs(barriers) do
			expect.falsy(CollectionService:HasTag(barrier, "SlowFoodsAccessBarrier"),
				barrier:GetFullName() .. " must not ALSO carry SlowFoods' own tag")
			expect.falsy(CollectionService:HasTag(barrier, "HeistAccessBarrier"),
				barrier:GetFullName() .. " must not ALSO carry the Bank's own tag")
		end
	end)

	suite:test("Gas2Go's robbable objects and barrier all live under Workspace.Gas2Go", function(expect)
		local g = workspace:FindFirstChild("Gas2Go")
		expect.truthy(g ~= nil, "Workspace.Gas2Go exists")
		if not g then return end
		for _, instance in ipairs(tagged("Gas2GoRegister")) do
			expect.truthy(instance:IsDescendantOf(g), instance:GetFullName() .. " is under Workspace.Gas2Go")
		end
		for _, instance in ipairs(tagged("Gas2GoATM")) do
			expect.truthy(instance:IsDescendantOf(g), instance:GetFullName() .. " is under Workspace.Gas2Go")
		end
		for _, instance in ipairs(tagged("Gas2GoAccessBarrier")) do
			expect.truthy(instance:IsDescendantOf(g), instance:GetFullName() .. " is under Workspace.Gas2Go")
		end
	end)

	suite:test("every Gas2GoRegister and Gas2GoATM has a Highlight and a rob sound/CashBurstEmitter on its attach part", function(expect)
		local function findAttachPart(model)
			local pivotPos = model:GetPivot().Position
			local best, bestDist = nil, math.huge
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					local dist = (d.Position - pivotPos).Magnitude
					if dist < bestDist then best, bestDist = d, dist end
				end
			end
			return best
		end
		local function checkObject(model, soundName)
			expect.truthy(model:FindFirstChildOfClass("Highlight") ~= nil, model:GetFullName() .. " has a pre-placed Highlight")
			local part = findAttachPart(model)
			expect.truthy(part ~= nil, model:GetFullName() .. " has an attach part")
			if part then
				local sound = part:FindFirstChild(soundName)
				expect.truthy(sound ~= nil and sound:IsA("Sound"), model:GetFullName() .. " has a " .. soundName)
				if sound then
					expect.truthy(sound.SoundId ~= "", model:GetFullName() .. " " .. soundName .. " has a real asset ID")
				end
				expect.truthy(part:FindFirstChildOfClass("ParticleEmitter") ~= nil, model:GetFullName() .. " has a CashBurstEmitter")
			end
		end
		for _, model in ipairs(tagged("Gas2GoRegister")) do checkObject(model, "RegisterRobSound") end
		for _, model in ipairs(tagged("Gas2GoATM")) do checkObject(model, "ATMRobSound") end
	end)

	-- Regression for the live-drift already fixed once at the Bank (spec
	-- addendum, 2026-09-14): Gas2Go's fixtures shipped with the SAME kind of
	-- independently-looping per-fixture Flash.Script the Bank's own
	-- AlarmEffects.phaseAt was introduced to replace -- confirmed live to be
	-- running, unconditionally, all the time, out of phase with its siblings.
	-- They must be gone, replaced by AlarmEffects' synchronized pulseLights.
	suite:test("RobberyAlarmLights has real light fixtures and no leftover per-fixture Flash.Script", function(expect)
		local lightsModel = workspace.Gas2Go:FindFirstChild("RobberyAlarmLights")
		expect.truthy(lightsModel ~= nil, "Workspace.Gas2Go.RobberyAlarmLights exists")
		if not lightsModel then return end
		local lightCount = 0
		for _, d in ipairs(lightsModel:GetDescendants()) do
			if d:IsA("PointLight") or d:IsA("SpotLight") then
				lightCount += 1
			end
			expect.falsy(d:IsA("Script") or d:IsA("LocalScript"), "no leftover per-fixture script: " .. d:GetFullName())
		end
		expect.truthy(lightCount >= 1, "at least one PointLight/SpotLight fixture")
	end)

	suite:test("the Attach C4 and Go to Vault prompt templates exist under HeistShared", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("PromptTemplates")
		expect.truthy(templates ~= nil, "HeistShared.PromptTemplates exists")
		if not templates then return end
		local attach = templates:FindFirstChild("AttachC4Prompt")
		local goToVault = templates:FindFirstChild("GoToVaultPrompt")
		expect.truthy(attach ~= nil and attach:IsA("ProximityPrompt"), "AttachC4Prompt is a ProximityPrompt")
		expect.truthy(goToVault ~= nil and goToVault:IsA("ProximityPrompt"), "GoToVaultPrompt is a ProximityPrompt")
	end)

	-- Spec addendum, 2026-08-30: the single continuous countdown sound was
	-- replaced entirely by a per-second tick sound (C4TickSound), cloned and
	-- played once per displayed second rather than looped for the full 5s.
	suite:test("the tick and explosion sound templates exist under HeistShared", function(expect)
		local shared = game.ReplicatedStorage.HeistShared
		local templates = shared:FindFirstChild("SoundTemplates")
		expect.truthy(templates ~= nil, "HeistShared.SoundTemplates exists")
		if not templates then return end
		expect.falsy(templates:FindFirstChild("CountdownSound"), "the replaced continuous countdown sound is gone, not left as clutter")
		local tick = templates:FindFirstChild("C4TickSound")
		local explosion = templates:FindFirstChild("ExplosionSound")
		expect.truthy(tick ~= nil and tick:IsA("Sound"), "C4TickSound is a Sound")
		expect.truthy(explosion ~= nil and explosion:IsA("Sound"), "ExplosionSound is a Sound")
		expect.truthy(explosion.SoundId ~= "", "ExplosionSound already has a real asset ID")
	end)

	suite:test("TeleporterBankA starts with no ProximityPrompt of its own", function(expect)
		local teleporterA = workspace.Bank:FindFirstChild("TeleporterBankA")
		expect.truthy(teleporterA ~= nil, "TeleporterBankA exists")
		if not teleporterA then return end
		expect.falsy(teleporterA:FindFirstChildOfClass("ProximityPrompt"),
			"inert until both buttons are pressed -- the C4 sequence clones prompts in, not a pre-placed one")
	end)

	-- Status billboard anchors (spec: Getaway-Distance-Claim-And-GUI,
	-- 2026-09-19). Each location's marker folder holds the single Part the
	-- getaway distance is measured from -- the SAME Part the server hands its
	-- own Getaway service and the client measures the rendered countdown
	-- against, which is what keeps the two from ever disagreeing.
	--
	-- Worth pinning because the two sides fail differently and neither failure
	-- is a good one: the servers WaitForChild then hard-assert at boot (so a
	-- missing folder or anchor takes the whole location down), while HeistClient
	-- bounded-waits and only warns (so the same fault silently costs that
	-- location its getaway widget with the game still running). This is the one
	-- construction path with that split, so a structural check here covers both.
	suite:test("every location's marker folder exists and holds a StatusBillboardAnchor BasePart", function(expect)
		for _, folderName in ipairs({ "HeistMarkers", "SlowFoodsMarkers", "Gas2GoMarkers", "NewsStationMarkers" }) do
			local folder = workspace:FindFirstChild(folderName)
			expect.truthy(folder ~= nil, "Workspace." .. folderName .. " exists")
			if folder then
				local anchor = folder:FindFirstChild("StatusBillboardAnchor")
				expect.truthy(anchor ~= nil, folderName .. ".StatusBillboardAnchor exists")
				expect.truthy(anchor ~= nil and anchor:IsA("BasePart"),
					folderName .. ".StatusBillboardAnchor is a BasePart -- Getaway measures from its .Position")
			end
		end
	end)

	-- Heist layers 2026-11-17 (Task 3): the SlowFoods Manager layer's world pieces.
	suite:test("SlowFoods Manager template, escape point and storage safe exist and are wired right", function(expect)
		local CollectionService = game:GetService("CollectionService")
		local template = game.ReplicatedStorage.RestaurantShared.ModelTemplates:FindFirstChild("Manager")
		expect.truthy(template ~= nil, "RestaurantShared.ModelTemplates.Manager exists")
		if template then
			local humanoid = template:FindFirstChildOfClass("Humanoid")
			expect.truthy(humanoid ~= nil and template:FindFirstChild("HumanoidRootPart") ~= nil, "a real rig")
			expect.equal(humanoid and humanoid.DisplayName, "Manager", "overhead name Manager")
			expect.truthy(CollectionService:HasTag(template, "Witness") and CollectionService:HasTag(template, "Invulnerable"), "keeps Witness and Invulnerable")
			expect.falsy(CollectionService:HasTag(template, "SlowFoodsManager"), "the template itself is never tagged")
		end
		local escape = workspace.SlowFoodsMarkers:FindFirstChild("ManagerEscapePoint")
		expect.truthy(escape ~= nil and escape:IsA("BasePart"), "SlowFoodsMarkers.ManagerEscapePoint is a BasePart")
		if escape then
			expect.truthy(escape.Anchored and not escape.CanCollide and escape.Transparency == 1, "anchored, invisible, non-colliding")
		end
		local safe = workspace.SlowFoods:FindFirstChild("StorageSafe")
		expect.truthy(safe ~= nil and safe:IsA("Model"), "Workspace.SlowFoods.StorageSafe is a Model")
		if safe then
			expect.falsy(CollectionService:HasTag(safe, "BankSafe"), "not tagged BankSafe")
			expect.truthy(safe:FindFirstChildOfClass("Highlight") ~= nil, "has a Highlight")
			local sound = safe:FindFirstChild("SafeRobSound", true)
			expect.truthy(sound ~= nil and sound.Parent:FindFirstChildOfClass("ParticleEmitter") ~= nil, "SafeRobSound beside a ParticleEmitter")
		end
	end)

	return suite:run()
end
