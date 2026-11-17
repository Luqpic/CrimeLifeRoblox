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

	t.test("(restore deps)", function()
		reset({})
		for k, v in saved do deps[k] = v end
	end)
end
