local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local Zone = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.Zone)
	local ZoneService = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.ZoneService)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("Zone")

	-- Occupancy is driven by a table the test mutates, standing in for a real
	-- GetPartsInPart sweep.
	local function makeWorld()
		local occupancy = {}
		local function tempZone(role)
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Transparency = 1
			part.Size = Vector3.new(20, 20, 20)
			part:SetAttribute("ZoneRole", role)
			part.Parent = workspace
			occupancy[part] = {}
			return part
		end
		local function query(part) return occupancy[part] or {} end
		return occupancy, tempZone, query
	end

	local function service(roles)
		local occupancy, tempZone, query = makeWorld()
		local zones, parts = {}, {}
		for _, role in ipairs(roles) do
			local part = tempZone(role)
			table.insert(parts, part)
			table.insert(zones, Zone.new(part, { config = Config, queryOccupants = query }))
		end
		local svc = ZoneService.new({ zones = zones, queryOccupants = query })
		return svc, occupancy, parts
	end

	suite:test("a zone reads its role from its attribute", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		expect.equal(#svc:GetOccupants("Vault"), 0, "starts empty")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	-- Regression for the sweep-cost bug. defaultQuery used an Exclude filter naming
	-- only the zone part, so a building-sized volume handed back every wall, floor and
	-- prop inside it (4,007 parts for NewsroomZone) and walked them all in Luau on
	-- every sweep, 10 times a second -- ~835ms of work per second across the 12 zones,
	-- pinning the server at ~29 FPS. The Include filter scopes the sweep to live
	-- character parts, so unrelated geometry inside the volume costs nothing.
	--
	-- Every other test here injects queryOccupants, so the real sweep had no coverage
	-- at all -- which is how the cost went unnoticed. This one deliberately uses it.
	-- Cleanup runs before the assertions so a failure cannot leak fixtures.
	suite:test("the real occupancy sweep ignores non-character geometry", function(expect)
		local zonePart = Instance.new("Part")
		zonePart.Anchored = true
		zonePart.CanCollide = false
		zonePart.Transparency = 1
		zonePart.Size = Vector3.new(80, 40, 80)
		zonePart.Position = Vector3.new(0, 5000, 0) -- clear of the real map
		zonePart:SetAttribute("ZoneRole", "Vault")
		zonePart.Parent = workspace

		local clutter = {}
		for i = 1, 1200 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.Size = Vector3.new(2, 2, 2)
			p.Position = zonePart.Position
				+ Vector3.new((i % 20) * 3 - 30, (i % 31) * 1.2 - 18, (i % 13) * 4 - 26)
			p.Parent = workspace
			clutter[i] = p
		end

		-- No queryOccupants dependency: this exercises the real defaultQuery. Open items pass 2026-11-18: the
		-- work is counted, not timed (a 3 ms wall-clock limit failed at 3.05 to 10.19 ms with the filter intact).
		-- The overlap seam passes the real engine query through and counts the parts it hands to the Luau loop.
		local calls, walked = 0, 0
		local zone = Zone.new(zonePart, {
			config = Config,
			overlap = function(part, params)
				calls += 1
				local hits = workspace:GetPartsInPart(part, params)
				walked += #hits
				return hits
			end,
		})
		local anyCharacter = false
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			if player.Character then anyCharacter = true end
		end

		local occupants = zone:GetOccupants()

		for _, p in ipairs(clutter) do p:Destroy() end
		zonePart:Destroy()

		expect.equal(#occupants, 0, "no player characters overlap, so no occupants")
		expect.equal(calls, if anyCharacter then 1 else 0, "the real sweep ran through the overlap seam")
		expect.equal(walked, 0, string.format("sweep must not walk the %d parts sharing its volume", #clutter))
	end)

	suite:test("entering fires Entered exactly once", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		local entered = {}
		svc.Entered:Connect(function(role, player) table.insert(entered, role .. ":" .. player) end)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		svc:Update()
		svc:Update()
		expect.equal(#entered, 1, "one Entered despite three sweeps")
		expect.equal(entered[1], "Vault:p1", "role and player")
		expect.truthy(svc:IsInside("Vault", "p1"), "occupancy tracked")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("leaving fires Exited exactly once", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		local exited = {}
		svc.Exited:Connect(function(role, player) table.insert(exited, player) end)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		occupancy[parts[1]] = {}
		svc:Update()
		svc:Update()
		expect.equal(#exited, 1, "one Exited")
		expect.falsy(svc:IsInside("Vault", "p1"), "no longer inside")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	-- Regression for the duffel-display bug: a handler reacting to Exited by
	-- calling IsInside must see the NEW (departed) state, not the stale
	-- pre-exit snapshot -- otherwise a corrective push (e.g. HeistServer's
	-- pushDuffel) recomputes the wrong rate and the client extrapolates
	-- forever with no future correction ever coming.
	suite:test("IsInside reflects the new state synchronously during Exited", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		local sawDuringExit = "not fired"
		svc.Exited:Connect(function(role, player)
			if role == "Vault" and player == "p1" then
				sawDuringExit = svc:IsInside("Vault", "p1")
			end
		end)
		occupancy[parts[1]] = {}
		svc:Update()
		expect.equal(sawDuringExit, false, "IsInside must already report false while Exited handlers run")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("IsInside reflects the new state synchronously during Entered", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		local sawDuringEnter = "not fired"
		svc.Entered:Connect(function(role, player)
			if role == "Vault" and player == "p1" then
				sawDuringEnter = svc:IsInside("Vault", "p1")
			end
		end)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		expect.equal(sawDuringEnter, true, "IsInside must already report true while Entered handlers run")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("zones with different roles are tracked independently", function(expect)
		local svc, occupancy, parts = service({ "Vault", "Claim" })
		occupancy[parts[1]] = { "p1" }
		occupancy[parts[2]] = { "p2" }
		svc:Update()
		expect.truthy(svc:IsInside("Vault", "p1"), "p1 in vault")
		expect.falsy(svc:IsInside("Vault", "p2"), "p2 not in vault")
		expect.truthy(svc:IsInside("Claim", "p2"), "p2 in claim")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("several players can occupy one zone", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		occupancy[parts[1]] = { "p1", "p2", "p3" }
		svc:Update()
		expect.equal(#svc:GetOccupants("Vault"), 3, "three occupants")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("a player moving between zones fires both transitions", function(expect)
		local svc, occupancy, parts = service({ "Vault", "Claim" })
		local events = {}
		svc.Entered:Connect(function(role, player) table.insert(events, "in:" .. role) end)
		svc.Exited:Connect(function(role, player) table.insert(events, "out:" .. role) end)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		occupancy[parts[1]] = {}
		occupancy[parts[2]] = { "p1" }
		svc:Update()
		expect.equal(events[1], "in:Vault", "entered vault")
		expect.truthy(table.find(events, "out:Vault") ~= nil, "left vault")
		expect.truthy(table.find(events, "in:Claim") ~= nil, "entered claim")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("a throwing query does not break the sweep", function(expect)
		local occupancy, tempZone, query = makeWorld()
		local goodPart = tempZone("Vault")
		occupancy[goodPart] = { "p1" }
		local badZone = { role = "Broken", GetOccupants = function() error("query failed") end,
			Seal = function() end, Rearm = function() end }
		local goodZone = Zone.new(goodPart, { config = Config, queryOccupants = query })
		local svc = ZoneService.new({ zones = { badZone, goodZone }, queryOccupants = query })
		svc:Update()
		expect.truthy(svc:IsInside("Vault", "p1"), "healthy zone still swept")
		goodPart:Destroy()
	end)

	suite:test("GetOccupants returns a copy, not the live table", function(expect)
		local svc, occupancy, parts = service({ "Vault" })
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		local list = svc:GetOccupants("Vault")
		table.insert(list, "intruder")
		expect.equal(#svc:GetOccupants("Vault"), 1, "internal state untouched")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	-- Multiple zones sharing one role (spec addendum, 2026-09-11): BankVaultZone
	-- spans several volumes -- occupancy for that role must be the UNION of
	-- every zone sharing it, not whichever zone happens to be processed LAST
	-- in the sweep stomping the others' results.
	local function multiRoleService(role, count)
		local occupancy, tempZone, query = makeWorld()
		local zones, parts = {}, {}
		for _ = 1, count do
			local part = tempZone(role)
			table.insert(parts, part)
			table.insert(zones, Zone.new(part, { config = Config, queryOccupants = query }))
		end
		local svc = ZoneService.new({ zones = zones, queryOccupants = query })
		return svc, occupancy, parts
	end

	suite:test("occupancy for a shared role is the union across every zone that carries it", function(expect)
		local svc, occupancy, parts = multiRoleService("BankVaultZone", 3)
		occupancy[parts[1]] = { "p1" }
		occupancy[parts[2]] = { "p2" }
		occupancy[parts[3]] = {}
		svc:Update()
		expect.truthy(svc:IsInside("BankVaultZone", "p1"), "p1, present in volume 1")
		expect.truthy(svc:IsInside("BankVaultZone", "p2"), "p2, present in volume 2")
		expect.equal(#svc:GetOccupants("BankVaultZone"), 2, "both counted, not overwritten by the empty third volume")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("a player leaving ALL volumes of a shared role fires exactly one Exited", function(expect)
		local svc, occupancy, parts = multiRoleService("BankVaultZone", 2)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		expect.truthy(svc:IsInside("BankVaultZone", "p1"), "inside via volume 1")

		local exited = {}
		svc.Exited:Connect(function(role, player) table.insert(exited, player) end)
		occupancy[parts[1]] = {}
		svc:Update()
		expect.equal(#exited, 1, "one Exited once truly outside every volume")
		expect.falsy(svc:IsInside("BankVaultZone", "p1"), "no longer inside")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("moving from one shared-role volume to another does not fire spurious Entered/Exited", function(expect)
		local svc, occupancy, parts = multiRoleService("BankVaultZone", 2)
		occupancy[parts[1]] = { "p1" }
		svc:Update()
		local events = {}
		svc.Entered:Connect(function(role, player) table.insert(events, "in") end)
		svc.Exited:Connect(function(role, player) table.insert(events, "out") end)

		-- p1 walks from volume 1 into volume 2 -- still inside the SAME role the
		-- whole time, just via a different physical part.
		occupancy[parts[1]] = {}
		occupancy[parts[2]] = { "p1" }
		svc:Update()

		expect.equal(#events, 0, "no Entered/Exited fired -- still continuously inside the shared role")
		expect.truthy(svc:IsInside("BankVaultZone", "p1"), "still inside")
		for _, p in ipairs(parts) do p:Destroy() end
	end)

	suite:test("one failing volume of a shared role does not lose occupants from the others", function(expect)
		local occupancy, tempZone, query = makeWorld()
		local goodPart = tempZone("BankVaultZone")
		occupancy[goodPart] = { "p1" }
		local brokenZone = { role = "BankVaultZone", GetOccupants = function() error("query failed") end,
			Seal = function() end, Rearm = function() end }
		local goodZone = Zone.new(goodPart, { config = Config, queryOccupants = query })
		local svc = ZoneService.new({ zones = { brokenZone, goodZone }, queryOccupants = query })
		svc:Update()
		expect.truthy(svc:IsInside("BankVaultZone", "p1"), "the healthy volume's occupant still counted")
		goodPart:Destroy()
	end)

	return suite:run()
end
