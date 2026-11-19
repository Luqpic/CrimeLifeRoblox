---
type: rule
tags: [rule, save, publish, studio]
updated: 2026-11-20
sources: ["OBT Vault/10 Rules/Save and Publish Rules.md (adapted)", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md"]
---

# Save and Publish Rules

## Rule

- **Never publish.** Not at the end of a batch, not to test. Live servers change only when the developer publishes.
- **The developer saves Studio.** Claude does not press Save. Local `.rbxl` places use File > Save to File; a cloud place uses File > Save to Roblox (a save, not a publish).
- **Every report ends with the save state**, normally **"NOT saved / NOT published"** ([[Reporting Rules]]).
- **Remind the developer to save** at the end of a batch when Studio changed.
- **Stop Play before an Edit change or a save.** Edit is where changes persist.
- **The git commit is not a save.** `Batch: <topic>` commits the vault and the `.luau` mirrors; the place itself lives in Studio. Do not push unless asked.

## Exception: one night, 2026-11-15

On 2026-11-15 the developer allowed Claude to save `Crimelife city.rbxl` at checkpoints during the overnight run that ported the FPS systems into the city ("Yes, save at checkpoints"). Claude saved six times, never published, and the batch note ends "Saved to `Crimelife city.rbxl` (checkpoint after Task 5) / NOT published." ([[2026-11-15 FPS Systems Into City]]). **This was a one-night permission.** The standing rule above is unchanged: the developer saves, Claude never publishes, and every report ends with the save state. Claude saves again only if the developer allows it again.

## Exception: the night of 2026-11-20

On 2026-11-20 the developer answered "Yes, save after each task" (picker, before sleeping): Claude, as the controller only (implementers never save), saved the cloud place "Crimelife Tycoon" with `save_place` after each task that passed its tests, versions 10, 15, 21 and 23, and never published ([[2026-11-20 Admin Animations Third Person]]). In a cloud place a save makes a place version; it is not a publish. **A one-night permission again**: the standing rule above is unchanged.

## Why

- Carried from the developer's OBT rules (the same developer): never publish, the developer saves, reports end "NOT saved / NOT published". Adopted for CrimeLife on 2026-11-14 with this vault.
- Some CrimeLife behaviour only exists in a published place: [[FPS-Persistence-Phase-3]] recorded restart durability, cross-server session locking and the load-abandonment policy as DEFERRED, "unmeasurable on an unpublished place". Publishing to test them is the developer's call, never Claude's.
- [[FPS-RPG-Gamepass-Launcher]] shipped with a placeholder gamepass id 0 to be set "in the real universe": anything tied to the live universe is the developer's step.

## How to apply

- List under "needs you" anything only a published place or the developer can do (save, publish, set a real product id, a multiplayer Start).
- Studio Play with ProfileStore uses the Mock store ([[Safety and Security Rules]]), so test progress in Play never reaches a real save.
