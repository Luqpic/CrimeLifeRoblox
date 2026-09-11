# Prompt: Death Screen, Tweened Leveling Bar, Level-Up Shine VFX

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Context, confirmed live before writing this — read this first

- `Lighting.DepthOfField` (a `DepthOfFieldEffect`) already exists in the scene but is `Enabled = false` and referenced by **zero** scripts — confirmed by grep. Nothing else uses it, so the death screen is free to drive it without any conflict; its original values are still captured and restored rather than hardcoding a "reset to defaults," in case the scene's authored resting values ever matter for something else later.
- `ReplicatedStorage.VFX` already exists as an empty folder — the natural home for the new level-up shine template.
- There is **no** dedicated "death camera" — the file that sounds like it (`FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md`, Part 3) turned out to be a fix for a bug where dying while zoomed in left the player stuck in first person; death already falls back to Roblox's ordinary third-person camera once that fix is applied. So the death screen adds no camera logic of its own — it's a pure overlay on top of whatever the camera is already doing.
- `Players.RespawnTime` is already fixed at `3` (set by `PlayerRagdoll` to match the ragdoll hold duration) — the sequence below is timed to land close to that, but the actual reveal is driven by waiting for the real respawn (`CharacterAdded`), not a guessed timer, so it can't desync from Roblox's own respawn timing if it ever drifts.
- `StarterGui.Custom Inventory.InventoryController.toolButton.toolName` already uses a `UITextSizeConstraint` alongside `TextScaled` to keep text a sane size regardless of string length. The death phrases vary a lot in length ("L + ratio." vs "Even the AI could've dodged that."), so the phrase label reuses that same established pattern rather than letting short phrases balloon to fill the box.

---

## Part 1 — Templates (one-time setup)

Run this **once** (Command Bar, or a temporary `Script` you delete afterward) — same pattern as the earlier GUI-template setup scripts.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local templates = ReplicatedStorage:WaitForChild("GuiTemplates")

-- ============================================
-- DeathScreen
-- ============================================
do
	local root = Instance.new("Frame")
	root.Name = "DeathScreen"
	root.Size = UDim2.fromScale(1, 1)
	root.Position = UDim2.fromScale(0, 0)
	root.BackgroundTransparency = 1

	local blackOverlay = Instance.new("Frame")
	blackOverlay.Name = "BlackOverlay"
	blackOverlay.Size = UDim2.fromScale(1, 1)
	blackOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
	blackOverlay.BackgroundTransparency = 1
	blackOverlay.BorderSizePixel = 0
	blackOverlay.ZIndex = 10
	blackOverlay.Parent = root

	local textContainer = Instance.new("CanvasGroup")
	textContainer.Name = "TextContainer"
	textContainer.AnchorPoint = Vector2.new(0, 1)
	textContainer.Position = UDim2.new(0, 40, 1, -60)
	textContainer.Size = UDim2.fromOffset(560, 90)
	textContainer.BackgroundTransparency = 1
	textContainer.GroupTransparency = 1
	textContainer.ZIndex = 5
	textContainer.Parent = root

	local phrase = Instance.new("TextLabel")
	phrase.Name = "Phrase"
	phrase.Size = UDim2.new(1, 0, 0, 55)
	phrase.BackgroundTransparency = 1
	phrase.Font = Enum.Font.GothamBold
	phrase.TextScaled = true
	phrase.TextColor3 = Color3.new(1, 1, 1)
	phrase.TextXAlignment = Enum.TextXAlignment.Left
	phrase.Text = ""
	phrase.Parent = textContainer

	local phraseSizeConstraint = Instance.new("UITextSizeConstraint")
	phraseSizeConstraint.MaxTextSize = 40
	phraseSizeConstraint.Parent = phrase

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Position = UDim2.new(0, 0, 0, 58)
	countdown.Size = UDim2.new(1, 0, 0, 28)
	countdown.BackgroundTransparency = 1
	countdown.Font = Enum.Font.Gotham
	countdown.TextScaled = true
	countdown.TextColor3 = Color3.new(1, 1, 1)
	countdown.TextXAlignment = Enum.TextXAlignment.Left
	countdown.Text = ""
	countdown.Parent = textContainer

	local countdownSizeConstraint = Instance.new("UITextSizeConstraint")
	countdownSizeConstraint.MaxTextSize = 22
	countdownSizeConstraint.Parent = countdown

	root.Parent = templates
end

