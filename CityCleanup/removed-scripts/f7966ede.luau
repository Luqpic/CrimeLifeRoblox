-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Screen.SoundScript V2 ; copies: 1 ; Adler-32: f7966ede
local carSeat = script.Parent.CarSeat.Value
	carSeat.Sound:Play()
	carSeat.Sound2:Play()

while true do
	wait()
	local speed = carSeat.Velocity.magnitude
	speed = math.floor(math.sqrt((carSeat.Velocity.x^2)+(carSeat.Velocity.y^2)+(carSeat.Velocity.z^2)))	
	carSeat.Sound.Pitch = (speed/180)+.2
	carSeat.Sound2.Pitch = (speed/150)+0

end