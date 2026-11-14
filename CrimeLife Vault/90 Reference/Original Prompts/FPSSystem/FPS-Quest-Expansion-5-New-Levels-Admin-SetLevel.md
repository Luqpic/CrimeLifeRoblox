# Prompt: 5 More Quest NPCs (Levels 10/20/35/50/70) + Raise Level Cap + Admin `/setlevel`

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Context — read this first

**The quest system has evolved since the prompts that built it, confirmed live by reading every
script's actual current source, not assumed.** It's now meaningfully better than originally
specified — this document builds on the *current* implementation, not the original design docs:

- `QuestDialogueController` (`StarterPlayer.StarterPlayerScripts`) is a **single shared script**, not
  one per NPC — it loops `QuestConfig.Quests` and wires every quest-giver NPC generically
  (`for questId, quest in QuestConfig.Quests do task.spawn(wireQuestNpc, questId, quest) end`). Its own
  comment explains why: a `LocalScript` parented directly onto an NPC in `Workspace` never executes at
  all (Roblox only runs LocalScripts under Character/Backpack/PlayerGui/PlayerScripts/ReplicatedFirst)
  — the original per-NPC design would have been silently inert. **This means adding 5 more quests
  needs zero changes to this script** — it already picks up new `QuestConfig` entries and their NPCs
  automatically.
- For the same reason, it reads the NPC's idle/point animation ids directly out of the `Animate`
  script's config children and plays them itself via a fresh `Animator`, rather than relying on the
  stock (inert-in-Workspace) `Animate` script to do it.
- `QuestService`, `QuestFeedbackController`, and `QuestLogController` are likewise already fully
  data-driven off `QuestConfig.Quests` — confirmed live, none of them need touching either.
- Quests are now **repeatable** by design (`QuestConfig.Quests.Level1Thugs.repeatable = true`):
  turning one in resets its state to `""` (so it can be accepted again) rather than a one-shot
  `Completed`. Completion feedback keys off a separate `_Completions` counter that only ever
  increases, not off the transient state — this was already fixed live; nothing to redo.
