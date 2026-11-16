# Known Issues Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Open Items in `Crimelife city.rbxl` that need no product decision, so what exists (city, FPS combat, heists) feels finished before police and phone work start.

**Architecture:** Small fixes in the city's existing scripts and data, each reproduced first, fixed in the owning script, and proven by a test or a measured Play. No new system.

**Tech Stack:** Luau in Roblox Studio; `Roblox_Studio` MCP; `ServerStorage.UnitTest.RunUnitTest` (city suites) and `ServerScriptService.Heist.Tests.RunAll` (heist suite); `CityMerge/transfer/export-source.luau` for exports.

**Spec:** this batch is maintenance, not a feature: its source is `CrimeLife Vault/60 Open Items/Open Items.md` and the developer's answers of 2026-11-17 (below). The tycoon is parked ("Nevermind, skip the tycoon. I want to spend more time sharpening what's outside of the tycoon right now.").

**The developer's answers (2026-11-17), binding:**
- `Workspace.HQ`: "Quarantine it" (to `ServerStorage.CityQuarantine`, not deleted).
- Weapon descriptions: "Yes, write them" (one line per weapon, editable afterwards).
- Old city prompts: "CrimeLife face everywhere" (save them `Custom`).

**Models:** Fable writes the gates and reviews. Opus builds Tasks 3 and 4. Sonnet builds Tasks 1, 2 and 5 and does the reviews.

## Global Constraints

- Target place **`Crimelife city.rbxl`**, resolved by name before every write. `FPS System.rbxl`, `Robbery System.rbxl`, `Test30.4` and OBT places are read only. Never publish. Save the city only with the developer's word for the run.
- Nothing visible is deleted: removed pieces go to `ServerStorage.CityQuarantine.<Reason>` with `OriginalPath` and `OriginalCFrame`.
- Every bug is reproduced (or shown by reading where a Play cannot reach it) before it is fixed, and the fix is in the script that owns the behaviour, not in a caller.
- Every edited script carries `CityMergeDeviation` (append with "; " where one exists), has a row in `CityMerge/after-import.md` (new section "Known issues pass 2026-11-17", Adler-32 before and after), and is exported to `CityScripts/` and checked by Adler-32.
- Baselines hold: city 18 suites **193 / 193 / 0** plus the new cases; heist suite failure set = the timing-sensitive `Zone` sweep only; exactly one enabled `SpawnLocation` in Workspace; no temporary object left.
- Numbers measured or "not recorded". Git: one commit per task named `Batch: <topic>`, by explicit path, `.DS_Store` never, nothing pushed. No key, token, UserId or account name in any file.

## Review Focus

1. **A fix that silently changes honest play:** the re-slot fix must not remove a weapon the player still has in another slot; the skin check must not lock out a skin on a weapon the player owns.
2. **Join-time state restored after the client seeds it** (the spurious Spraypaint toast is the same shape as the quest toast fixed in phase 2b): the fix must not swallow a real Spraypaint gain.
3. **Feedback under lag:** the "shot denied" cue must play only for a shot the client itself held back by its cooldown, not for every shot the server refuses.
4. **Moving `Workspace.HQ` out** must leave nothing in the city pointing at it (scripts, prompts, `ObjectValue`s).
5. **Weapon text** fits its card at 1080 x 659 and 844 x 390 without clipping.

---

### Task 1: City cleanup

**Files:** place: `Workspace.HQ`, four old prompts, `Workspace.EnemySpawns` (the Thug point), `NewsStationShared.ModelTemplates.NewsWorker`, `Heist.Services.LocationServer` (toast text), `ReplicatedStorage.SharedSystems.CashClaimVFX` (dead code).

