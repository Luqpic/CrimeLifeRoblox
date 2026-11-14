-- Removed by CityCleanup Task 2. Original path: Workspace.Model.Model.BigLazer.DamageScript_25 ; copies: 41 ; Adler-32: 53e83c57
script.Parent.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.Health-25
	end
end)