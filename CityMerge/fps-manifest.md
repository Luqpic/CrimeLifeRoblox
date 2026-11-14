# FPS System manifest

Measured 2026-11-15 from `FPS System.rbxl` (Edit, read-only). Machine-readable script list: `fps-manifest.tsv` (root, relative path, class, enabled, adler32). Adler-32 is over the script `Source` bytes. Per-script line count is in the table below only.

**Totals:** 88 roots, 7988 instances (roots plus descendants), 199 LuaSourceContainers (a root that is itself a script counts as 1), 3559520 serialized Base64 bytes. All roots exported to the store as `fps__<index>__<name>.b64` (store data directory is outside the repo and deleted at the end of Phase 2a).

FPS `Workspace` descendants (whole place) = 2220 (read at the start and again after Play).

## Roots

Descendants exclude the root. Roots in the plan's File Structure table that do not exist: none. Present but not in the table (left behind, as the plan states): `ReplicatedStorage.__ProbeOutside`; `ServerStorage.ArchivedWeaponPickups`, `Gun Pack`, `__MeshProbe`, `Body`; `Workspace."UI Animation Pack - by JakeDev"` (166 descendants), `Baseplate`, `Terrain`, `Camera`. Nothing else is outside the plan.

| # | Root | Class | Descendants | Scripts | Serialized bytes (Base64) | Store key |
|---|---|---|---|---|---|---|
| 1 | ReplicatedStorage/Blaster | Folder | 1554 | 21 | 1164708 | fps__1__Blaster.b64 |
| 2 | ReplicatedStorage/Cosmetics | Folder | 4 | 2 | 11388 | fps__2__Cosmetics.b64 |
| 3 | ReplicatedStorage/DialogModule | ModuleScript | 3 | 1 | 13892 | fps__3__DialogModule.b64 |
| 4 | ReplicatedStorage/Enemy | Folder | 3 | 3 | 13820 | fps__4__Enemy.b64 |
| 5 | ReplicatedStorage/GuiTemplates | Folder | 335 | 4 | 57520 | fps__5__GuiTemplates.b64 |
| 6 | ReplicatedStorage/Leveling | Folder | 3 | 1 | 4500 | fps__6__Leveling.b64 |
| 7 | ReplicatedStorage/Modules | Folder | 19 | 16 | 39956 | fps__7__Modules.b64 |
| 8 | ReplicatedStorage/Monetization | Folder | 4 | 1 | 5160 | fps__8__Monetization.b64 |
| 9 | ReplicatedStorage/Movement | Folder | 4 | 3 | 9132 | fps__9__Movement.b64 |
| 10 | ReplicatedStorage/Persistence | Folder | 1 | 1 | 4260 | fps__10__Persistence.b64 |
| 11 | ReplicatedStorage/Quests | Folder | 4 | 1 | 5232 | fps__11__Quests.b64 |
| 12 | ReplicatedStorage/Spraypaint | Folder | 3 | 1 | 4368 | fps__12__Spraypaint.b64 |
| 13 | ReplicatedStorage/Stats | Folder | 1 | 1 | 2856 | fps__13__Stats.b64 |
| 14 | ReplicatedStorage/UI | Folder | 7 | 6 | 29312 | fps__14__UI.b64 |
| 15 | ReplicatedStorage/UpdateRunningState | RemoteEvent | 0 | 0 | 732 | fps__15__UpdateRunningState.b64 |
| 16 | ReplicatedStorage/Utility | Folder | 6 | 5 | 5212 | fps__16__Utility.b64 |
| 17 | ReplicatedStorage/VFX | Folder | 25 | 0 | 19064 | fps__17__VFX.b64 |
| 18 | ReplicatedStorage/Weapons | Folder | 6 | 1 | 4524 | fps__18__Weapons.b64 |
| 19 | ServerScriptService/Blaster | Folder | 12 | 8 | 35956 | fps__19__Blaster.b64 |
| 20 | ServerScriptService/Cosmetics | Folder | 2 | 1 | 7164 | fps__20__Cosmetics.b64 |
| 21 | ServerScriptService/DisableDefaultShiftLock | Script | 0 | 1 | 1212 | fps__21__DisableDefaultShiftLock.b64 |
| 22 | ServerScriptService/Enemy | Folder | 3 | 2 | 39968 | fps__22__Enemy.b64 |
| 23 | ServerScriptService/Monetization | Folder | 2 | 1 | 6012 | fps__23__Monetization.b64 |
| 24 | ServerScriptService/Movement | Folder | 4 | 3 | 12464 | fps__24__Movement.b64 |
| 25 | ServerScriptService/Persistence | Folder | 3 | 2 | 15256 | fps__25__Persistence.b64 |
| 26 | ServerScriptService/Quests | Folder | 4 | 1 | 6336 | fps__26__Quests.b64 |
| 27 | ServerScriptService/Ragdoll | Folder | 2 | 1 | 2932 | fps__27__Ragdoll.b64 |
| 28 | ServerScriptService/Spraypaint | Folder | 3 | 2 | 13176 | fps__28__Spraypaint.b64 |
| 29 | ServerScriptService/Stats | Folder | 2 | 1 | 4984 | fps__29__Stats.b64 |
| 30 | ServerScriptService/Targets | Script | 0 | 1 | 1812 | fps__30__Targets.b64 |
| 31 | ServerScriptService/UnitTestRunner | Script | 0 | 1 | 1256 | fps__31__UnitTestRunner.b64 |
| 32 | ServerScriptService/Utility | Folder | 6 | 5 | 3416 | fps__32__Utility.b64 |
| 33 | ServerScriptService/WeaponAnimationPreview | Script | 0 | 1 | 3456 | fps__33__WeaponAnimationPreview.b64 |
| 34 | ServerScriptService/Weapons | Folder | 6 | 5 | 33080 | fps__34__Weapons.b64 |
| 35 | ServerStorage/Cash | Model | 4 | 0 | 6776 | fps__35__Cash.b64 |
| 36 | ServerStorage/EnemyTemplates | Folder | 2439 | 0 | 313220 | fps__36__EnemyTemplates.b64 |
| 37 | ServerStorage/MeleeStabilityTests | ModuleScript | 0 | 1 | 1776 | fps__37__MeleeStabilityTests.b64 |
| 38 | ServerStorage/ProfileStore | ModuleScript | 0 | 1 | 34908 | fps__38__ProfileStore.b64 |
| 39 | ServerStorage/RBX_ANIMSAVES | Model | 7 | 0 | 2880 | fps__39__RBX_ANIMSAVES.b64 |
| 40 | ServerStorage/UnitTest | Folder | 14 | 13 | 48632 | fps__40__UnitTest.b64 |
| 41 | ServerStorage/WeaponClassMotionTests | ModuleScript | 0 | 1 | 3040 | fps__41__WeaponClassMotionTests.b64 |
| 42 | ServerStorage/WeaponViewmodelMotionTests | ModuleScript | 0 | 1 | 4028 | fps__42__WeaponViewmodelMotionTests.b64 |
| 43 | ServerStorage/Weapons | Folder | 1270 | 38 | 1060028 | fps__43__Weapons.b64 |
| 44 | StarterGui/Bobbing Camera | LocalScript | 0 | 1 | 4796 | fps__44__Bobbing_Camera.b64 |
| 45 | StarterGui/Custom Inventory | ScreenGui | 55 | 2 | 55324 | fps__45__Custom_Inventory.b64 |
| 46 | StarterGui/QuestResponsesGui | BillboardGui | 12 | 0 | 17036 | fps__46__QuestResponsesGui.b64 |
| 47 | StarterPlayerScripts/AdminLevelController | LocalScript | 0 | 1 | 6172 | fps__47__AdminLevelController.b64 |
| 48 | StarterPlayerScripts/CashHud | LocalScript | 0 | 1 | 3464 | fps__48__CashHud.b64 |
| 49 | StarterPlayerScripts/CashShopController | LocalScript | 0 | 1 | 4928 | fps__49__CashShopController.b64 |
| 50 | StarterPlayerScripts/DamageDirectionIndicator | LocalScript | 0 | 1 | 3904 | fps__50__DamageDirectionIndicator.b64 |
| 51 | StarterPlayerScripts/DeathScreen | LocalScript | 0 | 1 | 7352 | fps__51__DeathScreen.b64 |
| 52 | StarterPlayerScripts/Footsteps | LocalScript | 0 | 1 | 6560 | fps__52__Footsteps.b64 |
| 53 | StarterPlayerScripts/GamepassShopController | LocalScript | 0 | 1 | 4692 | fps__53__GamepassShopController.b64 |
| 54 | StarterPlayerScripts/HudButtonEffects | LocalScript | 0 | 1 | 3652 | fps__54__HudButtonEffects.b64 |
| 55 | StarterPlayerScripts/HudClusterScale | LocalScript | 0 | 1 | 3220 | fps__55__HudClusterScale.b64 |
| 56 | StarterPlayerScripts/IndicatorClient | LocalScript | 0 | 1 | 4380 | fps__56__IndicatorClient.b64 |
| 57 | StarterPlayerScripts/LevelUpVFX | LocalScript | 0 | 1 | 4116 | fps__57__LevelUpVFX.b64 |
| 58 | StarterPlayerScripts/LevelingHud | LocalScript | 0 | 1 | 6960 | fps__58__LevelingHud.b64 |
| 59 | StarterPlayerScripts/PlayerCardController | LocalScript | 0 | 1 | 8976 | fps__59__PlayerCardController.b64 |
| 60 | StarterPlayerScripts/PlayerNameplates | LocalScript | 0 | 1 | 8348 | fps__60__PlayerNameplates.b64 |
| 61 | StarterPlayerScripts/PromptUiController | LocalScript | 0 | 1 | 4868 | fps__61__PromptUiController.b64 |
| 62 | StarterPlayerScripts/QuestDialogueController | LocalScript | 0 | 1 | 8124 | fps__62__QuestDialogueController.b64 |
| 63 | StarterPlayerScripts/QuestFeedbackController | LocalScript | 0 | 1 | 3796 | fps__63__QuestFeedbackController.b64 |
| 64 | StarterPlayerScripts/QuestLogController | LocalScript | 0 | 1 | 5812 | fps__64__QuestLogController.b64 |
| 65 | StarterPlayerScripts/RbxCharacterSounds | LocalScript | 1 | 2 | 13680 | fps__65__RbxCharacterSounds.b64 |
| 66 | StarterPlayerScripts/SkinsCardController | ModuleScript | 0 | 1 | 22204 | fps__66__SkinsCardController.b64 |
| 67 | StarterPlayerScripts/SpraypaintHud | LocalScript | 0 | 1 | 4720 | fps__67__SpraypaintHud.b64 |
| 68 | StarterPlayerScripts/StaminaHud | LocalScript | 0 | 1 | 6976 | fps__68__StaminaHud.b64 |
| 69 | StarterPlayerScripts/UIScaleController | LocalScript | 0 | 1 | 5352 | fps__69__UIScaleController.b64 |
| 70 | StarterPlayerScripts/UiTransitionBinder | LocalScript | 0 | 1 | 3724 | fps__70__UiTransitionBinder.b64 |
| 71 | StarterPlayerScripts/WeaponaryShopController | LocalScript | 0 | 1 | 36684 | fps__71__WeaponaryShopController.b64 |
| 72 | StarterCharacterScripts/Animate2 | LocalScript | 17 | 1 | 18532 | fps__72__Animate2.b64 |
| 73 | StarterCharacterScripts/Crouching | LocalScript | 4 | 1 | 9880 | fps__73__Crouching.b64 |
| 74 | StarterCharacterScripts/CustomShiftLock | LocalScript | 3 | 4 | 13028 | fps__74__CustomShiftLock.b64 |
| 75 | StarterCharacterScripts/LandAnim | LocalScript | 0 | 1 | 3304 | fps__75__LandAnim.b64 |
| 76 | StarterCharacterScripts/Lean | LocalScript | 0 | 1 | 5204 | fps__76__Lean.b64 |
| 77 | StarterCharacterScripts/Turning | LocalScript | 0 | 1 | 5956 | fps__77__Turning.b64 |
| 78 | SoundService/Main | SoundGroup | 4 | 0 | 896 | fps__78__Main.b64 |
| 79 | Workspace/Accessory Storage | Folder | 0 | 0 | 860 | fps__79__Accessory_Storage.b64 |
| 80 | Workspace/AnimVM | Folder | 0 | 0 | 848 | fps__80__AnimVM.b64 |
| 81 | Workspace/EnemySpawns | Folder | 12 | 0 | 5488 | fps__81__EnemySpawns.b64 |
| 82 | Workspace/Map | Folder | 23 | 0 | 6940 | fps__82__Map.b64 |
| 83 | Workspace/Model | Folder | 0 | 0 | 844 | fps__83__Model.b64 |
| 84 | Workspace/Part | Part | 1 | 0 | 6332 | fps__84__Part.b64 |
| 85 | Workspace/Quests | Folder | 1892 | 1 | 105072 | fps__85__Quests.b64 |
| 86 | Workspace/SpawnLocation | SpawnLocation | 1 | 0 | 5476 | fps__86__SpawnLocation.b64 |
| 87 | Workspace/Targets | Folder | 105 | 0 | 28744 | fps__87__Targets.b64 |
| 88 | Workspace/UI | Part | 5 | 1 | 12892 | fps__88__UI.b64 |

