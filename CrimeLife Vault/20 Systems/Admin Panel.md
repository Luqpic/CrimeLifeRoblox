---
type: system
tags: [system, admin, security, ui, city]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-20-admin-anim-thirdperson/admin-design.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-4-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-4-review.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-3-security-review.md", "CityMerge/after-import.md (Admin blocks, 2026-11-20)", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Admin Panel

**Skills:** `roblox-security`, `roblox-networking`, `roblox-ui` (load these for work here; add `roblox-game-systems` for a new action)

Crimelife City (the cloud place "Crimelife Tycoon") only. Built 2026-11-20 on the developer's brief "Design an admin panel I can use in the game (you design)" ([[2026-11-20 Admin Animations Third Person]]).

## What it does
A staff panel on **F2** with four tabs down the left: PLAYERS, HEISTS, ME, SERVER. A round ADMIN button in the HUD column opens it for phones and pads, and only admins ever see it. 31 actions, 17 owner-only and 14 helper. It replaces the old F2 "Admin: Set Level" panel and the `/setlevel` command.

- **Players:** look up, set level, give or take cash and Spraypaint, give weapon, heal, respawn, freeze and unfreeze, go to, bring, kick, ban (1 hour, 1 day, 7 days, forever).
- **Heists:** the state of the four heists, reset a cooldown (one or all), teleport to each heist, the Illegal Supplier or the spawn, set or clear stars, spawn police (1 to 6), spawn enemies, clear mine or clear all.
- **Me:** god, invisible, fly, noclip, walk speed (8 to 100), spectate.
- **Server:** announce, server stats (refreshed every 2 s only while the tab shows), the action log.

## Who is an admin
`Admin.Roles.roleOf` (pure) gives one of three answers. A Studio session is an owner (`RunService:IsStudio()`, false on a live server). The place creator is an owner. Rank in the creator group and in SolarArc Studios (group 4998611, `Config.GROUP_ID`): 255 owner, 252 and up helper. **No account id appears in code**; the old hard-coded one is gone from the place, `CityScripts/` and the vault ([[Leveling and Renown]]). Rank is read once per join (3 retries 60 s apart on an error) and cached; it is not refreshed mid-session.
- A helper never kicks, bans, freezes or brings an owner or another helper; `goto` and `spectate` are allowed. A helper acting on staff whose role is still loading is refused ("still loading").
- A role-less caller gets "Not allowed.", one log row a minute, nothing else.
- Helper limits: ban up to 1 day; announce at most once per 5 s (`ANNOUNCE_GAP`, owners are not held).

## Where it lives
- `ServerScriptService.Admin`: `Config` (every number), `Roles`, `Hooks` (server-only seam table), `Actions` (validate, run, dispatcher, log of 150 rows, `liveContext`), `AdminService` (Script).
- `ReplicatedStorage.AdminRemote` (RemoteFunction, `(action, args) -> {ok, message, data}`) and `AdminAnnounce` (RemoteEvent), created at run time by `AdminService`.
- `ServerStorage.AdminPanel`: `AdminPanelGui` (ScreenGui, `Sibling`, DisplayOrder 25, 760 x 480 panel, `FitScale` UIScale, `AdminPanelController` and `Config` inside) and `AdminHudGui` (the ADMIN button and the touch fly UP and DOWN). Built by `CityMerge/builds/2026-11-20-admin-panel-gui.luau` (re-runnable). **Non-admin clients never receive the code**: `AdminService` clones both GUIs into a role holder's `PlayerGui` and removes them on role loss.
- **In Edit both GUIs live in StarterGui, switched off** (Edit is the truth, [[2026-11-20 Edit Rigs on Every Spawner]]). `AdminService` moves them back into `ServerStorage.AdminPanel` first thing at server start, switches them on, and still clones them only to admins. To look at the panel in Edit: tick `Enabled` on `AdminPanelGui` and `Visible` on its `Panel` frame; untick both before saving.
- Hooks in the owning scripts: `LevelingService` (`setLevel`), `WeaponShopService` (`giveFree`), `BankInstance:ResetCooldown` registered by `HeistServer`, `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer`, `WantedService.setStars`, `PoliceDispatcher.spawnLoose`. Logic stays with the owner; the admin code calls through `Hooks`.
- Tests: `ServerStorage.UnitTest.Cases.AdminRoles_Test` (9) and `Admin_Test` (17 after the fixes).
- Retired: `ServerStorage.CityQuarantine.AdminReplaced.AdminLevelController` (disabled, account number replaced by 0).

