# Client load-order audit: the Robbery client scripts in the city (phase 3, Task 4)

Measured 2026-11-16 in `Crimelife city.rbxl`. Same defect class as `CityMerge/client-load-order-audit.md` (FPS, 2026-11-15): a client script reaches an instance that arrives on the client separately, by `.` index or by a `WaitForChild` that has no timeout, and the instance is late or (under streaming) absent. New in phase 3: Workspace parts the city streams (`StreamingEnabled`, min 128 / target 512) that the Robbery place, being small, always had on the client.

## Scope and search

The Robbery code that runs on the client: the 5 LocalScripts in `StarterPlayer.StarterPlayerScripts` (`HeistClient`, `WordScrambleClient`, `NotificationClient`, `UiButtonEffects`, `SupplierDialogueController`) and the modules they require (`ReplicatedStorage.SharedSystems.CashClaimVFX`, `UITransitions`, `UITheme`, `GamepassManager`; the four `*Shared.Config` modules). Each source scanned line by line (comments stripped) for `workspace` / `Workspace`, `script.Parent`, `PlayerGui` / `playerGui`, `character` / `Character`, `ReplicatedStorage.`, `WaitForChild`, `FindFirstChild`, `PlayerScripts`, `Backpack`, `LocalPlayer.`, and `.` indexes of a variable holding a GUI or a shared folder. `UITransitions`, `UITheme`, `GamepassManager` and the four configs: 0 instance lookups. `StarterCharacterScripts` Robbery items are 3 Sounds (no code). The 9 `Animate` LocalScripts (3 templates in `ReplicatedStorage.*Shared.ModelTemplates`, 6 in NPC models in `Workspace`) never run: a LocalScript only runs under a character, Backpack, PlayerGui, PlayerScripts or ReplicatedFirst.

Readers of `StatusBillboardAnchor` (`script_grep`): client `HeistClient` 453 (getaway distance and badge); server `LocationServer` 225, `HeistServer` 850 (each hands the Part to its `Getaway`); `WorldSpec` 915 (structure test). None checks the parent's class.

## Evidence (Play 1, before the fixes, character at the city spawn)

Client at 33.8 s: `[HeistClient] <Bank|SlowFoods|Gas2Go> status billboard not found` and `has no StatusBillboardAnchor -- getaway distance disabled` (NewsStation followed at about 48 s), and `Infinite yield possible on 'Workspace.Illegal Supplier:WaitForChild("Interaction")'`. All four marker folders were on the client with **0 children** (their Parts streamed out, 600 to 1,400 studs away). The warning timestamps were 10 s apart (18 s, 28 s, 38 s, 48 s after the first log line): `HeistClient` waited 10 s per location at script top, so its remote listeners (`HeistState`, `DuffelState`, `Toast`, `RobberySuccess`, ...) connected about 48 s after join, and the badge and getaway distance stayed off for the whole session even after the player walked up, because the lookups run once.

## Rows