## Scripts

Columns: relative path from its root | class | enabled | adler32 | lines. `(root)` = the root itself is the script. `n/a` = ModuleScript (no Enabled).


### ReplicatedStorage/Blaster

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 3796454014 | 104 |
| Scripts.CameraRecoiler | ModuleScript | n/a | 1682390330 | 29 |
| Scripts.InputCategorizer | ModuleScript | n/a | 937981725 | 97 |
| Scripts.ViewModelController | ModuleScript | n/a | 85491774 | 490 |
| Scripts.GuiController | ModuleScript | n/a | 2060541739 | 190 |
| Scripts.TouchInputController | ModuleScript | n/a | 2740281819 | 162 |
| Scripts.BlasterController | ModuleScript | n/a | 3161426517 | 586 |
| Scripts.CharacterAnimationController | ModuleScript | n/a | 3718965207 | 130 |
| Scripts.ShotReplication | Script | true | 3920695262 | 41 |
| Scripts.WeaponViewmodelMotion | ModuleScript | n/a | 3125689737 | 471 |
| Utility.drawRayResults | ModuleScript | n/a | 376659951 | 69 |
| Utility.castRays | ModuleScript | n/a | 1818418528 | 117 |
| Utility.playSoundFromSource | ModuleScript | n/a | 4128595951 | 14 |
| Utility.canDamageHumanoid | ModuleScript | n/a | 453962573 | 57 |
| Utility.playRandomSoundFromSource | ModuleScript | n/a | 1302233560 | 12 |
| Utility.getRayDirections | ModuleScript | n/a | 775215038 | 20 |
| Utility.bindSoundsToAnimationEvents | ModuleScript | n/a | 3768994124 | 27 |
| Utility.findOwningHumanoid | ModuleScript | n/a | 252421142 | 27 |
| Effects.impactEffect | ModuleScript | n/a | 2576291574 | 119 |
| Effects.laserBeamEffect | ModuleScript | n/a | 1849388566 | 28 |
| Effects.projectileEffect | ModuleScript | n/a | 2818603513 | 72 |