- `QuestFeedbackController` deliberately has **no** centre-screen banner — that was in an earlier
  draft and was cut ("the toast already announces the completion, and showing both said the same
  thing twice"). Current feedback is: shine effect + sound + bottom-left toast only. Don't reintroduce
  the banner as part of this document.

**One real gap found while reading `QuestDialogueController`'s current source**: its dialogue text
hardcodes the word **"Thugs"** in three places (progress line, ready-to-turn-in line, thank-you line).
That's fine for the one quest that exists today, but duplicating the system for Security/Criminal/
Police/Armed Criminal/Armed Police quests would have all five of them talking about "Thugs" too if
left as-is. This document fixes that as part of adding the new quests — it's a required part of
"reuse the same mechanism," not scope creep, since leaving it hardcoded would make the duplication
produce visibly wrong dialogue.

**Confirmed live**: `ServerScriptService.Quests.Events.GrantXp` is a persistent `BindableEvent`
(not created at runtime), and `ServerStorage.EnemyTemplates` contains `Security`, `Criminal`,
`Police`, `Armed Criminal`, `Armed Police` (singular — not "Armed Criminals"/"Armed Polices").

---

## Part 1 — raise the level cap

**`ReplicatedStorage.Leveling.Constants`** — change:

```lua
Constants.LEVEL_CAP = 10
```

to:

```lua
Constants.LEVEL_CAP = 70
```

Nothing else needs to change — `xpToNextLevel` is already a formula (`BASE_XP_TO_LEVEL +
XP_INCREMENT_PER_LEVEL * (level - 1)`), not a lookup table, so it extends on its own.
`MAX_HEALTH_PER_LEVEL` scaling to level 70 is a real, noticeable effect (a level-70 player reaches
238 max health) — this is an unmodified pre-existing formula, not something this document rebalances;
flagging it so it's a known, deliberate consequence rather than a surprise.

### Verify

- [ ] A player can now level past 10 (test by granting enough XP, e.g. via the admin command in
      Part 4 once it exists, or by adjusting `LEVEL_CAP` temporarily lower during a quick test then
      setting it back to 70).
- [ ] Leveling still stops exactly at 70, and XP granted while at 70 is still dropped (unchanged
      behavior from before, just at a higher ceiling).

---

## Part 2 — extend `QuestConfig` with 5 new quests and fix the hardcoded enemy name

**`ReplicatedStorage.Quests.QuestConfig`** — add `objectiveEnemyNamePlural` to the type and to every
entry (including the existing one, for consistency), and add the 5 new quests. Replace the whole
`export type QuestDefinition` and `QuestConfig.Quests` block with:

```lua
export type QuestDefinition = {
	name: string,
	description: string,
	npcName: string, -- must match a Model directly under Workspace.Quests
	requiredLevel: number,
	objectiveType: "KillCount", -- only type implemented today; the shape allows more later
	objectiveEnemyTemplate: string, -- must match an EnemyTemplates model name
	objectiveEnemyNamePlural: string, -- for dialogue text ("Security"/"Police" don't pluralize with "s")
	objectiveTarget: number,
	rewardCash: number,
	rewardXp: number,
	repeatable: boolean, -- true: turning in clears the quest so it can be taken again
}

QuestConfig.Quests = {
	Level1Thugs = {
		name = "A Warning to Thugs",
		description = "Defeat 10 Thugs.",
		npcName = "Level 1 Quest",
		requiredLevel = 1,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Thug",
		objectiveEnemyNamePlural = "Thugs",
		objectiveTarget = 10,
		rewardCash = 500,
		rewardXp = 100,
		repeatable = true,
	},
	Level10Security = {
		name = "Lockdown",
		description = "Defeat 10 Security guards.",
		npcName = "Level 10 Quest",
		requiredLevel = 10,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Security",
		objectiveEnemyNamePlural = "Security",
		objectiveTarget = 10,
		rewardCash = 900,
		rewardXp = 300,
		repeatable = true,
	},
	Level20Criminal = {
		name = "Clean Sweep",
		description = "Defeat 10 Criminals.",
		npcName = "Level 20 Quest",
		requiredLevel = 20,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Criminal",
		objectiveEnemyNamePlural = "Criminals",
		objectiveTarget = 10,
		rewardCash = 1600,
		rewardXp = 600,
		repeatable = true,
	},
	Level35Police = {
		name = "No Badge, No Mercy",
		description = "Defeat 10 Police.",
		npcName = "Level 35 Quest",
		requiredLevel = 35,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Police",
		objectiveEnemyNamePlural = "Police",
		objectiveTarget = 10,
		rewardCash = 2800,
		rewardXp = 1200,
		repeatable = true,
	},
	Level50ArmedCriminal = {
		name = "Heavy Hitters",
		description = "Defeat 10 Armed Criminals.",
		npcName = "Level 50 Quest",
		requiredLevel = 50,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Armed Criminal",
		objectiveEnemyNamePlural = "Armed Criminals",
		objectiveTarget = 10,
		rewardCash = 4500,
		rewardXp = 2000,
		repeatable = true,
	},
	Level70ArmedPolice = {
		name = "Last Stand",
		description = "Defeat 10 Armed Police.",
		npcName = "Level 70 Quest",
		requiredLevel = 70,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Armed Police",
		objectiveEnemyNamePlural = "Armed Police",
		objectiveTarget = 10,
		rewardCash = 8000,
		rewardXp = 0, -- level 70 is the cap (Part 1) -- any XP reward here would just be dropped, so
		              -- this quest's full value is in the cash reward instead
		repeatable = true,
	},
} :: { [string]: QuestDefinition }
```

**`StarterPlayer.StarterPlayerScripts.QuestDialogueController`** — in `refreshDialog`, replace the
three hardcoded `"Thugs"` occurrences:

```lua
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
```

with:

```lua
		if state == QuestConfig.STATE_COMPLETED then
			text = `Thanks again for taking care of those {quest.objectiveEnemyNamePlural}.`
			responses = { "Anytime." }
			mode = "Completed"
		elseif state == QuestConfig.STATE_READY_TO_TURN_IN then
			text = `You actually did it -- {quest.objectiveTarget} {quest.objectiveEnemyNamePlural} down. Ready to collect?`
			responses = { "Turn in quest", "Not yet" }
			mode = "ReadyToTurnIn"
		elseif state == QuestConfig.STATE_ACCEPTED then
			text = `Still on it? You've dealt with {progress}/{quest.objectiveTarget} {quest.objectiveEnemyNamePlural} so far.`
```

(`STATE_COMPLETED` is technically unreachable for a `repeatable` quest per Part 2's own context notes
above, but the branch is left correct rather than deleted — `repeatable` is a per-quest flag, so a
future non-repeatable quest would still reach it.)

### Verify

- [ ] All 6 quests exist in `QuestConfig.Quests` with correct `objectiveEnemyTemplate` values matching
      the real `EnemyTemplates` names exactly (`Security`, `Criminal`, `Police`, `Armed Criminal`,
      `Armed Police` — singular).
- [ ] Talking to the Level 1 NPC still says "Thugs" everywhere it should (regression check on the
      text-generation change).
- [ ] Once the NPCs exist (Part 3), each one's dialogue correctly names its own enemy type — e.g. the
      Level 35 NPC talks about "Police", not "Thugs" or "Polices".

---

## Part 3 — 5 new NPCs

Only `Level 1 Quest` exists to copy from — clone it, since `QuestService`/`QuestDialogueController`/
`QuestFeedbackController` are all already generic and need no further changes once each NPC model and
`ProximityPrompt` exist with the right names. Run once:

```lua
local Workspace = game:GetService("Workspace")
local questsFolder = Workspace.Quests
local original = questsFolder["Level 1 Quest"]

-- Placeholder spacing only -- reposition these by hand once you can see them in the map. Offsetting
-- along the original's own local X axis so they land in a predictable line relative to however it's
-- already oriented, rather than an arbitrary world-space guess.
local SPACING_STUDS = 15

local newNpcNames = { "Level 10 Quest", "Level 20 Quest", "Level 35 Quest", "Level 50 Quest", "Level 70 Quest" }

for i, npcName in newNpcNames do
	if questsFolder:FindFirstChild(npcName) then
		continue -- idempotent -- don't duplicate if this has already been run
	end

	local clone = original:Clone()
	clone.Name = npcName
	clone:PivotTo(original:GetPivot() * CFrame.new(SPACING_STUDS * i, 0, 0))

	local head = clone:FindFirstChild("Head")
	local nameLabel = head and head:FindFirstChild("gui") and head.gui:FindFirstChild("name")
	if nameLabel then
		nameLabel.Text = npcName
	end

	local prompt = clone:FindFirstChild("HumanoidRootPart") and clone.HumanoidRootPart:FindFirstChild("ProximityPrompt")
	if prompt then
		prompt.ObjectText = npcName
	end

	clone.Parent = questsFolder
	print("Created", npcName, "at", clone:GetPivot().Position)
end

-- Small consistency fix while in here: Level 1 Quest's own overhead name currently still reads
-- whatever the original dialogue-pack demo NPC was called, never corrected when its gui was built.
-- Worth fixing now since leaving it stale would be the one NPC out of 6 with the wrong label.
local originalNameLabel = original.Head and original.Head:FindFirstChild("gui") and original.Head.gui:FindFirstChild("name")
if originalNameLabel and originalNameLabel.Text ~= "Level 1 Quest" then
	originalNameLabel.Text = "Level 1 Quest"
end
```

Everything else — Invulnerable tagging, dialogue wiring, kill tracking, turn-in, reward granting,
completion feedback, and the Quest Log — is already generic and picks these up automatically because
each clone's `Model.Name` matches its quest's `npcName` in `QuestConfig` (Part 2).

### Verify

- [ ] All 5 new NPCs exist under `Workspace.Quests`, visibly spaced apart (not stacked on top of each
      other or the original) — reposition them to sensible map locations once you can see them.
- [ ] Each is invulnerable to weapon damage (same check as the original: shoot one, confirm no health
      change).
- [ ] Each offers its own quest correctly, respects its own `requiredLevel` (use the admin command
      from Part 4 to test each tier without grinding), tracks kills of only its own enemy type, and
      grants its own reward on turn-in.
- [ ] The Quest Log shows whichever of the 6 are currently accepted, each with correct live progress.
- [ ] Re-running the setup script a second time does not create duplicates (the `FindFirstChild`
      guard).

---

## Part 4 — admin `/setlevel` command

Server-authoritative (a client-side check alone would be trivially bypassable) and gated to a single
`UserId`, mirroring the existing `/view` `TextChatCommand` pattern in `PlayerCardController`.

### `ReplicatedStorage.Leveling.Remotes` (new `Folder`) with `SetLevelRequest` (new `RemoteEvent`)

### `ServerScriptService.Weapons.Scripts.LevelingService` — handle it

Add near the top, alongside the other remote/event references:

```lua
local setLevelRequest = ReplicatedStorage.Leveling.Remotes.SetLevelRequest
local ADMIN_USER_ID = 58662576
```

Add anywhere after `applyMaxHealth` is defined (it's used below):

```lua
-- Debug-only: directly sets a player's level, bypassing the normal XP-accumulation path entirely.
-- Locked to one UserId server-side -- the real enforcement point, since a client-side-only check is
-- trivially bypassed by calling the remote directly.
setLevelRequest.OnServerEvent:Connect(function(player: Player, targetLevel: any)
	if player.UserId ~= ADMIN_USER_ID then
		return
	end
	if typeof(targetLevel) ~= "number" then
		return
	end
	targetLevel = math.clamp(math.floor(targetLevel), 1, LevelingConstants.LEVEL_CAP)

	local leaderstats = player:FindFirstChild("leaderstats")
	local levelValue = leaderstats and leaderstats:FindFirstChild("Level")
	if levelValue then
		levelValue.Value = targetLevel
	end
	player:SetAttribute("Level", targetLevel)
	player:SetAttribute("XP", 0)
	local capped = targetLevel >= LevelingConstants.LEVEL_CAP
	player:SetAttribute("NextLevelXP", if capped then 0 else LevelingConstants.xpToNextLevel(targetLevel))
	playerLevels[player] = targetLevel

	local character = player.Character
	if character then
		applyMaxHealth(character, targetLevel)
	end
end)
```

### `StarterPlayer.StarterPlayerScripts.AdminSetLevelCommand` (new `LocalScript`)

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local ADMIN_USER_ID = 58662576

-- Skipped entirely for everyone else, so the command doesn't even show up in chat autocomplete for
-- anyone but the one account it actually works for. The server-side check in LevelingService is the
-- real gate; this is just tidiness.
if Players.LocalPlayer.UserId ~= ADMIN_USER_ID then
	return
end

local setLevelRequest = ReplicatedStorage.Leveling.Remotes.SetLevelRequest

local setLevelCommand = Instance.new("TextChatCommand")
setLevelCommand.Name = "SetLevel"
setLevelCommand.PrimaryAlias = "/setlevel"
setLevelCommand.Parent = TextChatService

setLevelCommand.Triggered:Connect(function(_, unfilteredText: string)
	local levelText = unfilteredText:match("^/setlevel%s+(%S+)$")
	local level = levelText and tonumber(levelText)
	if not level then
		return
	end
	setLevelRequest:FireServer(level)
end)
```

### Verify

- [ ] Typing `/setlevel 35` on your own account (`58662576`) immediately sets your level to 35,
      updates the leaderboard, resets XP/NextLevelXP correctly for that level, and applies the correct
      max health.
- [ ] `/setlevel` typed by a different account does nothing (test with a second account/Studio Team
      Test session if available; at minimum confirm the server-side `UserId` check is actually there
      and correct).
- [ ] `/setlevel 0`, `/setlevel -5`, `/setlevel 9999`, and `/setlevel abc` are all handled without
      erroring (clamped or ignored, not a script error in the output).
- [ ] Setting your level down (e.g. from 35 to 5) works too, not just up.

## Master verification checklist

- [ ] Level cap is 70; leveling works correctly all the way to it.
- [ ] All 6 quests (original + 5 new) work end to end: correct level gate, correct enemy tracked,
      correct dialogue naming its own enemy type, correct reward, repeatable behavior consistent
      across all 6.
- [ ] `/setlevel` works for your account only.
- [ ] Nothing about the existing Level 1 quest, the shop, combat, or any other system regressed.

## Notes for whoever applies this

- Every fact above was verified live immediately before this was written, including reading the
  actual current source of `QuestConfig`, `QuestService`, `QuestDialogueController`,
  `QuestFeedbackController`, and `LevelingService` rather than trusting the earlier design documents
  that originally built them.
- Per the standing workflow: do NOT commit this prompt document to the git repo. Once applied and
  verified, write a short plain-prose changelog entry following the template used by the existing
  entries under `FPSSystem/`, commit, then push.
