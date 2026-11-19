-- AimPitch (2026-11-20): a shoulder-camera player's aim pitch (Blaster.Scripts.ShoulderCamera reports it on the
-- UnreliableRemoteEvent Blaster.Remotes.AimPitch), kept on their character as attribute AimPitch so every other
-- client leans that upper body the same way (StarterPlayerScripts.AimPitchView). Only a finite number is taken,
-- clamped to +-SHOULDER_MAX_PITCH_DEGREES, at most one per AIM_PITCH_MIN_INTERVAL s; a 0 (the shoulder view ended) is
-- always taken so nobody is left tilted. Cosmetic only: nothing reads it for hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local shoulderMath = require(ReplicatedStorage.Blaster.Utility.shoulderMath)

local remote = ReplicatedStorage.Blaster.Remotes.AimPitch
local MAX_PITCH = math.rad(Constants.SHOULDER_MAX_PITCH_DEGREES)
local lastAt: { [Player]: number } = {}

remote.OnServerEvent:Connect(function(player: Player, value: any)
	local pitch = shoulderMath.acceptPitch(value, MAX_PITCH)
	local character = player.Character
	if pitch == nil or not character then
		return
	end
	local now = os.clock()
	if pitch ~= 0 and not shoulderMath.due(lastAt[player], now, Constants.AIM_PITCH_MIN_INTERVAL) then
		return
	end
	lastAt[player] = now
	character:SetAttribute("AimPitch", math.round(pitch * 100) / 100)
end)

Players.PlayerRemoving:Connect(function(player: Player)
	lastAt[player] = nil
end)