### ReplicatedStorage/Cosmetics

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Palettes | ModuleScript | n/a | 1528685247 | 175 |
| SkinApplier | ModuleScript | n/a | 3586719972 | 126 |

### ReplicatedStorage/DialogModule

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 1459106551 | 425 |

### ReplicatedStorage/Enemy

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 631277248 | 122 |
| AimConfig | ModuleScript | n/a | 32114794 | 99 |
| templateConfig | ModuleScript | n/a | 2360478200 | 87 |

### ReplicatedStorage/GuiTemplates

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| WeaponCard.StrokeHover | LocalScript | true | 2760580176 | 41 |
| EnemyGUI.GUI.HealthGUI.HealthManager | Script | true | 1894356930 | 17 |
| WeaponaryShop.ShopArea.DetailPanel.ActionButton.HoverAndClick | LocalScript | true | 4181364982 | 56 |
| WeaponaryShop.ShopArea.DetailPanel.EquipButton.StrokeHover | LocalScript | true | 3283683011 | 40 |

### ReplicatedStorage/Leveling

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 3371009100 | 68 |

### ReplicatedStorage/Modules

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| FootstepModule | ModuleScript | n/a | 2541688950 | 206 |
| FootstepModule.Footsteps.Default | ModuleScript | n/a | 3860780748 | 284 |
| FootstepModule.Footsteps.Fart | ModuleScript | n/a | 2234932877 | 96 |
| FootstepModule.Footsteps.Water | ModuleScript | n/a | 677552881 | 132 |
| FootstepModule.Landing.Default | ModuleScript | n/a | 1118649897 | 157 |
| FootstepModule.Landing.Fart | ModuleScript | n/a | 1797873519 | 96 |
| FootstepModule.Landing.Water | ModuleScript | n/a | 997884225 | 126 |
| FootstepModule.Jumping.Default | ModuleScript | n/a | 1209910925 | 141 |
| FootstepModule.Jumping.Fart | ModuleScript | n/a | 796876597 | 96 |
| FootstepModule.Jumping.Water | ModuleScript | n/a | 172457815 | 126 |
| PropertyAuthority | ModuleScript | n/a | 4223693298 | 70 |
| CameraAuthority | ModuleScript | n/a | 2682741682 | 150 |
| AnimationPriorities | ModuleScript | n/a | 1100373860 | 16 |
| RagdollController | ModuleScript | n/a | 3888814082 | 365 |
| MenuFovBlur | ModuleScript | n/a | 3514199789 | 49 |
| NotificationController | ModuleScript | n/a | 178485235 | 339 |

