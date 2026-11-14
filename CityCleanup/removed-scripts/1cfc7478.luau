-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.Body.whole int ok.Dials.Neon Dials.Script ; copies: 3 ; Adler-32: 1cfc7478
while wait(7) do
	local l = game.Lighting:GetMinutesAfterMidnight()/60
	if l<6.1 or l>17.7 then
		for index, child in pairs(script.Parent:GetChildren()) do
			if child:IsA("BasePart") then
			child.Transparency = 0
			end
		end
	else
		for index, child in pairs(script.Parent:GetChildren()) do
			if child:IsA("BasePart") then
			child.Transparency = 1
			end
		end
	end
end