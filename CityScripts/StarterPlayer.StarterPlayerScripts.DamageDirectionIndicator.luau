-- Screen-edge arrow pointing toward whatever just damaged you, fading out after a moment. Cloned
-- per-hit from ReplicatedStorage.GuiTemplates.DamageArrow instead of built with Instance.new.
--
-- BEARING MATH. Both the camera's look direction and the direction to the attacker are flattened
-- onto the horizontal plane, then atan2(cross.Y, dot) gives a signed angle where 0 is dead ahead,
-- positive is clockwise (right) and +/-180 is directly behind. The cross product must be
-- toAttacker:Cross(lookVector), in that order. Checked by hand rather than from memory: with the
-- Roblox default forward look (0,0,-1), camera-right is look x up = (1,0,0); an attacker at
-- (1,0,0) then gives cross = A x L = (0,1,0), so cross.Y = +1 and dot = 0, so angle = +90 deg.
-- Positive therefore means "to the right". Reversing the operands mirrors every indicator.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local damageDirectionRemote = ReplicatedStorage:WaitForChild("Blaster")
	:WaitForChild("Remotes")
	:WaitForChild("DamageDirection")
local damageArrowTemplate = ReplicatedStorage:WaitForChild("GuiTemplates"):WaitForChild("DamageArrow")

local RADIUS = 150 -- pixels from screen centre
local HOLD_TIME = 0.15
local FADE_TIME = 1.2

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DamageDirectionIndicator"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function showIndicator(attackerPosition: Vector3)
	local cameraPosition = camera.CFrame.Position
	local toAttacker = attackerPosition - cameraPosition
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 1e-3 then
		return -- attacker is directly above or below; no meaningful bearing
	end
	toAttacker = toAttacker.Unit

	local lookVector = camera.CFrame.LookVector
	lookVector = Vector3.new(lookVector.X, 0, lookVector.Z)
	if lookVector.Magnitude < 1e-3 then
		return -- camera is pointing straight up or down
	end
	lookVector = lookVector.Unit

	local dot = math.clamp(lookVector:Dot(toAttacker), -1, 1)
	local cross = toAttacker:Cross(lookVector) -- order matters, see the note above
	local angle = math.atan2(cross.Y, dot) -- 0 ahead, +90 right, -90 left, 180 behind

	local indicator = damageArrowTemplate:Clone()
	indicator.Rotation = math.deg(angle)
	-- Screen Y grows downward, hence the negated cosine: angle 0 puts it above centre.
	indicator.Position = UDim2.new(
		0.5, math.sin(angle) * RADIUS,
		0.5, -math.cos(angle) * RADIUS
	)
	indicator.Parent = screenGui

	task.wait(HOLD_TIME)
	if not indicator.Parent then
		return
	end
	local tween = TweenService:Create(
		indicator,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	indicator:Destroy()
end

-- Each hit gets its own arrow on its own thread, so hits from several directions in quick
-- succession show several arrows at once instead of one replacing another.
damageDirectionRemote.OnClientEvent:Connect(function(attackerPosition: Vector3)
	task.spawn(showIndicator, attackerPosition)
end)
