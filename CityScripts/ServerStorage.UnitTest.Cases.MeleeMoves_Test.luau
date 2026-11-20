-- Melee combos, heavy swings, block and parry (combat depth, 2026-11-20): ReplicatedStorage.Combat.MeleeRules and
-- ServerScriptService.Blaster.Scripts.MeleeMoves.
return function(t)
	local MeleeRules = require(game:GetService("ReplicatedStorage").Combat.MeleeRules)
	local MeleeMoves = require(game:GetService("ServerScriptService").Blaster.Scripts.MeleeMoves)
	local expect = t.expect

	t.test("nextStep: continues within cooldown + window, wraps after three, restarts after a gap", function()
		local cooldown = 60 / 90
		expect.equal(MeleeRules.nextStep(0, nil, 10, cooldown), 1)
		expect.equal(MeleeRules.nextStep(1, 10, 10 + cooldown, cooldown), 2)
		expect.equal(MeleeRules.nextStep(2, 10, 10 + cooldown + MeleeRules.COMBO_WINDOW - 0.01, cooldown), 3)
		expect.equal(MeleeRules.nextStep(3, 10, 10 + cooldown, cooldown), 1)
		expect.equal(MeleeRules.nextStep(2, 10, 10 + cooldown + MeleeRules.COMBO_WINDOW + 0.01, cooldown), 1)
	end)

	t.test("onSwing: x1, x1.2, x1.5; a heavy x2 only after a charge on the last swing held HEAVY_HOLD", function()
		local key = Instance.new("Folder") -- stands in for a player
		local weapon = Instance.new("Tool")
		weapon:SetAttribute("rateOfFire", 90)
		local t0 = 1000
		local function swing(at: number)
			local multiplier, heavy = MeleeMoves.onSwing(key, weapon, at)
			return multiplier, heavy
		end
		expect.equal((swing(t0)), 1)
		expect.equal((swing(t0 + 0.7)), 1.2)
		expect.equal((swing(t0 + 1.4)), 1.5)
		MeleeMoves.charge(key, t0 + 0.7) -- names an older swing: ignored
		local multiplier, heavy = swing(t0 + 2.1)
		expect.equal(multiplier, 1) -- the combo wrapped
		expect.equal(heavy, false)
		MeleeMoves.charge(key, t0 + 2.1)
		multiplier, heavy = swing(t0 + 2.1 + MeleeRules.HEAVY_HOLD - 0.05) -- let go too soon: a light step
		expect.equal(multiplier, 1.2)
		expect.equal(heavy, false)
		local last = t0 + 2.1 + MeleeRules.HEAVY_HOLD - 0.05
		MeleeMoves.charge(key, last)
		multiplier, heavy = swing(last + MeleeRules.HEAVY_HOLD + 0.01)
		expect.equal(multiplier, MeleeRules.HEAVY_MULTIPLIER)
		expect.equal(heavy, true)
		expect.equal((swing(last + MeleeRules.HEAVY_HOLD + 0.71)), 1) -- a heavy starts the combo over
		weapon:Destroy()
		key:Destroy()
	end)

	t.test("defend: front blocked to BLOCK_FACTOR, parried in the window while parryable, never from behind", function()
		local look = Vector3.new(0, 0, -1)
		local front, behind = Vector3.new(1, 0, -5), Vector3.new(0, 0, 5)
		local factor, parried = MeleeRules.defend(0.1, true, look, front)
		expect.equal(factor, 0)
		expect.equal(parried, true)
		factor, parried = MeleeRules.defend(0.1, false, look, front)
		expect.equal(factor, MeleeRules.BLOCK_FACTOR)
		expect.equal(parried, false)
		factor, parried = MeleeRules.defend(MeleeRules.PARRY_WINDOW + 0.05, true, look, front)
		expect.equal(factor, MeleeRules.BLOCK_FACTOR)
		expect.equal(parried, false)
		factor, parried = MeleeRules.defend(0.1, true, look, behind)
		expect.equal(factor, 1)
		expect.equal(parried, false)
	end)

	t.test("defend: a body that is not a blocking player takes the full hit", function()
		local model = Instance.new("Model")
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		local factor, parried = MeleeMoves.defend(humanoid, Vector3.zero)
		expect.equal(factor, 1)
		expect.equal(parried, false)
		model:Destroy()
	end)
end
