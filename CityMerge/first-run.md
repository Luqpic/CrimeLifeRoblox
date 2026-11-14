# First run of the FPS systems in the city (Task 4)

Measured 2026-11-15. Target `Crimelife city.rbxl`; comparison Play in `FPS System.rbxl` (read-only: Play only, no change). Both windows resolved by name. Every number below came from a call made in this run; "not recorded" where none was made. No script was edited. Nothing saved or published.

Method: solo Play (`start_stop_play`), console read with `LogService:GetLogHistory()` in the Server and Client datamodels (distinct lines by exact text), client readings from one Client `execute_luau` call, server readings and unit tests from temporary server `Script`s created during Play (results passed back through a `StringValue` in `ServerStorage`; both gone when Play stopped). The same code was run in both places.

## Step 1: spawns (Edit, before Play)

| | before | for the run | after Step 6 |
|---|---|---|---|
| `Workspace.Dev.DevSpawn.Enabled` | false | true | false |
| `Workspace.SpawnLocation.Enabled` (city) | true | false | true |
| enabled SpawnLocations in Workspace | 1 | 1 | 1 |

The character spawned at the slab in both places: city (16.4, 4.1, 50.3), FPS (16.6, 4.1, 49.3).

## Streaming settings

| | FPS System | Crimelife city |
|---|---|---|
| StreamingEnabled | true | true |
| StreamingMinRadius | **64** | **128** |
| StreamingTargetRadius | **1024** | **512** |
| StreamingIntegrityMode | PauseOutsideLoadedArea | PauseOutsideLoadedArea |
| ModelStreamingBehavior | not readable by script | not readable by script |

The radii differ. No behaviour below could be traced to them; the FPS content (enemy spawns span x -186..267, z -204..328) lies inside 512 studs of the slab spawn.

## Step 2: console (about 20 s after Play)

City, Server: 172 messages (6 output, 91 warnings, 75 errors), 29 distinct warning/error lines. Client: 392 messages (4 output, 125 warnings, 263 errors), 31 distinct.
FPS (fresh Play today), Server: 149 messages (6 output, 77 warnings, 66 errors), 22 distinct. Client: 337 messages (1 output, 92 warnings, 244 errors), 29 distinct.

Classified line by line:
- **City-recorded asset lines (the 9 known, 2026-11-14):** present, 8 of them (4 `ContentId ... failed` warnings: empty id, `rbxassetid://0`, 188608071, 130839932; 4 matching `Failed to load sound` errors on the server). The ninth, "Animation Spoofer cannot run while game is running", is an output line (seen in the client history, message type Output). Expected.
- **FPS baseline asset lines:** the 3 animation ids and 9 sound ids, with their warnings, in both places. Also in both places today: `Failed to load animation ... 91946150190183` and `... 89055632668771` on the server (the baseline recorded 89055632668771 on the client only and 91946150190183 as a warning only). Same in both places today, so not a port issue.
- `Infinite yield possible on 'Workspace:WaitForChild("WeaponAnimationPreview")'`: both. Expected.
- Unit-test noise after Step 4 (StartSessionAsync already loaded, migrate -1, hydrator `FindFirstChild` on table at `CashService:94` / `LevelingService:113`, late post-hydrator): both, as the baseline describes.
- `MonetizationService: ownership check failed for gamepass "RPG"` (warning): **FPS only** today, not in the city and not in the baseline. A failed web call in the FPS run; not a city issue.
- **In neither known set, city only:** one client error, reproduced in a second city Play (2 of 2 runs), absent from today's FPS client and from the baseline:
  ```
  HumanoidRootPart is not a valid member of Model "Workspace.SolarAudio"
  Stack Begin / Script 'Workspace.SolarAudio.Lean', Line 25 / Stack End
  ```
  Raised by `StarterPlayer.StarterCharacterScripts.Lean` line 25 (`local humanoidRootPart = character.HumanoidRootPart`). See the fix list.

After the purchase and kill (below) no further non-asset warning or error appeared on either client; the city server added only the unit-test noise.

## Step 3: client (one Client call; viewport 1080 x 659 in both)

