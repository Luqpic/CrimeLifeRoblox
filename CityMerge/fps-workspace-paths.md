# FPS Workspace paths referenced by script code

Measured 2026-11-15 over every script in `fps-manifest.md` (199). Search: any line containing `workspace` or `Workspace` as a word, which covers `workspace.X`, `game:GetService("Workspace")` and the local alias `local Workspace = game:GetService("Workspace")` (the only alias name used; no `local ws =` style aliases exist). Every hit is listed, alias-definition lines included. Source dump used: `scratchpad/p2data/m_src.txt` (not committed).

**The FPS `Workspace.Map` is not referenced by any script.** (Also searched: `"Map"`, `.Map`, `Accessory Storage`, `AnimVM`, `EnemySpawns`, `SpawnLocation`: none in script code.)

| script | line | path referenced | kind | text |
|---|---|---|---|---|
| ReplicatedStorage/Blaster/Scripts.CameraRecoiler (ModuleScript) | 3 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Scripts.CameraRecoiler (ModuleScript) | 8 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 8 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 18 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 109 | Workspace | comment/string | `-- Despite the blaster streaming mode being set to Atomic, objects outside of workspace are not streamed.` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 123 | Workspace | comment/string | `-- The viewmodel is parented into Workspace to render, which puts the player's own first-person` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 210 | Workspace | code | `self.model.Parent = Workspace` |
| ReplicatedStorage/Blaster/Scripts.ViewModelController (ModuleScript) | 417 | Workspace | code | `self.model.Parent = Workspace` |
| ReplicatedStorage/Blaster/Scripts.BlasterController (ModuleScript) | 6 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Scripts.BlasterController (ModuleScript) | 23 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| ReplicatedStorage/Blaster/Scripts.BlasterController (ModuleScript) | 137 | Workspace:GetServerTimeNow | code | `local now = Workspace:GetServerTimeNow()` |
| ReplicatedStorage/Blaster/Utility.castRays (ModuleScript) | 3 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Utility.castRays (ModuleScript) | 23 | Workspace:Spherecast | comment/string | `-- calling Workspace:Spherecast directly.` |
| ReplicatedStorage/Blaster/Utility.castRays (ModuleScript) | 27 | Workspace:Spherecast | code | `return Workspace:Spherecast(position, radius, direction, params)` |
| ReplicatedStorage/Blaster/Utility.castRays (ModuleScript) | 34 | Workspace:Spherecast | code | `local result = Workspace:Spherecast(position + unit * travelled, radius, unit * segment, params)` |
| ReplicatedStorage/Blaster/Effects.impactEffect (ModuleScript) | 3 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Effects.impactEffect (ModuleScript) | 39 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| ReplicatedStorage/Blaster/Effects.impactEffect (ModuleScript) | 46 | Workspace | code | `impact.Parent = Workspace` |
| ReplicatedStorage/Blaster/Effects.impactEffect (ModuleScript) | 100 | Workspace | code | `impact.Parent = Workspace` |
| ReplicatedStorage/Blaster/Effects.impactEffect (ModuleScript) | 107 | Workspace | code | `impact.Parent = Workspace` |
| ReplicatedStorage/Blaster/Effects.laserBeamEffect (ModuleScript) | 3 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Effects.laserBeamEffect (ModuleScript) | 18 | Workspace | code | `laser.Parent = Workspace` |
| ReplicatedStorage/Blaster/Effects.projectileEffect (ModuleScript) | 7 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Blaster/Effects.projectileEffect (ModuleScript) | 55 | Workspace | code | `round.Parent = Workspace` |
| ReplicatedStorage/DialogModule/(root) (ModuleScript) | 14 | Workspace.CurrentCamera.FieldOfView | comment/string | `-- ADAPTED: the original tweened Workspace.CurrentCamera.FieldOfView directly. This game arbitrates` |
| ReplicatedStorage/DialogModule/(root) (ModuleScript) | 34 | Workspace | comment/string | `-- NPC's own part in Workspace (the previous design): Roblox's GUI input system only hit-tests` |
| ReplicatedStorage/DialogModule/(root) (ModuleScript) | 35 | Workspace | comment/string | `-- GuiObjects that descend from a player's PlayerGui. A BillboardGui parented under a Workspace part` |
| ReplicatedStorage/Modules/FootstepModule (ModuleScript) | 84 | Workspace | comment/string | `if not parent then warn("Parent not specified, Footstep folder parented to workspace") end` |
| ReplicatedStorage/Modules/FootstepModule (ModuleScript) | 87 | Workspace | code | `parent = parent or workspace` |
| ReplicatedStorage/Modules/CameraAuthority (ModuleScript) | 25 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ReplicatedStorage/Modules/CameraAuthority (ModuleScript) | 31 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| ReplicatedStorage/Modules/MenuFovBlur (ModuleScript) | 2 | Workspace.CurrentCamera.FieldOfView | comment/string | `-- CameraAuthority as a new "Menu" source rather than writing Workspace.CurrentCamera.FieldOfView` |
| ReplicatedStorage/Quests/QuestConfig (ModuleScript) | 9 | Workspace.Quests | code | `npcName: string, -- must match a Model directly under Workspace.Quests` |
| ServerScriptService/Blaster/Scripts.Blaster.validateShot (ModuleScript) | 2 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Blaster/Scripts.Blaster.validateShot (ModuleScript) | 12 | Workspace:GetServerTimeNow | code | `local now = Workspace:GetServerTimeNow()` |
| ServerScriptService/Blaster/Scripts.ShotResolver (ModuleScript) | 25 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Blaster/Scripts.ShotResolver (ModuleScript) | 424 | Workspace | code | `blast.Parent = Workspace` |
| ServerScriptService/Blaster/Scripts.ShotResolver (ModuleScript) | 433 | Workspace.Terrain | code | `point.Parent = Workspace.Terrain` |
| ServerScriptService/Blaster/Scripts.ShotResolver (ModuleScript) | 441 | Workspace:GetPartBoundsInRadius | code | `for _, part in Workspace:GetPartBoundsInRadius(position, radius) do` |
| ServerScriptService/Enemy/Scripts.EnemyAI (ModuleScript) | 18 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Enemy/Scripts.EnemyAI (ModuleScript) | 64 | Workspace | comment/string | `-- `character` must already be parented to Workspace, tagged Constants.ENEMY_TAG, and holding` |
| ServerScriptService/Enemy/Scripts.EnemyAI (ModuleScript) | 596 | Workspace:GetServerTimeNow | code | `local seed = Workspace:GetServerTimeNow()` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 12 | Workspace | comment/string | `-- Templates live in ServerStorage rather than Workspace deliberately: a template parented into the` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 24 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 38 | Workspace:they | comment/string | `-- Rig templates live in ServerStorage rather than Workspace: they are design-time source objects, and` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 39 | Workspace | comment/string | `-- a template sitting in Workspace would be a live, visible, shootable character standing in the map.` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 108 | Workspace:FindFirstChild | code | `local folder = Workspace:FindFirstChild(ENEMIES_FOLDER_NAME)` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 112 | Workspace | code | `folder.Parent = Workspace` |
| ServerScriptService/Enemy/Scripts.EnemySpawner (Script) | 397 | Workspace | comment/string | ``EnemySpawner: no spawn points found. Tag Parts or Attachments in Workspace with `` |
| ServerScriptService/Quests/Scripts.QuestService (Script) | 10 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Quests/Scripts.QuestService (Script) | 31 | Workspace:FindFirstChild | code | `local questsFolder = Workspace:FindFirstChild("Quests")` |
| ServerScriptService/Quests/Scripts.QuestService (Script) | 37 | Workspace.Quests | comment/string | `warn(`QuestService: no NPC named "{quest.npcName}" under Workspace.Quests for quest "{questId}"`)` |
| ServerScriptService/WeaponAnimationPreview/(root) (Script) | 2 | Workspace:WaitForChild | code | `local folder = workspace:WaitForChild("WeaponAnimationPreview")` |
| ServerScriptService/Weapons/Scripts.CashService (Script) | 13 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| ServerScriptService/Weapons/Scripts.CashService (Script) | 136 | Workspace:FindFirstChild | code | `local folder = Workspace:FindFirstChild(DROPS_FOLDER_NAME)` |
| ServerScriptService/Weapons/Scripts.CashService (Script) | 140 | Workspace | code | `folder.Parent = Workspace` |
| ServerScriptService/Weapons/Scripts.CashService (Script) | 181 | Workspace | code | `anchor.Parent = Workspace` |
| ServerScriptService/Weapons/Scripts.CashService (Script) | 239 | Workspace | comment/string | `-- Under a folder rather than loose in Workspace, matching how Enemies are grouped.` |
| StarterGui/Bobbing Camera/(root) (LocalScript) | 2 | Workspace | code | `local Camera = game:GetService("Workspace").CurrentCamera` |
| StarterGui/Custom Inventory/InventoryController (LocalScript) | 10 | Workspace.CurrentCamera | code | `local camera = workspace.CurrentCamera` |
| StarterGui/Custom Inventory/InventoryController.SETTINGS (ModuleScript) | 665 | Workspace | code | `tool.Parent = workspace` |
| StarterPlayerScripts/DamageDirectionIndicator/(root) (LocalScript) | 14 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/DamageDirectionIndicator/(root) (LocalScript) | 18 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| StarterPlayerScripts/Footsteps/(root) (LocalScript) | 99 | Workspace.CurrentCamera | code | `RayParams.FilterDescendantsInstances = {workspace.CurrentCamera,Character} -- terrain may cause issues idk --i` |
| StarterPlayerScripts/Footsteps/(root) (LocalScript) | 103 | Workspace.Camera.CFrame.Position | code | `if LocalPlayer.Character ~= Character and HRP and (HRP.Position-workspace.Camera.CFrame.Position).Magnitude > ` |
| StarterPlayerScripts/Footsteps/(root) (LocalScript) | 108 | Workspace:Raycast | code | `return workspace:Raycast(a,b,RayParams)` |
| StarterPlayerScripts/Footsteps/(root) (LocalScript) | 116 | Workspace:Raycast | code | `local ray = workspace:Raycast(HRP.Position, -HRP.CFrame.UpVector*GetHipHeightFromHRP(),RayParams)` |
| StarterPlayerScripts/HudClusterScale/(root) (LocalScript) | 12 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/HudClusterScale/(root) (LocalScript) | 16 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| StarterPlayerScripts/IndicatorClient/(root) (LocalScript) | 5 | Workspace.UI.OverheadGui | comment/string | `-- Visual reference: Workspace.UI.OverheadGui (GothamSSm Heavy font, text stroke)` |
| StarterPlayerScripts/LevelUpVFX/(root) (LocalScript) | 12 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/LevelUpVFX/(root) (LocalScript) | 37 | Workspace | code | `burst.Parent = Workspace` |
| StarterPlayerScripts/PromptUiController/(root) (LocalScript) | 31 | Workspace:GetDescendants | code | `for _, d in ipairs(workspace:GetDescendants()) do` |
| StarterPlayerScripts/PromptUiController/(root) (LocalScript) | 36 | Workspace.DescendantAdded:Connect | code | `workspace.DescendantAdded:Connect(function(d)` |
| StarterPlayerScripts/QuestDialogueController/(root) (LocalScript) | 6 | Workspace | comment/string | `-- into Workspace never executes (Roblox only runs them under the Character, Backpack, PlayerGui,` |
| StarterPlayerScripts/QuestDialogueController/(root) (LocalScript) | 11 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/QuestDialogueController/(root) (LocalScript) | 22 | Workspace:WaitForChild | code | `local questsFolder = Workspace:WaitForChild("Quests")` |
| StarterPlayerScripts/QuestDialogueController/(root) (LocalScript) | 33 | Workspace | comment/string | `-- The rig ships with the stock Animate LocalScript, but a LocalScript parented into Workspace never` |
| StarterPlayerScripts/UIScaleController/(root) (LocalScript) | 15 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/UIScaleController/(root) (LocalScript) | 19 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| StarterPlayerScripts/WeaponaryShopController/(root) (LocalScript) | 7 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace")` |
| StarterPlayerScripts/WeaponaryShopController/(root) (LocalScript) | 137 | Workspace.CurrentCamera | code | `local camera = Workspace.CurrentCamera` |
| StarterCharacterScripts/Crouching/(root) (LocalScript) | 11 | Workspace.CurrentCamera | code | `local Camera = workspace.CurrentCamera` |
| StarterCharacterScripts/Crouching/(root) (LocalScript) | 95 | Workspace:Raycast | code | `local raycastResult = workspace:Raycast(rayStart, rayDirection, raycastParams)` |
| StarterCharacterScripts/Crouching/(root) (LocalScript) | 240 | Workspace:Raycast | code | `local rayResult = workspace:Raycast(` |
| StarterCharacterScripts/Crouching/(root) (LocalScript) | 250 | Workspace.FX | code | `dust.Parent = workspace.FX` |
| StarterCharacterScripts/CustomShiftLock/SmoothShiftLock (ModuleScript) | 9 | (alias of Workspace) | alias definition | `local Workspace = game:GetService("Workspace");` |
| StarterCharacterScripts/CustomShiftLock/SmoothShiftLock (ModuleScript) | 23 | Workspace.CurrentCamera | code | `local Camera = Workspace.CurrentCamera;` |
| StarterCharacterScripts/CustomShiftLock/SmoothShiftLock.Maid (ModuleScript) | 15 | Workspace.ChildAdded:Connect | code | `maid:GiveTask(workspace.ChildAdded:Connect(print))` |
| Workspace/Quests/Level 1 Quest.Animate (LocalScript) | 112 | Workspace.And | comment/string | `-- Workspace. And a FindFirstChild is more performant than checking for multiple` |
| Workspace/Quests/Level 1 Quest.Animate (LocalScript) | 425 | Workspace | comment/string | `-- Fixes issue with characters that are moved in and out of the Workspace accumulating tracks` |
| Workspace/UI/OverheadGui.InformationLabel.Script (Script) | 1 | Workspace.UI | comment/string | `-- This lives on a TEMPLATE (workspace.UI, a Part) that IndicatorClient clones onto characters. The` |
| Workspace/UI/OverheadGui.InformationLabel.Script (Script) | 2 | Workspace | comment/string | `-- original indexed .Head unconditionally, so while the template sat in Workspace -- where the` |
| Workspace/UI/OverheadGui.InformationLabel.Script (Script) | 4 | Workspace.UI | comment/string | `-- `Head is not a valid member of Part "Workspace.UI"` from the moment the place loaded.` |

