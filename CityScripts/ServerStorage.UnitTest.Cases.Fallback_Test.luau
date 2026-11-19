-- Tests for ReplicatedStorage.PlayerMovement.Fallback: which Roblox default R15 clip stands in for a movement clip
-- that did not load, and which clips have none (2026-11-20).
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local fallbackFor = require(ReplicatedStorage.PlayerMovement.Fallback)
	local expect = t.expect

	t.test("each looping kind maps to the Roblox default of its kind", function()
		local want = {
			Idle = "rbxassetid://507766388",
			Walk_F = "rbxassetid://507777826",
			Walk_B = "rbxassetid://507777826",
			Jog_L = "rbxassetid://507777826",
			Jog_R = "rbxassetid://507777826",
			Run_F = "rbxassetid://507767714",
			Run_L = "rbxassetid://507767714",
			Sprint = "rbxassetid://507767714",
			Jump = "rbxassetid://507765000",
			Fall = "rbxassetid://507767968",
			Climb = "rbxassetid://507765644",
			Swim = "rbxassetid://507784897",
			SwimIdle = "rbxassetid://507785072",
		}
		for name, id in want do
			expect.equal(fallbackFor(name), id)
		end
	end)

	t.test("legs copies, landings and the two moves have no stand-in", function()
		for _, name in { "IdleLegs", "Walk_FLegs", "Run_BLegs", "SprintLegs", "JumpLegs", "FallLegs", "Land", "LandLegs", "LandHard", "LandHardLegs", "Roll", "LedgeClimb", "Empty" } do
			expect.equal(fallbackFor(name), nil)
		end
	end)

	t.test("every clip in PlayerMovement.Animations is either mapped or one of the skipped kinds", function()
		local skipped = { Land = true, LandHard = true, Roll = true, LedgeClimb = true, Empty = true }
		for _, a in ReplicatedStorage.PlayerMovement.Animations:GetChildren() do
			local mapped = fallbackFor(a.Name) ~= nil
			expect.truthy(mapped or skipped[a.Name] or a.Name:find("Legs$") ~= nil)
		end
	end)
end