### ReplicatedStorage/Monetization

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 1587927762 | 76 |

### ReplicatedStorage/Movement

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 169647085 | 86 |
| Scripts.staminaStep | ModuleScript | n/a | 965759598 | 65 |
| Scripts.locomotionAnimations | ModuleScript | n/a | 2033328957 | 54 |

### ReplicatedStorage/Persistence

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Schema | ModuleScript | n/a | 926383738 | 48 |

### ReplicatedStorage/Quests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| QuestConfig | ModuleScript | n/a | 3617513536 | 134 |

### ReplicatedStorage/Spraypaint

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 2067918910 | 47 |

### ReplicatedStorage/Stats

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Constants | ModuleScript | n/a | 2930036738 | 31 |

### ReplicatedStorage/UI

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Sounds | ModuleScript | n/a | 1680856057 | 60 |
| Panels | ModuleScript | n/a | 1087123019 | 116 |
| Transitions | ModuleScript | n/a | 702576194 | 222 |
| Effects | ModuleScript | n/a | 3123690377 | 212 |
| CashBurst | ModuleScript | n/a | 2916064367 | 129 |
| PromptUI | ModuleScript | n/a | 3200479966 | 259 |

### ReplicatedStorage/Utility

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| bindToInstanceDestroyed | ModuleScript | n/a | 802048191 | 21 |
| bindToInstanceDestroyed.DestructionHandler | Script | true | 3092404442 | 28 |
| disconnectAndClear | ModuleScript | n/a | 2936424065 | 9 |
| safePlayerAdded | ModuleScript | n/a | 34100879 | 12 |
| lerp | ModuleScript | n/a | 4081262817 | 6 |

