-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Gui Giver ; copies: 1 ; Adler-32: d983599a
GUI = script.Parent.Screen

script.Parent.ChildAdded:connect(function(child)
	if child:IsA("Weld") then
		if child.Part1.Name == "HumanoidRootPart" then

			player = game.Players:GetPlayerFromCharacter(child.Part1.Parent)
			if player and (not player.PlayerGui:FindFirstChild("Screen")) then --// The part after the "and" prevents multiple GUI's to be copied over.
				GUI.CarSeat.Value = script.Parent --// Puts a reference of the seat in this ObjectValue, now you can use this ObjectValue's value to find the car directly.
				GUI:Clone().Parent = player.PlayerGui --// Compact version
				script.Parent.Startup:Play()
			end
		end
	end
end)

script.Parent.ChildRemoved:connect(function(child)
	if child:IsA("Weld") then
		if child.Part1.Name == "HumanoidRootPart" then
			script.Parent.Sound:Stop()
			script.Parent.Sound2:Stop()

			player = game.Players:GetPlayerFromCharacter(child.Part1.Parent)
			if player and player.PlayerGui:FindFirstChild("Screen") then
				player.PlayerGui:FindFirstChild("Screen"):Destroy()
			end
		end
	end	
end)

