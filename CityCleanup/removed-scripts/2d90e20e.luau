-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Smoke [FE+].Smoke_FE.Handler ; copies: 1 ; Adler-32: 2d90e20e
local car = script.Parent.Parent
local F = {}

F.UpdateSmoke = function(rl,rr)
	car.Wheels.RL.Smoke.Rate = rl
	car.Wheels.RR.Smoke.Rate = rr
	car.Wheels.RL.SQ.Volume = rl/50
	car.Wheels.RR.SQ.Volume = rr/50
end

script.Parent.OnServerEvent:connect(function(pl,Fnc,...)
	F[Fnc](...)
end)

car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" then
		car.Wheels.RL.SQ:Stop()
		car.Wheels.RR.SQ:Stop()
		car.Wheels.RL.Smoke.Rate=0
		car.Wheels.RR.Smoke.Rate=0
	end
end)

for i,v in pairs(car.Wheels:GetChildren()) do
	if v.Name=="RL" or v.Name=="RR" or v.Name=="R" then
		local sq = script.Parent.SQ:Clone()
		sq.Parent=v
		local sm = script.Parent.Smoke:Clone()
		sm.Parent=v
	end
end