City read at 87 s after start, FPS at 44 s.

| PlayerGui child | class | city Enabled | FPS Enabled | first GuiObject (by name), AbsoluteSize, city | same, FPS |
|---|---|---|---|---|---|
| GamepassShopGui | ScreenGui | true | true | GamepassShop 760 x 570 | 760 x 570 |
| DeathScreenGui | ScreenGui | true | true | DeathScreen 1080 x 659 | 1080 x 659 |
| PromptUiGui | ScreenGui | true | true | (none) | (none) |
| SkinsCardGui | ScreenGui | false | false | SkinsCard 240 x 580 | 240 x 580 |
| WeaponaryShopGui | ScreenGui | true | true | WeaponaryShop 920 x 580 | 920 x 580 |
| StaminaGui | ScreenGui | true | true | StaminaBar 240 x 10 | 240 x 10 |
| QuestLogGui | ScreenGui | true | true | QuestLog 420 x 460 | 420 x 460 |
| PlayerCardGui | ScreenGui | true | true | (none) | (none) |
| DamageDirectionIndicator | ScreenGui | true | true | (none) | (none) |
| LevelingGui | ScreenGui | true | true | LevelUpPopup 360 x 90 | 360 x 90 |
| NotificationGui | ScreenGui | true | true | Container 280 x 84 | 280 x 84 |
| CashShopGui | ScreenGui | true | true | CashShop 760 x 570 | 760 x 570 |
| AdminLevelGui | ScreenGui | false | false | Panel 300 x 200 | 300 x 200 |
| Freecam | ScreenGui | true | true | (none) | (none) |
| Bobbing Camera | LocalScript | true | true | n/a | n/a |
| Custom Inventory | ScreenGui | true | true | Inventory 563.5 x 240.0 | 563.5 x 240.0 |
| QuestResponsesGui | BillboardGui | true | true | dialogResponses 0 x 0 | 0 x 0 |
| BlasterGui | ScreenGui | false | false | Blaster 59.5 x 56 | 59.5 x 56 |
| ReticleGui | ScreenGui | false | false | Hitmarker 50 x 50 | 50 x 50 |
| BlasterTouchGui | ScreenGui | false | false | Buttons 280 x 290 | 280 x 290 |
| **TImeScripts** | Folder | n/a | **absent** | n/a | n/a |
| **count** | | **21** | **20** | | |

The one extra child is the city's own `StarterGui.TImeScripts` (from the original city file): a Folder of 42 descendants: two ScreenGuis, `SunRays` and `TimeSelection`, both `Enabled = false` (read in Edit), with 8 TextButtons, 3 TextLabels, 1 Frame and styling, and **no script at all**. It shows nothing and runs nothing.

| reading | city | FPS |
|---|---|---|
| PlayerScripts children | 28, same names as the baseline list | 28, same names |
| Humanoid.WalkSpeed | 20 | 20 |
| HumanoidRootPart present at read time | yes | yes |
| Backpack / character Tools | Crowbar / none | Crowbar / none |
| Workspace.EnemySpawns on client | yes, 12 descendants | yes, 12 |
| Workspace.Quests on client | yes, 1,892 descendants | yes, 1,892 |
| Workspace.AnimVM (viewmodel container) | yes | yes |
| Workspace.Enemies on client | 30 children | 20 children |
| client `#workspace:GetDescendants()` | 30,541 | 8,261 (baseline 5,091 at 11 s) |
| time of that call, first / second | 11.69 ms / 2.82 ms | 4.35 ms / 0.77 ms |
| 6 `NPCprompt` prompts on the client | all 6, Style Custom, Enabled | all 6, Style Custom, Enabled |
| ProximityPrompts on the client | 6 (all Custom) | 6 (all Custom) |
| PromptUiGui children (no prompt in range) | 0 | 0 |

Workspace children seen by the city client (14): Accessory Storage, AnimVM, Camera, Dev, Enemies, EnemySpawns, Ground, Map, Plots, Quests, the character, Targets, Terrain, TycoonPreview. FPS (16) also has Baseplate, Model, Part, SpawnLocation, UI and "UI Animation Pack - by JakeDev" (left behind by plan) at top level, which the city holds under `Dev` or does not import.

