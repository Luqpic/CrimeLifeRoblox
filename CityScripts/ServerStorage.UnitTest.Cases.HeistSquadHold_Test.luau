-- PoliceDispatcher's squad hold (heist police and Bank guards, 2026-11-20): while a hold (Heist.Services.HeistPolice,
-- until the robbery's first wave) holds a wanted player, the top-up sends that player no squad and keeps the alarm's
-- ring for the first round after the hold; everyone else is served as before. Stand-in players through the
-- dispatcher's seams (_players, _spawnRound, _alarmAnchor), all restored.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local Workspace = game:GetService("Workspace")
	local PoliceDispatcher = require(ServerScriptService.Wanted.PoliceDispatcher)
	local expect = t.expect

	local function standIn(name)
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 5000, 0)
		root.Parent = model
		Instance.new("Humanoid").Parent = model
		model.Parent = Workspace
		return { Name = name, Character = model, GetAttribute = function(_, attribute)
			return if attribute == "WantedStars" then 3 else nil
		end }
	end

	t.test("a held player's squad waits and keeps its alarm ring; released, its round goes from the ring", function()
		local savedPlayers, savedRound = PoliceDispatcher._players, PoliceDispatcher._spawnRound
		local robber, other = standIn("Robber"), standIn("Other")
		local ring = Vector3.new(1, 2, 3)
		local held, released = {}, {}
		local rounds = held
		local hold
		local ok, err = pcall(function()
			PoliceDispatcher._players = function() return { robber, other } end
			PoliceDispatcher._spawnRound = function(player, n, anchor)
				table.insert(rounds, { player = player, n = n, anchor = anchor })
			end
			hold = PoliceDispatcher.addSquadHold(function(player) return player == robber end)
			PoliceDispatcher._alarmAnchor[robber] = ring
			PoliceDispatcher._topUp()
			hold:Disconnect()
			rounds = released
			PoliceDispatcher._topUp()
		end)
		if hold then hold:Disconnect() end
		PoliceDispatcher._players, PoliceDispatcher._spawnRound = savedPlayers, savedRound
		PoliceDispatcher._alarmAnchor[robber], PoliceDispatcher._alarmAnchor[other] = nil, nil
		robber.Character:Destroy()
		other.Character:Destroy()
		if not ok then error(err, 0) end
		expect.equal(#held, 1)
		expect.equal(held[1].player, other)
		expect.equal(held[1].n, 6)
		local robberRound
		for _, round in released do
			if round.player == robber then robberRound = round end
		end
		expect.truthy(robberRound)
		expect.equal(robberRound.n, 6)
		expect.equal(robberRound.anchor, ring)
	end)

	t.test("a throwing hold holds nobody", function()
		local hold = PoliceDispatcher.addSquadHold(function() error("broken hold") end)
		local result = PoliceDispatcher.isHeld({ Name = "Anyone" })
		hold:Disconnect()
		expect.equal(result, false)
	end)
end
