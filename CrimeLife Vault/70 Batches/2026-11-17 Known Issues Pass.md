---
type: batch
tags: [batch, city, weapons, hud, cleanup]
updated: 2026-11-17
sources: [".superpowers/sdd/2026-11-17-known-issues-pass/progress.md", ".superpowers/sdd/2026-11-17-known-issues-pass/task-1-report.md to task-5-report.md", "docs/superpowers/plans/2026-11-17-known-issues-pass.md", "CityMerge/after-import.md (section Known issues pass 2026-11-17)", "CityMerge/known-issues/weapons.md"]
---

# 2026-11-17 Known Issues Pass

Five tasks, commits `c3a27c9..499d790` plus this note: city cleanup, re-slot copy and skin ownership and the join toast, weapons, movement and HUD, and the closing run.

## Asked for
Close the [[Open Items]] that need no product decision, so what exists (city, FPS combat, heists) feels finished before police tuning and phone work. The developer's answers are in [[CrimeLife Tycoon Decisions]]: quarantine `Workspace.HQ`, write the weapon descriptions, give the old city prompts the FPS face, skip the tycoon for now.

## What changed
**Task 1, city cleanup** (`2a96157`)
- `Workspace.HQ` (58,277 descendants, 23 scripts, a copy of `ServerStorage.HQ`) moved to `ServerStorage.CityQuarantine.WorkspaceHQ.HQ` with `OriginalPath`, `OriginalCFrame`, `Reason`. Its 3 server errors per Play (`opendoor`, `Bar`) are gone. Client Workspace descendants read 100,256 before and 73,236 after (at about 60 s and 25 s of client time: not like for like).
- The four prompts left in `Workspace.Map` (WareHouseRobbery Button1 to 3, CasinoMain.OpenBTN) saved `Custom`: Default 4, Custom 0 before; Default 0, Custom 4 after.
- `NewsWorker` template tags: Witness before; Invulnerable and Witness after. In Play the 2 spawned NewsWorkers carry both and `canDamageHumanoid` is false.
- `LocationServer._onCharacterRemoving` calls `forfeit:Die(..., "removed")`; the toast reads "Your character was removed. Bag lost." One added expect in `LocationServerSpec`.
- `CashClaimVFX` lost its unused frame constants, `formatWithCommas`, the empty `_render` and its 5 callers (13 / 0).
- The stuck Thug: not changed (see Decisions and Disproved).

**Task 2, shop and skins** (`caef49e`)
- Re-slotting a held weapon: before, 1 AK47 Tool became 2 (the equip branch looked only in the Backpack). Now `WeaponShopService` grants only when `findLiveTool` finds none in the Backpack or character: 1 Tool, the same instance, still held, its ammo kept.
- A skin for a weapon the player does not own: `CosmeticsService.ownsWeapon` refuses it before any write; `SpraypaintService.handleBuySkinRequest` refuses before it charges. RED 262 run, 259 passed, 3 failed with the gate off; GREEN 262 / 262.
- Spraypaint join toast: before, 1 card per HUD at join (0 to 300, then 300 to 900 as +600). `SpraypaintService.hydrate` now sets `SpraypaintRestored` last and `SpraypaintHud` re-seeds at every change until it is true: 0 cards at join, then +10 as 1 per HUD.

**Task 3, weapons** (`6ab7127`)
- `Description` on all 38 Tools (longest 53 characters); `"Description"` added to `WeaponShopService.CATALOG_ATTRIBUTES` so the card can show it (the catalogue copied only listed attributes). Measured by `TextBounds` on the detail card at the live scale 0.8763, at 0.8603 and at the computed phone scale 0.6321: one line each, 0 of 38 over the box.
- Shotgun readout: Benelli M4 read `-` for 2.62 s, now counts 0, 1 ... 7 shell by shell (Mossberg 590 up to 8); Glock 17 keeps its dashes until 1.37 s.
- Dry-fire cue (`GuiController.DryFire`, the `MagIn` click `rbxassetid://17682720424`, Volume 0.6): a press held back by the client's fire-rate cooldown plays it, once per press, not for Auto or melee. Glock 17 slow presses 5 shots 0 cues, pairs 0.04 s apart 4 shots 4 cues; Benelli M4 pairs 0.2 s apart 3 shots 3 cues; AK47 Auto 0 cues.
- RPG: the blast is a clone of `Blaster.Objects.RPGBlast` (a particle burst) instead of an engine `Explosion` (no property silences its bang): server and client saw 0 `Explosion`, 1 `RPGBlast`, 1 `Impact` sound. Damage and `Eliminated` credit unchanged. The RPG grid card reads OWNED (owned colour) once the pass is owned.
- Muzzles (Body-local `MuzzleAttachment`): Glock 17 (0.822, 0, 0) to (-0.89, 0.47, 0); Benelli M4 (1.517, 0, 0) to (-3.16, 0.48, 0); Spas 12 (3.566, 0, 0) to (-3.566, 0.28, 0). Before, flash origin was 1.776, 4.702 and 7.137 studs off the barrel end; after, tracer start and flash origin are 0.000 from it (measurement error about 0.05). Each got a `FlashEmitter`.
- Pump fore-ends: stopped at the cause (below).

