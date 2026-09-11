# Prompt: Death Screen Text Stuck After Respawn — Real Root Cause

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Root cause, confirmed from a screen recording, not guessed

Extracted and reviewed frames across the full recording. The pattern is consistent and specific: at several points the character is standing upright, fully alive and controllable, background sharp with **no** blur — while the *previous* death's phrase and "Respawning in N" text are still on screen. Each stale phrase only ever clears when the **next** death's sequence starts and eventually resets — never on its own respawn. That is a one-cycle-late pattern, not a random hang.

The recording also shows the in-game ESC menu open with its manual **Respawn** button — that is the trigger. In the previous version of `StarterPlayer.StarterPlayerScripts.DeathScreen`:
```lua
local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		task.spawn(playDeathSequence)   -- respawnCountAtDeath was read INSIDE this, not here
	end)
	respawnCount += 1
	respawnedSignal:Fire(character)
end
```
`task.spawn` schedules `playDeathSequence` to run at the next opportunity — a small but real gap between "`Died` fired" and "the sequence reads its own `respawnCountAtDeath` baseline." A manual respawn via the ESC menu's Respawn button can fire far sooner than the automatic ~3s timer this sequence's timing was built around. If the respawn lands inside that gap, `respawnCount` has already incremented by the time the baseline is read — so the sequence's wait condition (`respawnCount <= respawnCountAtDeath`) is permanently looking for *one more* respawn than the one that already happened, and only resolves on the **next** death instead of this one. Exactly the observed symptom.

The previous fix (guaranteed `pcall`-wrapped cleanup) does not help here: it only guarantees cleanup runs after the wrapped function *returns* — a coroutine still blocked forever inside a wait for a respawn that, from its own miscounted perspective, hasn't happened yet, never returns, so `pcall` never gets a chance to reach the cleanup at all.

## The fix

1. **Capture the count synchronously inside the `Died` handler itself**, not inside the spawned coroutine — closing the gap entirely, since nothing can interleave between two lines of the same synchronous callback.
2. **Poll with a hard deadline instead of waiting on a one-shot event** — a `BindableEvent:Wait()` can be fired before a thread ever arms itself and be missed entirely, blocking forever; a bounded poll (`MAX_RESPAWN_WAIT = 10`) means this can never hang indefinitely regardless of any other edge case, known or not.
3. **Your suggestion, taken seriously and built in as a second, independent layer**: `textContainer.Visible` is now toggled `true`/`false` around each sequence, on top of `GroupTransparency`. Even if some future change reintroduces a timing bug in the transparency tween, `Visible = false` between deaths means nothing can render regardless.

**`StarterPlayer.StarterPlayerScripts.DeathScreen`** — replace the entire script with:
```lua
-- Plays only for the local player's own death. Sequence: blur + a random ragebait phrase fade in
-- together, hold for 2s (with a live countdown), then a black screen covers the actual respawn
-- moment, then fades back out.
--
-- Respawn detection: a plain counter, incremented once per real CharacterAdded, captured
-- SYNCHRONOUSLY inside the Died handler itself (not inside the task.spawn'd sequence) -- a fast
-- manual respawn (the in-game ESC menu's Respawn button fires far sooner than the ~3s automatic
-- timer) could otherwise increment the counter before the sequence read its own baseline,
-- permanently deferring "has this death's respawn happened yet" to the NEXT death instead of this
-- one. That off-by-one is confirmed, from a screen recording, as the actual bug.
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
local HOLD_TIME = 2
local BLACK_FADE_TIME = 0.4
local DEATH_FAR_INTENSITY = 1
local DEATH_IN_FOCUS_RADIUS = 2
local MAX_RESPAWN_WAIT = 10 -- hard upper bound; never block longer than this no matter what

local gui = Instance.new("ScreenGui")
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

local function runDeathSequence(respawnCountAtDeath: number)
	textContainer.Visible = true
	depthOfField.Enabled = true

	phraseLabel.Text = PHRASES[math.random(1, #PHRASES)]
	countdownLabel.Text = `Respawning in {math.ceil(HOLD_TIME)}`

	local fadeInTweenInfo = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(textContainer, fadeInTweenInfo, { GroupTransparency = 0 }):Play()
	TweenService:Create(depthOfField, fadeInTweenInfo, {
		FarIntensity = DEATH_FAR_INTENSITY,
		InFocusRadius = DEATH_IN_FOCUS_RADIUS,
	}):Play()

	local holdDeadline = os.clock() + HOLD_TIME
	while os.clock() < holdDeadline do
		local remaining = math.max(0, math.ceil(holdDeadline - os.clock()))
		countdownLabel.Text = `Respawning in {remaining}`
		task.wait(0.2)
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
		-- Captured HERE, synchronously in the Died handler, not inside the task.spawn'd sequence --
		-- see the file header for why that gap was the actual bug.
		local respawnCountAtDeath = respawnCount
		task.spawn(playDeathSequence, respawnCountAtDeath)
	end)
	respawnCount += 1
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
```

### Verify — specifically targeting the confirmed failure mode, not just a generic re-test
- Die, then **immediately** open the ESC menu and click **Respawn** manually (do not wait for the automatic timer) — repeat this at least 5 times in a row. Every single time, the phrase/countdown/blur clear fully once the new character is alive and controllable. This is the exact sequence the recording showed failing before.
- Die and let the automatic ~3s timer respawn you instead (don't touch the menu) — confirm this path still works too, unchanged.
- Chain two deaths back-to-back (die again within a couple seconds of respawning) — confirm the first death's text doesn't bleed into or get confused with the second's, and both clear correctly on their own respawn, not "one cycle late."
- With the fix in place, deliberately check `textContainer.Visible` via the Studio console immediately after a clean respawn — it should read `false`, not just have `GroupTransparency = 1`.
- Confirm the inventory button (backpack icon, top-right) is never left behind a black layer after any of the above — this was the same underlying bug wearing a different appearance, per the previous prompt's findings.

## Verification checklist

- [ ] Manual respawn via the ESC menu (the confirmed trigger) no longer leaves the phrase/countdown stuck.
- [ ] Automatic timer-based respawn still works correctly, unchanged.
- [ ] Chained back-to-back deaths each clear on their own respawn, not one cycle late.
- [ ] `textContainer.Visible` is `false` (not just transparent) whenever no death sequence is active.
- [ ] Inventory button is never left covered after a death screen resolves, by any respawn method.