### ReplicatedStorage/Weapons

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| UpgradeConfig | ModuleScript | n/a | 1373273524 | 58 |

### ServerScriptService/Blaster

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.AccessoryFiltering | Script | true | 3467101391 | 47 |
| Scripts.Blaster | Script | true | 1213314758 | 88 |
| Scripts.Blaster.validateShootArguments | ModuleScript | n/a | 2424007007 | 35 |
| Scripts.Blaster.validateReload | ModuleScript | n/a | 2079170285 | 23 |
| Scripts.Blaster.validateShot | ModuleScript | n/a | 2386274073 | 69 |
| Scripts.ShotResolver | ModuleScript | n/a | 1560462989 | 761 |
| Scripts.ShotResolver.validateTag | ModuleScript | n/a | 2497835930 | 68 |
| Scripts.DamageDirectionService | Script | true | 3393479802 | 41 |

### ServerScriptService/Cosmetics

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.CosmeticsService | ModuleScript | n/a | 2805852613 | 144 |

### ServerScriptService/DisableDefaultShiftLock

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | Script | true | 2634298290 | 8 |

### ServerScriptService/Enemy

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.EnemyAI | ModuleScript | n/a | 760454415 | 1074 |
| Scripts.EnemySpawner | Script | true | 4047349777 | 415 |

