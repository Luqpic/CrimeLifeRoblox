# Prompt: Quest System (Level 1 — Defeat 10 Thugs), Built on Your Dialogue Template

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode
verification). It is self-contained.

## Context — read this first

This was brainstormed first (architectural-scope feature: new data model, new NPC interaction flow,
new GUI, reward flow, level-gating, damage immunity — no existing quest flow to extend). Every
technical claim below was verified live against the actual instances immediately before writing this.

**What you dropped in, confirmed live:**
- `Workspace."Dialogue System"` — a third-party dialogue asset, not yet "ungrouped" into place. Its
  pieces: `Ungroup in ReplicatedStorage.DialogModule` (the dialogue engine, a `ModuleScript`),
  `Ungroup in StarterGui.dialog` (the response-choice `ScreenGui`), `Ungroup in Workspace."showcase npc"`
  (a demo R6 rig wired up as an example), and a `READ ME` LocalScript with setup notes.
- `Workspace.Quests."Level 1 Quest"` — your prepared NPC rig. It's a full **R15** rig (matching this
  game's own enemy templates), not the demo's R6 shape.

**Four real problems in the template, found by reading its actual source, not assumed:**
1. `DialogModule`'s response UI is resolved via `game.Players.LocalPlayer` at the top of the module —
   it only works running **client-side**. The demo's `dialogScript` is currently a `Script` (server),
   which would error the instant it runs (`LocalPlayer` is `nil` on the server). It must be a
   `LocalScript`.
2. `DialogModule:triggerDialog`'s "close the dialogue if the player walks away" loop hardcodes
   `self.npc.Torso.Position` — an R6-only part name. Your R15 rig has no `Torso` (only
   `UpperTorso`/`LowerTorso`), so this errors the moment a conversation's responses are shown. Needs a
   rig-agnostic reference.
3. The floating name/dialogue bubble (`Head.gui`, a `BillboardGui` with `name`/`arrow`/`dialog`
   `TextLabel`s) only exists on the demo's R6 `Head`. Your R15 rig's `Head` has no `gui` child — it
   needs to be built there.
4. `DialogModule` tweens `Workspace.CurrentCamera.FieldOfView` directly for its talking-zoom effect —
   the same anti-pattern already fixed for the shop/player-card FOV+blur. It should route through
   `CameraAuthority.FieldOfView`'s existing `"Menu"` source instead, so a conversation can't fight ADS
   zoom or the shop/card menus (all three can coexist correctly since `CameraAuthority` already
   arbitrates and `MenuFovBlur` is already reference-counted).

**Two gaps in the existing FPS systems this quest needs, neither optional:**
- `canDamageHumanoid` (`ReplicatedStorage.Blaster.Utility.canDamageHumanoid` — the single gate both
  player and AI shots go through) currently returns `true` unconditionally for any non-player
  humanoid. Confirmed live: nothing today stops a player from shooting an NPC. Needs one new
  tag-based early return.
- `EnemySpawner` renames every spawned clone to the generic `"Enemy"` (confirmed live in
  `EnemySpawner.trySpawn`), so nothing downstream can tell a dead enemy was specifically a `Thug`
  versus any other type. Needs one attribute stamped at spawn time.

**Reused deliberately, not reinvented:** the `Eliminated` BindableEvent kill-tracking is fired
already; the reward routes real XP through `LevelingService`'s own `grantXp` (via a new narrow
`BindableEvent`, the same integration shape `Eliminated`/`Tagged` already use elsewhere in this
codebase — kept as an event rather than turning `LevelingService` into a general import, matching how
every other cross-system link here already works) so level-up thresholds and the max-health-per-level
side effect can't drift out of sync with kill-based leveling. Cash is granted with a direct
`leaderstats.Cash.Value` mutation — there's no shared logic to reuse there, `CashService`'s own reward
paths are exactly that simple.

**Design decisions locked in during brainstorming (stated so you can see the reasoning, not just the
result):**
- Quest completion requires returning to the NPC and choosing to turn it in — accepting is not the
  same click as collecting the reward.
