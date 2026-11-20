---
type: open
tags: [open-items, bugs, watch-list]
updated: 2026-11-20
sources: [".superpowers/sdd/2026-11-17-known-issues-pass/progress.md", ".superpowers/sdd/2026-11-17-police-and-wanted/progress.md", "CrimeLifeRoblox/CityMerge/police/final-run.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/*.md (Status lines and Notes)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/*.md (Status lines and Notes)", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-persistence-phase-3-design.md", "CrimeLifeRoblox/docs/superpowers/specs/2026-09-23-renown-phase-2-design.md", ".superpowers/sdd/2026-11-18-open-items-pass/open-items-closure.md", ".superpowers/sdd/2026-11-18-open-items-pass/progress.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-1-report.md to task-6-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/progress.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-report.md to task-3-4-report.md", ".superpowers/sdd/2026-11-20-admin-anim-thirdperson/task-1-review.md, task-2-review.md, task-3-4-review.md, task-3-security-review.md", "CityMerge/after-import.md (2026-11-20 blocks)"]
---

# Open Items

Harvested on 2026-11-14 (city items added the same day; 2026-11-15 items from [[2026-11-15 FPS Systems Into City]] added; 2026-11-16 items from [[2026-11-16 Robbery Systems Into City]]; 2026-11-17 items from [[2026-11-17 Police and Wanted]] and [[2026-11-17 Known Issues Pass]]; 2026-11-18 items from [[2026-11-18 Open Items Pass]]; 2026-11-20 items from [[2026-11-20 Admin Animations Third Person]]) from every change log whose `Status:` or Notes say not verified, needs a person, follow-up or later. Each item names its source; the date is the source's date. When an item closes, remove it here and say so in the batch note. Systems: [[Systems MOC]]. How to re-check: [[Regression Suite]].

## Needs the developer

### Publish, save and ids
- **Save the place (2026-11-20).** The working copy is now the cloud place "Crimelife Tycoon" (placeId 128488619644399). Claude saved it as place versions 10, 15, 21 and 23 on 2026-11-20 (after Task 1, Task 2, the camera review fixes and the admin review fixes) and never published; anything after version 23 is not in a saved version unless it was saved later (the heist police batch started after it). A save makes a place version, never a publish. The local `Roblox Games/Crimelife city.rbxl` is no longer the working copy (its last known state is the Nov 18 20:39 save, with the open items pass); decide whether to keep it as a snapshot. [[2026-11-20 Admin Animations Third Person]] [[2026-11-18 Open Items Pass]]
- **Turn on Studio access to API services for the cloud place.** Every Play logs `DataStoreService: StudioAccessToApisNotAllowed: Cannot write to DataStore from studio if API access is not enabled` (ProfileStore `____PS`, `SetAsync`), so the server boot is never at 0 errors. It is a place setting only the developer can change, not a code fault. Until then persistence in Studio is not exercised against the real store. [[2026-11-20 Admin Animations Third Person]] -> [[Persistence and Saves]]
- **`Documents/Roblox/CLAUDE.md` still names `Crimelife city.rbxl` as the primary place** (and the vault, not CLAUDE.md, now says the cloud place "Crimelife Tycoon"). Update that line (the 2026-11-20 vault update left `CLAUDE.md` untouched on purpose). [[2026-11-20 Admin Animations Third Person]]
- **Real gamepass ids.** Every FPS pass id is a placeholder `0` except RPG, which runs on stand-in pass 10904398 and must be swapped for the real RPG pass (2026-09-24). The owned-tile highlight needs real ids too (2026-09-18). Since 2026-11-18 every pass id, the heist duffel x2 / x4 and `DuffelSpeedBoost` included, lives in `ReplicatedStorage.Monetization.Constants.Gamepasses` (the duffel entries are `shop = false`): paste each real id there and nowhere else. Id `0` means "not configured": never owned, never prompts, no web call. [[FPS-RPG-Preview-Flip-Real-Pass-Sounds-Icons]] [[FPS-Shop-Polish-And-Denied-Feedback]] -> [[Gamepasses]] [[2026-11-18 Open Items Pass]]
- **Robbery: create the x2 and x4 duffel gamepasses**, then paste their ids into `ReplicatedStorage.Monetization.Constants.Gamepasses` (`DuffelCapacityX2`, `DuffelCapacityX4`; both are placeholder `0` in the city, 2026-09-12, rechecked 2026-11-16). A real purchase has never been run; the confirm is proven only through specs. [[Timer-Hourglass-And-Duffel-Upgrade-GUI]] [[2026-11-16 Robbery Systems Into City]] -> [[Gamepasses]] [[2026-11-18 Open Items Pass]]
- **Publish the 49 viewmodel KeyframeSequences**: the Studio tooling cannot upload animations (2026-09-20). [[FPS-Viewmodel-KeyframeSequence-Export]]
- **Upload icons for the eight new guns** (2026-09-24). [[FPS-Eight-New-Pistols-And-Shotguns]]
- **Share the sound assets that fail "not authorized"** in the Creator Dashboard: about 9 weapon sounds (2026-09-18) and about 10 sounds (2026-09-24); the logs do not say whether these overlap. [[FPS-Figma-1to1-Image-Export-And-Font-Fix]] [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]]

