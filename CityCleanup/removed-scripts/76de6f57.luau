-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Smoke [FE+] ; copies: 1 ; Adler-32: 76de6f57
local FE = workspace.FilteringEnabled
local car = script.Parent.Car.Value
car.Wheels.RL.SQ:Play()
car.Wheels.RR.SQ:Play()
local handler = car:WaitForChild("Smoke_FE")

while wait(.2) do
	local r1 = Ray.new(car.Wheels.RL.Position,(car.Wheels.RL.Arm.CFrame*CFrame.Angles(-math.pi/2,0,0)).lookVector*(.05+car.Wheels.RL.Size.x/2))
	local r1hit = 0
	if workspace:FindPartOnRay(r1,car)~=nil then r1hit=1 end

	local r2 = Ray.new(car.Wheels.RL.Position,(car.Wheels.RR.Arm.CFrame*CFrame.Angles(-math.pi/2,0,0)).lookVector*(.05+car.Wheels.RR.Size.x/2))
	local r2hit = 0
	if workspace:FindPartOnRay(r2,car)~=nil then r2hit=1 end
	
	local rl = math.min((math.max(math.abs((car.Wheels.RL.RotVelocity.Magnitude*car.Wheels.RL.Size.x/2) - (car.Wheels.RL.Velocity.Magnitude))-30,0)),50)*r1hit
	local rr = math.min((math.max(math.abs((car.Wheels.RR.RotVelocity.Magnitude*car.Wheels.RR.Size.x/2) - (car.Wheels.RR.Velocity.Magnitude))-30,0)),50)*r2hit
	
	if FE then
		handler:FireServer("UpdateSmoke",rl,rr)
	else
		car.Wheels.RL.Smoke.Rate = rl
		car.Wheels.RR.Smoke.Rate = rr
		car.Wheels.RL.SQ.Volume = rl/50
		car.Wheels.RR.SQ.Volume = rr/50
	end
end