- Reward is 500 Cash + 100 XP, calibrated against this game's own economy (doubles a fresh player's
  starting Cash; jumps roughly 3 levels' worth of XP at once).
- Built as a small **generic, data-driven quest framework** (one `QuestDefinitions` table, one
  `QuestService`), not a one-off hardcoded to this single quest — you said "concurrent quests" and
  "for now we just build level 1 first," implying more are coming. Adding quest #2 later is a new
  table entry, not new plumbing.
- Quests are session-only, matching every other piece of state in this game (Cash, Level, weapon
  ownership) — there is no `DataStore` anywhere in this codebase yet.

---

## Part 1 — Server: quest data, `QuestService`, and the two systemic gaps

### `ReplicatedStorage.Quests.QuestConfig` (new `ModuleScript`)

```lua
-- Shared quest definitions and the attribute-naming scheme, required by both QuestService and every
-- client that needs to read quest state (the NPC dialogue script, the Quest Log GUI). Mirrors
-- UpgradeConfig's role for the weapon-upgrade system -- one place the shape and naming can't drift.
local QuestConfig = {}

export type QuestDefinition = {
	name: string,
	description: string,
	npcName: string, -- must match a Model directly under Workspace.Quests
	requiredLevel: number,
	objectiveType: "KillCount", -- only type implemented today; the shape allows more later
	objectiveEnemyTemplate: string, -- must match an EnemySpawner EnemyTemplate attribute value
	objectiveTarget: number,
	rewardCash: number,
	rewardXp: number,
}

QuestConfig.Quests: { [string]: QuestDefinition } = {
	Level1Thugs = {
		name = "A Warning to Thugs",
		description = "Defeat 10 Thugs.",
		npcName = "Level 1 Quest",
		requiredLevel = 1,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Thug",
		objectiveTarget = 10,
		rewardCash = 500,
		rewardXp = 100,
	},
}

-- Same illegal-character problem UpgradeConfig already solves for weapon names -- quest ids here are
-- authored as plain identifiers already, but this keeps the attribute-naming scheme consistent and
-- future-proof against a quest id that isn't.
local function sanitize(id: string): string
	return (string.gsub(id, "[^%w_]", "_"))
end

function QuestConfig.stateAttributeFor(questId: string): string
	return "Quest_" .. sanitize(questId) .. "_State"
end

function QuestConfig.progressAttributeFor(questId: string): string
	return "Quest_" .. sanitize(questId) .. "_Progress"
end

-- Values the *_State attribute can hold. Absent/"" means never accepted.
QuestConfig.STATE_ACCEPTED = "Accepted"
QuestConfig.STATE_READY_TO_TURN_IN = "ReadyToTurnIn"
QuestConfig.STATE_COMPLETED = "Completed"

return QuestConfig
```

### `ReplicatedStorage.Quests.Remotes` (new `Folder`) with two new `RemoteEvent`s

Create `ReplicatedStorage.Quests.Remotes.AcceptQuestRequest` and
`ReplicatedStorage.Quests.Remotes.TurnInQuestRequest` (both `RemoteEvent`).

### `ServerScriptService.Quests.Scripts.QuestService` (new `Script`)