### ServerScriptService/Monetization

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.MonetizationService | Script | true | 3620959142 | 157 |

### ServerScriptService/Movement

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.RunningState | Script | true | 1164604505 | 29 |
| Scripts.RunningState.validateRunningState | ModuleScript | n/a | 2109323675 | 54 |
| Scripts.SprintAuthority | ModuleScript | n/a | 294162375 | 257 |

### ServerScriptService/Persistence

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.ProfileGateway | ModuleScript | n/a | 4214991426 | 374 |
| Scripts.PersistenceRunner | Script | true | 1328824806 | 3 |

### ServerScriptService/Quests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.QuestService | Script | true | 3020256532 | 167 |

### ServerScriptService/Ragdoll

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.PlayerRagdoll | Script | true | 3482046863 | 27 |

### ServerScriptService/Spraypaint

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.SpraypaintService | ModuleScript | n/a | 741528517 | 276 |
| Scripts.SpraypaintRunner | Script | true | 266355866 | 3 |

### ServerScriptService/Stats

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.KillStatsService | Script | true | 2664214293 | 104 |

### ServerScriptService/Targets

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | Script | true | 3229754595 | 35 |

### ServerScriptService/UnitTestRunner

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | Script | false | 3723772083 | 4 |

### ServerScriptService/Utility

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| TypeValidation.validateVector3 | ModuleScript | n/a | 143091887 | 16 |
| TypeValidation.validateInstance | ModuleScript | n/a | 208858350 | 27 |
| TypeValidation.validateCFrame | ModuleScript | n/a | 1202357766 | 21 |
| TypeValidation.validateSimpleTable | ModuleScript | n/a | 560171891 | 22 |
| TypeValidation.validateNumber | ModuleScript | n/a | 3855834372 | 16 |

### ServerScriptService/WeaponAnimationPreview

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | Script | true | 2351876902 | 70 |

### ServerScriptService/Weapons

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Scripts.EquipService | Script | true | 880165296 | 56 |
| Scripts.WeaponUpgradeService | Script | true | 2997349738 | 127 |
| Scripts.CashService | Script | true | 4129585844 | 268 |
| Scripts.LevelingService | Script | true | 2525621758 | 271 |
| Scripts.WeaponShopService | Script | true | 654312028 | 448 |

### ServerStorage/MeleeStabilityTests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 3719767651 | 25 |

### ServerStorage/ProfileStore

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 1233298642 | 2243 |

### ServerStorage/UnitTest

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| RunUnitTest | ModuleScript | n/a | 2205425575 | 107 |
| Cases.PropertyAuthority_Test | ModuleScript | n/a | 3681015234 | 81 |
| Cases.validateRunningState_Test | ModuleScript | n/a | 2471232670 | 103 |
| Cases.staminaStep_Test | ModuleScript | n/a | 3406101245 | 122 |
| Cases.Palettes_Test | ModuleScript | n/a | 1611046558 | 101 |
| Cases.SkinApplier_Test | ModuleScript | n/a | 2931050551 | 170 |
| Cases.CosmeticsOwnership_Test | ModuleScript | n/a | 3272276246 | 118 |
| Cases.SpraypaintConstants_Test | ModuleScript | n/a | 4279571236 | 52 |
| Cases.SpraypaintService_Test | ModuleScript | n/a | 739715998 | 195 |
| Cases.SpraypaintTier_Test | ModuleScript | n/a | 4240229808 | 93 |
| Cases.Schema_Test | ModuleScript | n/a | 1558435936 | 80 |
| Cases.ProfileGateway_Test | ModuleScript | n/a | 4138745152 | 310 |
| Cases.ProfileAdoption_Test | ModuleScript | n/a | 2120294281 | 425 |

