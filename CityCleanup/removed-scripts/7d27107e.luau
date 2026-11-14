-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.AC6_SOUND_IDLE.AC6_FE_Sounds.Handler ; copies: 1 ; Adler-32: 7d27107e
local Sounds = {}
local F = {}

F.newSound = function(name,par,id,pitch,loop)
	for i,v in pairs(Sounds) do
		if i==name then
			v:Stop()
			v:Destroy()
		end
	end
	local sn = Instance.new("Sound",par)
	sn.Name = name
	sn.SoundId = id
	sn.Pitch = pitch
	sn.Looped = loop
	sn.AncestryChanged:connect(function(child,parent) print(parent) end)
	Sounds[name]=sn
end

F.updateSound = function(sound,id,pit,vol)
	local sn = Sounds[sound]
	if id~=sn.SoundId then sn.SoundId = id end
	if pit~=sn.Pitch then sn.Pitch = pit end
end


F.pauseSound = function(sound)
	Sounds[sound]:Pause()
end

F.stopSound = function(sound)
	Sounds[sound]:Stop()
end

F.removeSound = function(sound)
	Sounds[sound]:Stop()
	Sounds[sound]:Destroy()
	Sounds[sound]=nil
end

script.Parent.OnServerEvent:connect(function(pl,Fnc,...)
	F[Fnc](...)
end)