-- Removed by CityCleanup Task 2. Original path: Workspace.Model.SecurityCDamagePart_15.Script ; copies: 8 ; Adler-32: 53dc3c56
script.Parent.Touched:Connect(function(hit)
	local humanoid = hit.Parent:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.Health-15
	end
end)