```lua
-- Three responsibilities: (1) tag every quest-giver NPC Invulnerable at server start, from the same
-- QuestConfig data everything else reads, so a new quest's NPC is protected automatically without a
-- second place remembering to do it; (2) track quest acceptance/progress/completion per player,
-- session-only, replicated via Player Attributes exactly like Level/Cash/WeaponUpgrade already are;
-- (3) handle accept/turn-in requests and the kill-count objective.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)
local safePlayerAdded = require(ReplicatedStorage.Utility.safePlayerAdded)

local acceptQuestRequest = ReplicatedStorage.Quests.Remotes.AcceptQuestRequest
local turnInQuestRequest = ReplicatedStorage.Quests.Remotes.TurnInQuestRequest
local eliminatedEvent = ServerScriptService.Blaster.Events.Eliminated

local INVULNERABLE_TAG = "Invulnerable"

-- Fired to hand XP off to LevelingService, so level-up thresholds and the max-health-per-level side
-- effect stay owned by the one place that already implements them correctly -- not duplicated here.
local grantXpEvent = Instance.new("BindableEvent")
grantXpEvent.Name = "GrantXp"
grantXpEvent.Parent = script

-- ============================================
-- NPC SETUP -- tag every quest-giver from data, once, at server start
-- ============================================
local questsFolder = Workspace:FindFirstChild("Quests")
for questId, quest in QuestConfig.Quests do
	local npc = questsFolder and questsFolder:FindFirstChild(quest.npcName)
	if npc then
		CollectionService:AddTag(npc, INVULNERABLE_TAG)
	else
		warn(`QuestService: no NPC named "{quest.npcName}" under Workspace.Quests for quest "{questId}"`)
	end
end

-- ============================================
-- STATE (session-only, matches Cash/Leveling/weapon ownership)
-- ============================================
-- questId -> {progress: number, state: string}. Absent questId = never accepted.
local playerQuests: { [Player]: { [string]: { progress: number, state: string } } } = {}

local function publishQuestAttributes(player: Player, questId: string)
	local quests = playerQuests[player]
	local entry = quests and quests[questId]
	player:SetAttribute(QuestConfig.stateAttributeFor(questId), entry and entry.state or "")
	player:SetAttribute(QuestConfig.progressAttributeFor(questId), entry and entry.progress or 0)
end

safePlayerAdded(function(player: Player)
	playerQuests[player] = {}
end)

Players.PlayerRemoving:Connect(function(player: Player)
	playerQuests[player] = nil
end)

-- ============================================
-- ACCEPT
-- ============================================
acceptQuestRequest.OnServerEvent:Connect(function(player: Player, questId: any)
	if typeof(questId) ~= "string" then
		return
	end
	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end

	local quests = playerQuests[player]
	if not quests then
		return
	end
	if quests[questId] then
		return -- already accepted, in progress, ready, or completed -- accept is one-shot
	end

	local level = (player:GetAttribute("Level") :: number?) or 1
	if level < quest.requiredLevel then
		return -- client should already be refusing to offer this; server is the real gate
	end

	quests[questId] = { progress = 0, state = QuestConfig.STATE_ACCEPTED }
	publishQuestAttributes(player, questId)
end)

-- ============================================
-- KILL TRACKING -- KillCount objective only, matching what's implemented today
-- ============================================
eliminatedEvent.Event:Connect(function(shooter: Player | Model, humanoid: Humanoid)
	if typeof(shooter) ~= "Instance" or not shooter:IsA("Player") then
		return
	end
	local character = humanoid.Parent
	local enemyTemplate = character and character:GetAttribute("EnemyTemplate")
	if not enemyTemplate then
		return
	end

	local quests = playerQuests[shooter]
	if not quests then
		return
	end

	for questId, entry in quests do
		if entry.state ~= QuestConfig.STATE_ACCEPTED then
			continue
		end
		local quest = QuestConfig.Quests[questId]
		if not quest or quest.objectiveType ~= "KillCount" or quest.objectiveEnemyTemplate ~= enemyTemplate then
			continue
		end

		entry.progress += 1
		if entry.progress >= quest.objectiveTarget then
			entry.progress = quest.objectiveTarget
			entry.state = QuestConfig.STATE_READY_TO_TURN_IN
		end
		publishQuestAttributes(shooter, questId)
	end
end)

-- ============================================
-- TURN IN
-- ============================================
turnInQuestRequest.OnServerEvent:Connect(function(player: Player, questId: any)
	if typeof(questId) ~= "string" then
		return
	end
	local quest = QuestConfig.Quests[questId]
	if not quest then
		return
	end

	local quests = playerQuests[player]
	local entry = quests and quests[questId]
	if not entry or entry.state ~= QuestConfig.STATE_READY_TO_TURN_IN then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("Cash")
	if cash then
		cash.Value += quest.rewardCash
	end
	grantXpEvent:Fire(player, quest.rewardXp)

	entry.state = QuestConfig.STATE_COMPLETED
	publishQuestAttributes(player, questId)
end)
```

