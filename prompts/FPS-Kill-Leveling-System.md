# Prompt: Kill-Based Leveling System (XP, Level-Up Rewards, HUD)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Context, confirmed before writing this — read this first

This reuses two things already verified live in Studio, not assumed:

- `ServerScriptService.Blaster.Events.Eliminated` — the same BindableEvent `ServerScriptService.Weapons.Scripts.CashService` already listens to on every kill, firing `(shooter, humanoid, appliedDamage)` where `shooter` may be a `Player` or an enemy character `Model`. `CashService.getEnemyTier` tiers the dying character as `Melee`/`Pistol`/`AutoRifle` by reading its currently-equipped Tool's `infiniteAmmo`/`fireMode` attributes.
- `StarterPlayer.StarterPlayerScripts.StaminaHud` — the visual shell to match: a `CanvasGroup` dark plate + `Frame` fill + `UICorner`, styled from shared `HUD_*` values in `ReplicatedStorage.Movement.Constants`, fading in/out with `TweenService`. Its per-frame predict/reconcile logic is specific to stamina's continuous drain and is **not** reused here — XP only changes in discrete jumps on kills, so this system has no per-frame reconciliation.

**Deliberate difference from Cash:** `CashService` explicitly excludes PvP kills ("Only enemies drop cash, never another player, so this cannot be farmed via PvP"). Leveling has no such restriction — both AI and PvP kills grant XP, per design.

**A real integration hazard, found while designing this, not guessed:** `CashService.onPlayerAdded` currently returns early if `player:FindFirstChild("leaderstats")` already exists:
```lua
local function onPlayerAdded(player: Player)
	if player:FindFirstChild("leaderstats") then
		return
	end
	local leaderstats = Instance.new("Folder")
	...
```
Once a second script (`LevelingService`, below) also creates a `Level` value in the same shared `leaderstats` folder, whichever of the two sibling scripts' `PlayerAdded` handlers happens to run first will create the folder — and if that's `LevelingService`, `CashService`'s guard sees the folder already exists and returns **before ever creating the `Cash` value**, silently breaking Cash. Script initialization order between sibling scripts in `ServerScriptService` is not guaranteed, so this must be fixed, not hoped around.

**Fix — make `CashService`'s guard per-value, not per-folder** (small, required, not a driveby refactor — this race did not exist before a second script needed to touch the same folder):
```lua
local function onPlayerAdded(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	if leaderstats:FindFirstChild("Cash") then
		return
	end

	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = STARTING_CASH
	cash.Parent = leaderstats
end
```

**Deliberately session-only, matching Cash:** there is no `DataStoreService` anywhere in this codebase yet. Level/XP resets on every join, exactly like Cash's `STARTING_CASH` re-initialization — this does not add persistence.

---

## Part 1 — Leveling constants

**New `ReplicatedStorage.Leveling.Constants`** (new top-level `Leveling` folder, sibling to `Blaster`/`Movement`/`Enemy`):
```lua
-- Shared constants for the kill-based leveling system. Placeholders, not balance -- tune freely.
local Constants = {}

Constants.XP_VALUES = {
	Melee = 10,
	Pistol = 15,
	AutoRifle = 20,
}

Constants.LEVEL_CAP = 10
Constants.BASE_XP_TO_LEVEL = 30
Constants.XP_INCREMENT_PER_LEVEL = 15

-- XP required to advance from `level` to `level + 1`. Only meaningful for level < LEVEL_CAP.
function Constants.xpToNextLevel(level: number): number
	return Constants.BASE_XP_TO_LEVEL + Constants.XP_INCREMENT_PER_LEVEL * (level - 1)
end

Constants.MAX_HEALTH_PER_LEVEL = 2
Constants.CASH_PER_LEVEL_UP = 25

Constants.LEVEL_UP_SOUND_ID = "rbxassetid://134821092416328"

return Constants
```
With these values, reaching the level 10 cap takes ~810 cumulative XP (~50-60 kills at the average tier) — reachable within a single session, which matters since progress resets every join.

### Verify
- `require(ReplicatedStorage.Leveling.Constants)` works from a server script with no errors.
- `Constants.xpToNextLevel(1)` returns `30`; `Constants.xpToNextLevel(9)` returns `150`.

---

## Part 2 — `LevelingService` (server)

