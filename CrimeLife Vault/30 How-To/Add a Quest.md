---
type: howto
tags: [howto, quests, dialogue]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-System-Level1-KillThugs.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "CLAUDE.md (Systems: Quests)"]
---

# Add a Quest

A new quest giver and quest. Data path: `ReplicatedStorage.Quests.QuestConfig` -> `QuestDialogueController` (client conversation) -> `QuestService` (server authority, kill counting, payout) -> `QuestFeedbackController` (toast, banner, VFX, sound). System: [[Quests and Dialogue]].

Skills: `roblox-game-systems`, `roblox-ui` (if the log or replies change).

## Steps
1. **Add the definition** to `QuestConfig`: the giver, the level gate, the enemy kind it counts (by spawn-kind name, part of the quest's own definition so the line and the objective cannot disagree), the count, the cash and XP reward, and the giver's lines per stage (untaken, in progress, ready to hand in).
2. **Place the giver** in `Workspace.Quests`: copy an existing giver so it has the floating name, speech bubble and the one custom-style ProximityPrompt. It stays anchored and invulnerable (`canDamageHumanoid` skips it). Outfit: clone Shirt, Pants, BodyColors and `Humanoid:AddAccessory` the accessories from a law-enforcement template; record the source in an `Outfit` attribute; no weapon Tools.
3. **Do not put scripts on the giver.** World scripts never run; the conversation lives in `StarterPlayerScripts.QuestDialogueController`, which finds the giver by name.
4. **The target enemy must exist** and be tagged by the spawner ([[Add an Enemy Type]]).
5. Replies are hosted in the player's own `StarterGui.QuestResponsesGui`, pointed at the current giver (a world-parented GUI is never hit-tested).
6. Raise the level cap in `ReplicatedStorage.Leveling.Constants` if the gate is above it.

## Files to touch
`QuestConfig`, `Workspace.Quests.<giver>`, sometimes `Leveling.Constants`.

## Check
- Set your level with the admin tool (`/setlevel` or the F2 panel, `AdminLevelController`) instead of grinding.
- Completion: a `Quest_<id>_Completions` player attribute change drives the toast ([[Notifications]]).
- **A person must press E on the giver.** Automated input could not trigger the custom-style prompt in the harness, with or without an outfit.
- Die mid-conversation and respawn: the camera must be released (the replies panel persists across respawn).

## Done before
[[FPS-Quest-System-Level1-KillThugs]], [[FPS-Dialogue-Responses-Billboard-Refactor]], [[FPS-Dialogue-Responses-Clickable-Fix]], [[FPS-Quest-Feedback-NPC-Polish]], [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]], [[FPS-Quest-Overflow-And-Dead-Code-Removal]], [[FPS-Quest-Givers-Law-Enforcement-Outfits]].
