-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.A-Chassis Interface.Warn.LocalScript ; copies: 1 ; Adler-32: 3d05c502
local Car = script.Parent.Parent.Car.Value
local Seat = Car:WaitForChild("DriveSeat")
while true do
  script.Parent.Visible = Seat.Velocity.magnitude < 3 and true or false
  script.Parent.Text = script.Parent.Parent.Handbrake.Visible == true and "Handbrake Enabled" or script.Parent.Parent.Handbrake.Visible == false and "Hold P for Parking Brake"
  script.Parent.Size = script.Parent.Parent.Handbrake.Visible == true and UDim2.new(0, 207, 0, 40) or script.Parent.Parent.Handbrake.Visible == false and UDim2.new(0, 250, 0, 40)
  game:GetService("RunService").RenderStepped:wait()
end
