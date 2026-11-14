-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Horn.Control.G.Horn ; copies: 1 ; Adler-32: abc28461
local mouse=game.Players.LocalPlayer:GetMouse()
script.Parent:WaitForChild("src")
src=script.Parent.src.Value
mouse.KeyDown:connect(function(key)
	if key=="h" then 
		src:Play()
	end
end)
mouse.KeyUp:connect(function(key)
	if key=="h" then 
		src:Stop()
	end
end)
src.Parent.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" then 
		src:Stop()
		script.Parent:Destroy()
	end
end)