94 hit lines.

## Summary: top-level Workspace names the code needs

Besides engine API on Workspace (`CurrentCamera`, `Terrain`, `Camera`, `GetServerTimeNow`, `Raycast`, `Spherecast`, `GetPartBoundsInRadius`, `GetDescendants`, `DescendantAdded`, `ChildAdded`), the code names these top-level children:

| name | where | status |
|---|---|---|
| `Quests` | `ServerScriptService/Quests/Scripts.QuestService` line 31 (`FindFirstChild`), `StarterPlayerScripts/QuestDialogueController` line 22 (`WaitForChild`), comment in `QuestConfig` | imported root (`Workspace.Quests`, top level, same name) |
| `Enemies` | `ServerScriptService/Enemy/Scripts.EnemySpawner` lines 37, 108, 112 (`ENEMIES_FOLDER_NAME`) | created at runtime by the script itself |
| `CashDrops` | `ServerScriptService/Weapons/Scripts.CashService` lines 40, 136, 140 (`DROPS_FOLDER_NAME`) | created at runtime by the script itself |
| `WeaponAnimationPreview` | `ServerScriptService/WeaponAnimationPreview` line 2 (`workspace:WaitForChild`, no timeout) | **MISSING from the plan, and missing in the FPS place too** (`workspace.WeaponAnimationPreview` is nil in FPS). The script is `Enabled = true`; it yields forever with an infinite-yield warning at the top of the script. Pre-existing in FPS. |
| `FX` | `StarterCharacterScripts/Crouching` line 250 (`dust.Parent = workspace.FX`) | **MISSING from the plan, and missing in the FPS place too** (`workspace.FX` is nil). Only reached when crouch dust is enabled (`DustEnabled = true`), where it would raise an error. Pre-existing in FPS. |

Also relevant to the city: `StarterPlayerScripts/PromptUiController` lines 31 and 36 walk `workspace:GetDescendants()` and subscribe to `workspace.DescendantAdded`. On the city's 166,574-descendant Workspace that is a heavier scan than in FPS (2,220); this is a performance watch item, not a missing path.

Nothing references a name that the plan renames (`Map`, `UI`, `Part`, `Model`, `SpawnLocation`): the renamed `Workspace.Dev.*` containers are safe on this evidence. Found by tags or attributes rather than paths: `EnemySpawnPoint`, `NPCprompt`, `Target`.