### `ServerScriptService.Weapons.Scripts.LevelingService` — listen for the new `GrantXp` event

Add near the other requires:

```lua
local grantXpEvent = ServerScriptService.Quests.Scripts.QuestService.GrantXp
```

At the bottom of the file, alongside the existing `eliminatedEvent.Event:Connect(...)`:

```lua
-- Quest rewards grant XP through this exact path, not a separate copy, so level-up thresholds and
-- the max-health-per-level side effect can never drift between kill-based and quest-based XP.
grantXpEvent.Event:Connect(function(player: Player, amount: number)
	grantXp(player, amount)
end)
```

`grantXp` is already a local function in this file (used by the `Eliminated` listener) — no other
change needed, it's already in scope.

### `ReplicatedStorage.Blaster.Utility.canDamageHumanoid` — the invulnerability gate

Add at the top of the function body, before the `if taggedHumanoid.Health <= 0` check (so it applies
uniformly to both the AI-shooter and player-shooter branches below it):

```lua
local CollectionService = game:GetService("CollectionService")
```

(add to the requires at the top of the file)

```lua
	local taggedCharacter = taggedHumanoid.Parent
	if taggedCharacter and CollectionService:HasTag(taggedCharacter, "Invulnerable") then
		return false
	end
```

Note `taggedCharacter` is already computed again further down in the existing function body (`local
taggedCharacter = taggedHumanoid.Parent`) — remove that now-duplicate line, keeping the one you just
added above.

### `ServerScriptService.Enemy.Scripts.EnemySpawner` — stamp the enemy's template name

In `trySpawn`, immediately after the existing `CollectionService:AddTag(character, Constants.ENEMY_TAG)`
line, add:

```lua
	character:SetAttribute("EnemyTemplate", template.Name)
```

This is the only place an enemy clone is ever created, so it's the only place this needs adding.

### Verify

- [ ] Shooting the Level 1 Quest NPC does nothing — no damage, no health change, confirmed by reading
      its `Humanoid.Health` before and after, not just visually.
- [ ] Killing a `Thug` (and only a `Thug` — test a `Criminal` or `Police` kill too) increments quest
      progress for a player with `Level1Thugs` accepted; the non-Thug kill does not.
- [ ] Accepting the quest twice in a row (fire `AcceptQuestRequest` again after already accepted) is a
      no-op — progress doesn't reset.
- [ ] Turning in before reaching 10 kills is refused server-side even if attempted directly.
- [ ] Turning in grants exactly 500 Cash and routes 100 XP through `LevelingService`'s real level-up
      logic (confirm a player near a level threshold actually levels up and gets the max-health bump,
      not just a flat XP number with no consequence).
- [ ] Every other enemy type is still fully damageable by players; nothing about combat regressed.

---

## Part 2 — Set up the dialogue template on the Level 1 Quest NPC

### Ungroup the template pieces (matching the pack's own instructions)

Move `Workspace."Dialogue System".Ungroup in ReplicatedStorage.DialogModule` to be a direct child of
`ReplicatedStorage`, and `Workspace."Dialogue System".Ungroup in StarterGui.dialog` to be a direct
child of `StarterGui`. Do **not** ungroup `"Ungroup in Workspace".showcase npc"` — it's the demo NPC,
being replaced, not reused directly (Part 3 builds fresh onto the Level 1 Quest rig instead).

### Fix `DialogModule` — rig-agnostic distance check, camera FOV via `CameraAuthority`

In `ReplicatedStorage.DialogModule`, inside `triggerDialog`, replace:

```lua
			local distance = (player.Character.PrimaryPart.Position - self.npc.Torso.Position).Magnitude
```

with:

```lua
			local npcRootPart = self.npc:FindFirstChild("HumanoidRootPart")
			local distance = if npcRootPart
				then (player.Character.PrimaryPart.Position - npcRootPart.Position).Magnitude
				else math.huge -- no root part somehow -- fail open to closing the dialogue, not erroring
```

Add near the top of the file:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)
```

Replace both direct camera FOV tweens:

```lua
	tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()