### ServerStorage/WeaponClassMotionTests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 3233707512 | 49 |

### ServerStorage/WeaponViewmodelMotionTests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 2146111159 | 92 |

### ServerStorage/Weapons

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| AK47.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| AKM.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| AMB-17.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| AUG A-3.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Crowbar.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Deagle.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| FN P-90.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| HCAR.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Kriss Vector.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| M16A1.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| M1911.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| MP9.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Mateba 2006M.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Mossberg 590.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Scar L.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Sig MPX.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Glock 17.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| MP443.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| PB.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| S&W 29.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Benelli M4.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Itacha Mag-10.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Spas 12.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| M14 EBR.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| AR-18.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| HK G3.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| APS.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Knife.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Baton.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| MP-153.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Glock 18.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| SIG M17.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| M45A1.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| USP Compact.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Remington 870.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| Sawed-Off 870.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| SPAS-13.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |
| RPG.Scripts.Blaster | LocalScript | true | 3877431381 | 16 |

### StarterGui/Bobbing Camera

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2970486269 | 97 |

### StarterGui/Custom Inventory

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| InventoryController | LocalScript | true | 208029789 | 202 |
| InventoryController.SETTINGS | ModuleScript | n/a | 4204269327 | 735 |

### StarterPlayerScripts/AdminLevelController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 11968854 | 196 |

### StarterPlayerScripts/CashHud

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3348007358 | 64 |

### StarterPlayerScripts/CashShopController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3067322196 | 137 |

### StarterPlayerScripts/DamageDirectionIndicator

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1750238707 | 83 |

### StarterPlayerScripts/DeathScreen

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 4022051210 | 196 |

### StarterPlayerScripts/Footsteps

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 4127807604 | 296 |

### StarterPlayerScripts/GamepassShopController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2847555 | 148 |

### StarterPlayerScripts/HudButtonEffects

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 4005637699 | 101 |

### StarterPlayerScripts/HudClusterScale

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 309402251 | 63 |

### StarterPlayerScripts/IndicatorClient

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2358959230 | 131 |

### StarterPlayerScripts/LevelUpVFX

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2415722068 | 94 |

### StarterPlayerScripts/LevelingHud

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3990833154 | 239 |

### StarterPlayerScripts/PlayerCardController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 4293396621 | 276 |

### StarterPlayerScripts/PlayerNameplates

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2121005472 | 250 |

### StarterPlayerScripts/PromptUiController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1225139167 | 161 |

### StarterPlayerScripts/QuestDialogueController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3223924563 | 207 |

### StarterPlayerScripts/QuestFeedbackController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1810268451 | 74 |

### StarterPlayerScripts/QuestLogController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 918625301 | 166 |

### StarterPlayerScripts/RbxCharacterSounds

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3057710799 | 453 |
| AtomicBinding | ModuleScript | n/a | 684057989 | 277 |

### StarterPlayerScripts/SkinsCardController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | ModuleScript | n/a | 681185616 | 737 |

### StarterPlayerScripts/SpraypaintHud

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1480707121 | 95 |

### StarterPlayerScripts/StaminaHud

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3234134790 | 217 |

### StarterPlayerScripts/UIScaleController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 4264990107 | 126 |

### StarterPlayerScripts/UiTransitionBinder

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1707266723 | 69 |

### StarterPlayerScripts/WeaponaryShopController

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1830119947 | 1248 |

### StarterCharacterScripts/Animate2

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3211711448 | 695 |

### StarterCharacterScripts/Crouching

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 3591834587 | 324 |

### StarterCharacterScripts/CustomShiftLock

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 1687758541 | 7 |
| SmoothShiftLock | ModuleScript | n/a | 1662119896 | 178 |
| SmoothShiftLock.Maid | ModuleScript | n/a | 759839748 | 223 |
| SmoothShiftLock.Spring | ModuleScript | n/a | 4293551735 | 246 |

### StarterCharacterScripts/LandAnim

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 10044350 | 54 |