| # | script | line | lookup (code) | verdict |
|---|---|---|---|---|
| 1 | `HeistClient` | 452 | `workspace:WaitForChild(MARKER_FOLDERS[location], 10)` | SAFE: bounded; the container has no Part of its own and always replicates. |
| 2 | `HeistClient` | 453 | `folder:WaitForChild("StatusBillboardAnchor", 10)` | **FIX**: a Part beyond the streaming radius, needed beyond 128 studs (getaway distance is read 0..250 studs out, the badge to its `MaxDistance` 300), and kept by reference for the session, so a later stream-out/in would leave a dead reference. Fixed in the place: the 4 marker Folders became Models of the same name, `ModelStreamingMode = Persistent` (below). |
| 3 | `HeistClient` | 454-456 | `anchor:WaitForChild("StatusBillboard", 10)` -> `Badge` -> `StatusImage` | **FIX** with row 2 (children of the anchor Part; they come with it). |
| 4 | `HeistClient` | 1204, 1209-1210 | `character.PrimaryPart`; `anchor.Position` | SAFE: nil-guarded every frame; `anchor` valid once row 2 holds. Same horizontal maths as server `Getaway` (both read this one Part's `Position`, Y dropped). |
| 5 | `HeistClient` | 11-14, 20, 28 | `ReplicatedStorage:WaitForChild("HeistShared")`, `("SharedSystems"):WaitForChild(...)` | SAFE: ReplicatedStorage, unbounded but always present (never streams). |
| 6 | `HeistClient` | 43, 56 | `player:WaitForChild("PlayerGui")`, then `player.PlayerGui` | SAFE: 56 runs after 43 resolved it. |
| 7 | `HeistClient` | 349-350, 387-389 | `DuffelUpgradeGui`, `DialogFrame`, buttons, all `WaitForChild(..., 10)` | SAFE: bounded, warns and degrades. |
| 8 | `HeistClient` | 487-488 | `*Shared` / `Config`, `WaitForChild(..., 10)` | SAFE: bounded, ReplicatedStorage. |
| 9 | `HeistClient` | 578-1091 (12 lines) | `remotes:WaitForChild("<Remote>")` | SAFE: ReplicatedStorage remotes created at server boot; unbounded is right (must not give up). |
| 10 | `HeistClient` | 839 | `player.PlayerGui:WaitForChild("LockpickGui")` | SAFE: StarterGui copy, always arrives (seen up to more than 5 s late in the city, which only logs an infinite-yield warning; it never fails to arrive). Not a part that streams. |
| 11 | `HeistClient` | 840 | `lockpickGui.Track` | SAFE: the ScreenGui is copied into PlayerGui as one tree, so its children exist once 839 returns. |
| 12 | `HeistClient` | 841-851 | `lockpickTrack:WaitForChild(...)` (8) | SAFE: as row 11. |
| 13 | `HeistClient` | 909-912 | `shared:WaitForChild("SoundTemplates")`, templates | SAFE: ReplicatedStorage. |
| 14 | `HeistClient` | 569 | `character:FindFirstChild(name)` | SAFE: nil-guarded. |
| 15 | `WordScrambleClient` | 16-18, 50 | `ReplicatedStorage:WaitForChild(...)` | SAFE: ReplicatedStorage. |
| 16 | `WordScrambleClient` | 21-64 (14 lines) | `playerGui:WaitForChild("WordScrambleGui")` and its children | SAFE: StarterGui copy (row 10); Play 1 logged one infinite-yield warning for it (late copy), resolved. |
| 17 | `WordScrambleClient` | 102-146 | `HackCodeGui` and children | SAFE: as row 16. |
| 18 | `WordScrambleClient` | 185-187, 248-354 | sound templates, remotes | SAFE: ReplicatedStorage. |
| 19 | `NotificationClient` | 17-18 | `ReplicatedStorage.SharedSystems.UITransitions`, `ReplicatedStorage.HeistShared.Config` (`.` index) | SAFE: ReplicatedStorage descendants; observed, not guaranteed, as in the FPS audit's RS rows: 0 such errors in the 6 city Plays of this task. |
| 20 | `NotificationClient` | 26-27 | `playerGui:WaitForChild("HeistNotificationGui")`, `NotificationTemplate` | SAFE: StarterGui copy (Play 1: one late-copy warning, resolved). |
| 21 | `NotificationClient` | 142, 153 | `card:FindFirstChild("Body")`, `("AlarmBox")` | SAFE: cloned template, guarded. |
| 22 | `UiButtonEffects` | 23, 25-26 | `ReplicatedStorage:WaitForChild(...)` | SAFE. |
| 23 | `UiButtonEffects` | 24, 27 | `ReplicatedStorage.UI:WaitForChild(...)` | SAFE: `UI` resolved by line 23 first. |
| 24 | `UiButtonEffects` | 36 (all GUI lookups) | `get()` = `WaitForChild(name, timeout or 10)` | SAFE: bounded everywhere. |
| 25 | `SupplierDialogueController` | 22-25 | `ReplicatedStorage:WaitForChild(...)` | SAFE. |
| 26 | `SupplierDialogueController` | 54 | `workspace:WaitForChild("Illegal Supplier")` | SAFE: the Model container replicates (seen at once in Play 1). |
| 27 | `SupplierDialogueController` | 57 | `npcModel:WaitForChild("Illegal Supplier")` (rig) | **FIX** with row 28: a streamed model, held by reference for `DialogModule`. |
| 28 | `SupplierDialogueController` | 58 | `npcModel:WaitForChild("Interaction"):WaitForChild("ProximityPrompt")` | **FIX**: unbounded wait on a streamed Part (Play 1: infinite yield at the spawn); the prompt is held by reference from script start, so after a stream-out/in `prompt.Triggered` would belong to a destroyed copy. Fixed in the place: `Illegal Supplier.ModelStreamingMode = Persistent`. |
| 29 | `CashClaimVFX` | 88 | `script.Parent:WaitForChild("UITheme")` | SAFE on the client (sibling module in ReplicatedStorage). It is the line that fails in `CashClaimVFXSpec` when the spec runs a clone with no parent: Task 5's, not a load-order issue. |
| 30 | `CashClaimVFX` | 79-80, 165-166 | `player:FindFirstChild("leaderstats")`, `("Cash")` | SAFE: guarded. |
| 31 | `CashClaimVFX` | 115, 174-175 | `PlayerGui`, `Custom Inventory` / `cashDisplay` with 10 s | SAFE: bounded, in a spawned thread (Task 2). |
| 32 | 9 `Animate` LocalScripts | n/a | character parts | SAFE: never run (templates in ReplicatedStorage; NPC models in Workspace). |

**32 rows: 4 FIX (rows 2, 3, 27, 28; two fixes), 28 SAFE.**

## Fixes applied (no script changed for them)

1. `Workspace.HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`: each Folder replaced by a `Model` with the same name, children (17 / 6 / 6 / 6 descendants, unchanged) and attributes, `ModelStreamingMode = Persistent`, `CityMergeDeviation` set. Chosen over a server-published attribute because the badge is a BillboardGui on the anchor itself: an attribute would have given the distance but not the badge. Every reader keeps its path; tags (exit spawns, cover points, guard posts, death volume) move with the Parts; no ObjectValue pointed at the old Folders (scan: 0). Both copies of the getaway maths now read the same persistent Part.
2. `Workspace["Illegal Supplier"].ModelStreamingMode` Default -> `Persistent` (293 descendants), `CityMergeDeviation` set.

Cost: 35 marker descendants and 293 supplier descendants always on each client (the client counts about 100,000 game descendants at the spawn).

## Verification

Client console at 25 s from the city spawn, non-asset warnings and errors:

| Play | after | client errors | client non-asset warnings | anchors + badges on client | supplier `Interaction` |
|---|---|---|---|---|---|
| 1 | before the fixes | 0 | 11 distinct (8 HeistClient / Illegal Supplier lines above, plus late StarterGui copies: `Custom Inventory` x8, `WordScrambleGui`, `HeistNotificationGui`, `QuestResponsesGui`) | 0 / 4 | absent |
| 2 | persistent markers + supplier, `UiButtonEffects` edit | 0 | 0 | 4 / 4, classes Model | present |
| 3 | + `NotificationClient` and first `HeistClient` HUD edit | 0 | 0 | not read | not read |
| 4 | all edits (final `HeistClient`) | 0 | 0 | 4 / 4 | not read |
| 5 | all edits | 0 | 0 | not read | not read |
| 6 | all edits | 0 | 0 | not read | not read |

PlayerGui 28 children in Plays 2 to 6. Plays 2 and 3 also logged one client error each later in the session from this run's own `execute_luau` commands (`AssistantCommand:2`, `_T4ClientLog is not a valid member`), not from game code. Server: only the known `Workspace.HQ` lines in every Play.

The late StarterGui copy (Play 1 only) is the same race the FPS audit recorded; it resolves by itself and every Robbery wait on it is either bounded or one that must not give up.

NOT saved / NOT published
