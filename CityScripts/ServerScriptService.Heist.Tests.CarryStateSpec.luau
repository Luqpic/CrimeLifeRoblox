local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	-- freshRequire matters here more than almost anywhere else in this
	-- codebase: CarryState is a SELF-INSTANTIATING singleton (the module
	-- itself returns CarryState.new() at the bottom) -- a plain cached
	-- require would hand every test the SAME shared table, leaking
	-- _carrying entries across tests.
	local CarryState = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.CarryState)
	local suite = TestRunner.new("CarryState")

	-- Minimal fake Tool: a real Instance so :Clone()/:Destroy() and the
	-- Unequipped event all behave like the genuine article.
	local function tempToolTemplate()
		local tool = Instance.new("Tool")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = tool
		return tool
	end

	-- `Instance.new("Player")` is not creatable from a normal script context
	-- (confirmed live: errors "lacking capability WritePlayer", engine-
	-- internal only) -- a plain Lua table standing in for the two members
	-- CarryState actually touches (.Character, :FindFirstChildOfClass) is
	-- the only option here, unlike Safe/RobbableObjectSpec's fake STRING
	-- players, which only ever need to work as a table key.
	local function tempPlayerWithCharacter()
		local character = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = character
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = character
		character.PrimaryPart = root
		character.Parent = workspace

		local backpack = Instance.new("Backpack")
		local player = {
			Character = character,
			FindFirstChildOfClass = function(_, className)
				if className == "Backpack" then return backpack end
				return nil
			end,
		}
		return player, character, humanoid, backpack
	end

	local function tempPlayerWithNoCharacter()
		return {
			Character = nil,
			FindFirstChildOfClass = function() return nil end,
		}
	end

	suite:test("IsCarrying is false before any pickup", function(expect)
		local carryState = CarryState.new()
		local player = tempPlayerWithCharacter()
		expect.falsy(carryState:IsCarrying(player), "not carrying")
		player.Character:Destroy()
	end)

	suite:test("PickUp equips the tool and flips IsCarrying true", function(expect)
		local carryState = CarryState.new()
		local player, character, humanoid = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		local supplyObject = { DropAt = function() end }

		local ok = carryState:PickUp(player, template, supplyObject)
		expect.truthy(ok, "pickup succeeded")
		expect.truthy(carryState:IsCarrying(player), "now carrying")
		expect.equal(humanoid:FindFirstChildOfClass("Tool") ~= nil or character:FindFirstChildOfClass("Tool") ~= nil, true,
			"a Tool clone is equipped/parented onto the character")
		character:Destroy()
	end)

	suite:test("PickUp refuses a second pickup while already carrying", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		local supplyObject = { DropAt = function() end }

		local firstOk = carryState:PickUp(player, template, supplyObject)
		expect.truthy(firstOk, "first pickup succeeds")
		local secondOk = carryState:PickUp(player, tempToolTemplate(), supplyObject)
		expect.falsy(secondOk, "second pickup refused")
		character:Destroy()
	end)

	suite:test("PickUp is a no-op when the player has no live Character/Humanoid", function(expect)
		local carryState = CarryState.new()
		local player = tempPlayerWithNoCharacter()
		local template = tempToolTemplate()
		local ok = carryState:PickUp(player, template, { DropAt = function() end })
		expect.falsy(ok, "refused -- no character")
		expect.falsy(carryState:IsCarrying(player), "not carrying")
	end)

	suite:test("Drop clears carrying state and calls DropAt on the originating SupplyObject with the given CFrame", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		local dropCalls = {}
		-- Colon-called by CarryState (state.supplyObject:DropAt(cframe)) --
		-- the mock's first parameter is the implicit self, not the CFrame.
		local supplyObject = { DropAt = function(_self, cframe) table.insert(dropCalls, cframe) end }

		carryState:PickUp(player, template, supplyObject)
		local dropCFrame = CFrame.new(5, 0, 5)
		carryState:Drop(player, dropCFrame)

		expect.falsy(carryState:IsCarrying(player), "no longer carrying")
		expect.equal(#dropCalls, 1, "DropAt called once")
		expect.equal(dropCalls[1], dropCFrame, "with the given CFrame")
		character:Destroy()
	end)

	suite:test("Drop is a no-op for a player who wasn't carrying", function(expect)
		local carryState = CarryState.new()
		local player = tempPlayerWithCharacter()
		local ok = pcall(function() carryState:Drop(player, CFrame.new()) end)
		expect.truthy(ok, "no error")
		player.Character:Destroy()
	end)

	suite:test("Consume clears carrying state, destroys the tool, returns true -- WITHOUT calling DropAt -- and returns the consumed supplyObject as a second value", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		local dropCalls = {}
		local supplyObject = { DropAt = function(_self, cframe) table.insert(dropCalls, cframe) end, cashOutAmount = 100 }

		carryState:PickUp(player, template, supplyObject)
		local consumed, returnedSupplyObject = carryState:Consume(player)

		expect.truthy(consumed, "consumed")
		expect.falsy(carryState:IsCarrying(player), "no longer carrying")
		expect.equal(#dropCalls, 0, "DropAt never called -- consumed, not dropped")
		expect.equal(returnedSupplyObject, supplyObject, "second return value is the exact supplyObject that was carried")
		character:Destroy()
	end)

	suite:test("Consume returns false (and no second value) for a player who wasn't carrying", function(expect)
		local carryState = CarryState.new()
		local player = tempPlayerWithCharacter()
		local consumed, returnedSupplyObject = carryState:Consume(player)
		expect.falsy(consumed, "nothing to consume")
		expect.equal(returnedSupplyObject, nil, "no supplyObject to return")
		player.Character:Destroy()
	end)

	suite:test("Consume's returned supplyObject carries its OWN distinct cashOutAmount through -- the per-location generalization this return value exists to support", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		-- Mirrors NewsStation's own ExpensiveCamera (20000) vs SlowFoods/Gas2Go's
		-- supplies (10000) -- proves the caller reads THIS specific object's own
		-- amount, not a shared/global constant.
		local supplyObject = { DropAt = function() end, cashOutAmount = 20000 }

		carryState:PickUp(player, template, supplyObject)
		local consumed, returnedSupplyObject = carryState:Consume(player)

		expect.truthy(consumed, "consumed")
		expect.equal(returnedSupplyObject.cashOutAmount, 20000, "the caller can read this specific object's own cashOutAmount off the returned reference")
		character:Destroy()
	end)

	suite:test("Forget clears carrying state without needing a live Tool/Character", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		carryState:PickUp(player, template, { DropAt = function() end })

		carryState:Forget(player)
		expect.falsy(carryState:IsCarrying(player), "forgotten")
		character:Destroy()
	end)

	suite:test("the Unequipped safeguard re-forces the carry tool back if something else unequips it", function(expect)
		local carryState = CarryState.new()
		local player, character, humanoid, backpack = tempPlayerWithCharacter()
		local template = tempToolTemplate()
		carryState:PickUp(player, template, { DropAt = function() end })

		local tool = character:FindFirstChildOfClass("Tool")
		expect.truthy(tool ~= nil, "tool is present")
		-- Simulate Roblox unequipping it (e.g. player selects another hotbar
		-- slot): parenting a Tool out of the character fires Unequipped.
		tool.Parent = backpack
		task.wait() -- let the Unequipped connection's re-equip run
		expect.truthy(carryState:IsCarrying(player), "still tracked as carrying")
		character:Destroy()
	end)

	-- Heavy-loot carry (heist layers 2026-11-17): a speedCap on the carried object becomes the
	-- character attribute CarrySpeedCap, read by Animate2 / SprintAuthority / Crouching.
	for _, case in ipairs({
		{ "Drop", function(cs, p) cs:Drop(p, CFrame.new()) end },
		{ "Consume", function(cs, p) cs:Consume(p) end },
		{ "Forget", function(cs, p) cs:Forget(p) end },
	}) do
		suite:test("a speedCap carry sets CarrySpeedCap and " .. case[1] .. " clears it", function(expect)
			local carryState = CarryState.new()
			local player, character = tempPlayerWithCharacter()
			carryState:PickUp(player, tempToolTemplate(), { DropAt = function() end, speedCap = 12 })
			expect.equal(character:GetAttribute("CarrySpeedCap"), 12, "cap set on pickup")
			-- Task 6: carrier-only ledges collide with the Carrier group.
			expect.equal(character.HumanoidRootPart.CollisionGroup, "Carrier", "character parts in Carrier while capped")
			case[2](carryState, player)
			expect.equal(character:GetAttribute("CarrySpeedCap"), nil, "cap cleared by " .. case[1])
			expect.equal(character.HumanoidRootPart.CollisionGroup, "Default", "back to Default after " .. case[1])
			character:Destroy()
		end)
	end

	suite:test("an object without speedCap sets no CarrySpeedCap", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		carryState:PickUp(player, tempToolTemplate(), { DropAt = function() end })
		expect.equal(character:GetAttribute("CarrySpeedCap"), nil, "no cap")
		expect.equal(character.HumanoidRootPart.CollisionGroup, "Default", "uncapped carry stays in Default")
		character:Destroy()
	end)

	suite:test("clearing the cap with the character gone does not error", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		carryState:PickUp(player, tempToolTemplate(), { DropAt = function() end, speedCap = 12 })
		player.Character = nil
		character:Destroy()
		expect.truthy(pcall(function() carryState:Consume(player) end), "Consume without a character is safe")
	end)

	suite:test("GetCarried returns the carried object, then nil after Consume", function(expect)
		local carryState = CarryState.new()
		local player, character = tempPlayerWithCharacter()
		local supplyObject = { DropAt = function() end }
		expect.equal(carryState:GetCarried(player), nil, "nothing before pickup")
		carryState:PickUp(player, tempToolTemplate(), supplyObject)
		expect.equal(carryState:GetCarried(player), supplyObject, "the carried object")
		carryState:Consume(player)
		expect.equal(carryState:GetCarried(player), nil, "nil after Consume")
		character:Destroy()
	end)

	return suite:run()
end
