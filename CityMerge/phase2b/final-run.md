# Phase 2b closing run (city place `Crimelife city.rbxl`, 2026-11-15)

Measured in this run (Task 5), after the three first-run leftovers were fixed and re-exported. Target `Crimelife city.rbxl` resolved by name; `FPS System.rbxl`, `Robbery System.rbxl` and Test30.4 untouched. Method as in `CityMerge/first-run.md`: solo Play, console read with `LogService:GetLogHistory()` in the Server and Client datamodels, tests and profile reads from a temporary server `Script` (results through values in `ServerStorage`), everything temporary removed before Play stopped. "Script error" means any Error-type log line other than `Failed to load ...` asset lines. Nothing saved or published.

## The three leftovers (Edit)

| Item | Change | Measured |
|---|---|---|
| `StarterCharacterScripts.Lean` | `lowerTorso.Root` and `humanoidRootPart.RootJoint` now `WaitForChild(name, 10)` plus a quiet `return` on nil | 5,970 / 3351089419 to 6,038 / 2152900123; `CityScripts/` file equals the place |
| `Workspace.FX` | empty `Folder`, attribute `PlacedBy = "phase 2b"` | `workspace:FindFirstChild("FX")` not nil on the client in all 5 Plays; still 0 children after Play 5 (the dust path was not reached) |
| `ServerScriptService.WeaponAnimationPreview` | `Enabled = false`, `CityMergeDeviation = "preview rig folder is not in the city"` | server console has 0 lines mentioning `WeaponAnimationPreview` and 0 `Infinite yield` lines in every Play |

## Five Plays from the city spawn, each read at 25 s

Spawn state: `Workspace.SpawnLocation.Enabled` true, `Workspace.Dev.DevSpawn.Enabled` false, 1 enabled SpawnLocation.

| Play | read at | PlayerGui | PlayerScripts | WalkSpeed | `FX` on client | client script errors | server script errors | `Infinite yield` (client / server) |
|---|---|---|---|---|---|---|---|---|
| 1 | 25.5 s | 21 | 28 | 20 | yes | 0 | 3 (see below) | 0 / 0 |
| 2 | 25.3 s | 21 | 28 | 20 | yes | 0 | 3 | 0 / 0 |
| 3 | 25.4 s | 21 | 28 | 20 | yes | 0 | 3 | 0 / 0 |
| 4 | 25.2 s | 21 | 28 | 20 | yes | 0 | 3 | 0 / 0 |
| 5 | 26.6 s | 21 | 28 | 20 | yes | 0 | 3 (read before the tests ran) | 0 / 0 |

One extra diagnostic Play (spawn switched to `Dev.DevSpawn` for the Play, then restored) read at 25 s: the same 3 server errors, so they do not depend on the spawn.

### The 3 server errors (not from this plan, not fixed)

The same three lines in every Play, from city content under `Workspace.HQ`, a folder that is now in the Edit place (58,277 descendants, 24 scripts, a copy of `ServerStorage.HQ`):

- 2 x `opendoor is not a valid member of Model "Workspace.HQ.Building.Ground_Floor.Reception.Model.Proximity Door.DoorNoHandle"` (the door script `Stairs.Script` reads `script.Parent.Parent.opendoor`; the model has no such child);
- 1 x `Bar is not a valid member of ServerStorage "ServerStorage"` (a script in `Workspace.HQ`, the barista prompt, one of 24).

`Workspace.HQ` was not in the place when this run's first source snapshot was taken (302 containers, none under `Workspace.HQ`) and was there at Play 1 (the error lines name it); who put it there is not recorded. In the earlier Task 4 Plays (`first-run.md`, leg 3) no such line was reported. Without these 3 lines every Play has 0 server script errors. Left in place for the controller and the developer to decide.

## Play 5: tests, purchase, kill, quest

Order: console and GUI read at 25 s, then purchase, kill, quest, and the unit tests last (the `ProfileGateway_Test` mock repoints the store).

