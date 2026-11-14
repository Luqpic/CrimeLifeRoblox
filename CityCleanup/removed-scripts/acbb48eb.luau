-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Speedometer V3.speedo.SpeedMeter.SpeedGUIScript ; copies: 1 ; Adler-32: acbb48eb
P = script.Parent
Player = game.Players.LocalPlayer
Human = Player.Character
Head = Human.Head


while true do
	wait(.3)
	local intSpeed = math.floor((Head.Velocity.magnitude)/1.6)
	P.SpeedLabel.Text = intSpeed.." MPH"
end