```

with:

```lua
	CameraAuthority.FieldOfView:Set("Menu", 65)
```

and (both occurrences — one in the `notActuallyAnExitQuip` branch, one in the `else`):

```lua
		tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 65}):Play()
	else
		tweenService:Create(game.Workspace.CurrentCamera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {FieldOfView = 70}):Play()
	end
```

with:

```lua
		CameraAuthority.FieldOfView:Set("Menu", 65)
	else
		CameraAuthority.FieldOfView:Clear("Menu")
	end
```

`CameraAuthority` already tweens smoothly on its own (see `CameraAuthority.FieldOfView`'s `applier`),
so the manual `TweenService:Create(...):Play()` calls here are no longer needed — `:Set`/`:Clear` alone
reproduce the same visual transition through the shared, conflict-safe path.

### Build `Head.gui` onto the Level 1 Quest rig

Run once:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local demoGui = Workspace["Dialogue System"]["Ungroup in Workspace"]["showcase npc"].Head.gui
local questNpc = Workspace.Quests["Level 1 Quest"]

if not questNpc.Head:FindFirstChild("gui") then
	local gui = demoGui:Clone()
	gui.Parent = questNpc.Head
end

print("Head.gui present:", questNpc.Head:FindFirstChild("gui") ~= nil)
```

### Add the `ProximityPrompt`, tag it, set attributes

Run once:

```lua
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local questNpc = Workspace.Quests["Level 1 Quest"]

if not questNpc:FindFirstChild("ProximityPrompt") then
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ProximityPrompt"
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Level 1 Quest"
	prompt.MaxActivationDistance = 10
	prompt.Parent = questNpc.HumanoidRootPart
	CollectionService:AddTag(prompt, "NPCprompt") -- DialogModule's turnProximityPromptsOn relies on this tag
	print("ProximityPrompt added.")
end
```

(`NPCprompt` is the tag `DialogModule.turnProximityPromptsOn` already scans for via
`CollectionService:GetTagged("NPCprompt")` — confirmed live in the module source above. This is what
stops two conversations from being open at once.)

### Restyle the dialogue GUI to match this game's theme

This game's established look (confirmed across the Weaponry Shop, Player Card, HUD): dark panels
(`Color3.fromRGB(20, 20, 24)`-ish, `BackgroundTransparency` around 0-0.1), `UICorner` with roughly
`0.15-0.2` scale radius, **GothamSSm Bold** font, white text with a black `UIStroke`, gold/yellow for
anything money-related (`Color3.fromRGB(255, 220, 120)`).

**`Workspace.Quests."Level 1 Quest".Head.gui.dialog`** (and do the same for `.name` and `.arrow`) —
replace the demo's font:

```lua
local Workspace = game:GetService("Workspace")
local gui = Workspace.Quests["Level 1 Quest"].Head.gui

for _, label in { gui.dialog, gui.name, gui.arrow } do
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
end
```

Leave `dialog`'s `RichText = true` alone — `DialogModule`'s typewriter reveal relies on it for the
`<font color='...'>` markup used to color response numbers; don't disable it.

**`StarterGui.dialog.dialogResponses.template`** — restyle the response button to the shop's palette:

```lua
local StarterGui = game:GetService("StarterGui")
local template = StarterGui.dialog.dialogResponses.template

template.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
template.BackgroundTransparency = 0.1
template.ImageTransparency = 1 -- unchanged, it never used the placeholder image visually anyway

if not template:FindFirstChildOfClass("UICorner") then
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.15, 0)
	corner.Parent = template
end

template.text.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
template.text.TextColor3 = Color3.new(1, 1, 1)
```

### Verify

- [ ] Interacting with the Level 1 Quest NPC shows the name/dialogue bubble above its head in this
      game's font (GothamSSm Bold, matching the shop/HUD), not the pack's default font.
- [ ] Response buttons match the dark, rounded theme.
- [ ] Talking to the NPC smoothly zooms the camera in and back out (via `CameraAuthority`, so it
      coexists correctly if you also happen to have the shop or player card open — confirm it doesn't
      snap or fight).