**New `ServerScriptService.Weapons.Scripts.LevelingService`** (sibling to `CashService`, same domain):
```lua
-- Kill-based leveling: XP is granted on every kill by a real player, for both AI and PvP kills --
-- unlike CashService, which deliberately excludes PvP so cash can't be farmed that way. Session-only,
-- matching how Cash already resets on every join; this does not add a DataStore.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)

-- Source of truth for the MaxHealth bonus on respawn -- leaderstats.Level is the display copy.
local playerLevels: { [Player]: number } = {}

local function applyMaxHealth(character: Model, level: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.MaxHealth = 100 + LevelingConstants.MAX_HEALTH_PER_LEVEL * (level - 1)
	humanoid.Health = humanoid.MaxHealth
end

local function onPlayerAdded(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local level = leaderstats:FindFirstChild("Level")
	if not level then
		level = Instance.new("IntValue")
		level.Name = "Level"
		level.Value = 1
		level.Parent = leaderstats
	end

	playerLevels[player] = level.Value
	-- Mirrored as attributes (alongside the leaderstats IntValue) so the client HUD can use one
	-- consistent GetAttributeChangedSignal-based replication path for XP, NextLevelXP, and Level.
	player:SetAttribute("Level", level.Value)
	player:SetAttribute("XP", 0)
	player:SetAttribute("NextLevelXP", LevelingConstants.xpToNextLevel(level.Value))

	player.CharacterAdded:Connect(function(character: Model)
		applyMaxHealth(character, playerLevels[player] or level.Value)
	end)
	if player.Character then
		applyMaxHealth(player.Character, playerLevels[player] or level.Value)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	playerLevels[player] = nil
end)

-- Same tier detection CashService.getEnemyTier uses, duplicated rather than shared -- this one also
-- runs against player victims (for PvP), which CashService's version never needs to.
local function getCharacterTier(character: Model): string
	local weapon = character:FindFirstChildOfClass("Tool")
	if not weapon then
		return "Pistol" -- reasonable middle tier if somehow unarmed
	end
	if weapon:GetAttribute(BlasterConstants.INFINITE_AMMO_ATTRIBUTE) then
		return "Melee"
	end
	if weapon:GetAttribute(BlasterConstants.FIRE_MODE_ATTRIBUTE) == BlasterConstants.FIRE_MODE.AUTO then
		return "AutoRifle"
	end
	return "Pistol"
end

local function grantXp(player: Player, amount: number)
	local level = playerLevels[player] or 1
	if level >= LevelingConstants.LEVEL_CAP then
		return -- capped: extra XP is simply dropped, nothing left to progress toward
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")

	local xp = ((player:GetAttribute("XP") :: number?) or 0) + amount

	-- Looped, not a single if, so a large XP grant can correctly cross more than one level at once.
	while level < LevelingConstants.LEVEL_CAP do
		local needed = LevelingConstants.xpToNextLevel(level)
		if xp < needed then
			break
		end
		xp -= needed
		level += 1

		if levelValue then
			levelValue.Value = level
		end
		player:SetAttribute("Level", level)

		if cash then
			cash.Value += LevelingConstants.CASH_PER_LEVEL_UP
		end

		local character = player.Character
		if character then
			applyMaxHealth(character, level)
		end
	end

	playerLevels[player] = level

	local capped = level >= LevelingConstants.LEVEL_CAP
	player:SetAttribute("XP", if capped then 0 else xp)
	player:SetAttribute("NextLevelXP", if capped then 0 else LevelingConstants.xpToNextLevel(level))
end

-- Reuses the same Eliminated BindableEvent CashService listens to -- no new event, no second place
-- that has to learn what a kill is. Unlike CashService, this does NOT check whether the dying
-- character is tagged as an enemy: PvP kills grant XP too, by design.
local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end

	local character = humanoid.Parent
	if not character then
		return
	end

	grantXp(shooter, LevelingConstants.XP_VALUES[getCharacterTier(character :: Model)])
end)
```

### Verify
- Kill an AI enemy of each tier: `player.leaderstats.Level` and the `Level`/`XP`/`NextLevelXP` attributes update correctly; a kill that crosses two level thresholds at once (e.g. via a script-forced large XP grant in a test) correctly applies both level-ups, not just one.
- Kill another player (PvP): XP is granted the same as an AI kill of the same weapon tier; confirm `CashService` does **not** grant Cash for this kill (unchanged, still enemy-only) while `LevelingService` does grant XP — two independent, non-conflicting reactions to the same `Eliminated` event.
- Reach the level cap (10): further kills grant no more levels, `XP`/`NextLevelXP` attributes read `0`, no errors.
- Die and respawn mid-session at a level above 1: `Humanoid.MaxHealth` on the new character reflects the current level's bonus, not the base 100.
- Rejoin the game (simulate via `Players.PlayerRemoving` then `PlayerAdded`, or actually leave/rejoin in Studio): Level/XP reset to 1/0, matching Cash's own reset-on-join behavior.
- With both `LevelingService` and `CashService` present, force `LevelingService`'s `PlayerAdded` handler to run first for a new player (or just verify in Play mode with both scripts live) and confirm `leaderstats.Cash` still gets created with `STARTING_CASH` — this is the exact race the Part-1 fix addresses.

