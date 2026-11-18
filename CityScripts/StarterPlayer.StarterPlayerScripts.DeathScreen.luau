-- Plays only for the local player's own death. Sequence: blur + a random ragebait phrase fade in
-- together, hold for 2s (with a live countdown), then a black screen covers the actual respawn
-- moment, then fades back out.
--
-- Respawn detection: a plain counter, incremented once per real CharacterAdded, captured
-- SYNCHRONOUSLY inside the Died handler itself (not inside the task.spawn'd sequence) -- a fast
-- manual respawn (the in-game ESC menu's Respawn button fires far sooner than the ~3s automatic
-- timer) could otherwise increment the counter before the sequence read its own baseline,
-- permanently deferring "has this death's respawn happened yet" to the NEXT death instead of this
-- one.
--
-- The wait itself is a bounded poll, not an event Wait() -- a one-shot event fired before a
-- waiting thread arms itself is missed entirely, blocking forever. Polling with a hard deadline
-- (MAX_RESPAWN_WAIT) means this can never hang indefinitely no matter what else might be wrong.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ragebait phrases -- edit freely, this is content, not logic.
local PHRASES = {
	"Are you really a criminal?",
	"Better luck next time!",
	"Skill issue.",
	"That was embarrassing.",
	"Maybe try aiming next time?",
	"You call that a fight?",
	"The floor is a nice place, isn't it?",
	"Get good.",
	"Even the AI could've dodged that.",
	"Was that your best?",
	"Someone call the police... oh wait.",
	"You blinked. That's on you.",
	"Free real estate.",
	"Have you considered a new hobby?",
	"Wow. Just... wow.",
	"That's a rookie mistake.",
	"Down bad.",
	"Rest in pieces.",
	"L + ratio.",
	"Was worth it though, right?",
}

local FADE_IN_TIME = 0.5
local HOLD_TIME = 5
local BLACK_FADE_TIME = 0.4
local DEATH_FAR_INTENSITY = 1
local DEATH_IN_FOCUS_RADIUS = 2
local MAX_RESPAWN_WAIT = 10 -- hard upper bound; never block longer than this no matter what

local gui = Instance.new("ScreenGui")
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- Sibling: see UI Layout Traps; the template's TextContainer sits at its children's ZIndex so the order is the same in both modes
gui.Name = "DeathScreenGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local root = guiTemplates:WaitForChild("DeathScreen"):Clone()
root.Parent = gui

local blackOverlay = root:WaitForChild("BlackOverlay") :: Frame
local textContainer = root:WaitForChild("TextContainer") :: CanvasGroup
local phraseLabel = textContainer:WaitForChild("Phrase") :: TextLabel
local countdownLabel = textContainer:WaitForChild("Countdown") :: TextLabel

textContainer.Visible = false

local depthOfField = Lighting:WaitForChild("DepthOfField") :: DepthOfFieldEffect
local originalDoFEnabled = depthOfField.Enabled
local originalFarIntensity = depthOfField.FarIntensity
local originalInFocusRadius = depthOfField.InFocusRadius

local respawnCount = 0

-- Every other GUI is hidden for the length of the death sequence, the same way a panel hides the
-- HUD behind it. Each one's Enabled state is recorded first, so restoring never switches on
-- something the game had deliberately switched off -- a panel left open when you died, or the
-- blaster GUIs while no weapon is equipped.
local previousEnabled: { [Instance]: boolean } = {}

local function setOtherGuisHidden(hidden: boolean)
	if hidden then
		for _, child in playerGui:GetChildren() do
			-- `gui` is this script's own ScreenGui; hiding it would hide the death screen itself.
			if child:IsA("LayerCollector") and child ~= gui and previousEnabled[child] == nil then
				previousEnabled[child] = child.Enabled
				child.Enabled = false
			end
		end
	else
		for instance, wasEnabled in previousEnabled do
			if instance.Parent then
				instance.Enabled = wasEnabled
			end
		end
		table.clear(previousEnabled)
	end
end

local function runDeathSequence(respawnCountAtDeath: number)
	textContainer.Visible = true
	depthOfField.Enabled = true
	setOtherGuisHidden(true)

	phraseLabel.Text = PHRASES[math.random(1, #PHRASES)]
	countdownLabel.Text = `Respawning in {math.ceil(HOLD_TIME)}`

	local fadeInTweenInfo = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(textContainer, fadeInTweenInfo, { GroupTransparency = 0 }):Play()
	-- No scrim behind the plate. The Figma frame has one, but in game it dimmed the whole HUD --
	-- cash readout, hotbar, button column -- for the entire death sequence, which read as a fault
	-- rather than as atmosphere. blackOverlay is still used further down for the black curtain that
	-- covers the respawn instant; that is the only thing it does now.
	TweenService:Create(depthOfField, fadeInTweenInfo, {
		FarIntensity = DEATH_FAR_INTENSITY,
		InFocusRadius = DEATH_IN_FOCUS_RADIUS,
	}):Play()

	-- The hold ends early if the respawn has ALREADY happened. The in-game ESC menu's Respawn
	-- button fires far sooner than the ~3s automatic timer, and this hold used to run its full
	-- fixed duration regardless -- leaving the player alive and controllable for ~2.2s with the
	-- phrase, countdown and blur still on screen. That fixed duration, not any miscount, is what
	-- the "text still up while alive" reports actually were; measured 2.13/2.17/2.19s before this
	-- guard versus ~0.4s on the automatic path.
	local holdDeadline = os.clock() + HOLD_TIME
	while os.clock() < holdDeadline and respawnCount <= respawnCountAtDeath do
		local remaining = math.max(0, math.ceil(holdDeadline - os.clock()))
		countdownLabel.Text = `Respawning in {remaining}`
		task.wait(0.2)
	end

	-- Already respawned: there is no respawn moment left to hide, so skip the black curtain
	-- entirely and let the caller's guaranteed cleanup clear the overlay immediately.
	if respawnCount > respawnCountAtDeath then
		return
	end

	TweenService:Create(
		blackOverlay,
		TweenInfo.new(BLACK_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	):Play()
	task.wait(BLACK_FADE_TIME)

	-- Bounded poll for the real respawn -- see the file header for why this is a poll with a
	-- deadline rather than a one-shot event wait.
	local respawnDeadline = os.clock() + MAX_RESPAWN_WAIT
	while respawnCount <= respawnCountAtDeath and os.clock() < respawnDeadline do
		task.wait(0.1)
	end
end

local function playDeathSequence(respawnCountAtDeath: number)
	local ok, err = pcall(runDeathSequence, respawnCountAtDeath)
	if not ok then
		warn("DeathScreen: sequence failed, forcing reset:", err)
	end

	-- Guaranteed, whether the sequence above completed normally, errored, or hit the timeout.
	-- Visible = false on top of GroupTransparency = 1: fully removed from rendering between deaths,
	-- not just faded, so nothing can be left showing regardless of how it got here.
	textContainer.GroupTransparency = 1
	textContainer.Visible = false
	-- In the guaranteed-cleanup block, so the HUD comes back whether the sequence finished, errored
	-- or timed out. Leaving the player alive with no HUD would be far worse than the original bug.
	setOtherGuisHidden(false)
	depthOfField.FarIntensity = originalFarIntensity
	depthOfField.InFocusRadius = originalInFocusRadius
	depthOfField.Enabled = originalDoFEnabled

	TweenService:Create(
		blackOverlay,
		TweenInfo.new(BLACK_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		-- Captured HERE, synchronously in the Died handler, not inside the task.spawn'd sequence.
		local respawnCountAtDeath = respawnCount
		task.spawn(playDeathSequence, respawnCountAtDeath)
	end)
	respawnCount += 1
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
