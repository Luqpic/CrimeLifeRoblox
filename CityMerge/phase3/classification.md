# Robbery roots: proposed classification (PROPOSAL, awaiting the gate)

Basis: `CityMerge/phase3/robbery-manifest.*` (Robbery, measured 2026-11-16) against the city read live in the same run (`citytsv`: every LuaSourceContainer's full name and Adler-32; `cityroots`: every root of every service). Rules are those of `task-1-brief.md`. A row's "Basis" names the rule or the reference that decides it. **G1 to G12** are the rows the rules do not settle; their facts are under "For the gate".

Verdict counts: **carry 38, use city 5, bridge 1, rename 1, leave behind 11** (56 roots).
Step 3 classes: **robbery-only 43, identical 1, differs 4, same name different thing 8** (the five `Lighting` rows are same-named, same-class city objects whose settings were not compared; they are left behind either way).

Method of Step 3: script roots compared by Adler-32 of every script at the same full name; non-script roots by name and class (and, for `QuestResponsesGui`, a property fingerprint over 13 nodes). `differs` rows were diffed from both sides (source of both read in this run).

## Roots

| # | Root | Verdict | Step 3 class | Basis | Note |
|---|---|---|---|---|---|
| 1 | Workspace/Baseplate | leave | robbery-only | Leave rule: baseplate | city ground is `Workspace.Ground.Baseplate` |
| 2 | Workspace/SpawnLocation | leave | same name, different thing | Leave rule: spawn | city `Workspace.SpawnLocation` is the only enabled spawn |
| 3 | Workspace/Bank | carry | robbery-only | Carry: `HeistServer`, `WorldSpec`; Bank set | transform in `locations.md`; G1 G2 G3 |
| 4 | Workspace/BankVault | carry | robbery-only | Carry: `HeistServer`, `SafeCode`, `LocationServer`; Bank set | by path `workspace.BankVault`; G1 |
| 5 | Workspace/HeistZones | carry | robbery-only | Carry: `HeistServer` (`workspace.HeistZones`); Bank set |  |
| 6 | Workspace/HeistMarkers | carry | robbery-only | Carry: `HeistServer`, `HeistClient` (`MARKER_FOLDERS`); Bank set |  |
| 7 | Workspace/SlowFoods | carry | robbery-only | Carry: `SlowFoodsServer`; SlowFoods set |  |
| 8 | Workspace/SlowFoodsZones | carry | robbery-only | Carry: tagged zone; SlowFoods set |  |
| 9 | Workspace/SlowFoodsMarkers | carry | robbery-only | Carry: `markerFolder = SlowFoodsMarkers`; SlowFoods set |  |
| 10 | Workspace/Gas2Go | carry | robbery-only | Carry: `Gas2GoServer`; Gas2Go set |  |
| 11 | Workspace/Gas2GoZones | carry | robbery-only | Carry: tagged zone; Gas2Go set |  |
| 12 | Workspace/Gas2GoMarkers | carry | robbery-only | Carry: `markerFolder = Gas2GoMarkers`; Gas2Go set |  |
| 13 | Workspace/Animation Tool | leave | robbery-only | Leave rule: only a test map needs it | Studio tool LocalScript; `script_grep` finds no reference |
| 14 | Workspace/Illegal Supplier | carry | robbery-only | Carry: `SuppliesServer`, `SupplierDialogueController` (`workspace:WaitForChild("Illegal Supplier")`) | in no location's set; G11 |
| 15 | Workspace/NewsStation | carry | robbery-only | Carry: `NewsStationServer`; NewsStation set |  |
| 16 | Workspace/NewsStationZones | carry | robbery-only | Carry: tagged zone; NewsStation set |  |
| 17 | Workspace/NewsStationMarkers | carry | robbery-only | Carry: `markerFolder = NewsStationMarkers`; NewsStation set |  |
| 18 | ReplicatedStorage/HeistShared | carry | robbery-only | Carry: required by every Heist script | `Config`, `Signal`, `TestRunner`, remotes, `DuffelBag`, templates |
| 19 | ReplicatedStorage/SharedSystems | carry | robbery-only | Carry: required by every location script, `HeistClient` | `CashClaimVFX` builds its own `CashDisplay`; G5 |
| 20 | ReplicatedStorage/RestaurantShared | carry | robbery-only | Carry: `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer` |  |
| 21 | ReplicatedStorage/Gas2GoShared | carry | robbery-only | Carry: `Gas2GoServer` |  |
| 22 | ReplicatedStorage/NewsStationShared | carry | robbery-only | Carry: `NewsStationServer` |  |
| 23 | ReplicatedStorage/Modules | use city | differs | Use city copy: city has the same three modules | 3 of 3 differ: comments only in `PropertyAuthority`, `CameraAuthority`; `MenuFovBlur` also lacks `acquire` in the city (G7) |
| 24 | ReplicatedStorage/UI | use city | differs | Use city copy: named in the brief | `Effects`, `PromptUI` identical; `Sounds`, `Transitions` differ in comments only; city adds `CashBurst` |
| 25 | ReplicatedStorage/DialogModule | use city | identical | Use city copy: identical (Adler-32 1459106551 both) |  |
| 26 | ServerScriptService/Heist | carry | robbery-only | Carry: the engine, with `Tests` (65 scripts) | `Tests` needed by the suite (`spec-baseline.md`) |
| 27 | ServerScriptService/PlayerData | bridge | robbery-only | Bridge: `CurrencyService` (Task 2); leave the save layer | `DataStoreBackend`, `MemoryBackend` left; `CurrencyAdapter` and `MemoryBackend` are required by `CurrencySpec` (G4) |
| 28 | ServerScriptService/HeistServer | carry | robbery-only | Carry: named server script | Bank, not on `LocationServer` |
| 29 | ServerScriptService/SlowFoodsServer | carry | robbery-only | Carry: named server script | `openCFrame` literal at line 198 (G12) |
| 30 | ServerScriptService/Gas2GoServer | carry | robbery-only | Carry: named server script | `openCFrame` literal at line 252 (G12) |
| 31 | ServerScriptService/SuppliesServer | carry | robbery-only | Carry: named server script | calls `currency:Add` (line 91) |
| 32 | ServerScriptService/NewsStationServer | carry | robbery-only | Carry: named server script | `openCFrame` literal at line 276 (G12) |
| 33 | ServerStorage/GuardTemplate | carry | robbery-only | Carry: `GuardPost` (`ServerStorage:FindFirstChild("GuardTemplate")`), `WorldSpec` |  |
| 34 | ServerStorage/RBX_ANIMSAVES | leave | same name, different thing | Leave rule: only a test map needs it | animation editor store; city has its own `ServerStorage.RBX_ANIMSAVES` (7 descendants); no script reference |
| 35 | StarterGui/LockpickGui | carry | robbery-only | Carry: `HeistClient` waits `LockpickGui` |  |
| 36 | StarterGui/HackCodeGui | carry | robbery-only | Carry: `WordScrambleClient` waits `HackCodeGui` |  |
| 37 | StarterGui/WordScrambleGui | carry | robbery-only | Carry: `WordScrambleClient` waits `WordScrambleGui` |  |
| 38 | StarterGui/NotificationGui | rename `HeistNotificationGui` | same name, different thing | Same-name rule; expected case | city `NotificationGui` is built at runtime by `ReplicatedStorage.Modules.NotificationController`; G6 |
| 39 | StarterGui/DuffelUpgradeGui | carry | robbery-only | Carry: `HeistClient` waits `DuffelUpgradeGui` |  |
| 40 | StarterGui/QuestResponsesGui | use city | differs | Use city copy: DialogModule's own asset | 13 nodes both, property fingerprint differs (not diffed per property) |
| 41 | StarterPack/PlaceholderPistol_TODO_ReplaceWithRealAsset | leave | robbery-only | Leave rule: test asset | only `Weapon`-tagged tool in the place; G9 |
| 42 | StarterPack/tommy gun | leave | robbery-only | Leave rule: test weapon | 16 scripts, not tagged `Weapon`, no script references it |
| 43 | Lighting/Sky | leave | same name, different thing | Leave rule: lighting | city `Lighting.Sky` exists; settings not compared |
| 44 | Lighting/SunRays | leave | same name, different thing | Leave rule: lighting | city `Lighting.SunRays` exists; settings not compared |
| 45 | Lighting/Atmosphere | leave | same name, different thing | Leave rule: lighting | city `Lighting.Atmosphere` exists; settings not compared |
| 46 | Lighting/Bloom | leave | same name, different thing | Leave rule: lighting | city `Lighting.Bloom` exists; settings not compared |
| 47 | Lighting/DepthOfField | leave | same name, different thing | Leave rule: lighting | city `Lighting.DepthOfField` exists; settings not compared |
| 48 | StarterPlayerScripts/HeistClient | carry | robbery-only | Carry: HUD client |  |
| 49 | StarterPlayerScripts/WordScrambleClient | carry | robbery-only | Carry: hacking client |  |
| 50 | StarterPlayerScripts/NotificationClient | carry | robbery-only | Carry: location cards client; follows G6 | waits `StarterGui.NotificationGui` (renamed with it) |
| 51 | StarterPlayerScripts/UiButtonEffects | carry | robbery-only | Carry: not in the city | brief expected a city copy; it does not exist (`UiButtonEffects` is Heist-specific: `HeistHUD`, `HeistModals`, `CashDisplay`, `DuffelUpgradeGui`...); calls `MenuFovBlur.acquire` (G7, G8) |
| 52 | StarterPlayerScripts/SupplierDialogueController | carry | robbery-only | Carry: supplier client (uses `DialogModule`) |  |
| 53 | StarterPlayerScripts/PromptUiController | use city | differs | Use city copy: named in the brief | city adds `screen.ZIndexBehavior = Sibling` (phase 2b); otherwise equal |
| 54 | StarterCharacterScripts/DuffelInitiateSound | carry | robbery-only | Carry: `Net:PlayCue` / `HeistClient playCue` play it by name |  |
| 55 | StarterCharacterScripts/DuffelFullSound | carry | robbery-only | Carry: `Net:PlayCue` / `HeistClient playCue` play it by name |  |
| 56 | StarterCharacterScripts/CashOutSuccessSound | carry | robbery-only | Carry: `Net:PlayCue` / `HeistClient playCue` play it by name |  |

## `differs` rows: what differs (read from both sides)

| Script (Robbery vs city) | Difference |
|---|---|
| `ReplicatedStorage.Modules.PropertyAuthority` | Robbery has 4 extra header comment lines ("SHARED WITH THE FPS System place"); code identical. |
| `ReplicatedStorage.Modules.CameraAuthority` | Comments only (both places' comment text differs; the code lines are equal after dropping comments). |
| `ReplicatedStorage.Modules.MenuFovBlur` | **Robbery has behaviour the city lacks:** `MenuFovBlur.acquire(): () -> ()` (lines 56-66; calls `open()` and returns a release function that calls `close()` once; double release is a no-op). Only caller: `StarterPlayerScripts.UiButtonEffects` line 183 (`local releaseBlur = MenuFovBlur.acquire()`). Rest is comments. |
| `ReplicatedStorage.UI.Sounds` | Comments only. |
| `ReplicatedStorage.UI.Transitions` | Comments only (plus two blank lines). |
| `StarterPlayer.StarterPlayerScripts.PromptUiController` | City has one extra line: `screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling` (phase 2b). Otherwise equal. |
| `StarterGui.QuestResponsesGui` | 13 nodes in both; the property fingerprint differs (Size, Position, colour, text, Billboard properties); not diffed per property. |

## PlayerGui names that a Robbery script creates or waits for

| Name | Robbery source | City | Class | Proposed |
|---|---|---|---|---|
| HeistHUD | `HeistClient` creates (line 40) | none | robbery-only | carry |
| HeistModals | `HeistClient` creates (line 52) | none | robbery-only | carry |
| CashDisplay | `CashClaimVFX:_buildPersistentGui` creates | none (the city has no always-on cash GUI) | robbery-only | G5 |
| CashBurst | `CashClaimVFX:PlaySequence` creates (transient) | none by that name (`UI.CashBurst` is a module that owns its own overlay) | robbery-only | carry |
| LockpickGui, HackCodeGui, WordScrambleGui, DuffelUpgradeGui | static `StarterGui` children, waited by `HeistClient`, `WordScrambleClient`, `UiButtonEffects` | none | robbery-only | carry |
| NotificationGui | static `StarterGui` child with `NotificationTemplate`, waited by `NotificationClient`, `UiButtonEffects` | runtime ScreenGui from `NotificationController` (line 43), `Container` | same name, different thing | rename `HeistNotificationGui` unless G6 rules otherwise |
| QuestResponsesGui | `DialogModule` line 40 waits it | `StarterGui.QuestResponsesGui` | differs | use city |
| PromptUiGui | `PromptUiController` line 21 creates | same name, same purpose (city copy of the same script) | differs (one line) | use city script |

## Tags and collision groups

- **Tags in use, Robbery vs city:** every place-content tag in `robbery-manifest.md` is robbery-only by name (the city has none of `Heist*`, `SlowFoods*`, `Gas2Go*`, `NewsStation*`, `Bank*`, `Cashier`, `CashRegister`, `CounterBarrier`, `NPCSpawner`, `Weapon`). `NPCprompt` exists in both (Robbery 1, city 6) with the same meaning, the shared `DialogModule` billboard engine: same thing, no rename. `ThreeDTextObject` / `ThreeDTextObjectBoundingBox` exist in both (Robbery 13, city 27): plugin tags, same meaning. The Studio/plugin tags are the same in both places (CoreGui/PluginGui instances). The city's own tags the Robbery code does not use: `Blaster` 21, `EnemySpawnPoint` 6, `Target` 7.
- **Collision groups:** Robbery `Default` only; city `Default` only. Identical, nothing to import.

## For the gate

| # | Row | Facts | Options |
|---|---|---|---|
| G1 | Bank set does not fit | Set footprint 271.4 x 382.0 against city `Bank` 132.5 x 162.0 (+138.9 X, +220.0 Z, both over 20). Transformed by the art registration (yaw 0), `BankVault` lands at x 1319.7..1411.3, z 2258.0..2619.0 (91.6 x 361.0, y 1.7..103.8); the city `Bank` twin ends at x 1284.0, z 2423.0. Its 5,449 parts hit 33 `Map.City.Buildings` parts (e.g. `UpperCity.Building_104`), 1 road part, 9 `nature` parts and 3 `Props.Palm_1` parts. The Bank art itself adds no hit beyond what the city twin already has (`locations.md`). | accept and clear the overlapped city parts (quarantine them); place the vault elsewhere in the city; ask the developer. The Bank waits regardless (brief). |
| G2 | Yaw ties | The footprint rule ties for SlowFoods and NewsStation (90 and 270 give the same extents), for Gas2Go (0 and 180) and, to 0.1 stud, for the Bank (0 and 90: 358.9 each). The proposal breaks every tie by registering the Robbery art onto the city twin (4 yaws x top 400 parts by volume): SlowFoods 90 (252 votes; 270 best 10), NewsStation 90 (246; 270 best 37), Gas2Go 180 (437; 0 best 42), Bank 0 (398; 90 best 8). | accept the registration yaws, or choose by hand |
| G3 | Translation reference | The brief centres the whole set's footprint; for SlowFoods, Gas2Go, NewsStation that equals the building's centre within 0.4 stud. For the Bank the set centre and the building centre differ by 57.9 X, 86.0 Z (set centre translation (986.65, 2369.0); art registration (1044.5, 2455.0)). Vertical: the rule puts the Robbery entrance floor on the city ground: SlowFoods -1.062, Gas2Go -0.039, NewsStation 0.000 equal the registration; Bank rule +2.000 (floor 0.0 on the Robbery baseplate to city `FootPaths.Union` 2.000) against registration +1.750. | accept registration values; for the Bank also pick set-centre or building-centre |
| G4 | `PlayerData` save layer left behind | `Heist.Tests.CurrencySpec` (11 cases) requires `PlayerData.CurrencyAdapter` and `PlayerData.MemoryBackend`; `DataStoreBackend` also reads `Config.DataStoreName` (`HeistCurrency_v1`). | keep `CurrencyAdapter` + `MemoryBackend` (tests only, no live store) and leave `DataStoreBackend` + `CurrencyService` save loop behind; or drop `CurrencySpec` from `RunAll` |
| G5 | One cash display | `CashClaimVFX` builds its own always-on `CashDisplay` ScreenGui (`CashFrame` ImageLabel with `UITheme.Assets.CashHUD`, `CashLabel` at 28 pt) and flies coins to `_targetPosition()` computed from its own constants. The city has no always-on cash element: cash shows in panels opened on demand (`PlayerCard.StatsContainer.CashRow.Value`, `WeaponaryShop.TitleBar.CashChip`, `CashShop` balance pill) and the default leaderboard. | leave `CashDisplay` out and point the coins at a city element (which one?), or keep `CashDisplay` as the only always-on cash card |
| G6 | One notification stack | Robbery `NotificationClient`: 5 s cards, rich text, `AlarmBox` variant, anchored bottom-right at inset 16 / 90 (above `DropSuppliesButton`), `UITransitions.SlideIn`. City `NotificationController.show(message, title?, detail?)`: 280x64 cards, MAX_VISIBLE 3, queued while a panel is open, container bottom-right margin 20 / 24. Same corner. | rename the Robbery GUI (default proposal), or route location cards through `NotificationController` (needs a place for the alarm box) |
| G7 | `MenuFovBlur.acquire` | Used only by Robbery `UiButtonEffects`; the city copy has `open` / `close` only. | add `acquire` (11 lines, additive) to the city module, or have `UiButtonEffects` use `open` / `close` |
| G8 | `UiButtonEffects` | The brief lists it as a city copy; no `UiButtonEffects` exists in the city (searched by name over every service outside `Map`, `HQ`, `TycoonPreview`). The Robbery script is Heist-specific. | carry it (proposal) |
| G9 | Trigger weapon tag | `LocationServer:_hasEquippedWeapon` and `_watchCharacter` require a Tool tagged `Weapon`. City `ServerStorage.Weapons` has 38 Tools: 17 tagged `Blaster`, 21 untagged, 0 tagged `Weapon`. The only `Weapon` tool in Robbery is the left-behind placeholder pistol. As imported, no robbery can start in the city. | tag the city tools `Weapon` (data), or accept `Blaster` in `HeistConfig.Tags.Weapon` / `LocationServer` (code) |
| G10 | Backpack core GUI | `HeistClient` lines 815 and 827 call `SetCoreGuiEnabled(Backpack, ...)`, re-enabling it after carrying supplies or on `CharacterRemoving`; the city's `Custom Inventory.InventoryController` line 13 disables it for good. After a carry the default backpack would reappear in the city. | change the two `true` calls (deviation), or leave and accept |
| G11 | `Illegal Supplier` placement | Not part of any location set. Robbery position about (109.9, 4.9, -339.0), inside the Robbery SlowFoods footprint (x -46.3..186.7, z -379.8..-202.5). Scripts find it by `workspace["Illegal Supplier"]`, so it stays a Workspace root. With the SlowFoods transform it lands at about (30.8, 3.8, 1713.9), inside the city SlowFoods footprint (x -10.0..167.3, z 1637.7..1870.0). Its 69 `Vector3Value`s are rig data. | move it with the SlowFoods set (proposal) or place by hand |
| G12 | Absolute coordinates | Three `LockedDoor` `openCFrame` literals (server scripts) are world coordinates; the other literals found are test fixtures or relative offsets. `Gate` `OpenOffset` is applied in the part's own space (`closed * CFrame.new(offset)`), so it moves with the transform. | per row, transform in the script (values in `locations.md`) or replace with a lookup of the door's closed CFrame plus the same local offset |

## Gate rulings (controller, 2026-11-16)

All are Claude's calls, made at the Task 1 gate; the developer reviews them in the batch note. Each row overrides the proposal above where they differ.

| # | Ruling | Why | Cost if wrong |
|---|---|---|---|
| G1 | **The Bank vault goes underground**, straight below where the Bank transform puts it. The Bank set splits: `Bank`, and every `HeistZones` / `HeistMarkers` child whose centre lies outside the `BankVault` box (Robbery coordinates, padded 2 studs), take the Bank transform; `BankVault` and every `HeistZones` / `HeistMarkers` child whose centre lies inside that box take the Bank transform plus a drop `dy`, chosen so the vault set's top is 40 studs below the lowest city BasePart or Terrain voxel in the vault set's XZ box (searched down to y -600). After the drop, `GetPartBoundsInBox` over the vault set finds no city part and `ReadVoxels` finds no terrain. | The code already calls it "the underground stretch", players reach it only by `TeleporterBankA` and leave by the exit spawn, and nothing in the scan holds its world position, so it need not sit beside the Bank. Above ground it lands on 33 city building parts. | The vault's look underground differs from the Robbery place; one `PivotTo` moves it if the developer wants it elsewhere. |
| G2 | Accept the registration yaws: SlowFoods 90, Gas2Go 180, NewsStation 90, Bank 0. | Registration matched thousands of parts to the city twins; the footprint rule only tied. | none: the twins are the same buildings. |
| G3 | Accept the registration translations for all four, Bank included (building centre, `ty` +1.750). | The Robbery art lands on its city twin; the vault no longer constrains the Bank's position (G1). | under 0.25 stud of floor height at the Bank entrance. |
| G4 | `CurrencySpec` is retired: moved to `ServerStorage.CityQuarantine.RetiredSpecs`, not deleted. `CurrencyAdapter`, `MemoryBackend`, `DataStoreBackend` are left behind. The bridge has its own test (`CurrencyBridge_Test`). | It tests the save layer that stays behind; keeping test-only modules for it would carry dead code. | 11 cases leave the heist suite; the baseline failure set is compared without them. |
| G5 | **One cash display: the city's.** The city has an always-on readout, `PlayerGui["Custom Inventory"].cashDisplay`, driven by `StarterPlayerScripts.CashHud` (the survey missed it). `CashClaimVFX` stops building its own `CashDisplay` and flies its coins to the centre of that frame (its `AbsolutePosition + AbsoluteSize / 2`, waited for with a 10 s timeout; no fly-to if absent). Edit in Task 2, checked by eye-free numbers in Task 4. | Two cash cards would show two figures for one balance. | coin flight ends at a different screen spot; visual only. |
| G6 | Rename the Robbery GUI to `HeistNotificationGui` and every Robbery reference to it. Both stacks share the bottom-right corner: Task 4's HUD step moves the Robbery stack clear of the city's. One stack for both is an Open Item. | Routing location cards through `NotificationController` loses the alarm-box variant and is new work. | two notification styles on screen until unified. |
| G7 | Add `acquire` to the city's `MenuFovBlur` (the 11 additive lines from the Robbery copy), as a deviation. | Additive; the city's `open` / `close` are unchanged. | none. |
| G8 | Carry `UiButtonEffects`. | No city copy exists; it is Heist-specific. | none. |
| G9 | **Tag every Tool in the city's `ServerStorage.Weapons` with `Weapon`** (data, no Robbery code edit), plus a city test asserting every Tool there carries the tag, so a new weapon cannot silently stop robberies from starting. Melee counts as a weapon. | One data change satisfies every Robbery check of the tag, client and server; Tools keep tags when cloned. | a robbery could start with a melee weapon, which the Robbery place never had. |
| G10 | `HeistClient` never enables the Backpack core GUI (deviation): line 815 `SetCoreGuiEnabled(Backpack, not carrying)` and line 827 `SetCoreGuiEnabled(Backpack, true)` are both changed so the Backpack stays disabled (drop the calls or pass `false`); any other `SetCoreGuiEnabled(...Backpack...)` call in Robbery client code gets the same treatment. | The city uses `Custom Inventory` and disables the default backpack for good. | none in the city. |
| G11 | `Illegal Supplier` moves with the SlowFoods transform. | It stands inside the SlowFoods footprint in the source and lands inside it in the city. | none. |
| G12 | Transform the three `LockedDoor` `openCFrame` literals in their scripts to the values in `locations.md` section 5 (deviations). | Three lines; nothing else holds a world coordinate. | they break if a location moves again; a later move must redo them. |
