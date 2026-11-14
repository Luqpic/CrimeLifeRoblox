-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.Lights [FE+].Lights_FE.Handler ; copies: 1 ; Adler-32: 998d689a
local car = script.Parent.Parent
local Lights = car.Body.Lights
local F = {}

local LightOn = false
local LInd = false
local RInd = false
local pulseDur = 1

F.UpdateLight = function(prt,mat,col,trn,lon,lrg)
	prt.Material = mat
	prt.BrickColor = col
	prt.Transparency = trn
	prt.L.Enabled = lon
	prt.L.Range = lrg
end

F.ToggleBlinker = function(lo, li, ri, pd)
	LightOn = lo
	LInd = li
	RInd = ri
	pulseDur = pd
end


script.Parent.OnServerEvent:connect(function(pl,Fnc,...)
	F[Fnc](...)
end)

while wait(pulseDur) do
	if LInd or RInd then
		PsOn = not PsOn
		if PsOn then
			if LInd then
				F.UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,20)
				F.UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,15)
			end
			if RInd then
				F.UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,20)
				F.UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Br. yellowish orange"),0,true,15)
			end
		else
			if (not LInd) and LightOn then
				F.UpdateLight(Lights.FLI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
				F.UpdateLight(Lights.RLI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
			else
				F.UpdateLight(Lights.FLI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
				F.UpdateLight(Lights.RLI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
			if (not RInd) and LightOn then
				F.UpdateLight(Lights.FRI,Enum.Material.Neon,BrickColor.new("Institutional white"),0,false,20)
				F.UpdateLight(Lights.RRI,Enum.Material.Neon,BrickColor.new("Burgundy"),0.1,false,10)
			else
				F.UpdateLight(Lights.FRI,Enum.Material.SmoothPlastic,BrickColor.new("Institutional white"),0,false,20)
				F.UpdateLight(Lights.RRI,Enum.Material.SmoothPlastic,BrickColor.new("Burgundy"),0,false,10)
			end
		end
	end
end