-- ============================================
-- LevelUpShine -- a single persistent, dormant ParticleEmitter template. Cloned once per character
-- at spawn (see Part 4), never cloned again after that -- level-ups only ever call :Emit() on the
-- existing instance, so there is no runtime Instance creation/destruction on level-up at all.
-- ============================================
do
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LevelUpShine"
	emitter.Enabled = false -- burst-only; :Emit() still works on a disabled emitter
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.6, 1)
	emitter.Speed = NumberRange.new(6, 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 245, 180), Color3.fromRGB(255, 215, 80))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = ReplicatedStorage.VFX
end
```

### Verify
- `ReplicatedStorage.GuiTemplates.DeathScreen` and `ReplicatedStorage.VFX.LevelUpShine` both exist.
- Only run this once; re-running duplicates them (delete the old ones first if you need to re-run it).

---

## Part 2 — `DeathScreen` (client)

**New `StarterPlayer.StarterPlayerScripts.DeathScreen`** (LocalScript):
```lua
-- Plays only for the local player's own death. Sequence: blur + a random ragebait phrase fade in
-- together, hold for 2s (with a live countdown), then a black screen covers the actual respawn
-- moment -- waited for via CharacterAdded, not a guessed timer, since Roblox's own respawn timing
-- isn't exact -- then fades back out.
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

local gui = Instance.new("ScreenGui")
gui.Name = "DeathScreenGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10 -- above the rest of the HUD; this is meant to cover the whole screen
gui.Parent = playerGui

local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")
local root = guiTemplates:WaitForChild("DeathScreen"):Clone()
root.Parent = gui

local blackOverlay = root:WaitForChild("BlackOverlay") :: Frame
local textContainer = root:WaitForChild("TextContainer") :: CanvasGroup
local phraseLabel = textContainer:WaitForChild("Phrase") :: TextLabel
local countdownLabel = textContainer:WaitForChild("Countdown") :: TextLabel

-- Captured once, restored exactly after each sequence -- nothing else currently touches
-- DepthOfField, but this avoids baking in an assumption about its resting values.
local depthOfField = Lighting:WaitForChild("DepthOfField") :: DepthOfFieldEffect
local originalDoFEnabled = depthOfField.Enabled
local originalFarIntensity = depthOfField.FarIntensity
local originalInFocusRadius = depthOfField.InFocusRadius

-- Fired every time this player's character actually respawns. The one CharacterAdded connection at
-- the bottom both binds the next Died and fires this, so a wait on it after a death cannot race:
-- the next real respawn is the earliest this can possibly fire relative to that wait.
local respawnedSignal = Instance.new("BindableEvent")

local function playDeathSequence()
	depthOfField.Enabled = true

	phraseLabel.Text = PHRASES[math.random(1, #PHRASES)]
	countdownLabel.Text = `Respawning in {math.ceil(HOLD_TIME)}`

	local fadeInTweenInfo = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(textContainer, fadeInTweenInfo, { GroupTransparency = 0 }):Play()
	TweenService:Create(depthOfField, fadeInTweenInfo, {
		FarIntensity = DEATH_FAR_INTENSITY,
		InFocusRadius = DEATH_IN_FOCUS_RADIUS,
	}):Play()

	-- Ticks the countdown down across the hold, matching the reference screenshot's
	-- "Respawning in N" readout.
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

	-- The actual respawn: waited for, not guessed. Everything is already fully hidden behind the
	-- black overlay by the time this resolves, however long Roblox's own respawn actually takes.
	respawnedSignal.Event:Wait()

	-- Reset instantly while still covered by black, so nothing is seen mid-reset.
	textContainer.GroupTransparency = 1
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
		task.spawn(playDeathSequence)
	end)
	respawnedSignal:Fire(character)
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)
```

### Verify
- Die: the background visibly blurs and a random phrase fades in at the bottom-left (bold white, consistent size whether the phrase is short or long), with a countdown ticking underneath.
- After the 2s hold, a black screen fades in; the actual respawn happens while covered (confirm by watching the output/character list — the old ragdoll is gone and the new character exists before the black screen starts fading back out).
- Black screen fades out to reveal the fresh spawn, blur and text both fully gone, `Lighting.DepthOfField` back to its original values (`Enabled = false`, original `FarIntensity`/`InFocusRadius`).
- Die several times in a row: a different-feeling random phrase each time (not always the same one — expected, `math.random` is per-client), no leftover GUI state or lingering blur from a previous death.
- Die while zoomed in first-person (requires the `BlasterController` fix from `FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md` Part 3 to already be applied): confirm the death screen still displays correctly over the reset third-person view.

---

## Part 3 — Tween the leveling bar's fill

**`StarterPlayer.StarterPlayerScripts.LevelingHud`** — replace `refreshBarValues` with:
```lua
local FILL_TWEEN_INFO = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local fillTween: Tween? = nil

