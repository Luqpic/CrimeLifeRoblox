-- Robbery interaction animations (developer 2026-11-20: "Add animations for robbing the cash register, using teh safe,
-- hacking teh computer so otehr players can see you interact with them"; picker "Every interaction"). A clip plays on
-- the local character, whose Animator replicates it to everyone, while a robbery prompt is held and while its minigame
-- is open. Which clip, by the prompt's ActionText; the ids come from ReplicatedStorage.Combat.Clips (one not uploaded
-- yet plays nothing).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

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
-- The action lock (developer 2026-11-20: "tween them into the place and fixate their character in that spot"; picker
-- "Locked until it ends"): the character eases to STAND_MIN..STAND_MAX studs from the object, facing it, over
-- TWEEN_SECONDS, and the movement controls are off until the hold ends or the minigame closes.
local STAND_MIN, STAND_MAX, TWEEN_SECONDS = 2.2, 3.2, 0.25

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

local controls: any = nil
local function getControls(): any
	if controls == nil then
		local ok, module = pcall(function()
			return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: any)
		end)
		controls = if ok and module then module:GetControls() else false
	end
	return controls or nil
end

local locked = false
local function unlock()
	if locked then
		locked = false
		local c = getControls()
		if c then
			c:Enable()
		end
	end
end

-- Lock the controls; with a prompt, ease into place in front of its object, facing it.
local function lock(prompt: ProximityPrompt?)
	if not locked then
		locked = true
		local c = getControls()
		if c then
			c:Disable()
		end
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local holder = prompt and prompt.Parent
	local target = if holder and holder:IsA("Attachment") then holder.WorldPosition
		elseif holder and holder:IsA("BasePart") then holder.Position
		else nil
	if not (root and target) then
		return
	end
	local flat = Vector3.new(root.Position.X - target.X, 0, root.Position.Z - target.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	local spot = Vector3.new(target.X, root.Position.Y, target.Z) + flat.Unit * math.clamp(flat.Magnitude, STAND_MIN, STAND_MAX)
	local goal = CFrame.lookAt(spot, Vector3.new(target.X, spot.Y, target.Z))
	local start = root.CFrame
	local began = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		local alpha = math.min(1, (os.clock() - began) / TWEEN_SECONDS)
		if not locked or not root.Parent then
			connection:Disconnect()
			return
		end
		root.CFrame = start:Lerp(goal, TweenService:GetValue(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		root.AssemblyLinearVelocity = Vector3.zero
		if alpha >= 1 then
			connection:Disconnect()
		end
	end)
end

local function stop()
	unlock()
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
		lock(prompt)
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
				lock(nil)
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
