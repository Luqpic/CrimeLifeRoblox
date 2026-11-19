-- AimPitchView (2026-11-20): leans other players' upper bodies by the aim pitch their shoulder camera reports
-- (character attribute AimPitch, set by ServerScriptService.Blaster.Scripts.AimPitch), eased each frame through the
-- same waist / neck split as the shooter's own view (Blaster.Scripts.ShoulderCamera.tilt).
-- Streaming-safe (review I3): no per-character connection; ten times a second each other player's current character
-- is read (a character streamed out and back in is a new instance and is simply picked up again), and the joints are
-- found when first needed and found again if they went away. The frame loop returns at once with no tilted character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShoulderCamera = require(ReplicatedStorage.Blaster.Scripts.ShoulderCamera)

local localPlayer = Players.LocalPlayer
local EASE = 12
local POLL = 0.1
local tilted = {} -- [character] = { waist, neck, current, target }
local sinceRead = 0

local function readTargets()
	for _, player in Players:GetPlayers() do
		local character = player ~= localPlayer and player.Character
		if character and character.Parent then
			local target = character:GetAttribute("AimPitch")
			target = if type(target) == "number" then target else 0
			local entry = tilted[character]
			if not entry and target ~= 0 then
				entry = { current = 0 }
				tilted[character] = entry
			end
			if entry then
				entry.target = target
			end
		end
	end
end

local function alive(joint)
	return joint and joint.alive()
end

RunService.RenderStepped:Connect(function(dt: number)
	sinceRead += dt
	if sinceRead >= POLL then
		sinceRead = 0
		readTargets()
	end
	if next(tilted) == nil then
		return
	end
	local a = 1 - math.exp(-EASE * dt)
	for character, entry in tilted do
		if not character.Parent then
			tilted[character] = nil
			continue
		end
		if not alive(entry.waist) then
			entry.waist = ShoulderCamera.joint(character, "UpperTorso", "Waist")
		end
		if not alive(entry.neck) then
			entry.neck = ShoulderCamera.joint(character, "Head", "Neck")
		end
		entry.current += (entry.target - entry.current) * a
		if entry.target == 0 and math.abs(entry.current) < 0.005 then
			entry.current = 0
		end
		ShoulderCamera.tilt(entry.waist, entry.neck, entry.current)
		if entry.current == 0 and entry.target == 0 then
			tilted[character] = nil
		end
	end
end)