- [ ] Walking away mid-conversation closes it cleanly (no error in the output — this is the R15
      `Torso` fix; watch the Output window specifically while testing this).
- [ ] Only one conversation can be active at a time across every NPC carrying the `NPCprompt` tag.

---

## Part 3 — the actual quest dialogue script

**`Workspace.Quests."Level 1 Quest"`** — add a `LocalScript` (name it `QuestDialogue`):

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogModule = require(ReplicatedStorage.DialogModule)
local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)

local player = Players.LocalPlayer
local npc = script.Parent
local prompt = npc:WaitForChild("HumanoidRootPart"):WaitForChild("ProximityPrompt")

local QUEST_ID = "Level1Thugs"
local quest = QuestConfig.Quests[QUEST_ID]

local acceptQuestRequest = ReplicatedStorage.Quests.Remotes.AcceptQuestRequest
local turnInQuestRequest = ReplicatedStorage.Quests.Remotes.TurnInQuestRequest

local dialogObject = DialogModule.new(quest.name, npc, prompt)

-- What responseNum 1/2 mean for whatever was last shown -- set fresh right before every
-- triggerDialog call, since the same two response slots mean something different depending on state.
local currentMode: string? = nil

-- Rebuilds dialog slot 1 in place (mutating rather than growing DialogModule's internal dialogs
-- array, which otherwise has no way to remove/replace an entry) so every interaction reflects the
-- player's CURRENT quest state, not whatever state existed the first time this NPC was talked to.
local function refreshDialog()
	local state = player:GetAttribute(QuestConfig.stateAttributeFor(QUEST_ID))
	local progress = (player:GetAttribute(QuestConfig.progressAttributeFor(QUEST_ID)) :: number?) or 0
	local level = (player:GetAttribute("Level") :: number?) or 1

	local text, responses, mode
	if state == QuestConfig.STATE_COMPLETED then
		text = "Thanks again for taking care of those Thugs."
		responses = { "Anytime." }
		mode = "Completed"
	elseif state == QuestConfig.STATE_READY_TO_TURN_IN then
		text = `You actually did it -- {quest.objectiveTarget} Thugs down. Ready to collect?`
		responses = { "Turn in quest", "Not yet" }
		mode = "ReadyToTurnIn"
	elseif state == QuestConfig.STATE_ACCEPTED then
		text = `Still on it? You've dealt with {progress}/{quest.objectiveTarget} Thugs so far.`
		responses = { "Understood" }
		mode = "InProgress"
	elseif level < quest.requiredLevel then
		text = "Come back when you're a bit stronger."
		responses = { "Okay" }
		mode = "UnderLevel"
	else
		text = `{quest.description} Will you help?`
		responses = { "Accept", "Not right now" }
		mode = "Offer"
	end

	dialogObject.dialogs[1] = { text = text, responses = responses }
	currentMode = mode
end

prompt.Triggered:Connect(function(triggeringPlayer)
	refreshDialog()
	dialogObject:triggerDialog(triggeringPlayer, 1)
end)

