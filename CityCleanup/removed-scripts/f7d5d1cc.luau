-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Backfire [FE+] ; copies: 1 ; Adler-32: f7d5d1cc
local FE = workspace.FilteringEnabled
local car = script.Parent.Car.Value
local handler = car:WaitForChild("Backfire_FE")
local _Tune = require(car["A-Chassis Tune"])

script.Parent.Values.Gear.Changed:connect(function()
	if script.Parent.Values.RPM.Value>3200 then
		if FE then
			handler:FireServer("Backfire1")
			wait (0.1)
		else
			car.Body.Exhaust.Backfire1.Backfire1:play()
			car.Body.Exhaust.Backfire2.Backfire1:play()
			car.Body.Exhaust.Backfire3.Backfire1:play()
			car.Body.Exhaust.Backfire4.Backfire1:play()
			car.Body.Exhaust.Backfire1.Fire.Enabled = true
			car.Body.Exhaust.Backfire2.Fire.Enabled = true
			car.Body.Exhaust.Backfire3.Fire.Enabled = true
			car.Body.Exhaust.Backfire4.Fire.Enabled = true
			car.Body.Exhaust.BFLight1.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight2.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight3.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight4.SpotLight.Enabled = true
			wait (0.03)
			car.Body.Exhaust.Backfire1.Fire.Enabled = false
			car.Body.Exhaust.Backfire2.Fire.Enabled = false
			car.Body.Exhaust.Backfire3.Fire.Enabled = false
			car.Body.Exhaust.Backfire4.Fire.Enabled = false
			car.Body.Exhaust.BFLight1.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight2.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight3.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight4.SpotLight.Enabled = false
			wait (0.07)
		end
	end
end)

while wait() do
	--//Backfire//--
	local randomability = math.random (1, 10)
	
	local throtOff = script.Parent.Values.RPM.Value > 2990 and randomability <=1 and script.Parent.Values.Throttle.Value <= _Tune.IdleThrottle/100
	local redline = script.Parent.Values.Throttle.Value > 0 and math.ceil(script.Parent.Values.RPM.Value) > _Tune.Redline-_Tune.RevBounce and script.Parent.Values.Gear.Value<#_Tune.Ratios-2
	
	if throtOff or redline then
		if FE then
			handler:FireServer("Backfire2")
			wait (0.1)
		else
			car.Body.Exhaust.Backfire1.Backfire1:play()
			car.Body.Exhaust.Backfire2.Backfire2:play()
			car.Body.Exhaust.Backfire3.Backfire3:play()
			car.Body.Exhaust.Backfire4.Backfire4:play()
			car.Body.Exhaust.Backfire1.Fire.Enabled = true
			car.Body.Exhaust.Backfire2.Fire.Enabled = true
			car.Body.Exhaust.Backfire3.Fire.Enabled = true
			car.Body.Exhaust.Backfire4.Fire.Enabled = true
			car.Body.Exhaust.BFLight1.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight2.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight3.SpotLight.Enabled = true
			car.Body.Exhaust.BFLight4.SpotLight.Enabled = true
			wait (0.03)
			car.Body.Exhaust.Backfire1.Fire.Enabled = false
			car.Body.Exhaust.Backfire2.Fire.Enabled = false
			car.Body.Exhaust.Backfire3.Fire.Enabled = false
			car.Body.Exhaust.Backfire4.Fire.Enabled = false
			car.Body.Exhaust.BFLight1.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight2.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight3.SpotLight.Enabled = false
			car.Body.Exhaust.BFLight4.SpotLight.Enabled = false
			wait (0.07)
		end
	end
--//--//--
end