**PromptUiController (the suspect):** the 6 quest-giver prompts are saved with Style `Custom` in Edit in both places, so the controller's `forceCustom` scan (lines 31-35) is not what styles them; they arrive Custom either way, and its `DescendantAdded` handler (line 36) also catches anything that streams in later. The scan itself, measured with an equivalent call, costs 11.69 ms once in the city vs 4.35 ms in FPS. Observed: no difference in how the quest-giver prompts are handled. Read in Edit, not observed at runtime: the city map holds 26 ProximityPrompts with Style `Default`; none had streamed in to the client at the slab, and when one does the controller will switch it to `Custom` and draw the FPS prompt face on it.

## Step 4: unit tests (temporary server Script, per suite, then all)

| suite | city run / passed / failed | FPS today | FPS baseline |
|---|---|---|---|
| PropertyAuthority_Test | 8 / 8 / 0 | 8 / 8 / 0 | 8 / 8 / 0 |
| validateRunningState_Test | 8 / 8 / 0 | 8 / 8 / 0 | 8 / 8 / 0 |
| staminaStep_Test | 10 / 10 / 0 | 10 / 10 / 0 | 10 / 10 / 0 |
| Palettes_Test | 11 / 11 / 0 | 11 / 11 / 0 | 11 / 11 / 0 |
| SkinApplier_Test | 14 / 14 / 0 | 14 / 14 / 0 | 14 / 14 / 0 |
| CosmeticsOwnership_Test | 12 / 12 / 0 | 12 / 12 / 0 | 12 / 12 / 0 |
| SpraypaintConstants_Test | 8 / 8 / 0 | 8 / 8 / 0 | 8 / 8 / 0 |
| SpraypaintService_Test | 21 / 21 / 0 | 21 / 21 / 0 | 21 / 21 / 0 |
| SpraypaintTier_Test | 8 / 8 / 0 | 8 / 8 / 0 | 8 / 8 / 0 |
| Schema_Test | 9 / 9 / 0 | 9 / 9 / 0 | 9 / 9 / 0 |
| ProfileGateway_Test | 22 / 22 / 0 | 22 / 22 / 0 | 22 / 22 / 0 |
| ProfileAdoption_Test | 16 / 16 / 0 | 16 / 16 / 0 | 16 / 16 / 0 |
| **sum of suites** | **147 / 147 / 0** | **147 / 147 / 0** | **147 / 147 / 0** |
| filter `""` (all) | 147 / 147 / 0 | 147 / 147 / 0 | 147 / 147 / 0 |

`[FAIL]` lines captured through `LogService.MessageOut` during the runs: 0 in each place.

## Step 5: server checks (temporary server Script)

| | city (119 s after start) | FPS (59 s after start) |
|---|---|---|
| profile bound (`ProfileGateway.get`) | yes | yes |
| profile Data cash / level / xp | 500 / 1 / 0 | 500 / 1 / 0 |
| `leaderstats.Cash` | **500** | **500** |
| Level, XP attributes | 1, 0 | 1, 0 |
| server Backpack / character Tools / LoadoutSlot1 | Crowbar / none / Crowbar | Crowbar / none / Crowbar |
| spawn points with `EnemyType` | 6 | 6 |
| live enemies under `Workspace.Enemies` | 30 | 26 |
| per type (nearest spawn point gives the same split) | Thug, Offender, Disrupters, Smuggler, Bandits, Saboteur: 5 each | Thug 5, Saboteur 5, Disrupters 5, Bandits 4, Smuggler 4, Offender 3 |

Every live enemy's nearest spawn point is the point of its own type, in both places; all six points produced. The cap is 5 per type (30); the FPS reading was taken 60 s earlier in the session, so its 26 is a top-up still in progress, not a difference.

## Purchase and kill through the game's own paths

