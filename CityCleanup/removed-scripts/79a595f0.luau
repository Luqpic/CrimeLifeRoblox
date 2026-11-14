-- Removed by CityCleanup Task 2. Original path: Workspace.Back Door.OwnerOnlyDoorScript ; copies: 3 ; Adler-32: 79a595f0
local Players = game:GetService("Players")

local DeactivatedColor = Color3.fromRGB(75, 151, 75)
local ActivatedColor = Color3.fromRGB(166, 0, 0)

local Model = script.Parent
local ColorParts = Model.ColorParts
local HitPart = Model.HitPart
local Button =  Model.Button
local OwnerOnlyPrompt = Button.OwnerOnlyDoorPrompt

local isActive = true

HitPart.Touched:Connect(function(hit)
	if hit then
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if plr and (not plr.Tycoon.Value or not Model:FindFirstAncestor(plr.Tycoon.Value.Name)) then
			if isActive then
				plr.Character:BreakJoints()
			end
		end
	end
end)

OwnerOnlyPrompt.Triggered:Connect(function(plr)
	if plr.Tycoon.Value and Model:FindFirstAncestor(plr.Tycoon.Value.Name) then
		if isActive then
			isActive = false
			OwnerOnlyPrompt.ObjectText = "To Activate"
			
			for	_, part in pairs(ColorParts:GetChildren()) do
				if part:IsA("BasePart") then
					part.Color = DeactivatedColor
				end
			end
		else
			isActive = true
			OwnerOnlyPrompt.ObjectText = "To Deactivate"
			
			for	_, part in pairs(ColorParts:GetChildren()) do
				if part:IsA("BasePart") then
					part.Color = ActivatedColor
				end
			end
		end
	end
end)

OwnerOnlyPrompt.ObjectText = "To Deactivate"