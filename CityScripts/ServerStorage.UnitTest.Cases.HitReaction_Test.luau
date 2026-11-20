-- Enemy hit reactions (combat, 2026-11-20): ServerScriptService.Enemy.Scripts.HitReaction.
return function(t)
	local HitReaction = require(game:GetService("ServerScriptService").Enemy.Scripts.HitReaction)
	local expect = t.expect

	local function rig()
		local model = Instance.new("Model")
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Anchored = true
		root.Position = Vector3.new(0, 7000, 0)
		root.Parent = model
		model.PrimaryPart = root
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = model
		model.Parent = workspace
		return model, humanoid, root
	end

	t.test("kind: a shotgun within 8 studs knocks down, a headshot staggers, anything else flinches", function()
		expect.equal(HitReaction.kind(false, "Shotgun", 6), "knockdown")
		expect.equal(HitReaction.kind(true, "Shotgun", 20), "stagger")
		expect.equal(HitReaction.kind(true, "Pistol", 6), "stagger")
		expect.equal(HitReaction.kind(false, "AutoRifle", 3), "flinch")
	end)

	t.test("react: a red flash on every hit; a headshot stuns for STAGGER_SECONDS, not again within the cooldown", function()
		local model, humanoid, root = rig()
		local from = root.Position + Vector3.new(0, 0, 20)
		HitReaction.react(humanoid, from, nil, false)
		local flashLight = model:FindFirstChild("HitFlash") :: Highlight
		expect.truthy(flashLight and flashLight.Enabled)
		expect.equal(root:GetAttribute("StunnedUntil"), nil)
		HitReaction.react(humanoid, from, nil, true)
		local stunned = root:GetAttribute("StunnedUntil")
		expect.truthy(typeof(stunned) == "number" and stunned > os.clock() + HitReaction.STAGGER_SECONDS - 0.1)
		root:SetAttribute("StunnedUntil", 0)
		HitReaction.react(humanoid, from, nil, true)
		expect.equal(root:GetAttribute("StunnedUntil"), 0)
		model:Destroy()
	end)
end
