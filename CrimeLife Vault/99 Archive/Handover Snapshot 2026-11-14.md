---
type: archive
tags: [archive, handover, snapshot]
updated: 2026-11-14
sources: ["CLAUDE.md (as of 2026-11-14, every section except the separate other-project section)"]
---

> Frozen snapshot of the CrimeLife / FPS System parts of `Documents/Roblox/CLAUDE.md` as of 2026-11-14. Never edit it. The vault now replaces it; where they disagree, the vault wins. (Known drift already: it says progression is session-only, but [[FPS-Persistence-Phase-3]] added saves on 2026-09-23; and it names `FPSSystem/` as the change-log folder, which moved to `70 Batches/` on 2026-11-14.)

# Roblox Development — Operating Context

Primary place: **FPS System** (`Roblox Games/FPS System.rbxl`). A second place, **Robbery System**,
shares UI modules with it but is a separate project — never edit it unless it is named explicitly.

Live Studio access runs through the `Roblox_Studio` MCP server (`.mcp.json`), which attaches to a
running Studio instance. Confirm the attached instance is the FPS System place before any write.

## How to work in this project

1. **Read before you edit.** The instance tree below is derived from the change-log archive, not from
   a live read. Confirm the real path through the Studio MCP server before changing anything.
2. **Reproduce first, then measure.** The established practice here is to demonstrate a fault with
   numbers before altering code (nearest-neighbour distances, climb rate, loudness peaks, absolute
   positions), and to re-measure after. A change log that cannot cite a before and after number is
   not finished.
3. **Verify the result, not the arithmetic.** A successful edit report is not proof. Read the
   resulting property back — especially `AbsolutePosition`, `AbsoluteSize` and `AbsoluteCanvasSize`,
   which are the only honest witnesses for layout work.
4. **Separate what was verified from what was not.** Every change log carries a `Status:` line and
   says plainly which parts were confirmed live and which still need a person. Keep that honesty.
5. **Record every change.** One markdown change log per change, in
   `CrimeLifeRoblox/FPSSystem/` — **this clone is the source of truth** (git repo, remote
   `Luqpic/CrimeLifeRoblox`, branch `main`). Follow the existing Summary / Cause / Changes / Notes
   shape, and make one commit per change log, matching the `Add change log: <what changed>`
   convention already in the history. Notes carry the reasoning and the disproved theories — those
   are the most valuable part of the archive.

   `RobloxFPSsystem/` is a second clone of the same repo, fully contained in the one above and
   safe to ignore.

   `PromptFolder/` is **not** a duplicate, despite sharing filenames. It is the archive of the
   original PROMPTS — what was asked for — while the repo holds the change logs, what actually
   happened. The same name means two different documents: `FPS-Kill-Leveling-System.md` is a
   20,374-byte specification there and a 1,062-byte change log in the repo. Seven of its files
   exist nowhere else. Never delete it, never overwrite it with change logs, and read it when
   you need the original intent behind a system rather than the record of the work.
6. **Prefer the shared module over a local rebuild.** Most historical bugs in this place came from
   five panels each reimplementing the same widget. If a behaviour exists in `ReplicatedStorage.UI.*`
   or `ReplicatedStorage.Modules.*`, route through it.
7. **Extend weapons by attribute, not by fork.** Weapon behaviour is data on the Tool
   (`infiniteAmmo`, `knockbackForce`, ADS zoom, burst mode, ray count). Add an opt-in attribute that
   the shared blaster code reads; do not branch the shared code per weapon.

## Instance tree (from the change-log archive)

**ReplicatedStorage**
- `Blaster.Constants`, `Blaster.Scripts.BlasterController`, `Blaster.Scripts.ViewModelController`,
  `Blaster.Utility.canDamageHumanoid`, `Blaster.Remotes.DamageDirection`, `Blaster.ViewModels.*`
- `Weapons.UpgradeConfig`, `Weapons.Remotes.BuyRequest`, `Weapons.Remotes.UpgradeRequest`
- `Enemy.Constants`, `Enemy.AimConfig`, `Enemy.templateConfig`
- `Quests.QuestConfig`, `Quests.Remotes`; `DialogModule`
- `Leveling.Constants`, `Leveling.Remotes`; `Movement.Constants`
- `Modules.CameraAuthority`, `Modules.MenuFovBlur`, `Modules.NotificationController`
- `UI.Theme`, `UI.Panels`, `UI.Effects`, `UI.Transitions`, `UI.CashBurst`, `UI.PromptUI`,
  `UI.OpenPlayerCard`
- `GuiTemplates.*` — WeaponaryShop, PlayerCard, QuestLog, DeathScreen, Notification, WeaponCard,
  WeaponStatPanel, EnemyGUI, QuestResponsesBillboard

**ServerScriptService**
- `Weapons.Scripts.*` — CashService, EquipService, LevelingService, WeaponPickup, WeaponShopService,
  WeaponUpgradeService