**Task 4, movement and HUD** (`499d790`)
- `WalkSpeed` 20 / 25.83: `Animate2`'s backward clamp (line 419) fired on a velocity test while the player pressed into a wall, and the `move()` ramp (line 587, 20 + 50 x 0.1167 = 25.83) lifted it again. It now keys on input (`isInputBackwards`). After: 115 frames with a backward velocity, WalkSpeed never dropped from 38 outside a landing window; walking backwards still clamps to 20.
- Level-up popup (`LevelingHud.placePopup`): see [[HUD and UI Shell]]. At 1100 x 679 it overlapped the getaway widget (240 x 34) and the toast (360 x 48); now it overlaps nothing.
- Two names over a player: none. `IndicatorClient` draws only damage numbers; only `PlayerNameplates` draws a name. No change.

**Task 5, this note and the vault**: `20 Systems` notes (Weapons and Blaster, Weapon Shop and Upgrades, Spraypaint, Cosmetics and Skins, Movement and Stamina, Nameplates and Billboards, Enemies and Spawner, City Map and Plots, Robbery Heists and Getaway, HUD and UI Shell, Police and Wanted), Open Items, Decisions, Batch Log.

## Decisions
The developer's three answers and each ruling are in [[CrimeLife Tycoon Decisions]]. In short: NewsWorker `Invulnerable` (witnessed-hurt heat from guards only); the Thug point not moved; the level-up popup placed by Option A plus B1; the star meter counted in the overlap set; every NPC overhead kept; no save.

## Verified
**Five Plays from the city spawn** (each read at 25 s of game time, server then client; warnings and errors counted; an asset line contains `Failed to load`, `ContentId` or `asset`):

| Play | server non-asset | server asset | client non-asset | client asset |
|---|---|---|---|---|
| 1 | 0 | 152 | 0 | 317 |
| 2 | 0 | 153 | 0 | 315 |
| 3 | 0 | 158 | 0 | 327 |
| 4 | 0 | 146 | 0 | 326 |
| 5 | 0 | 159 | 0 | 320 |

Play 5 also had 1 enabled `SpawnLocation`. The three `Workspace.HQ` server lines of the police closing run are gone.

**Suites** (in Play 5): city `[SUMMARY] 262 run, 262 passed, 0 failed, 10.134s`; heist `TOTAL: 620 passed, 1 failed` (only `Zone` "the real occupancy sweep", 3.55 ms). Task 4's own run had the heist suite at 621 / 0 (the sweep passed that time).

**The four flows, in a later Play** (player under an invisible `ForceField`):
- Purchase: client `BuyRequest("AKM")`, Cash 500 to 25 (price 475), `WeaponOwned_AKM` true.
- Kill: AKM given to a loadout slot, a real `Blaster.Remotes.Shoot` from the client at a Smuggler (100 hp set to 40, six studs away): 4 shots, enemy dead; `CriminalKills` 0 to 1, XP 15, Spraypaint 2.
- Quest turn-in: client `AcceptQuestRequest("Level1Thugs")` at the giver, ten `Eliminated` events fired on temporary Models with `EnemyTemplate = "Thug"` (the phase 3 method), state `ReadyToTurnIn`, client `TurnInQuestRequest`: state cleared, completions 1, Cash 100 to 625 (+500 reward, +25 level-up), level 4 to 5.
- SlowFoods bank-in with police in the game: pivot into the zone, Crowbar equipped, then 1 star (heat 1) and 2 Police; one register robbed through its real prompt (camera aimed, `InputHoldBegin`, 8.0 s, `Triggered` fired); stepping out along x = 96.8 from z = 1778.8 in 55-stud steps: Cash 500 until the 100 reading, 2,500 at the 150 reading (+2,000); heat 1 and stars 1 stayed. All four ran for real, except that the kill used a set health value and the turn-in's ten kills were fired events, not ten enemies shot.
- After: 0 `Tmp` objects and no Workspace attribute in Edit; 1 enabled `SpawnLocation`.

