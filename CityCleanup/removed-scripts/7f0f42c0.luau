-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Screen.FOV ; copies: 1 ; Adler-32: 7f0f42c0
wait()
local carSeat = script.Parent.CarSeat.Value
local cam = game.Workspace.CurrentCamera

while wait() do
	local speed = carSeat.Velocity.Magnitude
	cam.FieldOfView = ((-100000/((20*speed)+3500))+90)
end