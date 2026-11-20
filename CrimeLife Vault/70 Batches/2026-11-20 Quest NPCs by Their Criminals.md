---
type: batch
tags: [batch, city, quests, enemies]
updated: 2026-11-20
sources: ["[[2026-11-20 Quest NPCs Combat Stealth Gacha]] (part 1)", "Edit read-back and screenshot, 2026-11-20 evening"]
---

# 2026-11-20 Quest NPCs by Their Criminals

Part 1 of [[Current Work]]. Built natively.

## Asked for
"I moved all teh criminals to tehir designated areas. I need you to move the police NPC quest alongside too". Picker: "Edge of each area": about 80 studs from the criminals' pad, outside their 70-stud wander, on open ground, facing them.

## What changed
The 6 police quest givers in `Workspace.Quests` (one per criminal type, `QuestConfig` npcName / objectiveEnemyTemplate) moved out of their row by spawn (z 2477.5) to 80 studs from their criminals' pad, on the side toward the player spawn (the first clear direction within 20 degrees, except the Saboteur's at 20 degrees), facing the pad. One undo step ("Move the police quest NPCs next to their criminals").

| Quest | Criminals | New pivot |
|---|---|---|
| Level 1 Quest (Ofc. Doyle) | Thug | (-247.3, 3.8, 2605.7) |
| Level 10 Quest | Smuggler | (-109.0, 2.0, 1874.8) (a road spot skipped) |
| Level 20 Quest | Offender | (-250.5, 4.0, 2399.2) |
| Level 35 Quest | Bandits | (921.8, 3.0, 3374.6) |
| Level 50 Quest | Disrupters | (-517.4, 3.2, 1402.0) |
| Level 70 Quest | Saboteur | (-16.9, 1.0, 1030.6) |

Spot rule: solid ground (terrain or a collidable, visible part; the `SurfaceLightRoad` parts 14 studs up are skipped) within 6 studs of the pad's height, flat, a 6 x 7 x 6 box clear, and not within 75 studs of another criminal pad.

## Verified
Edit read-back (each 80.0 studs from its pad) and a screenshot of Ofc. Doyle at the edge of the Thug area; in Play all six stand at the new places; city 370 / 370 / 0.

## Left open
If you move a criminal pad again, the quest NPC does not follow by itself: move the `Workspace.Quests` model too (or ask for it).

## Saved
Studio saved to Roblox (Save, never Publish). NOT published.

## Links
[[Quests and Dialogue]] · [[Enemies and Spawner]] · [[Current Work]]
