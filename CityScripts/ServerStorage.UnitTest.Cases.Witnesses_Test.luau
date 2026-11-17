-- Witnesses: who sees a crime in public, and which guards see a wanted player (police and wanted, Task 3,
-- 2026-11-17). Stand-in witnesses are real unparented Models (a Head and a Humanoid); the tag lookup and the
-- line of sight are injected through Witnesses._deps and restored at the end.
return function(t)
	local ServerScriptService = game:GetService("ServerScriptService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Witnesses = require(ServerScriptService.Wanted.Witnesses)
	local Constants = require(ReplicatedStorage.Wanted.Constants)
	local expect = t.expect

	local deps = Witnesses._deps
	local saved = table.clone(deps)
	local models = {}
	local clear = true
	deps.tagged = function() return models end
	deps.inSight = function() return clear end

	local function witness(position: Vector3, guard: boolean?, health: number?): Model
		local model = Instance.new("Model")
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Position = position
		head.Parent = model
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		if health then humanoid.Health = health end
		if guard then model:SetAttribute("WitnessRole", "Guard") end
		return model
	end
	local function reset(list)
		for _, m in models do m:Destroy() end
		models = list
		clear = true
	end

	t.test("a crime 100 studs from a witness in sight counts", function()
		reset({ witness(Vector3.zero) })
		expect.equal(Witnesses.sees(Vector3.new(100, 0, 0)), true)
	end)

	t.test("a crime 130 studs away does not (WITNESS_RANGE 120)", function()
		reset({ witness(Vector3.zero) })
		expect.equal(Constants.WITNESS_RANGE, 120)
		expect.equal(Witnesses.sees(Vector3.new(130, 0, 0)), false)
	end)

	t.test("a crime out of sight does not", function()
		reset({ witness(Vector3.zero) })
		clear = false
		expect.equal(Witnesses.sees(Vector3.new(10, 0, 0)), false)
	end)

	t.test("a dead witness sees nothing; the line of sight starts at the witness's head", function()
		reset({ witness(Vector3.zero, false, 0) })
		expect.equal(Witnesses.sees(Vector3.new(10, 0, 0)), false)
		local from
		reset({ witness(Vector3.new(0, 7, 0)) })
		deps.inSight = function(eye) from = eye return true end
		expect.equal(Witnesses.sees(Vector3.new(10, 0, 0)), true)
		expect.equal(from, Vector3.new(0, 7, 0))
		deps.inSight = function() return clear end
	end)

	t.test("guardSees: a guard within SEEN_RANGE 150 in sight counts; a civilian or a guard at 160 does not", function()
		reset({ witness(Vector3.zero, true) })
		expect.equal(Witnesses.guardSees(Vector3.new(140, 0, 0)), true)
		expect.equal(Witnesses.guardSees(Vector3.new(160, 0, 0)), false)
		reset({ witness(Vector3.zero) })
		expect.equal(Witnesses.guardSees(Vector3.new(10, 0, 0)), false)
		clear = false
		reset({ witness(Vector3.zero, true) })
		clear = false
		expect.equal(Witnesses.guardSees(Vector3.new(10, 0, 0)), false)
	end)

	-- Fix round 1: the real Sight probe, 5,000 studs above the map. A second witness's body standing
	-- between the first witness and the crime does not hide it (witnesses are left out of each other's rays).
	t.test("a second witness standing in the line of view does not hide the crime", function()
		local base = Vector3.new(0, 5000, 0)
		local first = witness(base)
		-- Dead, so only the first one can see: its body is still a witness's body, left out of the rays.
		local second = witness(base + Vector3.new(10, 0, 0), false, 0)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Anchored = true
		body.Size = Vector3.new(2, 12, 8) -- wider and taller than every probe point
		body.CFrame = CFrame.new(base + Vector3.new(10, 0, 0))
		body.Parent = second
		for _, m in { first, second } do
			for _, p in m:GetDescendants() do
				if p:IsA("BasePart") then p.Anchored = true end
			end
			m.Parent = workspace
		end
		reset({ first, second })
		deps.inSight = saved.inSight
		local ok, result = pcall(Witnesses.sees, base + Vector3.new(30, 0, 0))
		deps.inSight = function() return clear end
		expect.equal(ok and result, true)
	end)

	-- Final review 2026-11-17: sees() leaves out the hurt victim's own model.
	t.test("the hurt victim is not its own witness; another witness beside it still is", function()
		local victim = witness(Vector3.zero)
		reset({ victim })
		local alone = Witnesses.sees(Vector3.new(10, 0, 0), victim)
		models = { victim, witness(Vector3.new(5, 0, 0)) }
		local withOther = Witnesses.sees(Vector3.new(10, 0, 0), victim)
		expect.equal(alone, false)
		expect.equal(withOther, true)
	end)

	t.test("(restore deps)", function()
		reset({})
		for k, v in saved do deps[k] = v end
	end)
end
