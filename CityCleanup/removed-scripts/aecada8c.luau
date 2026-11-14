-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Lights [FE+].Lights ; copies: 1 ; Adler-32: aecada8c
local car = script.Parent.Parent.Car.Value
local mouse = game.Players.LocalPlayer:GetMouse()
local cValues = script.Parent.Parent.Values
local Lights = car.Body.Lights
local FE = workspace.FilteringEnabled
local handler = car:WaitForChild("Lights_FE")

local mode=0
local LightOn=false
local LInd=false
local RInd=false
local PsOn=false
local lSteer = 0
local rSteer = 0

local day = 390
local night = 1050
local pulseDur = .33
local cancelThr = .4

handler:FireServer("ToggleBlinker",false,false,false,1)

function UpdateLight(prt,mat,col,trn,lon,lrg)
	if FE then
		handler:FireServer("UpdateLight",prt,mat,col,trn,lon,lrg)
	else
		prt.Material = mat
		prt.BrickColor = col
		prt.Transparency = trn
		prt.L.Enabled = lon
		prt.L.Range = lrg
	end
end

car.DriveSeat.ChildRemoved:connect(function(child)
	if child.Name=="SeatWeld" then
		UpdateLight(Lights.RV,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,15)
		if LightOn then
			UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
			UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
			UpdateLight(Lights.R,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,true,10)
			UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
			UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
		else
			UpdateLight(Lights.FLI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
			UpdateLight(Lights.FRI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
			UpdateLight(Lights.R,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
		end
		if LInd or RInd then
			handler:FireServer("ToggleBlinker",LightOn,LInd,RInd,pulseDur)
		end
	end
end)

function ToggleLight()
	if LightOn then
		UpdateLight(Lights.F,Enum.Material.Neon,BrickColor.new("Baby blue"),0,true,60)
		if not LInd then UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20) end
		if not RInd then UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20) end
	else
		UpdateLight(Lights.F,Enum.Material.SmoothPlastic,BrickColor.new("Baby blue"),0,false,60)
		if not LInd then UpdateLight(Lights.FLI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20) end
		if not RInd then UpdateLight(Lights.FRI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20) end
	end
	if cValues.Brake.Value>0 then
		UpdateLight(Lights.R,Enum.Material.Neon,BrickColor.new("Really red"),0,true,15)
		if not LInd then UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15) end
		if not RInd then UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15) end
	else
		if LightOn then
			UpdateLight(Lights.R,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,true,10)
			if not LInd then UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10) end
			if not RInd then UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10) end
		else
			UpdateLight(Lights.R,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			if not LInd then UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10) end
			if not RInd then UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10) end
		end
	end
end

function AutoLight()
	if mode == 0 then
		if (game.Lighting:GetMinutesAfterMidnight()<day or game.Lighting:GetMinutesAfterMidnight()>night) then
			if not LightOn then
				LightOn = true
				ToggleLight()
			end
		else
			if LightOn then
				LightOn = false
				ToggleLight()
			end
		end
	end
end

cValues.Brake.Changed:connect(function()
	if cValues.Brake.Value>0 then
		UpdateLight(Lights.R,Enum.Material.Neon,BrickColor.new("Really red"),0,true,15)
		if not LInd then UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15) end
		if not RInd then UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15) end
	else
		if LightOn then
			UpdateLight(Lights.R,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,true,10)
			if not LInd then UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10) end
			if not RInd then UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10) end
		else
			UpdateLight(Lights.R,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			if not LInd then UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10) end
			if not RInd then UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10) end
		end
	end
end)

UpdateLight(Lights.RV,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,15)
cValues.Gear.Changed:connect(function()
	if cValues.Gear.Value == -1 then
		UpdateLight(Lights.RV,Enum.Material.Neon,BrickColor.new("Institutional white"),0,true,15)
	else
		UpdateLight(Lights.RV,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,15)
	end
end)

cValues.SteerT.Changed:connect(function()
	if not (LInd and RInd) then
		if LInd then
			lSteer=math.min(cValues.SteerT.Value,lSteer)
			if lSteer-cValues.SteerT.Value < -cancelThr then LInd=false end
		else
			lSteer=0
		end
		if RInd then
			rSteer=math.max(cValues.SteerT.Value,rSteer)
			if rSteer-cValues.SteerT.Value > cancelThr then RInd=false end
		else
			rSteer=0
		end
	end
end)

script.Parent.Toggle.MouseButton1Click:connect(function()
	if mode==0 then
		script.Parent.Toggle.Text = "Lights: On"
		mode=1
		LightOn=true
	elseif mode==1 then
		script.Parent.Toggle.Text = "Lights: Off"
		mode=2
		LightOn=false
	else
		script.Parent.Toggle.Text = "Lights: Auto"
		mode=0
		AutoLight()

	end
	ToggleLight()
end)

mouse.keyDown:connect(function(k)
	if k=="z" then
		if RInd then
			RInd=false
			LInd=true
		else
			LInd=not LInd
		end
	elseif k=="c" then
		if LInd then
			LInd=false
			RInd=true
		else
			RInd=not RInd
		end		
	elseif k=="x" then
		if LInd and RInd then
			LInd = false
			RInd = false
		else
			LInd = true
			RInd = true
		end
	end
end)

game:GetService("UserInputService").InputBegan:connect(function(input,IsRobloxFunction)
	if input.KeyCode ==Enum.KeyCode.DPadLeft and input.UserInputState == Enum.UserInputState.Begin then
		if RInd then
			RInd=false
			LInd=true
		else
			LInd=not LInd
		end
	elseif input.KeyCode ==Enum.KeyCode.DPadRight and input.UserInputState == Enum.UserInputState.Begin then
		if LInd then
			LInd=false
			RInd=true
		else
			RInd=not RInd
		end
	elseif input.KeyCode ==Enum.KeyCode.DPadUp and input.UserInputState == Enum.UserInputState.Begin then
		if LInd and RInd then
			LInd = false
			RInd = false
		else
			LInd = true
			RInd = true
		end
	end
end)


ToggleLight()
game.Lighting.Changed:connect(AutoLight)
AutoLight()

while wait(pulseDur) do
	PsOn = not PsOn
	if PsOn then
		if LInd then
			script.Parent.Left.Visible=true
			UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,20)
			UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,15)
		end
		if RInd then
			script.Parent.Right.Visible=true
			UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,20)
			UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,15)
		end
	else
		script.Parent.Left.Visible=false
		script.Parent.Right.Visible=false
		if (not LInd) and LightOn then
			UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
		else
			UpdateLight(Lights.FLI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
		end
		if (not RInd) and LightOn then
			UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
		else
			UpdateLight(Lights.FRI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
		end
		if cValues.Brake.Value>0 then
			if not LInd then 
				UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15)
			else
				UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
			if not RInd then
				UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Really red"),0,false,15)
			else
				UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
		else
			if (not LInd) and LightOn then 
				UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
			else
				UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
			if (not RInd) and LightOn then 
				UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
			else
				UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
		end
	end
end