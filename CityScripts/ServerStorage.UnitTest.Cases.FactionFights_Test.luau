-- Faction fights (2026-11-20): police and criminal NPCs take each other as targets (EnemyAI:_accepts / _hostileTo) and
-- their shots land on each other (canDamageHumanoid); same-faction NPCs and heist guards stay safe from AI fire.
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local EnemyAI = require(ServerScriptService.Enemy.Scripts.EnemyAI)
	local EnemyConstants = require(ReplicatedStorage.Enemy.Constants)
	local canDamageHumanoid = require(ReplicatedStorage.Blaster.Utility.canDamageHumanoid)
	local expect = t.expect

	local made = {}
	local function npc(faction: string, guard: boolean?): Model
		local model = Instance.new("Model")
		model:SetAttribute("Faction", faction)
		if guard then
			model:SetAttribute("WitnessRole", "Guard")
		end
		CollectionService:AddTag(model, EnemyConstants.ENEMY_TAG)
		Instance.new("Humanoid").Parent = model
		table.insert(made, model)
		return model
	end
	local function fakeEnemy(model: Model)
		return setmetatable({ character = model, config = {} }, EnemyAI)
	end

	local ok, err = pcall(function()
		local cop, cop2, thug, guard = npc("Police"), npc("Police"), npc("Criminal"), npc("Police", true)

		t.test("a police NPC accepts a criminal NPC, not another officer or itself", function()
			local ai = fakeEnemy(cop)
			expect.truthy(ai:_accepts(thug))
			expect.falsy(ai:_accepts(cop2))
			expect.falsy(ai:_accepts(cop))
		end)

		t.test("a criminal NPC accepts a police NPC", function()
			expect.truthy(fakeEnemy(thug):_accepts(cop))
		end)

		t.test("AI shots hurt the other faction only, never a heist guard", function()
			expect.truthy(canDamageHumanoid(cop, thug:FindFirstChildOfClass("Humanoid") :: Humanoid))
			expect.truthy(canDamageHumanoid(thug, cop:FindFirstChildOfClass("Humanoid") :: Humanoid))
			expect.falsy(canDamageHumanoid(cop, cop2:FindFirstChildOfClass("Humanoid") :: Humanoid))
			expect.falsy(canDamageHumanoid(thug, guard:FindFirstChildOfClass("Humanoid") :: Humanoid))
		end)
	end)
	for _, model in made do
		model:Destroy()
	end
	if not ok then
		error(err, 0)
	end
end