| Step | Result |
|---|---|
| Purchase of AK47 through `BuyRequest` from the client | cash 500 to 300 (leaderstats and profile), `WeaponOwned_AK47` nil to true, profile `weaponsOwned` Crowbar + AK47 (saved to the profile) |
| Quest accept, character 5.7 studs from `Workspace.Quests["Level 1 Quest"]` (server `PivotTo`) | state `Accepted`, progress 0; profile `quests` = `{"Level1Thugs":{"state":"Accepted","progress":0}}` read right after |
| First Thug kill (`TakeDamage` then `Eliminated:Fire`, Thug health 90) | XP 0 to 10 (profile xp 10), quest progress 1 (profile `progress 1`), cash 300 |
| 9 more Thug kills | progress 10, state `ReadyToTurnIn` (profile the same); level 3, XP 25, cash 350 |
| Far turn-in (character 45.0 studs away, client `TurnInQuestRequest`) | refused: state `ReadyToTurnIn`, completions 0, cash 350 |
| Near turn-in (4.6 studs) | cash 350 to 875 (+500 quest reward, +25 level-up bonus: the quest's 100 XP crossed level 3 to 4), level 4, XP 65, completions 1, state "", profile `questCompletions` `{"Level1Thugs":1}`, profile `quests` empty, profile cash 875, xp 65, level 4 |
| Unit tests, each suite then all | 16 suites: PropertyAuthority 8, validateRunningState 8, staminaStep 10, Palettes 11, SkinApplier 14, CosmeticsOwnership 12, SpraypaintConstants 8, SpraypaintService 21, SpraypaintTier 8, Schema 9, ProfileGateway 22, ProfileAdoption 17, QuestReach 4, BlasterGuard 4, ShotRate 5, QuestSave 10; sum **171 / 171 / 0**; filter `""` **171 / 171 / 0**; 0 `[FAIL]` or `[TIMEOUT]` lines |

The 147 cases that existed before phase 2b all pass: the 12 original suites now sum to 148 (`ProfileAdoption_Test` gained one case, 16 to 17; the other 11 original suites sum to 131, unchanged from `baseline.md`), and the 4 new suites add 23 (148 + 23 = 171). The unit tests ran on the mock store; the saves above are reads of the in-session profile, not of a DataStore.

## After the last Play (Edit)

- Temporary objects: none (`_T5*` in `ServerStorage` and `ServerScriptService` removed before Play stopped; 0 found in Edit). Spawns: `DevSpawn` false, city `SpawnLocation` true, 1 enabled SpawnLocation.
- `WeaponAnimationPreview.Enabled` false; `Workspace.FX` present.

### Whole-place checksums, against Task 1's baseline (`baseline.md`)

Definitions as in `baseline.md`: Adler-32 over the sorted `<full name>=<Source>` entries (source) joined with `\n`; the Enabled form over `<full name>=<Enabled>`.

| | containers | BaseScripts | enabled | Enabled checksum | source checksum |
|---|---|---|---|---|---|
| Task 1 baseline | 297 | 196 | 121 | 336067737 | 215335317 |
| before this run's Plays (Edit) | 302 | 196 | 120 | 3334077668 | 3626723810 |
| after Play 5 (Edit), whole place incl. `Workspace.HQ` | 326 | 220 | 144 | 4126413690 | 3149783013 |
| after Play 5, `Workspace.HQ.*` rows left out | 302 | 196 | 120 | not recomputed | rows identical to "before" (the only difference is the `Workspace.HQ.*` set, 24 containers) |

Per-script comparison with the baseline: the 26 sources exported in Task 1 (`git show f2c2a68:CityScripts/...`) and the three recorded old values for scripts Task 1 did not export (`QuestFeedbackController` 3,283 / 1810268451, `Schema_Test` 3,688 / 1558435936, `ProfileAdoption_Test` 18,152 / 2120294281, from `after-import.md`) were put back, the 5 new modules left out, and the combined Adler-32 recomputed from per-entry (length, Adler-32) with `adler32_combine`: **215335317, the baseline value, over 297 containers.** So the scripts whose Adler-32 differs from Task 1's baseline are exactly these 19, and nothing else:

| Edited (14) | New in this plan (5) |
|---|---|
| `ReplicatedStorage.Persistence.Schema` | `ServerScriptService.Blaster.Scripts.Blaster.validateFireInterval` |
| `ReplicatedStorage.Quests.QuestConfig` | `ServerStorage.UnitTest.Cases.BlasterGuard_Test` |
| `ReplicatedStorage.UI.CashBurst` | `ServerStorage.UnitTest.Cases.QuestReach_Test` |
| `ServerScriptService.Blaster.Scripts.Blaster.validateShootArguments` | `ServerStorage.UnitTest.Cases.QuestSave_Test` |
| `ServerScriptService.Blaster.Scripts.Blaster.validateShot` | `ServerStorage.UnitTest.Cases.ShotRate_Test` |
| `ServerScriptService.Quests.Scripts.QuestService` | |
| `ServerScriptService.Weapons.Scripts.LevelingService` | |
| `ServerStorage.UnitTest.Cases.ProfileAdoption_Test` | |
| `ServerStorage.UnitTest.Cases.Schema_Test` | |
| `StarterPlayer.StarterCharacterScripts.Lean` | |
| `StarterPlayer.StarterPlayerScripts.AdminLevelController` | |
| `StarterPlayer.StarterPlayerScripts.DamageDirectionIndicator` | |
| `StarterPlayer.StarterPlayerScripts.PromptUiController` | |
| `StarterPlayer.StarterPlayerScripts.QuestFeedbackController` | |

This equals the set of scripts phase 2b edited or created (Tasks 2 to 5; `WeaponaryShopController`, edited in 2a, is baseline here). The Enabled checksum differs from the baseline in one script, `WeaponAnimationPreview` (enabled 121 to 120); the Enabled checksum was not recomputed with that flag flipped back.

## Not run

- Real mouse fire (the rate-of-fire margin), pressing E on a quest giver, a phone, a second player, a published place.
- Respawn after 10 s (not in the brief's step list for this run).

NOT saved / NOT published