## How it works
- **Server order:** role, the action's role, `args` is a table, target (a UserId number resolved with `Players:GetPlayerByUserId`, never an Instance from the client), `validate` (finite whole numbers in range, names looked up in frozen tables), a 0.25 s cooldown per admin, run in a `pcall`, log. Errors reach the client as fixed strings.
- **Text** (announce, kick and ban reasons) is bounded by bytes first (4 x the limit), then trimmed, then filtered with `TextService:FilterStringAsync` for broadcast. A filter failure falls back to the fixed text for kick and ban and fails closed for announce. The announce card is the city's one notification style, title ADMIN ([[Notifications]]).
- **Per-life states live on the character** (`AdminFrozen`, `AdminGod`, `AdminInvisible`, `AdminWalkSpeed`, `AdminFly`, `AdminNoclip`) so they end with the body; `Died`, `CharacterRemoving` and a role change clear them. The role itself rides on the delivered GUIs (`AdminRole`), **not** on the Player.
- **God:** an invisible ForceField (refuses every `TakeDamage`), an `AdminGod` check in the Bank death pit (`HeistServer`), and a void guard that puts a god admin back on the spawn. Every damage path was grepped (ShotResolver, enemy and police through it, heist guards, lasers, the pit; no fall damage, no Explosion instances).
- **Invisible:** every part and decal to transparency 1, originals kept and restored exactly; later parts such as a new Tool are included; `PlayerNameplates` hides the plate and the View Card prompt.
- **Walk speed:** character attribute `AdminWalkSpeed`; `SprintAuthority` writes it last in its tick, `Animate2` uses it as the only target while set.
- **Fly, noclip, spectate** run on the client (it owns the body) and only while the server's attributes are set. Fly is a `LinearVelocity` plus `AlignOrientation` with PlatformStand; Space up, LeftControl down at ContextActionService High with Sink so shift lock never toggles. Spectate writes `CameraSubject` and asks the server for a `ReplicationFocus` on the target; it unequips the admin's tool first so the shoulder camera lets go ([[Weapons and Blaster]]).
- **Heist reset** lives on `BankInstance` (it owns the state machine): only from Cooldown, then the normal rearm; a reset from Idle or Active is refused.
- **Spawned police** are loose officers (no squad) near the admin, Armed Police from the third; **spawned enemies** are the non-police templates with no spawner accounting; clears kill (`Health = 0`) so the spawner and dispatcher run their normal death paths ([[Police and Wanted]], [[Enemies and Spawner]]).
- **UI:** `UI.Panels` closer, `MenuFovBlur`, `Effects.bindClose`, sounds and stroke hover on every control, a one-line status at the foot (accent ok, danger refusal plus `Sounds.denied()`), one remote call at a time 0.3 s apart, kick and ban fire on a second click within 3 s ("CLICK AGAIN"), controls a helper may not use are hidden by their `Action` attribute. Fit scale `min(1, (safeW - 16) / 760, (safeH - 16) / 480)`.

## Extend it
- A new action: add it to `Actions` with its role and a `validate`; if the logic belongs to another system, add a seam to `Hooks` and register it from the owning script (never copy the logic). Put every number in `Admin.Config`. Add a case to `Admin_Test`.
- A new panel control carries an `Action` attribute (and `OwnerOnly` when needed) so helpers do not see it.
- Never put an account id, name or key in code or notes; rank is the only identity.

## Watch out
- **Studio is always an owner.** `RunService:IsStudio()` makes every Studio session an owner, so a Studio test cannot show the helper or role-less paths; the `Roles.set(player, role)` seam does. It is a test seam: nothing outside `Roles.load` calls it.
- **Ban works only in a published game.** In Studio `BanAsync` fails and the panel shows "Ban works only in a published game."; a real ban was never run.
- A player attribute replicates to every client: do not mark staff with one ([[Streaming and Replication Traps]]). `AdminInvisible` and the other `Admin*` states are still character attributes while on, so an exploiter can still see that a character is invisible, god or flying (accepted, open).
- Invisible restores the saved values; the RPG's loaded-round part is flipped by its own ammo watcher, so a shot while invisible can show it until restore.
- Loose admin police count against `POLICE_CAP` in the dispatcher's top-ups until cleared (CLEAR MINE).
- A teleport streams the spot in first (`RequestStreamAroundAsync`, 5 s) because the place has StreamingEnabled.
- The panel on a phone: scale 0.658 at 844 x 390, text 7.9 to 10.5 px, computed, never seen ([[Open Items]]).
- `Admin.Hooks` makes `LevelingService` require `Admin.Roles` at the top: if that module errors, leveling stops loading.
- The git history still holds the old account id (`FPSSystem/Weapons/LevelingService.luau` in the frozen FPS mirror too). A user id is public information, not a credential; only a history rewrite would remove it.

## History
- 2026-11-20: built and reviewed in one night (31 actions, panel, hooks, 25 specs, then 26 after the fixes); fixes for a role lost mid-session, spectate after a respawn, a quadratic text pattern, the staff-naming attribute, the god-guard leak, kick and ban filter fallback and the announce gap. Saved as place versions 21 and 23. [[2026-11-20 Admin Animations Third Person]]

See [[Batch Log]].