- [ ] **Step 1: `Workspace.HQ` to quarantine.** First list every reference to it (`script_grep` for `workspace.HQ`, `Workspace.HQ`, `"HQ"`; every `ObjectValue` pointing into it). Move it to `ServerStorage.CityQuarantine.WorkspaceHQ` with `OriginalPath` / `OriginalCFrame`. Check: a Play logs none of its 2 to 3 server errors; client descendants at the spawn at 25 s before and after recorded.
- [ ] **Step 2: Old prompts.** Every ProximityPrompt under `Workspace.Map` saved `Style = Default` is saved `Custom` (expected 4: 3 warehouse buttons, the casino button). Count before and after.
- [ ] **Step 3: The stuck Thug.** The Thug point at (169, 1.5, 2498.75) reaches the short east road end where a Thug stuck at about (215, 5, 2485). Move the point (not the enemy code) to a road spot that keeps the phase 2a placement rules (180 studs or more from the spawn, 120 from every plot, 130 from the quest-giver row, 60 from other points and robbery buildings, on a road, weakest type nearest; `CityMerge/placement.md`) and has open road for its patrol radius. Check: a Play of 3 minutes, every Thug's position sampled every 10 s; none stays within 2 studs of the same spot for 30 s.
- [ ] **Step 4: NewsStation workers.** Tag `ReplicatedStorage.NewsStationShared.ModelTemplates.NewsWorker` `Invulnerable`, as the clerks and cashiers were. Then list every other `Humanoid` under the imported heist templates and Workspace roots that is neither tagged `Invulnerable` nor a Bank guard; report them (do not tag without the controller). Check: in a Play, `canDamageHumanoid` false for a spawned NewsWorker.
- [ ] **Step 5: Removal toast.** `LocationServer`'s `CharacterRemoving` path tells the player the character was removed, not "You died before banking". Add a cause rather than reusing `died`; the `LocationServerSpec` removal case asserts the new cause.
- [ ] **Step 6: `CashClaimVFX` leftovers.** Remove the unused frame constants, `formatWithCommas` if unused, the empty `_render` and its callers, and `self._gui`; `CashClaimVFXSpec` still 13 / 0.
- [ ] **Step 7: Suites, commit.** Both suites as the baselines. `git commit -m "Batch: city cleanup, HQ copy quarantined"`.

---

### Task 2: Two exploits and the join-time toast

**Files:** `ServerScriptService.Weapons.Scripts.WeaponShopService` (re-slot), `ServerScriptService.Cosmetics.Scripts.CosmeticsService` and `ServerScriptService.Spraypaint.Scripts.SpraypaintService` (skins), `StarterPlayerScripts.SpraypaintHud` (toast); new cases in `ServerStorage.UnitTest.Cases`.

Skills to load: `roblox-security`, `roblox-testing`.

- [ ] **Step 1: Re-slot copy.** Reproduce in Play: hold the AK47, `SetLoadoutSlotRequest("AK47", 3)` while it is in slot 1; count AK47 Tools in Backpack and character (expected bug: 2). Fix in `WeaponShopService` so moving a weapon between slots leaves exactly one Tool (the held one keeps its ammo, or the new one replaces it: whichever keeps the magazine honest, stated in the report). Case `ReslotCopy_Test` if the logic can be reached as a function, else a Play check repeated after the fix: 1 Tool, equip state kept.
- [ ] **Step 2: Skin for an unowned weapon.** `EquipSkinRequest` and `BuySkinRequest` refuse a weapon the player does not own (`WeaponOwned_<name>` attribute, as `UpgradeRequest` does). Cases in `CosmeticsOwnership_Test` (or a new `SkinOwnership_Test`): owned weapon accepted, unowned refused, nothing stored, nothing charged.
- [ ] **Step 3: Spraypaint join toast.** Reproduce: join with a saved Spraypaint balance (mock store) and count toasts at join. Fix with the phase 2b pattern (`QuestsRestored`): the server marks the player once Spraypaint is restored, and the HUD treats changes before the mark as a seed. A real gain after the mark still toasts once. Check by the same Play, before and after.
- [ ] **Step 4: Suites, commit.** `git commit -m "Batch: re-slot copy, skin ownership, join toast"`.

---

### Task 3: Weapons

**Files:** `ServerStorage.Weapons` Tools (attributes, attachments), the Blaster client (`ReplicatedStorage.Blaster` controllers: cooldown feedback, ammo HUD), the RPG's explosion code, the shop card for gamepass weapons.

Skills to load: `roblox-game-systems`, `roblox-audio`, `roblox-ui`.

