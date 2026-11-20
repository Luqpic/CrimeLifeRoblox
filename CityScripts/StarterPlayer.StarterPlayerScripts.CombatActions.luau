-- Wounded finishers and stealth takedowns (combat, 2026-11-20), the client side: shows "E  FINISH" or "E  TAKEDOWN"
-- (StarterGui.CombatHint) when one is possible and sends it on E, gamepad X or a tap on the hint
-- (ReplicatedStorage.Combat.Remotes.Finish). The server (Enemy.Scripts.Finishers) checks everything again.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ENEMY_TAG = require(ReplicatedStorage.Enemy.Constants).ENEMY_TAG
local finishRemote = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Remotes"):WaitForChild("Finish")
local player = Players.LocalPlayer
local hint = player:WaitForChild("PlayerGui"):WaitForChild("CombatHint"):WaitForChild("Hint") :: TextButton

local FINISH_RANGE = 8
local TAKEDOWN_RANGE = 5
local BEHIND_DOT = -0.5

local current: Model? = nil
local currentKind: string? = nil

-- The nearest enemy to finish (wounded, close) or to take down (crouched, behind one that has not noticed you).
local function pick(): (Model?, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, nil
	end
	local crouched = root:GetAttribute("IsCrouching") == true
	local best, bestKind, bestDistance = nil, nil, math.huge
	for _, model in CollectionService:GetTagged(ENEMY_TAG) do
		local enemyRoot = model:IsA("Model") and model.PrimaryPart
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if enemyRoot and humanoid and humanoid.Health > 0 then
			local offset = root.Position - enemyRoot.Position
			local distance = offset.Magnitude
			if distance < bestDistance then
				if model:GetAttribute("Wounded") == true and distance <= FINISH_RANGE then
					best, bestKind, bestDistance = model, "Finish", distance
				elseif crouched and model:GetAttribute("Aware") ~= true and distance <= TAKEDOWN_RANGE then
					local look = Vector3.new(enemyRoot.CFrame.LookVector.X, 0, enemyRoot.CFrame.LookVector.Z)
					local flat = Vector3.new(offset.X, 0, offset.Z)
					if look.Magnitude > 0.01 and flat.Magnitude > 0.01 and look.Unit:Dot(flat.Unit) <= BEHIND_DOT then
						best, bestKind, bestDistance = model, "Takedown", distance
					end
				end
			end
		end
	end
	return best, bestKind
end

local function act()
	if current and currentKind then
		finishRemote:FireServer(current, currentKind)
	end
end

task.spawn(function()
	while true do
		current, currentKind = pick()
		hint.Visible = current ~= nil
		if currentKind then
			local word = if currentKind == "Finish" then "FINISH" else "TAKEDOWN"
			hint.Text = if UserInputService.PreferredInput == Enum.PreferredInput.Touch then word else "E  " .. word
		end
		task.wait(0.1)
	end
end)

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		act()
	end
end)
hint.Activated:Connect(act)