local function refreshBarValues()
	local xp = (player:GetAttribute("XP") :: number?) or 0
	local nextLevelXp = (player:GetAttribute("NextLevelXP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	levelLabel.Text = `Lv. {level}`
	local fraction = if nextLevelXp > 0 then math.clamp(xp / nextLevelXp, 0, 1) else 1

	if fillTween then
		fillTween:Cancel()
	end
	fillTween = TweenService:Create(fill, FILL_TWEEN_INFO, { Size = UDim2.fromScale(fraction, 1) })
	fillTween:Play()
end
```
`TweenService` is already required at the top of this script (used by the level-up popup), so no new require is needed. Everything else in the file is unchanged.

Note on level-up specifically: since the fill resets to a low fraction for the new level's threshold, a level-up will visibly tween across the *whole* bar (sweeping from near-full back down near-empty) rather than jumping straight there — that's the simple, direct interpretation of "tween the progress bar." A fancier two-stage version (tween up to 100% first, then snap-and-tween from 0 for the overflow) is a small follow-up if the sweep-back reads oddly in practice, not included here since it wasn't asked for.

### Verify
- Gain XP without leveling up: the fill animates smoothly to the new fraction instead of snapping instantly.
- Gain enough XP to level up: the bar still animates (even across the reset), doesn't error, and ends at the correct fraction for the new level.
- Two XP gains in quick succession: the second tween cleanly cancels/replaces the first (no fighting/flicker), same cancel-before-replay pattern already used for the level-up popup's tweens.

---

## Part 4 — `LevelUpVFX` (client)

**New `StarterPlayer.StarterPlayerScripts.LevelUpVFX`** (LocalScript):
```lua
-- Bright particle shine on level-up, visible to every client -- Level already replicates to
-- everyone (same trick the player card uses), so this needs no RemoteEvent. One dormant, zero-cost
-- ParticleEmitter is attached once per character at spawn; leveling up only ever calls :Emit() on
-- it, so this never clones or destroys an Instance at runtime.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local shineTemplate = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("LevelUpShine")

local EMIT_COUNT = 30

local trackedLevels: { [Player]: number } = {}

local function onCharacterAdded(character: Model)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart then
		return
	end
	local shine = shineTemplate:Clone()
	shine.Parent = rootPart
end

local function onLevelChanged(player: Player)
	local level = (player:GetAttribute("Level") :: number?) or 1
	local lastLevel = trackedLevels[player]

	if lastLevel and level > lastLevel then
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		local shine = rootPart and rootPart:FindFirstChild("LevelUpShine")
		if shine and shine:IsA("ParticleEmitter") then
			shine:Emit(EMIT_COUNT)
		end
	end

	trackedLevels[player] = level
end

local function onPlayerAdded(player: Player)
	trackedLevels[player] = (player:GetAttribute("Level") :: number?) or 1

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	player:GetAttributeChangedSignal("Level"):Connect(function()
		onLevelChanged(player)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
```

### Verify
- Level up: a bright gold/white particle burst radiates outward from your own character, visible in third person.
- With a second player in the session: their level-up shine is visible to you too (and yours to them) — confirms this works without any server involvement, purely off the already-replicated `Level` attribute.
- Respawn after a level-up: the new character gets its own fresh `LevelUpShine` emitter (check `HumanoidRootPart` has exactly one `LevelUpShine` child, not zero and not stacking up duplicates across respawns).
- No continuous performance cost while idle: the emitter's `Enabled` stays `false` and `Rate` stays `0` at all times outside of the brief `:Emit()` burst — confirm in the Studio performance stats that this isn't contributing any steady-state particle count between level-ups.

## Verification checklist

- [ ] Death screen: blur + random phrase (from the 20 provided) fade in together, hold 2s with a ticking countdown, black screen covers the real respawn (event-driven, not a guessed timer), then fades out cleanly with `DepthOfField` restored to its original values.
- [ ] Leveling bar fill animates via tween on every XP change, including across a level-up reset.
- [ ] Level-up triggers a one-shot particle shine on the correct character, visible to every client, with zero idle/steady-state cost between level-ups.
- [ ] None of this affects existing behavior: guns' knockback, the level-up popup/sound, the leaderboard, or camera-reset-on-death are all unchanged.
