-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.Body.Seat.Player Positioner ; copies: 4 ; Adler-32: 9d1a6c7b
script.Parent.ChildAdded:connect(function(child) 
	if child:IsA("Weld") and game.Players:GetPlayerFromCharacter(child.Part1.Parent)~=nil then 
		local P=game.Players:GetPlayerFromCharacter(child.Part1.Parent) 
		local S=script.L:Clone() S.Parent=P.PlayerGui 
		S.Seat.Value=script.Parent 
		S.Disabled=false 
	end 
end)