The exports in `CityScripts/` match Studio by Adler-32 (checked task by task; the rows are in `CityMerge/after-import.md`, section "Known issues pass 2026-11-17"; the instance edits in `CityMerge/known-issues/weapons.md`).

## Not verified
- Never seen by eye: the dry-fire click, the RPG burst, the new muzzle flashes, the level-up popup at any size (all read back as numbers).
- 1080 x 659 and 844 x 390 positions are computed from the layout; the phone branch never ran live.
- The Spraypaint join was emulated with an attribute sequence (Studio cannot rejoin with a saved balance without a mock store).
- Two players, a phone, a published place.
- The bank-in threshold: in the police closing run SlowFoods banked at the 201 reading; here it banked by the 150 reading, stepping from a different point (z = 1778.8, the exit-spawn row of `CityMerge/phase3/locations.md`, not the true anchor). Not reconciled.
- This run's own mistake, no effect on the place: an early probe stepped the character to a z with no ground, the character fell out of the world and lost its root part (a respawn and a Play restart followed), and the SlowFoods cooldown made a second robbery in that Play impossible.

## Disproved
- "One Thug is stuck at (215, 5, 2485)": not reproduced in a 185 s Play (five Thugs sampled every 10 s, none within 2 studs for 30 s). The 2026-11-15 record stays, the item stays open.
- "`IndicatorClient`'s `OverheadGui` and `PlayerNameplates` may both draw a name": `IndicatorClient` never clones `OverheadGui` in the city.
- "The `WalkSpeed` swing is a sprint ramp": it is the backward clamp reacting to collision velocity.

## Left open
Closed here and removed from [[Open Items]]: the fix wave `Batch: known issues pass fixes` (`placePopup` no longer needs the duffel on desktop, `restoreEquippedWeapons` uses `findLiveTool`, the stale `handleBuySkinRequest` comment and its unreachable type check, the `CashClaimVFX` orphaned comment); `Workspace.HQ`; the 26 leftover prompts; the removal toast; the HUD overlaps (the level-up popup against the getaway widget, the toast and the duffel and card); the CashClaimVFX dead leftovers; NewsStation workers damageable for city XP; police squads fill slowly (closed by [[2026-11-17 Police Slow Fill]], removed now); the re-slot copy; the unowned skin choice; the third-person muzzles; the RPG bang and GAMEPASS card; "no shot denied feedback"; the static "reloading" readout; the double name; the empty `Description`; the Spraypaint join toast; the `WalkSpeed` swing.

New or kept open (in [[Open Items]]):
- Pump fore-ends need a mesh split and an upload (the developer).
- 12 guns have no third-person `FlashEmitter`.
- The Thug that did not reproduce (kept, with the 185 s measurement).
- Unused `Workspace.Dev.UI.OverheadGui`.
- Landing-window speed jitter and the 180-degree `AutoRotate` clamp.
- The phone popup layout, computed only; `placePopup` does not re-lay out on resize and was not measured on a very wide viewport.
- Small leftovers: the Burst re-press cue, `RPGBlast` inline numbers, `WeaponShopService` touched for one word, the `GamepassOwned_RPG` flicker, Humanoids without `Invulnerable`, no automated test for six of the fixes.
- Save state: the place file was last written Nov 17 15:04 (`stat`), after Task 2's commit and before Task 3's, and after the Studio restart a read-back found police, the slow-fill fix and Tasks 1 and 2 present, so they are on disk; only Task 3 (38 `Description`s, three muzzles, `GuiController.DryFire`, `Blaster.Objects.RPGBlast`, the edited Blaster and shop scripts), Task 4 (`Animate2`, `LevelingHud`) and the fix wave are unsaved. Nothing was saved by Claude in this run (no word to save).
- The HQ client-descendant counts (100,256 before, 73,236 after) are not like for like: they were read at about 60 s and 25 s of client time.

## Links
[[Open Items]] [[CrimeLife Tycoon Decisions]] [[Weapons and Blaster]] [[Weapon Shop and Upgrades]] [[HUD and UI Shell]] [[Police and Wanted]] [[City Map and Plots]] [[Movement and Stamina]] [[2026-11-17 Police Slow Fill]]

NOT saved / NOT published