- [ ] **Step 1: Descriptions.** Write one `Description` attribute per Tool in `ServerStorage.Weapons` (38): one line, at most 60 characters, factual (role, fire mode, what it is good for), in the shop's tone, no brand names beyond the weapon's own name. List them all in the report. Check the card renders each without clipping at 1080 x 659 and 844 x 390 (the longest three measured by `TextBounds`).
- [ ] **Step 2: Shotgun reload HUD.** The ammo HUD shows a static "reloading" through a shell-by-shell reload. It shows the shell count rising (or the HUD's own reloading state for magazine weapons, unchanged). Check in Play with the Benelli M4 and Mossberg 590: the readout changes with each shell.
- [ ] **Step 3: "Shot denied" cue.** When the client's own cooldown holds a shot back, play a short dry-fire cue (an existing sound if one fits; the report names it) at most once per held trigger press. No cue for shots the server refuses (Review Focus 3). Check: firing faster than the rate of fire plays the cue; normal fire plays none.
- [ ] **Step 4: RPG.** The impact plays only the RPG's own sound: the engine's explosion bang is silenced (an `Explosion` with no sound, or the blast done without one). The shop grid card stops reading "GAMEPASS" once the pass is owned (shows the owned state the other cards use). Check both in Play (ownership through the existing test seam).
- [ ] **Step 5: Third-person muzzles.** On the Glock 17, Benelli M4 and Spas 12, `MuzzleAttachment` sits at the stock end. Move each to the barrel's open end (measure the barrel mesh's extent along the weapon's forward axis). Check: the muzzle flash and tracer start within 0.3 stud of the barrel end in third person (world positions read in Play).
- [ ] **Step 6: Pump fore-ends.** Find why the Mossberg 590 and Spas 12 fore-ends do not move (the pump animation, the joint, or a missing `Motor6D`). Fix if the cause is a missing or misnamed joint or keyframe target; if it needs a new animation upload, report it and stop (uploads need the developer).
- [ ] **Step 7: Suites, commit.** `git commit -m "Batch: weapon descriptions, reload readout, dry fire, RPG, muzzles"`.

---

### Task 4: Movement and HUD

Skills to load: `roblox-characters-animation`, `roblox-ui`.

- [ ] **Step 1: `WalkSpeed` 20 / 25.83.** Use superpowers:systematic-debugging. Find every writer of `WalkSpeed` (`script_grep`), log each write with its source in a Play while landing from a jump and sprinting, and name the writer of 25.83. Fix the root cause in that writer; if the swing is intended (a sprint ramp), document it and change nothing.
- [ ] **Step 2: Level-up popup overlaps.** The level-up popup overlaps the getaway widget and the toast at 1080 x 659, and the getaway, duffel and card at 844 x 390. Move the popup (or the heist widgets) by the smallest offset that clears every pair at both sizes; read `AbsolutePosition` / `AbsoluteSize` live at 1080 x 659, computed at 844 x 390 (say which).
- [ ] **Step 3: Two names over a player.** `IndicatorClient`'s `OverheadGui` and `PlayerNameplates` may both draw a name over another player. Show it by reading both scripts (a second player cannot be started from the tools); if both draw for the same player, keep one (the newer `PlayerNameplates`) and turn the other off for players, keeping what it does for NPCs. Report what a person must check with two players.
- [ ] **Step 4: Suites, commit.** `git commit -m "Batch: walk speed, level-up popup, nameplates"`.

---

### Task 5: Closing run and vault

- [ ] **Step 1: Five Plays** from the city spawn: 0 client and 0 server script errors other than asset lines; both suites; a purchase, a kill, a quest turn-in and a SlowFoods bank-in still work.
- [ ] **Step 2: Vault** per `Vault Conventions.md`: batch note `70 Batches/2026-11-17 Known Issues Pass.md`, Batch Log, the touched `20 Systems` notes (Weapons and Blaster, Spraypaint, Cosmetics and Skins, Movement and Stamina, Nameplates and Billboards, Enemies and Spawner, City Map and Plots, Robbery Heists and Getaway), Open Items (each closed item removed and named in the batch note; anything found and left open added), Decisions (the developer's three answers quoted, Claude's rulings).
- [ ] **Step 3: Commit.** `git commit -m "Batch: known issues pass"`.

---

## Not in this plan

- Police and a wanted level: designed next, with the developer.
- Phone performance: after police, with readings from the developer's phone.
- Re-placing enemies and quest givers by eye, real gamepass ids, asset sharing, animation uploads, a casino or warehouse heist, unifying the two notification styles and the two gamepass systems: the developer's or later work.