- `Blaster.Scripts.ShotResolver`, `Blaster.Scripts.DamageDirectionService`
- `Enemy.Scripts.EnemyAI`, `Enemy.Scripts.EnemySpawner`
- `Quests.Scripts.QuestService`; `Movement.Scripts.SprintAuthority`;
  `Ragdoll.Scripts.PlayerRagdoll`; `UnitTestRunner`

**ServerStorage** — `Weapons.*` (per-weapon models, ~37), `EnemyTemplates.*` (Thug, Police,
StandardEnemy), `Cash` (clone source), `ArchivedWeaponPickups`, `UnitTest.Cases.*`

**StarterPlayer.StarterPlayerScripts** — WeaponaryShopController, PlayerCardController,
QuestDialogueController, QuestLogController, QuestFeedbackController, InventoryController,
DeathScreen, LevelingHud, LevelUpVFX, StaminaHud, PlayerNameplates, WeaponStatBillboard,
DamageDirectionIndicator, AdminLevelController, UiTransitionBinder, InventoryDeathLock (superseded)

**StarterPlayer.StarterCharacterScripts** — `Lean`

**StarterGui** — `ScreenGui` (HUD), `QuestResponsesGui`, `Custom`, `dialog`

**Workspace** — `EnemySpawns`, `Quests`, `UI`

## Systems

- **Weapons / blaster.** Data-driven: stats live as Tool attributes, shared code reads them.
  `ShotResolver` is server authority for hits, knockback and stun stamping. ViewModels are built by a
  re-runnable build script that copies raw meshes rather than consuming them, using a donor-skeleton
  swap (add a mesh to the core part, never replace it).
- **Shop and upgrades.** `WeaponShopService` + `WeaponaryShopController` over `BuyRequest` /
  `UpgradeRequest`. Ownership is permanent and uncapped; upgrades key on (player, weapon type) and
  share one damage figure from `UpgradeConfig`. Progression is session-only — there is no persistence
  layer. The detail panel carries a 3D viewport preview oriented from the muzzle marker.
- **Economy.** `CashService` and `leaderstats.Cash`. Spending throws a coin burst from the clicked
  button (`UI.CashBurst`); earning flies coins into the HUD (Robbery place's `CashClaimVFX`). Same
  coin slice on both sides deliberately.
- **Enemies.** `EnemySpawner` reads `Workspace.EnemySpawns`, spawns from `ServerStorage.EnemyTemplates`
  by `EnemyType` marker, scatters within a 22-stud radius sampled through a square root, tops up every
  2.5s, and tags each rig with its spawn kind for quest credit. Rigs sit in an `EnemyCharacter`
  collision group that does not self-collide. `EnemyAI` supports per-type overrides for damage,
  accuracy ceiling, recoil and melee engage range.
- **Quests.** `QuestConfig` -> `QuestDialogueController` -> `QuestService` (server authority), with
  kill tagging from the spawner and `QuestFeedbackController` for feedback. Replies are hosted in the
  player's own `StarterGui.QuestResponsesGui` and pointed at the current giver.
- **Leveling.** `LevelingService` + `LevelingHud` + `LevelUpVFX`, constants in
  `ReplicatedStorage.Leveling`.
- **UI.** `UI.Panels` owns HUD visibility and panel exclusivity; `CameraAuthority` arbitrates camera
  claims; `MenuFovBlur` reference-counts blur; `UI.Effects` owns hover, click and close-button
  behaviour; `UI.Transitions` owns fades. Panel art is Figma-exported slices at 4x via the REST
  `/v1/images` pipeline — titles are baked into banner artwork, so re-centring a title is an export
  change, not a layout property.

## Known traps (each one cost a debugging session)

- `UIPadding` offsets its children; it does not inset the frame. Give a button a `Label` child rather
  than padding the button.
- A `CanvasGroup`'s `GroupTransparency` does not fade its own `UIStroke`.
- A `UIListLayout` owns the position — and often the size — of what it stacks. Animating those
  directly is discarded on the next layout pass.
- A GUI parented into the world (BillboardGui/SurfaceGui on a world object) is drawn but never
  hit-tested for the mouse. Clickable UI must live under the player's `PlayerGui`.
- `ZIndexBehavior` is a global on the `ScreenGui`, not a per-element property.
- `Instance.Name` collides with a custom `Name` property on templates — check before assigning.
- `Sound.PlaybackLoudness` reports the raw waveform and ignores `Volume`; it compares assets, it does
  not measure applied gain.
- `AnchorPoint` and `Position` must agree. `AnchorPoint (0, 0.5)` with `Position.Y = 0` puts a bar's
  centre on its track's top edge.
- `BillboardGui` size in Scale is studs; in Offset it is pixels.
- `AbsolutePosition` is measured below the top-bar inset while an overlay that ignores the inset is
  not — add the inset back or everything lands ~36px high.
- `ServerStorage` does not replicate; a client cannot read templates from it.
- Equipping sets `MouseBehavior` to `LockCenter`, so the cursor is pinned to screen centre — any
  click-versus-drag test must measure cursor movement, never a distance to a frame.
- TweenService is render-driven. With the Studio viewport collapsed, `RenderStepped` reports 0 FPS
  and tweens do not advance — an environmental failure, not a code fault.
