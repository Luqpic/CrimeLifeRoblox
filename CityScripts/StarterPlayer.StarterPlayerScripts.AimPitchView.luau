-- AimPitchView (2026-11-20): leans other players' upper bodies by the aim pitch their shoulder camera reports
-- (character attribute AimPitch, set by ServerScriptService.Blaster.Scripts.AimPitch), eased each frame through the
-- same waist / neck split as the shooter's own view (Blaster.Scripts.ShoulderCamera.tilt). Idle while nobody aims up or
-- down: the frame loop returns at once with no tilted character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShoulderCamera = require(ReplicatedStorage.Blaster.Scripts.ShoulderCamera)

local localPlayer = Players.LocalPlayer
local EASE = 12
local tilted = {} -- [character] = { waist, neck, current, target }

local function track(character: Model)
	local function changed()
		local target = character:GetAttribute("AimPitch")
		target = if type(target) == "number" then target else 0
		local entry = tilted[character]
		if not entry and target ~= 0 then
			entry = {
				waist = ShoulderCamera.joint(character, "UpperTorso", "Waist"),
				neck = ShoulderCamera.joint(character, "Head", "Neck"),
				current = 0,
			}
			tilted[character] = entry
		end
		if entry then
			entry.target = target
		end
	end
	character:GetAttributeChangedSignal("AimPitch"):Connect(changed)
	changed()
end

local function watch(player: Player)
	if player == localPlayer then
		return
	end
	player.CharacterAdded:Connect(track)
	if player.Character then
		track(player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

RunService.RenderStepped:Connect(function(dt: number)
	if next(tilted) == nil then
		return
	end
	local a = 1 - math.exp(-EASE * dt)
	for character, entry in tilted do
		if not character.Parent then
			tilted[character] = nil
			continue
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