---

## Part 3 — `LevelingHud` (client)

**New `StarterPlayer.StarterPlayerScripts.LevelingHud`** (LocalScript, matching `StaminaHud`'s naming and structure):
```lua
-- Leveling HUD: a persistent XP progress bar (bottom-centre, fades in on XP gain / out when idle,
-- mirroring the visual shell of StarterPlayer.StarterPlayerScripts.StaminaHud) plus a separate,
-- more prominent level-up popup + sound. XP only changes in discrete jumps on kills -- unlike
-- stamina, there is no continuous drain/regen to predict, so this has no per-frame reconciliation.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MovementConstants = require(ReplicatedStorage.Movement.Constants)
local LevelingConstants = require(ReplicatedStorage.Leveling.Constants)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Bar size/position are specific to this bar (StaminaHud's own HUD_WIDTH/HUD_HEIGHT/HUD_TOP_OFFSET
-- are for its top-centre placement); colour/corner/fade timing are borrowed from MovementConstants
-- for visual consistency with the rest of this game's HUD.
local BAR_WIDTH = 260
local BAR_HEIGHT = 14
local BAR_BOTTOM_OFFSET = 140 -- starting estimate above the hotbar; verify in Play mode, nudge if needed
local BAR_HOLD_TIME = 2

local POPUP_HOLD_TIME = 1.5
local POPUP_FADE_TIME = 0.5

local fadeTweenInfo =
	TweenInfo.new(MovementConstants.HUD_FADE_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local gui = Instance.new("ScreenGui")
gui.Name = "LevelingGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ============================================
-- XP BAR
-- ============================================
local bar = Instance.new("CanvasGroup")
bar.Name = "Bar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.new(0.5, 0, 1, -BAR_BOTTOM_OFFSET)
bar.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
bar.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
bar.BackgroundTransparency = MovementConstants.HUD_BACKGROUND_TRANSPARENCY
bar.BorderSizePixel = 0
bar.GroupTransparency = 1
bar.Parent = gui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
barCorner.Parent = bar

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.AnchorPoint = Vector2.new(0, 0.5)
fill.Position = UDim2.fromScale(0, 0.5)
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = MovementConstants.HUD_FILL_COLOR
fill.BorderSizePixel = 0
fill.Parent = bar

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
fillCorner.Parent = fill

local levelLabel = Instance.new("TextLabel")
levelLabel.Name = "LevelLabel"
levelLabel.BackgroundTransparency = 1
levelLabel.Size = UDim2.fromScale(1, 1)
levelLabel.Font = Enum.Font.GothamBold
levelLabel.TextScaled = true
levelLabel.TextColor3 = Color3.new(1, 1, 1)
levelLabel.Text = "Lv. 1"
levelLabel.Parent = bar

-- ============================================
-- LEVEL-UP POPUP
-- ============================================
local popup = Instance.new("Frame")
popup.Name = "LevelUpPopup"
popup.AnchorPoint = Vector2.new(0.5, 0.5)
popup.Position = UDim2.fromScale(0.5, 0.35)
popup.Size = UDim2.fromOffset(360, 90)
popup.BackgroundColor3 = MovementConstants.HUD_BACKGROUND_COLOR
popup.BackgroundTransparency = 1
popup.BorderSizePixel = 0
popup.Parent = gui

local popupCorner = Instance.new("UICorner")
popupCorner.CornerRadius = UDim.new(0, MovementConstants.HUD_CORNER_RADIUS)
popupCorner.Parent = popup

local popupLabel = Instance.new("TextLabel")
popupLabel.Name = "Label"
popupLabel.BackgroundTransparency = 1
popupLabel.Size = UDim2.fromScale(1, 1)
popupLabel.Font = Enum.Font.GothamBold
popupLabel.TextScaled = true
popupLabel.TextColor3 = Color3.new(1, 1, 1)
popupLabel.TextTransparency = 1
popupLabel.Text = ""
popupLabel.Parent = popup

local levelUpSound = Instance.new("Sound")
levelUpSound.Name = "LevelUpSound"
levelUpSound.SoundId = LevelingConstants.LEVEL_UP_SOUND_ID
levelUpSound.Parent = popup

gui.Parent = playerGui

-- ============================================
-- STATE
-- ============================================
local barVisible = false
local barFadeTween: Tween? = nil
local barHideThread: thread? = nil
local popupHideThread: thread? = nil
local lastKnownLevel: number? = nil

local function setBarVisible(shouldShow: boolean)
	if shouldShow == barVisible then
		return
	end
	barVisible = shouldShow
	if barFadeTween then
		barFadeTween:Cancel()
	end
	barFadeTween = TweenService:Create(bar, fadeTweenInfo, { GroupTransparency = if shouldShow then 0 else 1 })
	barFadeTween:Play()
end

local function showBarThenFade()
	setBarVisible(true)
	if barHideThread then
		task.cancel(barHideThread)
	end
	barHideThread = task.delay(BAR_HOLD_TIME, function()
		setBarVisible(false)
	end)
end

local function showLevelUpPopup(level: number)
	popupLabel.Text = `LEVEL UP! Lv. {level}`
	levelUpSound:Play()

	if popupHideThread then
		task.cancel(popupHideThread)
	end

	TweenService:Create(
		popup,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = MovementConstants.HUD_BACKGROUND_TRANSPARENCY }
	):Play()
	TweenService:Create(
		popupLabel,
		TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ TextTransparency = 0 }
	):Play()

	popupHideThread = task.delay(POPUP_HOLD_TIME, function()
		TweenService:Create(
			popup,
			TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		):Play()
		TweenService:Create(
			popupLabel,
			TweenInfo.new(POPUP_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		):Play()
	end)
end

-- ============================================
-- WIRING
-- ============================================
-- Paints the bar from the current attribute values without triggering the show/fade animation --
-- used for the initial, quiet paint so joining doesn't flash the bar at 0%.
local function refreshBarValues()
	local xp = (player:GetAttribute("XP") :: number?) or 0
	local nextLevelXp = (player:GetAttribute("NextLevelXP") :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	levelLabel.Text = `Lv. {level}`
	local fraction = if nextLevelXp > 0 then math.clamp(xp / nextLevelXp, 0, 1) else 1
	fill.Size = UDim2.fromScale(fraction, 1)
end

local function onXpChanged()
	refreshBarValues()
	showBarThenFade()
end

local function onLevelChanged()
	local level = (player:GetAttribute("Level") :: number?) or 1
	-- Guards against a false popup from the initial attribute set on join: lastKnownLevel is seeded
	-- by a plain read below, before this signal is connected, so the first real change is the
	-- earliest this can fire.
	if lastKnownLevel and level > lastKnownLevel then
		showLevelUpPopup(level)
	end
	lastKnownLevel = level
	refreshBarValues()
	showBarThenFade()
end

refreshBarValues()
lastKnownLevel = (player:GetAttribute("Level") :: number?) or 1

player:GetAttributeChangedSignal("XP"):Connect(onXpChanged)
player:GetAttributeChangedSignal("NextLevelXP"):Connect(onXpChanged)
player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
```

### Verify
- Join the game: the XP bar is not visible at first (no flash at 0%), no level-up popup fires just from joining.
- Kill an enemy: the bar fades in showing partial fill and the correct level number, then fades out after ~2s of no further change.
- Level up: the bottom bar updates (resets toward 0 fill for the new level's threshold, or shows full/`NextLevelXP = 0` text state if now capped) **and** the center popup shows "LEVEL UP! Lv. N", fading in/out, with `rbxassetid://134821092416328` audibly playing exactly once per level-up (not once per XP tick).
- A kill that crosses two levels at once (see Part 2 test) still only shows/plays the popup logic correctly — confirm it doesn't double-fire or show a stale level number.
- Screenshot the bottom bar with a full hotbar of weapons visible underneath: confirm no overlap; nudge `BAR_BOTTOM_OFFSET` if there is one.
- Reach the level cap: bar shows a sensible "maxed" state (full bar, no further changes on subsequent kills), no errors.

## Verification checklist

- [ ] `CashService`'s leaderstats guard is fixed to be per-value, not per-folder; Cash still initializes correctly regardless of whether `CashService` or `LevelingService`'s `PlayerAdded` handler runs first.
- [ ] Both AI and PvP kills grant XP; only AI kills (unchanged) grant Cash drops.
- [ ] Leveling up grants `+2 MaxHealth` (felt immediately, and correctly re-applied after respawn) and `+25 Cash`.
- [ ] `Level` appears in the default leaderboard via `leaderstats`, alongside `Cash`.
- [ ] Level/XP reset to 1/0 on every join, matching Cash's own session-only behavior — no DataStore added.
- [ ] Level cap (10) holds: no further leveling or XP display past it, no errors.
- [ ] XP bar visually matches `StaminaHud`'s shell (dark plate, rounded corners, same fade behavior) but fades on XP-gain-then-idle rather than stamina's continuous logic.
- [ ] Level-up popup shows "LEVEL UP! Lv. N", fades in/out, and plays `rbxassetid://134821092416328` exactly once per level-up.
- [ ] A single kill that crosses multiple level thresholds applies all of them correctly (Cash, MaxHealth, and the popup/bar state all end up consistent with the final level, not the intermediate ones).
