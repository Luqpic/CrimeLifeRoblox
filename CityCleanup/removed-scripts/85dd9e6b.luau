-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Brake.Control ; copies: 3 ; Adler-32: 85dd9e6b
if script.Parent.Parent:IsA("VehicleSeat") then
	script.Parent.Parent.ChildAdded:connect(function(child)
		if child:IsA("Weld") and game.Players:GetPlayerFromCharacter(child.Part1.Parent)~=nil then
			local p=game.Players:GetPlayerFromCharacter(child.Part1.Parent)
			local g=script.G:Clone()
			g.Parent=p.PlayerGui
			g:WaitForChild("src")
			g.src.Value=script.Parent
			g.src2.Value=script.Parent
			g.src3.Value=script.Parent
			g.Lights3.Disabled=false
		
		end
	end)
end