dialogObject.responded:Connect(function(responseNum: number)
	if currentMode == "Offer" and responseNum == 1 then
		acceptQuestRequest:FireServer(QUEST_ID)
		dialogObject:hideGui("Good luck out there.")
	elseif currentMode == "ReadyToTurnIn" and responseNum == 1 then
		turnInQuestRequest:FireServer(QUEST_ID)
		dialogObject:hideGui("Well earned. Take care of yourself.")
	else
		dialogObject:hideGui()
	end
end)
```

`dialogObject.dialogs[1] = {...}` reaches into `DialogModule`'s internal table directly — confirmed
live that `self.dialogs` is a plain field on the returned object, not hidden behind any accessor, so
this is consistent with how the module already exposes itself, not a fragile workaround.

### Verify

- [ ] A fresh player (level 1, quest not accepted) is offered the quest and can Accept or decline.
- [ ] Declining leaves the quest not-accepted — talking again re-offers it (doesn't lock you out).
- [ ] After accepting, talking again shows live progress (`X/10`), not the original offer.
- [ ] After the 10th Thug, talking shows the turn-in option; choosing it grants the reward and flips
      to the "thanks again" line permanently — re-accepting is not offered again.
- [ ] Choosing "Not yet" at the ready-to-turn-in stage closes the conversation without granting
      anything, and the quest is still ready to turn in next time you talk.

---

## Part 4 — the Quests button and Quest Log panel

### GUI template — `ReplicatedStorage.GuiTemplates.QuestLog` (new)

Build this the same way `WeaponaryShop`/`PlayerCard` are built (dark rounded panel, title bar with a
close button, GothamSSm Bold). Structure:

- `QuestLog` (`Frame`, dark background, `UICorner`, sized/positioned like `PlayerCard`'s panel)
  - `TitleBar` (`Frame`) → `CloseButton` (`TextButton`)
  - `QuestList` (`ScrollingFrame`, `ClipsDescendants = true`, `AutomaticCanvasSize = Y`, a
    `UIListLayout`) → one `QuestEntry` template (`Frame`) containing:
    - `NameLabel` (`TextLabel`) — the quest's `name`
    - `DescriptionLabel` (`TextLabel`) — the quest's `description`
    - A progress bar reusing the exact `LevelingBar` pattern already in this game (a `Frame`/
      `CanvasGroup` with a `Fill` child sized by `UDim2.fromScale(fraction, 1)`) instead of inventing a
      new bar style.

### `StarterGui.Custom Inventory` — new `questsButton`

Run once. Clone `weaponaryButton` as the base (matching its styling exactly) and place it in the
empty space next to the other two buttons — read `playerCardButton`'s and `weaponaryButton`'s actual
live `Position` first and continue that same spacing pattern rather than guessing offsets:

```lua
local StarterGui = game:GetService("StarterGui")
local inventoryGui = StarterGui["Custom Inventory"]
local weaponaryButton = inventoryGui.weaponaryButton
local playerCardButton = inventoryGui.playerCardButton

if not inventoryGui:FindFirstChild("questsButton") then
	local questsButton = weaponaryButton:Clone()
	questsButton.Name = "questsButton"
	-- Continue whatever consistent spacing already exists between playerCardButton and
	-- weaponaryButton -- read it live rather than hardcoding an assumed offset.
	local spacing = weaponaryButton.Position - playerCardButton.Position
	questsButton.Position = weaponaryButton.Position + spacing
	questsButton.TextLabel.Text = "Quests"
	questsButton.Parent = inventoryGui
	print("questsButton added at", questsButton.Position)
end
```

Verify after running this that `questsButton` doesn't overlap anything and reads clearly — adjust
`Position` by hand in Studio if the read-live spacing doesn't land cleanly (this is a one-time visual
placement, not something to over-engineer).

### `StarterPlayer.StarterPlayerScripts.QuestLogController` (new `LocalScript`)

Mirrors `WeaponaryShopController`'s open/close shape closely, including reusing `MenuFovBlur`:

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local QuestConfig = require(ReplicatedStorage.Quests.QuestConfig)
local MenuFovBlur = require(ReplicatedStorage.Modules.MenuFovBlur)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local guiTemplates = ReplicatedStorage:WaitForChild("GuiTemplates")

local gui = Instance.new("ScreenGui")
gui.Name = "QuestLogGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = guiTemplates:WaitForChild("QuestLog"):Clone()
panel.Visible = false
panel.Parent = gui

local closeButton = panel.TitleBar.CloseButton
local questList = panel.QuestList
local entryTemplate = questList.QuestEntry:Clone()
questList.QuestEntry:Destroy()

local isOpen = false

local function refresh()
	for _, child in questList:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for questId, quest in QuestConfig.Quests do
		local state = player:GetAttribute(QuestConfig.stateAttributeFor(questId))
		if state ~= QuestConfig.STATE_ACCEPTED and state ~= QuestConfig.STATE_READY_TO_TURN_IN then
			continue -- Quest Log shows concurrent (active) quests only, matching what was asked for
		end

		local progress = (player:GetAttribute(QuestConfig.progressAttributeFor(questId)) :: number?) or 0
		local entry = entryTemplate:Clone()
		entry.NameLabel.Text = quest.name
		entry.DescriptionLabel.Text = if state == QuestConfig.STATE_READY_TO_TURN_IN
			then "Ready to turn in!"
			else `{quest.description} ({progress}/{quest.objectiveTarget})`
		entry.ProgressBar.Fill.Size = UDim2.fromScale(math.clamp(progress / quest.objectiveTarget, 0, 1), 1)
		entry.Parent = questList
	end
end

local function openLog()
	if isOpen then
		return
	end
	isOpen = true
	panel.Visible = true
	MenuFovBlur.open()
	refresh()
end

local function closeLog()
	if not isOpen then
		return
	end
	isOpen = false
	panel.Visible = false
	MenuFovBlur.close()
end

closeButton.MouseButton1Click:Connect(closeLog)

player.AttributeChanged:Connect(function(attributeName: string)
	if isOpen and attributeName:match("^Quest_") then
		refresh()
	end
end)

local inventoryGui = playerGui:WaitForChild("Custom Inventory")
local questsButton = inventoryGui:WaitForChild("questsButton")
questsButton.MouseButton1Click:Connect(function()
	if isOpen then
		closeLog()
	else
		openLog()
	end
end)
```

