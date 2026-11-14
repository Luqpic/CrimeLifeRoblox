# FPS System test baseline

Measured 2026-11-15 in `FPS System.rbxl`: a fresh Play session, temporary `Script` under `ServerScriptService` (discarded when Play stopped), `require(ServerStorage.UnitTest.RunUnitTest)`. This is the reference for later comparison, not a gate.

## Unit tests

One call with filter `""` (all suites): **147 run, 147 passed, 0 failed.**

Each suite by name, filter = the full module name (no suite name is a substring of another, so no collisions):

| suite | run | passed | failed |
|---|---|---|---|
| PropertyAuthority_Test | 8 | 8 | 0 |
| validateRunningState_Test | 8 | 8 | 0 |
| staminaStep_Test | 10 | 10 | 0 |
| Palettes_Test | 11 | 11 | 0 |
| SkinApplier_Test | 14 | 14 | 0 |
| CosmeticsOwnership_Test | 12 | 12 | 0 |
| SpraypaintConstants_Test | 8 | 8 | 0 |
| SpraypaintService_Test | 21 | 21 | 0 |
| SpraypaintTier_Test | 8 | 8 | 0 |
| Schema_Test | 9 | 9 | 0 |
| ProfileGateway_Test | 22 | 22 | 0 |
| ProfileAdoption_Test | 16 | 16 | 0 |
| **total** | **147** | **147** | **0** |

Failing test names: none. The runner returns only counts; it prints `[PASS]`/`[FAIL]` lines (with `warn` on failure) to the console, so failing names would have appeared there.

Expected, harmless warnings in every run (documented in the Unit Test Runner note): `ProfileAdoption_Test` stand-in tables make `LevelingService:113` and `CashService:94` hydrators fail with "attempt to call missing method 'FindFirstChild' of table"; `ProfileGateway_Test` produces `StartSessionAsync failed ... already loaded` (3 attempts) and `migrate failed ... no migration step for stored version -1`; one test produces "a late post-hydrator that throws".

## Console after the run (LogService history, after more than 15 s)

Server datamodel: 512 messages (357 output, 96 warnings, 59 errors). Distinct error lines (after exact text match): **3**, all `Failed to load animation with sanitized ID rbxassetid://<id>: Animation failed to load` for ids 136801098480203 (12x), 70581846281736 (23x), 122749871988730 (24x). Each has a paired warning `ContentId: ... failed due to: Requester does not have permission for Asset.` (the ids are not owned by the account Studio is signed in with).

Client datamodel: 356 messages (1 output, 106 warnings, 249 errors). Distinct error lines: **13**:
- animation load failures, ids 136801098480203 (19x), 122749871988730 (37x), 70581846281736 (36x), 89055632668771 (1x)
- `Failed to load sound rbxassetid://<id>: Requester does not have permission for Asset.` for 9 ids: 130534131095313, 129018550886739, 109353553631662, 71482608669492, 106116361617365, 117454231326703, 94326126511116, 117185816509314, 80026580557237 (17 to 18x each)

All errors are asset-permission failures (animations and sounds). Distinct error lines across server and client by exact text: 13 (the 3 server ones also occur on the client). No script runtime error was logged. The client also logged `ContentId ... Requester does not have permission` warnings for ids 91946150190183 and 94550951381303, which have no matching error line, and the test-noise warnings listed above come from the server.

## Client, same Play session (about 11 s after the character spawned)

`PlayerGui` children (class, `Enabled`):

| name | class | Enabled |
|---|---|---|
| GamepassShopGui | ScreenGui | true |
| DeathScreenGui | ScreenGui | true |
| PromptUiGui | ScreenGui | true |
| SkinsCardGui | ScreenGui | false |
| WeaponaryShopGui | ScreenGui | true |
| StaminaGui | ScreenGui | true |
| QuestLogGui | ScreenGui | true |
| PlayerCardGui | ScreenGui | true |
| DamageDirectionIndicator | ScreenGui | true |
| LevelingGui | ScreenGui | true |
| NotificationGui | ScreenGui | true |
| CashShopGui | ScreenGui | true |
| AdminLevelGui | ScreenGui | false |
| Freecam | ScreenGui | true |
| Bobbing Camera | LocalScript | n/a |
| Custom Inventory | ScreenGui | true |
| QuestResponsesGui | BillboardGui | true |
| BlasterGui | ScreenGui | false |
| ReticleGui | ScreenGui | false |
| BlasterTouchGui | ScreenGui | false |

`Players.LocalPlayer.PlayerScripts` children (28): UiTransitionBinder, PlayerScriptsLoader, CashHud, GamepassShopController, DeathScreen, Footsteps, RbxCharacterSounds, PromptUiController, HudClusterScale, WeaponaryShopController, StaminaHud, PlayerModule, HudButtonEffects, QuestLogController, LevelUpVFX, SkinsCardController, PlayerCardController, IndicatorClient, DamageDirectionIndicator, QuestDialogueController, LevelingHud, QuestFeedbackController, PlayerNameplates, UIScaleController, CashShopController, AdminLevelController, SpraypaintHud, DestructionHandler (a Script).

Character `Humanoid.WalkSpeed` read from the client: **20** (the `StarterPlayer.CharacterWalkSpeed` setting is 25; the live value was changed by a script, so compare against 20, read at the same point, and not against 25).

Client `#workspace:GetDescendants()`: **5091** (server-side Workspace in Edit: 2220; the difference is the character, the viewmodel, enemies, drops and other runtime content).

## After Play

Play stopped; the FPS window is in Edit; its 88 roots total 7,988 instances and `Workspace` has 2,220 descendants, equal to the manifest. The temporary runner script is gone. Nothing was saved.
