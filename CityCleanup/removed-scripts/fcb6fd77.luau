-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Backfire [FE+].Backfire_FE.Handler ; copies: 1 ; Adler-32: fcb6fd77
local car = script.Parent.Parent
local F = {}

F.Backfire1 = function()
	car.Body.Exhaust.Backfire1.Backfire1:play()
	car.Body.Exhaust.Backfire2.Backfire1:play()
	car.Body.Exhaust.Backfire1.Fire.Enabled = true
	car.Body.Exhaust.Backfire2.Fire.Enabled = true
	car.Body.Exhaust.BFLight1.SpotLight.Enabled = true
	car.Body.Exhaust.BFLight2.SpotLight.Enabled = true
	wait (0.03)
	car.Body.Exhaust.Backfire1.Fire.Enabled = false
	car.Body.Exhaust.Backfire2.Fire.Enabled = false
	car.Body.Exhaust.BFLight1.SpotLight.Enabled = false
	car.Body.Exhaust.BFLight2.SpotLight.Enabled = false
	wait (0.07)
end

F.Backfire2 = function()
	car.Body.Exhaust.Backfire1.Backfire2:play()
	car.Body.Exhaust.Backfire2.Backfire2:play()
	car.Body.Exhaust.Backfire1.Fire.Enabled = true
	car.Body.Exhaust.Backfire2.Fire.Enabled = true
	car.Body.Exhaust.BFLight1.SpotLight.Enabled = true
	car.Body.Exhaust.BFLight2.SpotLight.Enabled = true
	wait (0.03)
	car.Body.Exhaust.Backfire1.Fire.Enabled = false
	car.Body.Exhaust.Backfire2.Fire.Enabled = false
	car.Body.Exhaust.BFLight1.SpotLight.Enabled = false
	car.Body.Exhaust.BFLight2.SpotLight.Enabled = false
	wait (0.07)
end


script.Parent.OnServerEvent:connect(function(pl,Fnc,...)
	F[Fnc](...)
end)

car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" then
		car.Body.Exhaust.Backfire1.Fire.Enabled = false
		car.Body.Exhaust.Backfire2.Fire.Enabled = false
		car.Body.Exhaust.BFLight1.SpotLight.Enabled = false
		car.Body.Exhaust.BFLight2.SpotLight.Enabled = false
	end
end)