### Verify

- [ ] The Quests button opens/closes the log with the same FOV+blur treatment as the shop/player
      card, and all three can be open/closed in any combination without the effect getting stuck on.
- [ ] Accepting `Level1Thugs` makes it appear in the log with a 0/10 progress bar; killing Thugs
      updates the bar live while the log is open, with no manual refresh needed.
- [ ] Reaching 10/10 shows "Ready to turn in!"; turning in at the NPC removes it from the log (it's
      no longer `Accepted`/`ReadyToTurnIn`).
- [ ] A quest never offered/accepted does not appear in the log at all.

---

## Part 5 — cleanup

Once everything above is verified working:

- Delete `Workspace."Dialogue System"` entirely (everything useful was ungrouped out of it in Part 2;
  what's left is the demo `showcase npc`, the `READ ME`, and per the `READ ME`'s own instructions, a
  `ThumbnailCamera` — search for and remove that too if it exists somewhere in this folder or
  `Workspace` directly).
- Confirm `ReplicatedStorage.DialogModule` and `StarterGui.dialog` are the only two things left behind
  from the original pack, now fully wired into the Level 1 Quest NPC.

Do this last, after the checklist below passes — it's the only remaining copy of the original demo
setup if anything needs re-referencing.

## Master verification checklist

- [ ] The Level 1 Quest NPC is fully invulnerable to player weapons.
- [ ] Full quest loop works end to end: talk → offer → accept → kill 10 Thugs (tracked live) → talk →
      turn in → 500 Cash + 100 XP granted through real `LevelingService` logic → quest marked
      completed, never re-offered.
- [ ] A level-0-requirement quest (this one) is always offered; the under-level dialogue branch exists
      and is reachable if you temporarily lower `requiredLevel` in `QuestConfig` to test it.
- [ ] Quest Log button/panel works, shows only active quests, live-updates progress, matches the
      game's visual theme.
- [ ] Dialogue GUI (bubble + response buttons) matches the game's theme, not the pack's defaults.
- [ ] No leftover demo objects (`showcase npc`, `ThumbnailCamera`, the `READ ME` script) remain.
- [ ] Every existing system (shop, player card, combat, enemy AI, leveling from kills) is completely
      unaffected — this only adds new pieces and two small, additive changes to
      `canDamageHumanoid`/`EnemySpawner`.

## Notes for whoever applies this

- Every fact above was verified live via `inspect_instance`/`script_read`/`search_game_tree`
  immediately before this was written, including reading `DialogModule`'s and `canDamageHumanoid`'s
  full source rather than assuming their behavior.
- `script_grep` and `script_read` have been observed to report different line numbers for the same
  script in this project. Match edits on the quoted code, not on line numbers.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
