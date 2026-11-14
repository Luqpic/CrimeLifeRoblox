-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.AC6_SOUND_IDLE ; copies: 1 ; Adler-32: 5234c18b
--[[
		___      _______                _     
	   / _ |____/ ___/ /  ___ ____ ___ (_)__ 
	  / __ /___/ /__/ _ \/ _ `(_-<(_-</ (_-<
	 /_/ |_|   \___/_//_/\_,_/___/___/_/___/
 						SecondLogic @ Inspare
]]
local FE = workspace.FilteringEnabled
local car = script.Parent.Car.Value
local _Tune = require(car["A-Chassis Tune"])
local on = 0

script:WaitForChild("Idle")



if not FE then
	for i,v in pairs(car.DriveSeat:GetChildren()) do
		for _,a in pairs(script:GetChildren()) do
			if v.Name==a.Name then v:Stop() wait() v:Destroy() end
		end
	end
	for i,v in pairs(script:GetChildren()) do
		v.Parent=car.DriveSeat
	end
	
	car.DriveSeat.Idle:Play()
	
	while wait() do
		local _RPM = script.Parent.Values.RPM.Value
		
		if not car.DriveSeat.IsOn.Value then on=math.max(on-.015,0) else on=1 end
    car.DriveSeat.Idle.Pitch = (car.DriveSeat.Idle.SetPitch.Value - car.DriveSeat.Idle.SetRev.Value*_RPM/_Tune.Redline)*on^2
end
else
	local handler = car.AC6_FE_Sounds
	handler:FireServer("newSound","Idle",car.DriveSeat,script.Idle.SoundId,0,true)
	handler:FireServer("playSound","Idle")

	local pitch=0

	while wait() do
		local _RPM = script.Parent.Values.RPM.Value
		
		if not car.DriveSeat.IsOn.Value then on=math.max(on-.015,0) else on=1 end
		pitch = (script.Idle.SetPitch.Value - script.Idle.SetRev.Value*_RPM/_Tune.Redline)*on^2
		handler:FireServer("updateSound","Idle",script.Idle.SoundId,pitch,script.Idle.Volume)
	end
end