Seams used (no script edited): the purchase goes through the real remote, `ReplicatedStorage.Weapons.Remotes.BuyRequest:FireServer("AK47")` from the Client, handled by `WeaponShopService` lines 320-364. The kill reproduces what `ShotResolver` does on a lethal hit (lines 570 and 654): `humanoid:TakeDamage(health)` then `ServerScriptService.Blaster.Events.Eliminated:Fire(player, humanoid, damage, "Crowbar")` from a temporary server Script; `LevelingService` (lines 257-270), `CashService`, `QuestService`, `KillStatsService` and `SpraypaintService` listen to that event. No cash grant was needed: the cheapest sellable non-gamepass gun is AK47 at 200 in both places, under the starting 500. The sequence ran after the unit tests in both places (the same order).

| step | city | FPS |
|---|---|---|
| before buy: cash, `WeaponOwned_AK47`, profile weaponsOwned | 500, nil, Crowbar | 500, nil, Crowbar |
| after buy (client and server): cash, `WeaponOwned_AK47` | 300, true | 300, true |
| after buy: profile weaponsOwned, profile cash | Crowbar, AK47; 300 | Crowbar, AK47; 300 |
| kill target | Thug (Crowbar), health 90 | Thug (Crowbar), health 90 |
| before kill: XP, Level, NextLevelXP | 0, 1, 30 | 0, 1, 30 |
| after kill: health, XP, Level, profile xp | 0, 10, 1, 10 | 0, 10, 1, 10 |
| after kill: cash, `Workspace.CashDrops` children | 300, 1 | 300, folder absent |

XP 10 is `XP_VALUES.Melee` (the Thug carries a melee weapon) in both. The cash drop is a 30% roll per kill (`Enemies and Spawner`), so one drop in the city and none in FPS is chance, not a difference. Not recorded: shooting a real round (needs a person at the mouse) and equipping the AK47 into a slot.

## Step 6: after Play

- Both windows in Edit (`list_roblox_studios`).
- Spawns restored: `DevSpawn.Enabled = false`, city `SpawnLocation.Enabled = true`, 1 enabled SpawnLocation in Workspace.
- City `#workspace:GetDescendants()` = **168,624**. StreamingEnabled true, Plots 8 children, 0 unanchored BaseParts under `Workspace.Map`. No `_T4*` object left in `ServerStorage` or `ServerScriptService`.
- Scripts unchanged, by checksum taken in Edit before the first Play and after the last (Adler-32 over the sorted list of every BaseScript's full name and `Enabled`, and over every LuaSourceContainer's full name and `Source`):

| | BaseScripts | enabled | Enabled checksum | source containers | source checksum |
|---|---|---|---|---|---|
| city before | 196 | 121 | 336067737 | 297 | 4045279041 |
| city after | 196 | 121 | 336067737 | 297 | 4045279041 |
| FPS before | 112 | 111 | 128569116 | 213 | 2816375716 |
| FPS after | 112 | 111 | 128569116 | 213 | 2816375716 |

## Screenshots (Edit)

- `screenshots/task4-dev-area.jpg`: camera (60, 60, 140) looking at (0, 5, 50). The FPS test map on the baseplate: two grey ramps, red crates, target dummies, the six quest givers, the round spawn pad; two enemy spawn points far left and right. The imported HUD overlays the left side (Cash 0 in Edit).
- `screenshots/task4-city-spawn.jpg`: camera (30, 40, 2550) looking at the city SpawnLocation (-11, 1.5, 2498.75): the city crossroads with the spawn pad, a car, street lights and plots behind; the same HUD overlay.

## What matched

PlayerScripts (28, same names), WalkSpeed 20, every FPS ScreenGui with the same Enabled and the same first-frame size at the same viewport, EnemySpawns / Quests / AnimVM on the client, starting Crowbar, profile bound, Cash 500, all six spawn points producing their own type, 147 / 147 tests per suite, the purchase (500 -> 300, ownership set and saved to the profile) and the kill (XP 0 -> 10, saved to the profile), quest-giver prompts present and Custom on the client.

## What differed

