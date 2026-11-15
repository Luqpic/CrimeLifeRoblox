--!strict
-- Swaps every ProximityPrompt's default Roblox face for the Figma one (UI.PromptUI).
-- Identical in the "FPS System" and "Robbery System" places -- keep it that way.
--
-- Style is forced to Custom here as well as on the saved prompts, because a prompt created at
-- runtime (or one a designer adds later and forgets to set) would otherwise draw Roblox's own
-- action/object text alongside this one, which is exactly the duplicate-chrome problem the panel
-- artwork already hit once in this project.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PromptUI = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("PromptUI"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Its own ScreenGui so nothing else's focus-mode hiding or fade binding reaches world prompts.
local screen = Instance.new("ScreenGui")
screen.Name = "PromptUiGui"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local function forceCustom(prompt: ProximityPrompt)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
		prompt.Style = Enum.ProximityPromptStyle.Custom
	end
end

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		forceCustom(d)
	end
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		forceCustom(d)
	end
end)

-- One live handle per shown prompt. Keyed by the prompt itself and cleared on PromptHidden, so a
-- prompt destroyed mid-hold cannot leave its billboard behind.
local shown: { [ProximityPrompt]: any } = {}
local holdConnections: { [ProximityPrompt]: RBXScriptConnection } = {}
-- Watches the prompt's own Enabled flag while its face is up. See the connection below for why.
local enabledWatch: { [ProximityPrompt]: RBXScriptConnection } = {}

local function stopWatch(prompt: ProximityPrompt)
	local conn = enabledWatch[prompt]
	if conn then
		conn:Disconnect()
		enabledWatch[prompt] = nil
	end
end

local function stopHold(prompt: ProximityPrompt)
	local conn = holdConnections[prompt]
	if conn then
		conn:Disconnect()
		holdConnections[prompt] = nil
	end
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	if shown[prompt] then
		return
	end
	local handle = PromptUI.create(prompt, screen)
	if not handle then
		return
	end
	shown[prompt] = handle
	handle.show()

	-- Disabling a prompt that is CURRENTLY ON SCREEN does not fire PromptHidden, so its face would
	-- sit there after the thing it belongs to is finished with. Seen live on the Bank buttons: the
	-- prompt read Enabled = false while its billboard was still up, long after the press landed.
	-- Watching the flag closes it the moment the game turns the prompt off.
	stopWatch(prompt)
	enabledWatch[prompt] = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			return
		end
		stopWatch(prompt)
		stopHold(prompt)
		local live = shown[prompt]
		if live then
			shown[prompt] = nil
			live.hide(live.destroy)
		end
	end)
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	stopHold(prompt)
	stopWatch(prompt)
	local handle = shown[prompt]
	if handle then
		-- Dropped from the live table first, so a re-show while this one is still fading builds a
		-- fresh handle instead of adopting one that is on its way out. The fade then destroys itself.
		shown[prompt] = nil
		handle.hide(handle.destroy)
	end
end)

-- The ring only means anything for a hold prompt. HoldDuration 0 triggers instantly, so there is
-- nothing to fill and the ring stays as an outline.
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	local handle = shown[prompt]
	if not handle then
		return
	end
	-- Pressing lifts the prompt whether or not there is a hold to fill, so an instant prompt still
	-- reacts to the key going down. The cursor drives the same state from the plate itself.
	handle.setLifted(true)
	if prompt.HoldDuration <= 0 then
		return
	end
	stopHold(prompt)
	local started = os.clock()
	holdConnections[prompt] = RunService.RenderStepped:Connect(function()
		local live = shown[prompt]
		if not live then
			stopHold(prompt)
			return
		end
		live.setProgress((os.clock() - started) / prompt.HoldDuration)
	end)
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	stopHold(prompt)
	local handle = shown[prompt]
	if handle then
		handle.setLifted(false)
		handle.setProgress(0)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	stopHold(prompt)
	local handle = shown[prompt]
	if handle then
		-- Drain, do NOT leave it full. The hold is spent the moment this fires, and the prompt often
		-- stays on screen afterwards -- an instant prompt, or an action the server refuses. Holding the
		-- meter at 1 left those sitting there brim-full with nothing left to do.
		handle.setLifted(false)
		handle.setProgress(0)
	end
end)