### City map (2026-11-14)
- **Set `Workspace.ModelStreamingBehavior` to `Legacy`** in the Properties panel: it is not scriptable, so it is not confirmed (2026-11-14). Re-checked 2026-11-18: it is not a script-readable member. [[2026-11-14 City Baseline and Cleanup]] [[2026-11-18 Open Items Pass]]
- **Agree or change the provisional performance targets** in `CityCleanup/baseline-2026-11-14.md` (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Look at the city under streaming on a real phone** and name any far landmark that must stay visible; with a 512 target radius only 1 of the 6 robbery buildings is loaded at spawn (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Decide lighting and time of day** from `ServerStorage.CityQuarantine.Scripts` (8 scripts, disabled) (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Decide the fate of `CityQuarantine.Duplicates`, `LooseTycoon` and `StagingSlab`.** `StagingSlab` holds `UnderGroundCasino` and `WareHouseP2`, which look like the underground halves of the casino and warehouse robberies (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **`Workspace.Map.Loose` still holds 213 unsorted pieces**, including 138 unnamed Models (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **Heaviest remaining models**, the candidates for a later simplification pass (2026-11-14). Workspace is 118,679 instances against a target of <= 163,700, so this is not a miss (the simplification pass is later work, developer 2026-11-18); the six robbery buildings alone are about 83,419 instances and the warehouse about 56,000. From the after-task3 probe, less the models quarantined since ([[2026-11-14 City Baseline and Cleanup]]): [[2026-11-18 Open Items Pass]]
  1. `Map.Robbery.WareHouseRobbery(NotUnderGroundPart)` 56,397
  2. `Map.City` 25,554 (a container)
  3. `Map.City.Buildings` 13,465
  4. `Map.City.nature` 6,935
  5. `Map.Robbery.NewsStation` 6,434
  6. `Map.Robbery.Gas2Go` 6,407
  7. `Map.Robbery.SlowFoods` 6,399
  8. `Gas2Go.BuildingGasStation` 5,468
  9. `NewsStation.Model` 4,950
  10. `Map.Robbery.Bank` 3,891 (tied with `CasinoMain` 3,891)
  The last probe prints only the containers, so these counts are the last per-model figures measured (after Task 3), not a fresh read.

### City and the FPS port (2026-11-15)
- **Re-place the six enemy points and six quest givers by hand.** Their positions are provisional (placed by rules, not by eye; no screenshot could be taken). Old CFrames are in `CityMerge/placement.md`. [[2026-11-15 FPS Systems Into City]] -> [[City Map and Plots]]
- **One Thug was stuck at about (215, 5, 2485)** against `Building_15` at the short east road end (2026-11-15), and **did not reproduce** on 2026-11-17: a 185 s Play, five Thugs sampled every 10 s, none within 2 studs for 30 s, though Thugs did reach x 219 to 220, z 2482 to 2484 while moving. Not moved: every other spot breaks a placement rule (west fails the 130-from-giver rule, -Z the plot rule, +Z 180 is the Smuggler). Options if it shows again: move the Thug out to ring 190 to 200 on the east side and the Smuggler out to +Z 190 to 220, or swap the two. [[2026-11-15 FPS Systems Into City]] [[2026-11-17 Known Issues Pass]] -> [[Enemies and Spawner]]
- **About 79 asset-permission warnings per Play** from MeshIds in `Workspace.TycoonPreview` and `ServerStorage.HQ` (Test30.4 assets on an unpublished local file): share the assets or replace the meshes. [[2026-11-15 FPS Systems Into City]]
- **Checks that need a person at the keyboard in the city:** how shooting feels, pressing E on a quest giver, the weapon shop by real clicks, a phone, two players. [[2026-11-15 FPS Systems Into City]]
- **Walk the `TycoonPreview`.** Its fit on `Plot3` was checked by one screenshot and bounding numbers only. [[2026-11-15 FPS Systems Into City]]
- **Five ScreenGuis stay `ZIndexBehavior.Global` in the city** because `Sibling` would change their paint order (swapped pairs / overlapping pairs): `CashShopGui` 233 / 0, `GamepassShopGui` 51 / 0, `WeaponaryShopGui` 609 / 0, `QuestLogGui` 2 / 0, `Custom Inventory` 123 / 0. `DeathScreenGui` is `Sibling` since 2026-11-18 (renumbered, drawing order unchanged). The counts include hidden objects and model ties as tree order. [[2026-11-15 FPS Hardening In City]] -> [[UI Layout Traps]] [[2026-11-18 Open Items Pass]]
- **Phone and two-player checks still owed** for everything in phase 2b (quest reach at the giver, the quest toast, the flipped ScreenGuis). [[2026-11-15 FPS Hardening In City]]

### Heists in the city (2026-11-16)
- **The Bank escape ring has only 5 of 32 clear points** (UpperCity tower roofs, palms); `EscapeDistance` is kept at 200 (SlowFoods 10 of 32, Gas2Go 18, NewsStation 15). Only the road exit (bearing 200 degrees from the exit spawn, road the whole way to 260 studs) was proven; tune in playtests, with a person walking it. `CityMerge/phase3/locations.md`. [[2026-11-16 Robbery Systems Into City]]
- **Casino and warehouse are still art with no heist** (`Workspace.Map.Robbery.CasinoMain`, `WareHouseRobbery(NotUnderGroundPart)`, about 56,397 instances for the warehouse). A casino heist is new work (later work, developer 2026-11-18); `StagingSlab` still holds `UnderGroundCasino` and `WareHouseP2`. [[2026-11-16 Robbery Systems Into City]] [[2026-11-18 Open Items Pass]]
- **Checks that need a person in the city:** a real lockpick and word scramble by hand; the safe keypad; the Bank's ATMs, registers and safe (never robbed in the city, so the Bank duffel was vault accrual only); two players in one heist; a real E press (automation could not trigger prompts). [[2026-11-16 Robbery Systems Into City]]
- **The level-up popup layout was seen only at 1100 x 679.** `LevelingHud.placePopup` now places the popup again on a viewport resize while it is shown, and `UIScaleController` caps every scale at 1 (read back 1.000), so the "scale above 1" case does not happen. Still needs a person: the phone branch live (844 x 390 is computed from the layout numbers: scaled about 0.71 into the gap left of the duffel, clearing the star meter by 2 px, no phone notch inset measured) and the resize by eye. [[2026-11-16 Robbery Systems Into City]] [[2026-11-17 Known Issues Pass]] -> [[HUD and UI Shell]] [[2026-11-18 Open Items Pass]]
- **Unit tests:** `LocationServer`'s `CharacterRemoving` wiring is proven by reading and the Bank Play only. [[2026-11-16 Robbery Systems Into City]] [[2026-11-18 Open Items Pass]]
- **Playtest before release (2026-11-16):** a shotgun volley at the supplier by hand, NPC respawn timing, city enemies near the heist zones, prompt styling and the two HUDs at both sizes, the Bank loot and the three puzzles by hand. [[2026-11-16 Robbery Systems Into City]] [[2026-11-18 Open Items Pass]]

### Police and the wanted level (2026-11-17)
All from [[2026-11-17 Police and Wanted]]; system: [[Police and Wanted]].
- **Numbers to tune in playtests** (all in `ReplicatedStorage.Wanted.Constants` unless named): alarm levels (Gas2Go 1, SlowFoods 1, NewsStation 2, Bank 3); police hit 0.25, kill 1; witnessed kill 0.5, hurt 0.25; witness range 120; seen range 150; drain 8 s per star; search window 20 s; squads 2 / 4 / 4+2 / 4+4 / 4+6; rings 60 to 120 and 90 to 160; top-up 5 s; leave 200 studs or 60 s; cap 24; `GuardDamage` 6 and `GuardFireInterval` 0.9 (`HeistShared.Config`, `NewsStationShared.Config`); NewsStation guard respawn 60 s.
- **The guards' lethality at the Bank:** a robber in full view of all four dies in about 5.5 s at 6 per shot; one spot 30 studs away has no guard ray at all. Judge it in a playtest.
- **Checks that need a person:** two players (a second robber at the Bank gets no alarm heat if they joined after the trigger; squads sharing the 24 cap; officers preferring their own squad's player; a bystander between a guard and a robber blocks the guard's shot; guards activate on anyone's proximity), a phone (frame time and memory with police, the meter at 844 x 390 live, computed only), how the chase and the shooting feel, a real conversation with a crooked cop (the new lines were never seen typed), the vault path for police at the Bank (a robber in `BankVault` has no exit-spawn match for the path check; never exercised), the star meter on screen in this run (viewport 1 x 1).
- **Police wait at the SlowFoods door**: its interior is off the navmesh, so they engage only when the robber comes out.
- **Guards are anchored and never move:** the Bank's "run to cover" moves nothing; guards shoot from their posts.
- **Deferred minors, still true:** the `start()` filter test needs a real player, so that part is proven in Play only; the alarm registration lines in `LocationServer` and `HeistServer` are proven by Play only; an adopted officer can push a squad over its target until the next dispatcher tick (1 s), when the surplus leaves (the cap is unaffected); the star is a text glyph, not art; `WantedSeen` casts the seen rays on every 2 Hz step, also inside the search window; the drain after leaving sight read 6.8 s, not 8 (2 Hz stepping); the hidden `dialog` labels on the givers still hold the authoring text "LEVEL 1 QUEST" (overwritten before shown); Bank guards stand 3 studs above their posts (kept as they were); `Cashier`, `BankClerk` and (since 2026-11-17) `NewsWorker` are `Invulnerable`, so "hurting a heist civilian" now means guards only; `PoliceDispatcher.debug` and its spawn log stay as a test aid (off by default). [[2026-11-18 Open Items Pass]]
- **Watch (Task 1, 2026-11-18):** the Armed Police Scar L muzzle sits about 1.5 studs under a flat floor when the officer stands (0 shots in a static test, 150 fired in the chase); a lethal blow from full health with no `Tagged` keeps the stars (accepted, exploit-safe: it reads as a self-reset); the `HealthChanged` MaxHealth clause has no spec, and the search and the ally hold are Play-proven only; `_sidestep` has no ledge or wall check and its extra ray per shot is unmeasured; `allyInLine` is not cleared on a target change; searching officers hold at the last-seen spot until sight or a star drop (stars drain after the window, so squads shrink). -> [[Police and Wanted]] [[2026-11-18 Open Items Pass]]

### Heist layers leftovers (2026-11-17)
All from [[2026-11-17 Heist Layers]].
- **Gas2Go ATM vanished once** after a death mid-rip; not reproduced in 3 tries. Since 2026-11-18 `ATMRipOut` rebuilds it from a boot copy, at `Rearm` only. Watch in a real playtest. [[2026-11-18 Open Items Pass]]
- **Carrier ledges (Bank obby):** the collision-group order is fixed (`EnemyCharacter` vs `CarrierLedge` is false at runtime); `CanQuery = false` is inert while `CanCollide` is true (engine), only the collision group keeps default queries off; trials were scripted, not human (J1 and J5 10 / 10 capped); the inbound jump at base speed was not walked by a person. [[2026-11-18 Open Items Pass]]
- **A hands-full gold bar** dropped at the box despawns after the usual 20 s; the gold carrier's death and leave are not pinned in a spec; the fallback paths are tested with fakes only.
- **Edges:** a re-picked carry outside the radius banks at once (accepted); a Manager can be shoved; `Rearm` resets an ATM that an old rip may still carry; the desk and its OFF AIR billboard are always visible; the `Crouching` stand-up clamp is fixed but was not measured. [[2026-11-18 Open Items Pass]]
- **Small:** one Manager run-time sample (14.66 s). [[2026-11-18 Open Items Pass]]
- **Needs a person:** every layer played by hand, two players in a crew, a leaver mid-broadcast, whether the Manager catch window (about 15 s against player WalkSpeed 25) feels right, and the payout numbers (3000, 9000, 6000, 1500, 8000).
- **Review notes, not fixed:** Task 2 weak-key table with string fakes; Task 2 repeat-trigger ordering note; the Task 2 HUD check ran on a stand-alone bank; Task 6 inline `require` in `HeistServer`; a `Died:Once` closure per lockpick trigger (harmless). [[2026-11-17 Heist Layers]] [[2026-11-18 Open Items Pass]]

### Known issues pass leftovers (2026-11-17)
All from [[2026-11-17 Known Issues Pass]].
- **Landing-window speed jitter:** inside the 0.55 s landing window the client ramp (+5.8 per 0.1 s tick) and the server's replicated cap interleave (logged 6.11 then 0.77, 10.68 then 6.02); also a 180-degree `AutoRotate` turn clamps for a few ticks. Not changed. -> [[Movement and Stamina]]
- **Checks that need a person:** two players for nameplates (each sees one name over the other, none over themselves, no default name after a respawn, the damage number on the shooter's screen only, plate hides past 50 studs; the six quest givers, the supplier and enemies keep their overheads); how the dry-fire click, the RPG burst and the new muzzle flashes look and sound (none heard or judged by eye); a real rejoin with a saved Spraypaint balance (the join was emulated with an attribute sequence); the level-up popup on a phone.
- **No automated test** for the re-slot fix (a remote handler on a live Player), the Spraypaint join flag, the dry-fire cue, the shotgun readout, the OWNED card, `LevelingHud.placePopup` or the `Animate2` clamp: each was shown by a measured Play read-back. The Burst re-press dry-fire cue is fixed (cue 0, Semi control 1). [[2026-11-18 Open Items Pass]]
- **Small leftovers:** `GamepassOwned_RPG` came up true once and false once in Plays ("ownership check failed" warning); one confirm path now, recheck in a Play with the stand-in pass. [[2026-11-18 Open Items Pass]]
- **Humanoids not tagged `Invulnerable`** (as read in Edit 2026-11-17): `Workspace.Map.Props` rigs and dummies, the `TycoonPreview` band, Barista2 and 14 mannequins, `Workspace.Targets.Target` x7 and the six `Workspace.Quests` givers (tagged at runtime by `QuestService`). The placed `SlowFoods.Cashier` x3 and `Bank.Bank Clerk` x2 now carry `Invulnerable` and `Witness` (2026-11-18). Information only. [[2026-11-18 Open Items Pass]]

### Open items pass leftovers (2026-11-18)
All from [[2026-11-18 Open Items Pass]].
- **Tests (Task 5 review):** two new `ProfileAdoption` cases add 4 stand-in hydrator warnings to each city run; the `Zone` case passes vacuously with no player character; the `CurrencyBridge_Test` real-player branch is conditional; the `SlowFoodsKey` death case waits up to 1 s on engine behaviour; the `CarryState:Forget` drop fallback never runs in Studio (`CharacterRemoving` fires before `PlayerRemoving`).
- **Economy (Task 5 review):** a refused `Add` after `bank:Claim` would lose the bag while toasting "Banked N" (not reachable today); the `hydrate` merge assumes no other hydrator writes Cash first (`ProfileGateway` is not mirrored). -> [[Economy and Cash]]
- **Quarantine restore:** `OriginalPath` attributes that start `StarterGUI.` could break a restore by first segment (the service is named `StarterGui` again since 2026-11-18).
- **Phone, keypad and notifications (Task 6):** on a phone (844 x 390, computed) the heist toast and the bottom-right stack overlap at x 544..632 when both show (city cards already did); the keypad focus fix needs a real-keyboard check (through the MCP keyboard the first B press still re-focused it); not seen live: a real purchase, a word scramble or hack registration, the popup re-place on a resize; only the 3 newest heist cards show in a burst (the city rule); `GetTextBoundsAsync` yields in `displayNow`, so same-frame cards may stack out of order. -> [[Notifications]] [[HUD and UI Shell]]
- **Task 4:** the quest restore prune permanently drops saves for quest ids missing from `QuestConfig` (accepted, as asked); the Police kill test mutates the real Play session; the read-only Robbery place keeps the old heist wording (the text sweep did not touch it).
- **Hygiene:** 26 untracked space-named copies in `CityScripts/` (" <name> .luau"), not from this batch; the developer may delete them.

### Admin, animation and third person (2026-11-20)
All from [[2026-11-20 Admin Animations Third Person]]; systems: [[Admin Panel]], [[Character Movement and Animation]], [[Weapons and Blaster]], [[Camera Authority]].
- **Needs a person (two players):** spectate. The action refuses yourself and the list is empty in solo Studio, so it is unmeasured: the camera follows the target, `ReplicationFocus` is set, it stops on death, leave and STOP. Also: a helper on one account and an owner on another, a real kick, and a real ban (Studio answers "Ban works only in a published game", so `BanAsync` never ran).
- **The GIVE WEAPON list click was never exercised.** The list builds from `ReplicatedStorage.Weapons.Catalog`; `giveWeapon` itself is proven through the remote (Deagle owned, slot 2, Tool in the Backpack). Virtual input died in the last Plays because the Mac display slept ([[Tween and Render Traps]]); click it once by hand or re-run with `caffeinate -d -u -t N`.
- **Phone checks of the new touch parts (none seen on a device):** the admin panel scales to 0.658 at 844 x 390 (computed; panel 500 x 316 in a 750 x 332 safe area, text 7.9 to 10.5 px, nothing clipped on the live panel at that scale); the ADMIN HUD button (ClusterScale 0.579, 44 px, top about 44 px below the safe top); the touch fly UP and DOWN (top-right at y 4 and 64, 56 px, 8 px clear of the touch Reload button); the roll button (x 556..612, y 306..362, computed with the blaster UIScale 0.6; 16 px clear of Shoot; at 1920 x 1080 it sits 10 px below Shoot); the VIEW and SWAP buttons at 844 x 390 (read back only at 1100 x 679, no overlaps, VIEW 16.8 px clear of Shoot and 30 px of Reload). Notch insets not modelled. Gamepad: the roll on B and the shoulder swap on R3 were not run; pads open the panel through the HUD button only.
- **NPC dialogue mid-shoulder was not exercised** (Task 2 review I5): a real conversation started while the shoulder camera is on. Seat, PlatformStand, `LoadCharacter` and a Weaponary panel were measured and are clean.
- **Task 1, not measured:** a roll out of a sprint (Sprint distance), the touch and gamepad roll paths, a second player watching the moves, a death mid-ledge (the limbs' `CanCollide` restore on the death path), the published Tool hold pose. A real touch device for the roll button.
- **Task 1 review Minors, not fixed:** M2 a client that skips `FireServer` rolls free at the client cooldown (30 x 1.4 studs/s for up to 0.74 s; accepted by the brief, a server displacement watch would close it); M4 a stale `Stamina` attribute lets a legitimate roll run free (same root); M5 a move is not cancelled by a mid-move stun, freeze, ragdoll or carry pick-up (`blocked()` at the top of `stepMove` would do it); M6 a crouched jump still plays `Jump` for a frame window; M7 leg scale is read once at script start (1.044 and 1.096 for the same avatar, rates vary about 5% per spawn); M8 `Animate2`'s startup stop loop can stop a `Movement` track once; the OBT leftover `script.Do` BindableEvent is unused. -> [[Character Movement and Animation]]
- **`AutoRotate` stayed false in one long Play session** (the mouse icon showed the shift-lock cursor with no key pressed, on a fresh `LoadCharacter` character); a fresh Play was true before and after a roll. `CustomShiftLock` (made once per character) is the suspect; not investigated, not touched. Watch for it.
- **Task 2 review Minors, not fixed:** M1 the `AimPitch` server limit lets a 0 through at any rate (cosmetic: it could flip the replicated attribute about 12 times a second); M2 the server cannot know the shoulder camera is on; M4 per-frame cost in `ShoulderCamera.update` (a raycast and a filter re-assign each frame; the review suggests setting the filter once and skipping the raycast while still); M5 `enter` calls `lockBuiltIn` unprotected, so a throw would leave the state set and the root with `AutoRotate` off; M6 crouching in third person snaps the camera instead of easing; M7 the `ViewMode` attribute is not cleared on unequip; M8 and M9 cosmetic. No pure test for the remembered-mode logic (`ShoulderMath_Test` has 5 cases). -> [[Weapons and Blaster]]
- **Admin, not fixed (reviews and the after-import "Not fixed" list):**
  - Roles are cached once per join: a rank lookup that fails stops after 4 tries (about 3 minutes) and a demotion in the group is not seen until the server closes (security M3, correctness M7). The design said "retry at the next panel open", but a role-less player has no panel.
  - Refusal rows from role-less callers share the 150-row log and can evict real rows (security M4); keep them in a counter or a 20-row ring.
  - `SetLevelRequest` stays as an owner-only dead entry point (security M7); the remote and handler could be deleted.
  - Staff states other than the role still show as character attributes while on (`AdminInvisible`, `AdminGod`, `AdminFly` and so on), so an exploiter can see a flying or invisible admin; hide on the server instead if it matters.
  - Fly has no gamepad up and down (correctness M5): the stick follows the camera pitch; A for up and L2 for down would do it (B closes the panel). The touch UP and DOWN buttons are decided once at fly start.
  - Invisible restores the saved values (correctness M6): the RPG's loaded-round part is flipped by its own ammo watcher, so a shot while invisible can show it until restore.
  - Loose admin police count against `POLICE_CAP` until CLEAR MINE; an `EnemyAI.getLive()` clear ("CLEAR ALL, POLICE TOO") is accurate (heist guards are not `EnemyAI`) but was not run during a robbery.
  - The old admin account number is still in git history (security M8, and in the frozen FPS mirror `FPSSystem/Weapons/LevelingService.luau`); a user id is public, not a credential, so only a history rewrite would remove it. The vault copies were removed 2026-11-20 (three lines in two batch notes; three notes under `90 Reference/Original Prompts/` keep it as frozen specifications).
  - Studio is always an owner, so the helper and role-less paths are testable only through the `Roles.set` seam.

### Heist police, gunfights and level toughness (2026-11-20)
From [[2026-11-20 Heist Police and Bank Guards]] and [[2026-11-20 Readable Gunfights and Level Toughness]]; systems: [[Police and Wanted]], [[Robbery Heists and Getaway]], [[Enemies and Spawner]], [[Leveling and Renown]], [[Weapons and Blaster]], [[Movement and Stamina]].

Questions for the developer:
- **Done 2026-11-20 morning:** the developer chose the other way round: the armed police stay upstairs in the lobby, and normal police also spawn after the obby pit. [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **Done 2026-11-20 morning:** guards pay only during a robbery (`NoKillReward`). [[2026-11-20 Walking Bank Guards and Edit Rigs]]
- **Answered 2026-11-20 morning: no free gun.** The weapons will move from buying to a gacha (a future batch; see below).
- **Offender `DamageOverride` 8 to 6 if 1v2 feels hard.** Standing damage rose from 7.2 to 14.0 dps (62 % health left) because recoil no longer ruins follow-up shots; strafing is unchanged. The lever is a Studio attribute on `ServerStorage.EnemyTemplates.Offender`.
- **A level-up still fully heals mid-fight.** Rare after the first levels, except by farming guards.

Not yet checked (needs a person or a longer run):
- Two players, and a phone, for the heist police, the guards and the aim line.
- A real Blaster hit on a guard (the provocation was emulated with `Tagged`).
- NewsStation guards firing in Play (they are Police rigs with a Mateba; only placement was read).
- A roll against NPC fire (the `RollingUntil` stamp and the widest cone are specs and a read-back only), and a flinch in Play (specs only).
- NewsStation's 6:30 wave (the run ended at 5:05).
- The 1v2 verdict assumes 4 clicks a second; at the Glock's 650 rpm cap every case ended above 75 %. Run-to-run variance is large (Police standing 8.0 to 22.7 dps) and the before cells are single runs; Bandits standing is the tightest (one run ended at 50 %).

Minors left open:
- **Batch 2 M2:** one steering path check a second while robbers are inside (since 2026-11-20 morning from one side a tick, in turn).
- **A roll in place gets the widest NPC cone.** `RollAuthority` stamps `RollingUntil` for any accepted roll, moving or not. Bounded by stamina (12.3 a roll, regen 6.25 a second) and the 0.9 s cooldown, about 37 % uptime sustained. Fix if it matters: require horizontal speed above about 8 at request time.
- **The 8 s token timeout against a very slow weapon.** A burst longer than 8 s would free a slot early; no current weapon does that (Mateba 220 rpm, a burst is at most about 3 s).
- **NPC explosions and bleed ticks bypass falloff and armor** (by design; no current NPC weapon is known to use either).
- **The `Health` script stays asleep if `MaxHealth` rises without a `Health` write.** Nothing does that today; the only writer, `applyMaxHealth`, sets Health too.
- Gun guards turn toward their target at each 10 Hz update in sight (the 2 degree skip in `_face` softens it).

Concerns carried from the reports (pre-existing or measured, not fixed):
- Squads cannot spawn while every robber is in the vault: the dispatcher's entrance lookup covers `Workspace.Bank`, not `BankVault`.
- After the squad hold ends, a non-participant left in the Bank lobby is unseen and their stars drain.
- A wanted bystander who was in the building when the session started is held and counted as seen for the first 2 minutes (review I1 narrowed it to those present at the start).
- The police damage window in Batch 2 used MaxHealth 1000; the `Tagged` total (63) is more reliable than the 53.5 HP net.

### Walking guards and Edit rigs (2026-11-20 morning)
From [[2026-11-20 Walking Bank Guards and Edit Rigs]].
- **The admin panel has cut buttons.** Left as asked until the GUI revamp; the rule is in [[GUI Rules]].
- **Weapons by gacha instead of buying** (developer: "Instead of buying, we are doing gacha"). A future batch, pickers first: currency (cash or Robux), odds shown, duplicates, pity, and the paid random item rules (`PolicyService` restrictions) if Robux is involved.
- **Edit rigs elsewhere: done** ([[2026-11-20 Edit Rigs on Every Spawner]]): criminal pads, civilian spawners and the admin GUIs. Police squads and admin-spawned NPCs stay without rigs (the developer: no fixed place).
- **A non-admin joining should get no admin GUI** now that the GUIs live in StarterGui in Edit (taken back at boot). Needs a second player to see.
- **The armed wave was not watched live:** the vault door prompt did not fire for the test player (teleported, likely not a participant). Covered by the spec and the boot read-back.
- **Guard room damage.** A player standing still in the open lost 178 HP in 10 s (2 Police guards from cover, 17 hits of 6; the near Security guard chasing, about 5 swings). Levers: `MELEE_LEASH` 20 in GuardPost, `GuardDamage` 6 in the Bank config.
- One patrolling guard was seen standing on a low object in the guard room (the path agent can jump). Cosmetic; a `PathfindingModifier` or `AgentCanJump = false` would stop it.
- Not checked: two players, a phone, NewsStation guards in a robbery.

### Smooth enemies, patrols and dropped duffels (2026-11-20 late night)
All from [[2026-11-20 Smooth Enemies Patrols and Dropped Duffels]].
- **Two-player checks:** how another player sees the crouch with a gun (priority change on the client), the action lock and a picked-up bag on the back; another player (not the owner) picking up a dropped bag. -> [[Character Movement and Animation]] [[Robbery Heists and Getaway]]
- **Bank and NewsStation drops** run the same code as SlowFoods and Gas2Go but were not run live; a bag dropped in the Bank vault is reachable only by players who get into the vault. -> [[Robbery Heists and Getaway]]
- **Patrol cost and spread:** not profiled over a long session with 24 gang NPCs, nor with several players far apart. -> [[Police and Wanted]]

### Product calls waiting
- **Tycoon compound look (2026-11-18):** the approved Flow top view (`docs/compound-views/flow-top-result.jpg`) has a fourth guard tower at the SE corner and pyramid tower roofs; the plan has three corner towers. Confirm whether the plan should add the SE tower. [[2026-11-17 Compound Floor Plan]]
- **Tycoon compound plan (2026-11-17):** share the artifact with the builder (Share menu), pick a room for the F2 spare slot, confirm Claude's layout rulings and price stages 0 to 8. [[2026-11-17 Compound Floor Plan]] -> [[Compound Floor Plan]]
- **Price curve (keep until a playtest, developer 2026-11-18).** Nebula at 8200 Spraypaint is about 4,100 Criminal kills; re-size it after the playtest (2026-09-24). Upgrade, cash-drop and Spraypaint rates are all placeholders (2026-09-16, 2026-09-23). [[FPS-Skins-Card-Preview-Hover-Feedback-Vip-On-Hold]] [[FPS-Upgrade-Damage-CashBurst-SlotAnim-Baton-Sound-SpinFix]] -> [[Spraypaint]] [[2026-11-18 Open Items Pass]]
- **APS mesh (developer, 2026-11-18):** the APS is now a machine pistol (pistol slot, mag 20, Price 650), but its mesh is a 7.02-stud rifle with rifle hold clips: pick a pistol mesh. [[FPS-AK47-Display-Fix-11-New-Guns-Integration]] -> [[Weapons and Blaster]] [[2026-11-18 Open Items Pass]]
- **Three enemy outfit pieces could not be sourced** (a hi-vis vest, a second vest, duty belts) (2026-09-16). [[FPS-Enemy-Marketplace-Outfits]]

### Needs a person in a running game
- **Press E on a quest giver** (automated input could not trigger the prompt) (2026-09-24); **click a reply** in an FPS quest conversation (2026-09-16). [[FPS-Quest-Givers-Law-Enforcement-Outfits]] [[FPS-Dialogue-Responses-Clickable-Fix]]
- **Move the five newer quest givers off their temporary line** (2026-09-16). `/setlevel` and the old F2 panel are retired (2026-11-20): the new F2 panel is listed under "Admin, animation and third person". [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]] [[2026-11-20 Admin Animations Third Person]]
- **Two-player test:** admin spectate (2026-11-20, see "Admin, animation and third person"), nameplates at distance, the View Card prompt round trip, prompts toggling while a panel is open, the overhead plate seen by a second player (2026-09-18, 2026-09-24). [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]] [[FPS-Player-Nameplates-And-LevelUp-Fix]] [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- **Persistence on a published place** (2026-09-23): saves surviving a real server restart, locking across two servers, the 30 s load deadline and the cancel when a player leaves mid-load (never run), the kick on a failed load (half verified), and someone watching the first published session. Proven so far only against the mock store. [[FPS-Persistence-Phase-3]]
- **Feel and look of the new guns**: firing, reload and aim feel, third-person hold, mid-reload look (2026-09-24); how the 2026-09-15 guns look in game. [[FPS-Eight-New-Pistols-And-Shotguns]] [[FPS-New-Guns-Magazines-And-Pump-Forends]] [[FPS-Loadout-Expansion-10-New-Guns]] [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]]
- **Eye checks:** the Knife's blade roll, third-person hold and bleed number (2026-09-21); the melee swing from a real click (2026-09-20); the melee hit effect and the level-up burst in motion, and whether the level-up light reads as a flashbang up close (2026-09-19); the death screen (2026-09-19); the new prompt in the FPS place (2026-09-19); the cash-spend burst animation (2026-09-19); the Acid skin ring (2026-09-23). [[FPS-Knife-Bleed-Melee]] [[FPS-Melee-Viewmodel-Swing]] [[FPS-Melee-Hit-And-LevelUp-VFX]] [[FPS-Death-Screen-You-Died-And-Alignment]] [[Figma-ProximityPrompt-Redesign]] [[Cash-Spend-Burst-Replaces-Price-Label]] [[FPS-Weapon-Skins-Phase-1]]
- **Ear check:** equip-sound volume (2026-09-19). [[Enemies-Climbing-Each-Other-And-Nameplate-Gap]]
- **Robbery getaway** (2026-09-20, city 2026-11-16): the Bank's road exit was walked in the city (bank-in at 201 studs); still owed: a Bank escape on foot from the vault by a person, the getaway widget seen on screen, more than one player, cash across a rejoin on a published place, tuning the 200-stud distance. [[Getaway-Distance-Replaces-Claim-Zone]] [[2026-11-16 Robbery Systems Into City]]

## Open bugs

- **Mossberg 590 and Spas 12 fore-ends do not move** (2026-09-24). Cause found 2026-11-17: neither viewmodel has a `Pump` part or `PumpJoint`; the fore-end is fused into the long meshes (Mossberg `Body` + `TrimA-D`, Spas 12 `Mesh1-4`, its fore-end inside `Mesh3`). Needs the fore-end split out as its own mesh (Blender plus a mesh upload, the developer), then a `Pump` part on a `PumpJoint`; no code or keyframe is missing. [[FPS-New-Guns-Magazines-And-Pump-Forends]] [[2026-11-17 Known Issues Pass]] -> [[Weapons and Blaster]]

## Watch list

- **The server fire-rate margin (10% under the interval) has not been tried with real mouse fire**: a laggy but honest client could have shots dropped; only synthetic timestamps were run (2026-11-15). [[2026-11-15 FPS Hardening In City]]
- **A client whose profile never restores never shows a quest completion** (`QuestsRestored` is never set). It cannot happen while a failed profile load kicks the player (2026-11-15). [[2026-11-15 FPS Hardening In City]] -> [[Quests and Dialogue]]
- **All phase 2b save tests ran on the mock store only** (quest progress, purchase, kill, turn-in); a published place is untested (2026-11-15). [[2026-11-15 FPS Hardening In City]] -> [[Persistence and Saves]]
- **8 CoreGui load-timeout errors** (`GraphQL extendSchema`, `StarterScript`, then the player list and top bar) on the client in the Task 5 run: Roblox's own modules, seen once, not in the earlier Plays (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **The late-sibling rescue in `WeaponaryShopController` is unobserved**: the race did not recur in five Plays, so only the `WaitForChild` contract backs it (2026-11-15). [[2026-11-15 FPS Systems Into City]]
- **City: colour-cycling casino parts and blinking alarm lights are now static**, because their scripts were removed; 43 scripts were disabled in place (`QuarantinedScript = true`) and most travelled into quarantine with their models, 1 remains in Workspace (2026-11-14). [[2026-11-14 City Baseline and Cleanup]]
- **RPG knockback on another player** is untested (2026-09-24). [[FPS-RPG-Gamepass-Launcher]]
- **Skin buy:** a real two-click buy ran in 2026-11-18 (Spraypaint 5000 -> 4500); the not-enough-Spraypaint refusal and the purchase strip at the new prices are still unseen (2026-09-18 to 2026-09-24). [[FPS-Spraypaint-Phase-2]] [[Revert-Global-Spraypaint-Balance]] [[FPS-Shop-Polish-And-Denied-Feedback]] [[2026-11-18 Open Items Pass]]
- **The saved Police kill counter** is now pinned by a mock-store test (Play only); three live test suites are missing from the repo (2026-09-23). [[FPS-Persistence-Phase-3]] [[2026-11-18 Open Items Pass]]
- **Stepping off a kerb costs the full ~0.5 s landing recovery** (2026-09-20); lean while crouched is slightly reduced by the landing fix; the jolt fix is confirmed as an input value, not on screen (2026-09-19). [[FPS-All-Landings-Dead-Stop]] [[FPS-Landing-Jolt-Root-Cause]]
- **The three newest enemies' health, speed and accuracy are placeholders** (2026-09-17). [[FPS-Enemy-Roster-Rework-3-New-Recruits]] [[2026-11-18 Open Items Pass]]
- **A long hotbar drag released over empty space** is untested (2026-09-13); the NPC dialogue plate hiding during a real conversation is unseen (2026-09-18). [[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]] [[FPS-Figma-UI-Bugfix-Pass-3]]
- **Robbery:** the Bank and BankVault models are heavy at 572 and 624 parts (2026-09-12). [[Performance-Optimization-And-Unification]] [[2026-11-18 Open Items Pass]]

- **From the final review of the hardening batch (2026-11-15), still open:** [[2026-11-15 FPS Hardening In City]] [[2026-11-18 Open Items Pass]]
  - The quest reach check trusts the character position, which the client owns: it stops a remote fired from across the map, not a client that also teleports. Needs server movement validation to close.
  - A refused shot leaves client ammo one lower than the server until the next reload or equip (no resync path exists).
- **Weapons (Task 3, 2026-11-18):** a 600 ms stall refuses 4 honest shots at 600 rpm (accepted loss, pinned); no spec pins the `validateShot` wiring, the press stamp or the controller's `thirdPersonAim` call (Play read-backs only); a target the shoulder camera sees but the head does not gets a shot into the wall in front of the head (by design); the Tools' hold clips (6170771161, 6170792878) fail to load in Studio, so the published hold pose is unmeasured; `EnemyTemplates.Security.Baton` has no `swingDelay`. -> [[Weapons and Blaster]] [[2026-11-18 Open Items Pass]]

## Documentation drift

None open (all three items closed 2026-11-18). [[2026-11-18 Open Items Pass]]