1. A client error from `Lean` line 25 in the city (2 of 2 Plays), absent in FPS.
2. PlayerGui has 21 children in the city vs 20: the city's own inert `TImeScripts` folder.
3. Streaming radii: 128 / 512 in the city vs 64 / 1024 in FPS.
4. Client instance count and the cost of a full `workspace:GetDescendants()` scan: 30,541 and 11.69 ms vs 8,261 and 4.35 ms.
5. 26 city ProximityPrompts are saved `Default`; `PromptUiController` will restyle them when they stream in (code reading, not observed).

## Fix list

### Must fix (the plan's gate: an error from an imported script that FPS lacks)

| # | what differs (evidence) | root cause (code) | smallest fix | test that proves it | risk |
|---|---|---|---|---|---|
| 1 | Client error `HumanoidRootPart is not a valid member of Model "Workspace.<player>"`, stack `Workspace.<player>.Lean, Line 25`, in 2 of 2 city Plays; 0 in today's FPS Play and in the baseline. Observed effect on play: none found; the character had its HumanoidRootPart when read later, and WalkSpeed, tools and movement readings match. | `StarterPlayer.StarterCharacterScripts.Lean` lines 24, 25 and 33 index `character.Humanoid`, `character.HumanoidRootPart`, `character.LowerTorso` with `.` at script start; in the city the root part is not yet a child of the character when the script runs. Why it arrives later in the city is not proven (the city client streams far more: 30,541 vs 8,261 instances); the character model's `ModelStreamingMode` is Default. Only this script does that: a scan of every StarterCharacterScripts source's first 60 lines found no other direct part index. | In `Lean` itself (it is the only caller; there is no shared module on this path): `character:WaitForChild("Humanoid")`, `character:WaitForChild("HumanoidRootPart")`, `character:WaitForChild("LowerTorso")` on lines 24, 25 and 33. Alternative to weigh: on this place's R15 rig the root joint is an `AnimationConstraint` (read in the city Play), so `Lean` already returns at line 43-44 in FPS and does nothing; deleting it would remove the error and no behaviour. | Two city Plays: the client `LogService` history holds no line with `Lean`; one FPS Play stays clean; `diff` the edited source against the mirror shows only those three lines. | Low. `WaitForChild` without a timeout waits forever if a rig has no LowerTorso (R6), but the R15 branch is the only one that reaches line 33. Deletion: loses the lean if the rig ever goes back to Motor6D joints. |

### Should fix (robustness / performance under streaming; the game works without them)

| # | what differs (evidence) | root cause | smallest fix | test | risk |
|---|---|---|---|---|---|
| 2 | 26 city ProximityPrompts saved `Style = Default` (read in Edit); on the client at the slab none had streamed in, so the restyle was **not observed**. | `StarterPlayerScripts.PromptUiController` lines 31-40 force every ProximityPrompt in Workspace to `Custom` and draw the FPS face on it (comment line 3: kept identical with the Robbery place). | A decision, not a code bug: if the city's own prompts should keep Roblox's face, scope the controller to tagged prompts in the controller itself (one check in `forceCustom` and in `PromptShown`); if they should get the FPS face, no change. | Teleport the client next to a city prompt and read its `Style` and `PromptUiGui` children. | The Robbery place shares this script; any change must be made in both or it breaks the "identical" rule. |

The full scan in `PromptUiController` costs 11.69 ms once at client start in the city (4.35 ms in FPS); `DescendantAdded` already covers prompts that stream in later. Measured as negligible, so no fix is proposed.

### Same in both places, or not a port issue

- `WeaponAnimationPreview` infinite yield; `Crouching`'s `workspace.FX` (not reached in this run): both places.
- Asset-permission errors and warnings (animations, sounds), including 91946150190183 and 89055632668771 on the server: both places today.
- `MonetizationService` RPG ownership warning: FPS only, a failed web call; not a city issue.
- `TImeScripts` in PlayerGui (the 21st child): city content, two disabled ScreenGuis, no scripts; inert. Keep or remove as a city decision.
- Streaming radii differ (128 / 512 vs 64 / 1024); no behaviour traced to them. Worth a decision when the play moves into the city (Task 5), not a fix here.
- Enemy count and cash-drop differences: different read times and a 30% roll.

NOT saved / NOT published
