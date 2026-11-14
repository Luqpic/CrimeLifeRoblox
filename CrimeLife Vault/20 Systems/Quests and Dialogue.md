---
type: system
tags: [system, quests, dialogue, npc]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-System-Level1-KillThugs.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Feedback-NPC-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Dialogue-Responses-Billboard-Refactor.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Dialogue-On-Shared-Billboard-Engine.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Billboard-Input-And-Toast-Duration.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md"]
---

# Quests and Dialogue

**Skills:** `roblox-game-systems`, `roblox-ui`, `roblox-characters-animation` (load these for work here)

## What it does
Six quest givers in the FPS place, gated at levels 1, 10, 20, 35, 50 and 70, each ask for kills of one enemy type and pay cash and XP on hand-in. Players talk to them through a billboard dialogue with numbered replies; a Quests button opens a log. Quests are repeatable. The same dialogue engine also runs the Robbery place's Illegal Supplier.

## Where it lives
- `ReplicatedStorage.Quests.QuestConfig`: every quest (giver, required level, target enemy name, count, rewards, giver lines). Single source.
- `ReplicatedStorage.Quests.Remotes` (`AcceptQuestRequest`, `TurnInQuestRequest`).
- `ServerScriptService.Quests.Scripts.QuestService`: server authority on quest state, kill counting, payout.
- `ReplicatedStorage.DialogModule` (+ `sounds` `tick`, `tick2`): the conversation engine. Byte-identical copy in the Robbery place since 2026-09-19.
- `StarterGui.QuestResponsesGui`: the one reply billboard, owned by the player, kept across respawns (set explicitly), `Active = true` (set in the Robbery copy; the FPS one was authored with it on).
- `StarterPlayer.StarterPlayerScripts.QuestDialogueController`, `.QuestLogController`, `.QuestFeedbackController`.
- `ReplicatedStorage.GuiTemplates.QuestLog`, `StarterGui."Custom Inventory".questsButton`.
- `Workspace.Quests.<giver>`: rig with `gui` billboard (`name` / `arrow` / `dialog`), ProximityPrompt (tagged `NPCprompt`, `RequiresLineOfSight = false`, `Style = Custom`), `Outfit` attribute.
- Robbery place: `StarterPlayerScripts.SupplierDialogueController`; server outcome via `SubmitSupplierChoice` / `SupplierResult` ([[Robbery Heists and Getaway]]).

## How it works
- Ladder (2026-09-17 roster): level 10 Smuggler, 35 Bandits, 70 Saboteur; level 1 is "A Warning to Thugs" (10 thugs). The level 20 and 50 targets are not named in the change logs. Reward figures were specified in the 2026-09-16 prompt and are not re-measured in any log.
- Kill credit reuses the `Eliminated` signal leveling uses; the spawner tags each rig with its spawn kind so a quest can ask for one type ([[Enemies and Spawner]]).
- Givers are invulnerable (`canDamageHumanoid` skips them), anchored, play an idle stance, and point once on accept and once on claim (one gesture, guarded against restart).
- Conversation opens client-side off the prompt; what the giver says depends on untaken / in progress / ready. Replies type out letter by letter, grow on hover, take number-key shortcuts, each with a circular `Num` badge.
- Camera FOV goes through `CameraAuthority` ([[Camera Authority]]); the conversation releases its claim and clears the reply billboard on end, walk-away or death.
- Hand-in: a `QUEST COMPLETE` toast with the quest name ([[Notifications]]), queued while a panel is open. Quests button badge counts finished-but-unclaimed quests from completion counts (`Quest_<id>_Completions` attributes).
- Log entries show a `CLAIM` (acid) or `ACTIVE` pill and a progress column.
- Givers wear law-enforcement outfits by tier: Security (1, 10), Police (20, 35), SWAT (50, 70).
- Supplier: offer / explainer / decline; selling with nothing carried is refused by the server and answered in dialogue.

## Extend it
- New quest: one entry in `QuestConfig` (target enemy name inside the quest, never hard-coded in lines) plus a giver in `Workspace.Quests` with the same billboard, prompt and `NPCprompt` tag.
- New NPC conversation in either place: a controller like `QuestDialogueController` / `SupplierDialogueController` driving `DialogModule`; keep outcomes server-side.

## Watch out
- Clickable UI must live under `PlayerGui`: a billboard parented to a world object is drawn but never hit-tested. Two wrong theories (weapon mouse lock; always-on-top) were disproved.
- `BillboardGui.Active` defaults false; an `Instance.new` copy ignores clicks.
- The reply GUI must survive respawn or the conversation holds a dead reference and the player stays zoomed in after dying.
- Scripts in `Workspace` NPCs do not run; dialogue logic lives in player scripts.
- Fading the dialogue plate must include `BackgroundTransparency`.
- Quest progress and completions are not saved ([[Persistence and Saves]]).
- Automation cannot trigger the `Style = Custom` quest prompts; press E by hand to test.
- The Security shirt is a marketplace asset printed "RO-GHOUL" on the back.
- The five later givers were placed in a line at temporary positions on 2026-09-16; no log records them being moved.

## History
- 2026-09-24: givers dressed by tier from the enemy templates' uniforms; talking to one not verified. [[FPS-Quest-Givers-Law-Enforcement-Outfits]]
- 2026-09-23: quest toasts queue behind open panels. [[Notification-Queue-While-Panel-Open]]
- 2026-09-19 (Robbery): Illegal Supplier moved onto `DialogModule`; reply billboard `Active = true`, prompt line-of-sight off; real-mouse clicks verified. [[Supplier-Dialogue-On-Shared-Billboard-Engine]], [[Supplier-Billboard-Input-And-Toast-Duration]]
- 2026-09-18: quest log overflow (three causes) fixed; duplicate `QuestResponsesBillboard` template removed. [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- 2026-09-18: CLAIM / ACTIVE pills (swap not yet seen live). [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-18: dialogue plate stuck on screen fixed; one reply container. [[FPS-Figma-UI-Bugfix-Pass-3]]
- 2026-09-18: caret and long rectangle fixed. [[FPS-Figma-UI-Bugfix-Pass-2]]
- 2026-09-18: Figma nameplates, `Num` badges, `QUEST COMPLETE` title. [[FPS-Figma-UI-Bugfix-Pass]]
- 2026-09-17: levels 10, 35, 70 retargeted to Smuggler, Bandits, Saboteur. [[FPS-Enemy-Roster-Rework-3-New-Recruits]]
- 2026-09-16: replies hosted in `StarterGui.QuestResponsesGui`, pointed at the current giver (click awaited a person). [[FPS-Dialogue-Responses-Clickable-Fix]]
- 2026-09-16: replies moved into the world beside the giver. [[FPS-Dialogue-Responses-Billboard-Refactor]]
- 2026-09-16: five more givers at 10/20/35/50/70. [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]]
- 2026-09-16: completion toast, repeatable quests, badge, gestures. [[FPS-Quest-Feedback-NPC-Polish]]
- 2026-09-16: quest system and the first quest. [[FPS-Quest-System-Level1-KillThugs]]

See [[Batch Log]].
