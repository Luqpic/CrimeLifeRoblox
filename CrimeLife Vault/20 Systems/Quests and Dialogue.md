---
type: system
tags: [system, quests, dialogue, npc]
updated: 2026-11-20
sources: ["70 Batches/2026-11-17 Police and Wanted.md", ".superpowers/sdd/2026-11-17-police-and-wanted/task-5-report.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-System-Level1-KillThugs.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Feedback-NPC-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Dialogue-Responses-Billboard-Refactor.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Roster-Rework-3-New-Recruits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Dialogue-On-Shared-Billboard-Engine.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Billboard-Input-And-Toast-Duration.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
---

# Quests and Dialogue

**Skills:** `roblox-game-systems`, `roblox-ui`, `roblox-characters-animation` (load these for work here)

## What it does
Six quest givers in the FPS place, gated at levels 1, 10, 20, 35, 50 and 70, each ask for kills of one enemy type and pay cash and XP on hand-in. Players talk to them through a billboard dialogue with numbered replies; a Quests button opens a log. Quests are repeatable. The same dialogue engine also runs the Robbery place's Illegal Supplier.

## Where it lives
- `ReplicatedStorage.Quests.QuestConfig`: every quest (giver, required level, target enemy name, count, rewards, `description`). Single source of quest data. The spoken lines are not here: they are templates in `QuestDialogueController`, shared by all six givers and filled from `QuestConfig` (found 2026-11-17). In the city also `MAX_INTERACT_DISTANCE` (30 studs), `withinReach`, `restore`, `RESTORED_ATTRIBUTE` and, since 2026-11-18, `REFUSALS` (the refusal texts).
- `ReplicatedStorage.Quests.Remotes` (`AcceptQuestRequest`, `TurnInQuestRequest`).
- `ServerScriptService.Quests.Scripts.QuestService`: server authority on quest state, kill counting, payout; in the city also the save mirror and the hydrator (sets the player attribute `QuestsRestored` last).
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
- **Turn-in order (2026-11-18).** `QuestService` records and saves first, then pays: completions +1, the state cleared (repeatable) or marked Completed, publish, save, then cash and `GrantXp`. Nothing yields in between, so it was safe before and is now safe by order too. Play (Level 1 quest, 10 Thug kills through the real `Eliminated` event, turn-in from the client): cash 575 to 1100, XP 45 to 70, level 4 to 5, completions 0 to 1, state ""; that is the 500 reward plus the 25 level-up bonus of the quest's 100 XP. The profile read `quests` [], `questCompletions` {Level1Thugs: 1}.
- **Refusal feedback (2026-11-18).** No new remote: `QuestService` answers on the same RemoteEvent with `FireClient(player, questId, reason)`. Accept: `too_far`, `low_level`; turn-in: `too_far`, `not_ready`. `QuestFeedbackController` shows `QuestConfig.REFUSALS[reason]` through `NotificationController.show(text, "QUEST")`: "Too far away.", "Not ready yet.", "Your level is too low.". Still silent: a bad argument type, an unknown quest id, a player still loading on accept, an accept for a quest already taken. Seen in Play: accept at 45.0 studs showed "Too far away." (card title bounds 46 x 15, message 60.5 x 13, both inside 240 x 18), a turn-in at 5.1 studs while only Accepted showed "Not ready yet.". `low_level` was not driven live. A dead player's refused request also reads "Too far away." (`canReach` is false for a dead character).
- Hand-in: a `QUEST COMPLETE` toast with the quest name ([[Notifications]]), queued while a panel is open. Quests button badge counts finished-but-unclaimed quests from completion counts (`Quest_<id>_Completions` attributes).
- Log entries show a `CLAIM` (acid) or `ACTIVE` pill and a progress column.
- Givers wear law-enforcement outfits by tier: Security (1, 10), Police (20, 35), SWAT (50, 70); in the city they are crooked cops (below).
- Supplier: offer / explainer / decline; selling with nothing carried is refused by the server and answered in dialogue.

## In the city
Measured 2026-11-15 ([[2026-11-15 FPS Systems Into City]]):
- A quest giver is an R15 `Model` directly under `Workspace.Quests`, named exactly as `QuestConfig`'s `npcName` (`Level 1 Quest`, `Level 10 Quest`, `Level 20 Quest`, `Level 35 Quest`, `Level 50 Quest`, `Level 70 Quest`): `Humanoid`, `HumanoidRootPart` (anchored, 3 studs above the pivot), 15 MeshPart limbs, clothing, outfit accessories and an `Animate` folder; 302 to 320 descendants each, 1,892 in all with 119 parts. The pivot is at the feet.
- `HumanoidRootPart.ProximityPrompt` carries tag `NPCprompt`, `Style = Custom`, `MaxActivationDistance = 10`, no line of sight needed. `Head.gui` is the name and dialogue billboard. The `Outfit` attribute (Security, Police, Armed Police) is read by nothing at runtime.
- No script stores an absolute position of a giver, and no giver has a joint, weld or `ObjectValue` outside its model: moving one with `PivotTo` is self-contained.
- They now stand on the sidewalk at z 2477.5, x -44.89 to -114.89, facing the spawn ([[City Map and Plots]]); provisional. In the run from the city spawn all six were present with their prompts.

## In the city, phase 2b
Measured 2026-11-15 ([[2026-11-15 FPS Hardening In City]]):
- Accept and turn-in need the character within 30 studs of the giver (`QuestService` `canReach`): a far turn-in at 45.0 studs was refused, a near one at 4.6 paid. A test must place the character first (server `PivotTo`).
- Progress and completions are saved (`quests`, `questCompletions`, [[Persistence and Saves]]) and restored on join; since 2026-11-18 the restore also prunes the save (`QuestService.hydrate` writes `QuestConfig.restore`'s result back to `profile.Data`, so entries for ids that left `QuestConfig` and clamped numbers do not linger). Level 1 turn-in: cash 350 to 875, because the 100 XP crossed a level and the 25 level-up bonus came with the 500 reward.
- `QuestFeedbackController` shows QUEST COMPLETE only for completions seen after the `QuestsRestored` attribute is set; earlier changes only seed the count.
- Kills for a test: `TakeDamage` then fire `ServerScriptService.Blaster.Events.Eliminated` from a server Script; the Shoot remote is now rate-limited ([[Weapons and Blaster]]).

## The givers are crooked cops (city, 2026-11-17)
[[2026-11-17 Police and Wanted]]. The developer: "A criminal; givers go rogue". Claude's call: crooked cops (they keep their uniforms; no new art). Quests, rewards, levels, model names and `npcName` are unchanged; the player's replies are unchanged.
- **Nameplates** (`Workspace.Quests.<model>.Head.gui.name.Text`): `OFC. DOYLE - LV 1`, `OFC. PIKE - LV 10`, `SGT. MARSH - LV 20`, `LT. GRADY - LV 35`, `CPT. VOSS - LV 50`, `CHIEF HARLAN - LV 70`.
- **Lines** (`QuestDialogueController`, one shared set): offer "Off the books: {description} Cash, no questions."; repeat "Back again? {description} Same envelope."; in progress "Keep it quiet. {progress}/{target} {enemies} cleared so far."; ready "Clean work. {target} {enemies} gone. Your envelope's ready." (the line had a spaced double hyphen until 2026-11-18, a breach of [[Player-Facing Text]]); completed "Those {enemies} won't be missed. Not a word, ever."; under level "Not yet, kid. Earn a rep first."; accept quip "You never heard it from me."; turn-in quip "Count it later. And we never met."
- **Fit** was computed, not read live (viewport 1 x 1): every line at 24 px or more, every name on one line at 21 px. The ready line was read back in Play on 2026-11-18 after a real E press (`user_keyboard_input`): `Workspace.Quests."Level 1 Quest".Head.gui.dialog.Text` read "Clean work. 10 Thugs gone. Your envelope's ready.", visible, `TextFits` true, bounds 229.0 x 40.4 inside 267 x 40.8, replies "Turn in quest" and "Not yet". The other lines were never seen typed in a real conversation. The six nameplates keep the hyphen between name and level: a name/tag separator, like the one in "Name - [$Price]".
- Uniformed police who hunt you and uniformed crooked cops who pay you both exist; the lines make the difference ([[Police and Wanted]]).


## Quest givers by their criminals (2026-11-20)
Each `Workspace.Quests` giver stands about 80 studs from its criminals' `EnemySpawnPoint` pad, facing it. Moving a pad does not move its giver. [[2026-11-20 Quest NPCs by Their Criminals]]

## Extend it
- New quest: one entry in `QuestConfig` (target enemy name inside the quest, never hard-coded in lines) plus a giver in `Workspace.Quests` with the same billboard, prompt and `NPCprompt` tag.
- New NPC conversation in either place: a controller like `QuestDialogueController` / `SupplierDialogueController` driving `DialogModule`; keep outcomes server-side.

## Watch out
- Clickable UI must live under `PlayerGui`: a billboard parented to a world object is drawn but never hit-tested. Two wrong theories (weapon mouse lock; always-on-top) were disproved.
- `BillboardGui.Active` defaults false; an `Instance.new` copy ignores clicks.
- The reply GUI must survive respawn or the conversation holds a dead reference and the player stays zoomed in after dying.
- Scripts in `Workspace` NPCs do not run; dialogue logic lives in player scripts.
- Fading the dialogue plate must include `BackgroundTransparency`.
- Quest progress and completions are saved in the city only; the frozen FPS place still loses them ([[Persistence and Saves]]).
- Automation cannot trigger the `Style = Custom` quest prompts; press E by hand to test (a `user_keyboard_input` E press worked in the 2026-11-18 Play).
- `QuestFeedbackController`'s header comment says "bottom-left toast" while the stack is bottom-right (an old comment, not changed).
- `restore` permanently drops saved entries for quest ids missing from `QuestConfig` (asked for by the open item); removing a quest from the config costs players its progress.
- The Security shirt is a marketplace asset printed "RO-GHOUL" on the back.
- The five later givers were placed in a line at temporary positions on 2026-09-16; no log records them being moved.

## History
- 2026-11-18: turn-in records and saves before it pays; refusal toasts ("Too far away.", "Not ready yet.", "Your level is too low.") on the existing remotes; the restore prunes the save; the ready line lost its double hyphen ("Clean work."). [[2026-11-18 Open Items Pass]]
- 2026-11-17 (city): the givers become crooked cops: new nameplates with ranks and new lines in `QuestDialogueController`; quests unchanged. [[2026-11-17 Police and Wanted]]
- 2026-11-15: city: accept and turn-in need the giver within 30 studs; quest progress saved and restored; no replayed completion toast on rejoin. [[2026-11-15 FPS Hardening In City]]
- 2026-11-15: ported into the city as an exact copy; the six givers moved to the city sidewalk by the spawn; pressing E still needs a person. [[2026-11-15 FPS Systems Into City]]
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
