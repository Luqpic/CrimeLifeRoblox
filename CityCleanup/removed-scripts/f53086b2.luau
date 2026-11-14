-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.AC6_First_Person_Gauges ; copies: 1 ; Adler-32: f53086b2
--[[
		___      _______                _     
	   / _ |____/ ___/ /  ___ ____ ___ (_)__ 
	  / __ /___/ /__/ _ \/ _ `(_-<(_-</ (_-<
	 /_/ |_|   \___/_//_/\_,_/___/___/_/___/
 						  By DarkMAwakening
]]

local car = script.Parent.Car.Value
local intach = car.Body.Dash.Tac.G.Needle 
local inspd = car.Body.Dash.Spd.G.Needle
local dash = car.Body.Dash.DashSc.G
--------------------------------------------------
script.Parent.Values.RPM.Changed:connect(function()
	intach.Rotation = -65 + script.Parent.Values.RPM.Value * 250 / 8000
end)

script.Parent.Values.Velocity.Changed:connect(function(property)
	inspd.Rotation = -30 + (440 / 160) * (math.abs(script.Parent.Values.Velocity.Value.Magnitude*((10/12) * (50/88))))
end)

script.Parent.Values.Gear.Changed:connect(function()
	local gearText = script.Parent.Values.Gear.Value
	if gearText == 0 then 
		gearText = "N"
		car.Body.Dash.DashSc.G.Gear.Text = "N"
		car.DriveSeat.Filter:FireServer('reverse',false)
	elseif gearText == -1 then
		gearText = "R"
		car.Body.Dash.DashSc.G.Gear.Text = "R"
		car.DriveSeat.Filter:FireServer('reverse',true)
	end
	car.Body.Dash.DashSc.G.Gear.Text = gearText
end)

script.Parent.Values.PBrake.Changed:connect(function()
	dash.PBrake.Visible = script.Parent.Values.PBrake.Value
end)