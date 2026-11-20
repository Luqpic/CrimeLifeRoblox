---
type: batch
tags: [batch, city, rules, npc, enemies, admin, gui]
updated: 2026-11-20
sources: ["The developer's request and picker answers, 2026-11-20 (after the walking-guards batch)", "CityMerge/after-import.md ('Edit rigs on every spawner 2026-11-20')", "git log c541bb8..HEAD"]
---

# 2026-11-20 Edit Rigs on Every Spawner

Follow-up to [[2026-11-20 Walking Bank Guards and Edit Rigs]], built natively. It applies the Edit rule ([[Verify in Edit and by Screenshot]]) to the spawns that still had nothing in Edit.

## Asked for
The developer, about the list of spawns without Edit rigs: "Do all of them now". Picker answers:
- Police squads: "For polices, no need to have a fixed spot in edit since they spawn during robberies. When I say fixed spot, I meant the NPCS like the criminals since they all revolve in one area."
- Admin-spawned NPCs: "Leave as is" (the admin picks the place live).
- Admin GUI: "Real panel in StarterGui".
- The 10 civilian spawners found on the way: "Rigs on them too".

## What changed
- **Criminals.** Each of the 6 `EnemySpawnPoint` pads (Thug, Offender, Smuggler, Bandits, Disrupters, Saboteur) carries a rig of its type in Edit, standing on the pad. `EnemySpawner` takes them at start (`EditRig.take(pad, pad half height + 3.2)`), so the pad moves under the rig. The enemies still come from `ServerStorage.EnemyTemplates`. The Offender and Disrupters pads sat 1 stud under the terrain; their rigs stand on the surface, so those pads rise 1 stud at Play (flush with the ground).
- **Civilians.** The 10 `NPCSpawner` placeholders (Bank clerks 2, SlowFoods cashiers 3 and manager 1, Gas2Go cashiers 2, NewsStation workers 2) carry their NPC as a rig. `NPCSpawnManager._findSpawners` takes it on the server at boot (`ReplicatedStorage.SharedSystems.NPCSpawnManager`, mirrored for the first time). The clone still comes from the manager's template. The 5 pre-placed clerks and cashiers that stood on the same spots were removed: the game deleted them at boot anyway (`_clearPreexisting`), and the rigs replace them in Edit.
- **Admin GUI.** `AdminHudGui` and `AdminPanelGui` live in StarterGui, switched off. `AdminService` takes them back into `ServerStorage.AdminPanel` first thing at server start, switches them on, and still gives them only to admins. To look at the panel in Edit, tick `Enabled` on `AdminPanelGui` and `Visible` on its `Panel` frame; untick both before saving.
- **New test** `ServerStorage.UnitTest.Cases.EditRigs_Test` (3): `EditRig.take`; no marker holds its rig in Play; the admin GUIs are in ServerStorage, switched on, and gone from StarterGui.
- World edits are three undo steps: the rigs and the GUI move; the removal of the pre-placed civilians with the first lift; the two rigs set on the terrain.

## Verified
- City 369 / 369 / 0 (with the test player shielded, see below); heist 764 passed / 0 failed.
- Edit: 36 rigs on their markers (20 from the morning, 16 new); feet on pads and floors; screenshot of a criminal pad. After Play the rigs and the StarterGui GUIs are still there, `ServerStorage.AdminPanel` is empty in Edit.
- Play: exactly one `AdminHudGui` and one `AdminPanelGui` in the owner's PlayerGui, none in StarterGui; all 10 civilians spawned 0.00 studs from their spawners; criminals spawned and wandered off their pads (Disrupters were up by the end of the test run).

## Not verified
- A non-admin player joining (needs a second player): they should get no admin GUI.

## Left open
- Police squads and admin-spawned NPCs stay without Edit rigs (the developer's answers).
- Unit test trap: the first full city run had 2 failures (`WantedService_Test`, `EnemyTargetFilter_Test`) that use the real Play player. The player stands near the criminals' area and was hurt during the run; both passed alone and the full suite passed with a ForceField on the player. [[Unit Test Runner]]

## Saved
Studio saved to Roblox (Save, never Publish). NOT published. Nothing pushed.

## Links
[[Enemies and Spawner]] · [[Robbery Heists and Getaway]] · [[Admin Panel]] · [[Verify in Edit and by Screenshot]] · [[Vault and Documentation Decisions]]