### StarterCharacterScripts/Lean

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2478388517 | 154 |

### StarterCharacterScripts/Turning

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| (root) | LocalScript | true | 2747668829 | 247 |

### Workspace/Quests

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| Level 1 Quest.Animate | LocalScript | true | 461847317 | 972 |

### Workspace/UI

| path | class | enabled | adler32 | lines |
|---|---|---|---|---|
| OverheadGui.InformationLabel.Script | Script | true | 2983742675 | 21 |

## CollectionService tags

Count of tagged instances inside the 88 roots, and place-wide. Tags with zero in the roots and a place-wide count live elsewhere (Lighting, Studio theme data, left-behind containers) and are not imported.

| tag | in roots | place-wide |
|---|---|---|
| 1788975189 | 1 | 1 |
| Assistant:68432017-132f-4000-9bf2-0824d3573826 | 3 | 3 |
| Assistant:fd7caafa-f5ab-4e60-83c3-72e1801e81b8 | 1 | 1 |
| Blaster | 21 | 21 |
| EnemySpawnPoint | 6 | 6 |
| NPCprompt | 6 | 6 |
| Target | 7 | 7 |
| RigEdit | 0 | 6 |
| Theme_Accent | 0 | 17 |
| Theme_GridItem | 0 | 50 |
| Theme_PlaceHolder | 0 | 84 |
| Theme_Primary | 0 | 34 |
| Theme_PrimaryText | 0 | 263 |
| Theme_Secondary | 0 | 36 |
| Theme_SecondaryText | 0 | 69 |
| VFXStudio_ThemeableUI | 0 | 3 |
| WeaponPickup | 0 | 16 |
| data-testid=--studio-foundation--stylesheet-wrapper | 0 | 1 |
| gui-object-defaults | 0 | 1 |
| size-full | 0 | 1 |

`WeaponPickup` (16) is not in any root: the pickups are in the left-behind `ServerStorage.ArchivedWeaponPickups`. The `Theme_*` tags are not in any imported root either (they sit in the left-behind containers or Studio data); where the blaster UI and theme code expect them is for Task 2 step 4 to confirm.

## Settings copied by value (as read)

| setting | value |
|---|---|
| StarterPlayer.CameraMaxZoomDistance | 30 |
| StarterPlayer.CharacterWalkSpeed | 25 |
| StarterPlayer.CharacterUseJumpPower | false |
| StarterPlayer.CharacterJumpHeight | 7.199999809265137 |
| StarterPlayer.EnableMouseLockOption | true |
| StarterPlayer.LoadCharacterAppearance | true |
| Players.RespawnTime | 3 |
| Workspace.FallenPartsDestroyHeight | -500 |
| Workspace.StreamingEnabled (read for reference) | true |
| Registered collision groups | Default only |

## World bounding boxes of the Workspace roots (studs)

| root | BaseParts | min (x, y, z) | max (x, y, z) |
|---|---|---|---|
| EnemySpawns | 6 | (-185.6, 0.0, -204.1) | (267.2, 1.0, 327.9) |
| Quests | 119 | (-22.2, 0.0, 36.2) | (-5.4, 5.8, 58.3) |
| Targets | 91 | (-30.5, -0.0, -5.4) | (26.5, 14.7, 109.0) |
| AnimVM | none | | |
| Accessory Storage | none | | |
| Map | 20 | (-32.0, 0.0, -9.0) | (32.0, 16.0, 111.0) |
| UI | 1 | (-68.2, 0.0, 9.8) | (-64.2, 1.0, 11.8) |
| Part | 1 | (-67.9, 0.0, 2.0) | (-67.2, 0.5, 2.6) |
| Model | none | | |
| SpawnLocation | 1 | (6.0, 0.0, 45.0) | (18.0, 1.0, 57.0) |

FPS `Workspace.Baseplate`: position (0, -8, 0), size (2048, 16, 2048), **top Y = 0.00**.
Note: `EnemySpawns` spans (-185.6..267.2, -204.1..327.9), a much wider area than the other anchors. `ServerScriptService.UnitTestRunner` is the only disabled script (`Enabled = false`).
