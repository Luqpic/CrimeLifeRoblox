---
type: system
tags: [system, ui, billboard, nameplate]
updated: 2026-11-20
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "CLAUDE.md (Known traps)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Enemy-Overhead-GUI-Integration.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-5.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Player-Nameplates-And-LevelUp-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Polish-And-Denied-Feedback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Enemies-Climbing-Each-Other-And-Nameplate-Gap.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Billboard-Scale-And-Cash-Drop-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Global-Notifications-And-Location-Status-Billboards.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Player-Overhead-GUI-Integration.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Nameplates and Billboards

**Skills:** `roblox-ui`, `roblox-characters-animation` (load these for work here)

## What it does
World-space overheads: one name + health plate design shared by enemies and players (players also show their criminal rank), a View Card prompt on other players, and Robbery's location status badges. Quest-giver dialogue billboards belong to [[Quests and Dialogue]]; the weapon stat billboard over world pickups was retired with the shop refactor ([[Weapon Shop and Upgrades]]).

## Where it lives
- `ReplicatedStorage.GuiTemplates.EnemyGUI` (`GUI.Info.Name`, `GUI.HealthGUI`, `HealthIcon`, `HealthManager` script); cloned onto each enemy head by `ServerScriptService.Enemy.Scripts.EnemySpawner`.
- `StarterPlayer.StarterPlayerScripts.PlayerNameplates` (client): player plates, `ViewCardPrompt`, rank line.
- `ReplicatedStorage.UI.OpenPlayerCard` (BindableEvent) -> `PlayerCardController.openCard(target)` ([[Player Card]]).
- Ranks: `ReplicatedStorage.Leveling.Constants.RANKS`, `rankForLevel(level)` ([[Leveling and Renown]]).
- Legacy: `Workspace.Dev.UI.OverheadGui` (a Part template). In the city nothing clones it: `IndicatorClient` draws only the floating damage number on the shooter's client, and the template's own per-frame Script returns early. Removal is the developer's call.
- Robbery: per-location `StatusBillboardAnchor` parts in each `*Markers` folder; colour driven from `HeistClient`'s `LOCATIONS` loop ([[Robbery Heists and Getaway]]).

## How it works
- Plate: name in white display type with a dark shadow; track `#0E1016` with `#2A2F3C` hairline; fill `#FF4B4B`; remaining health alone, right-aligned (`90`, not `90 / 90`); white Health icon at the bar's left end.
- Size `UDim2.fromScale(5, 1.6)` studs for players (1.2 before ranks were added; name and bar keep their stud sizes), enemy `{5,0},{1.2,0}`; `MaxDistance` 50; `AlwaysOnTop = false`.
- Enemy plates show the real type: the spawner writes `enemyType` to the label (models stay named `"Enemy"` because targeting keys on it). Plate hides at 0 health. Attached after spawn because spawned enemies have their scripts stripped.
- Default Roblox overhead suppressed: `Humanoid.DisplayDistanceType = None` on every `CharacterAdded` (enemies: off in the templates).
- You never see your own plate (does not block aim in third person); rank shows on your card.
- Health refreshes on `HealthChanged` and `MaxHealth`. Rank listens to the Player's `Level`.
- `ViewCardPrompt` on every other player's `HumanoidRootPart`: `E`, 12 studs, no line of sight. All prompts disable while a panel is open (`UI.Panels.onChanged`, weak-key registry).
- Robbery status badge: emoji logo with a `UIStroke` green / yellow / red for Idle / Active / Cooldown, sized in Offset (constant on screen by design).

## Extend it
- Change a rank's name or colour: one line in `RANKS`.
- Restyle plates in the `EnemyGUI` template; mirror stud sizes in `PlayerNameplates` so both match.

## Watch out
- `BillboardGui` size in Scale is studs, in Offset pixels; the first player plate (`fromOffset(250, 64)`) ballooned with distance.
- `info.Name` returns the instance's name string; use `FindFirstChild("Name")`. The label "Name" and script "Text" collide with properties.
- Wait for the Head (10 s) before building a plate; under streaming it can land after `CharacterAdded`.
- A world GUI is drawn but never hit-tested; clickable UI must live in `PlayerGui`.
- No double name (read 2026-11-17): only `PlayerNameplates` draws a name over a player (and turns Roblox's default name off, yours included). A second player has still not looked.

## History
- 2026-11-20: no plate and no View Card prompt while the character has `AdminInvisible` (first mirror of `PlayerNameplates` in `CityScripts/`). [[Admin Panel]] [[2026-11-20 Admin Animations Third Person]]
- 2026-11-17: checked for a double name over a player: none, only `PlayerNameplates` draws one; every NPC overhead kept. [[2026-11-17 Known Issues Pass]]
- 2026-09-24: criminal ranks on player plates; Health icon in every overhead bar; plate waits for the Head. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- 2026-09-19: enemy nameplate gap (bar starts at 0.640, +0.071 gap). [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- 2026-09-18: prompts stand down while a panel is open. [[FPS-Shop-Polish-And-Denied-Feedback]]
- 2026-09-18: possible `OverheadGui` duplication flagged; its per-frame error fixed. [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- 2026-09-18: plates sized in studs to match `EnemyGUI`; no plate over your own head. [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]]
- 2026-09-18: player nameplates + View Card prompt. [[FPS-Player-Nameplates-And-LevelUp-Fix]]
- 2026-09-18: enemies show their real type; health bar to the Figma. [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-16: `EnemyGUI` moved to `GuiTemplates` and onto every enemy. [[FPS-Enemy-Overhead-GUI-Integration]]
- 2026-09-12 (Robbery): location status billboards. [[Global-Notifications-And-Location-Status-Billboards]]
- 2026-09-11: weapon stat billboard over pickups, later scaled 1.25x. [[FPS-Weapon-Stat-Billboard-And-Cash-Upgrade-System]], [[FPS-Billboard-Scale-And-Cash-Drop-System]]

See [[Batch Log]].
