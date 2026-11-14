-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Ignition ; copies: 1 ; Adler-32: b64fa29d
local car = script.Parent.Car.Value

script:WaitForChild("Start1")
script:WaitForChild("Start2")

for i,v in pairs(car.DriveSeat:GetChildren()) do
	for _,a in pairs(script:GetChildren()) do
		if v.Name==a.Name then v:Stop() wait() v:Destroy() end
	end
end
for i,v in pairs(script:GetChildren()) do
	v.Parent=car.DriveSeat
end

car.DriveSeat.Start1:Play()
wait(0.7)
car.DriveSeat.Start2:Play()
script.Parent.IsOn.Value=true
wait(6)
car.DriveSeat.Start1:Stop()
car.DriveSeat.Start2:Stop()