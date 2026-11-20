-- Robbery interaction animations (developer 2026-11-20: "Add animations for robbing the cash register, using teh safe,
-- hacking teh computer so otehr players can see you interact with them"; picker "Every interaction"). A clip plays on
-- the local character, whose Animator replicates it to everyone, while a robbery prompt is held and while its minigame
-- is open. Which clip, by the prompt's ActionText; the ids come from ReplicatedStorage.Combat.Clips (one not uploaded
-- yet plays nothing).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clips = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Clips"))
local player = Players.LocalPlayer

-- While held (ActionText, lower case, contains the pattern): Register = grabbing; Kneel = down on a knee, then working.
local HOLDS = {
	{ "rob register", "Register" }, { "rob atm", "Register" }, { "rip out", "Register" }, { "rob thing", "Register" },
	{ "steal supplies", "Register" },
	{ "crack safe", "Kneel" }, { "attach c4", "Kneel" }, { "pick lock", "Kneel" }, { "deposit", "Kneel" },
}
-- Once triggered: a one-shot.
local TRIGGERED = { { "pick up", "PickUp" }, { "steal supplies", "PickUp" } }
-- While open (ScreenGui.Enabled).
local MINIGAMES = { LockpickGui = "Kneel", HackCodeGui = "Type", WordScrambleGui = "Type" }

local cache: { [string]: AnimationTrack } = {}
local animator: Animator? = nil
local current: string? = nil
local playing: { AnimationTrack } = {}
local holding: ProximityPrompt? = nil
local generation = 0

local function getAnimator(): Animator?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local found = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if found ~= animator then
		animator = found
		cache = {}
	end
	return found
end

local function kindOf(prompt: ProximityPrompt, list): string?
	local text = string.lower(prompt.ActionText)
	for _, entry in list do
		if string.find(text, entry[1], 1, true) then
			return entry[2]
		end
	end
	return nil
end

local function stop()
	generation += 1
	for _, track in playing do
		track:Stop(0.2)
	end
	table.clear(playing)
	current = nil
end

local function loop(use: string): AnimationTrack?
	local a = getAnimator()
	local track = a and Clips.track(a, use, cache)
	if track then
		track.Looped = true
		track:Play(0.15)
		table.insert(playing, track)
	end
	return track
end

local function start(kind: string)
	if current == kind then
		return
	end
	stop()
	current = kind
	if kind ~= "Kneel" then
		loop(kind)
		return
	end
	local a = getAnimator()
	local down = a and Clips.track(a, "KneelDown", cache)
	if not down then
		loop("KneelLoop")
		return
	end
	down.Looped = false
	down:Play(0.15)
	table.insert(playing, down)
	local mine = generation
	task.delay(math.max(0.2, (if down.Length > 0 then down.Length else 0.7) - 0.1), function()
		if generation == mine then
			loop("KneelLoop")
		end
	end)
end

local function minigameOpen(): boolean
	local gui = player:FindFirstChildOfClass("PlayerGui")
	for name in MINIGAMES do
		local screen = gui and gui:FindFirstChild(name)
		if screen and screen:IsA("ScreenGui") and screen.Enabled then
			return true
		end
	end
	return false
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local kind = kindOf(prompt, HOLDS)
	if kind then
		holding = prompt
		start(kind)
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	if prompt == holding then
		holding = nil
		if not minigameOpen() then
			stop()
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local kind = kindOf(prompt, TRIGGERED)
	if kind then
		stop()
		local a = getAnimator()
		local track = a and Clips.track(a, kind, cache)
		if track then
			track.Looped = false
			track:Play(0.1)
		end
	end
end)

-- Minigames keep their clip going while open.
local playerGui = player:WaitForChild("PlayerGui")
for name, kind in MINIGAMES do
	task.spawn(function()
		local screen = playerGui:WaitForChild(name, 30)
		if not (screen and screen:IsA("ScreenGui")) then
			return
		end
		screen:GetPropertyChangedSignal("Enabled"):Connect(function()
			if screen.Enabled then
				start(kind)
			elseif current == kind and not holding then
				stop()
			end
		end)
	end)
end

player.CharacterAdded:Connect(function()
	stop()
	holding = nil
end)
