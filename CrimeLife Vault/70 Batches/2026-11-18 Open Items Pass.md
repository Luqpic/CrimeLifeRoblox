---
type: batch
tags: [batch, city, open-items, heist, weapons, police, ui, gamepasses, notifications]
updated: 2026-11-18
sources: [".superpowers/sdd/2026-11-18-open-items-pass/progress.md", ".superpowers/sdd/2026-11-18-open-items-pass/open-items-closure.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-1-report.md to task-6-report.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-1-review.md to task-6-review.md", ".superpowers/sdd/2026-11-17-heist-layers/final-review.md", "git log 5ed7678..HEAD"]
---

# 2026-11-18 Open Items Pass

Six tasks on `main`, base `5ed7678`, commits `894c845`, `7c0309c`, `851c388`, `eab14de`, `8a4d8af`, `0f34b88`, `668e659`, `cd6a4a2`, `e8e9c64`, `24c44da`, plus the vault update. Every Open Items entry was worked: most closed, the rest were rewritten or stay for the developer. The heist-layers whole-branch final review ran first and its fixes are Task 2. City place `Crimelife city.rbxl` (Studio id `82377353-15c7-4338-8ef3-8af02cbb6c20`, then `de451648-6d7d-40ea-b015-720be9b8e443` after Studio restarted itself at 19:52:50).

## Asked for
The developer, two requests:
1. Reinforce the vault rules: only the vault's `roblox-*` skills (never Anthropic skills unless named), and juggle Opus and Sonnet ([[Vault Skills Only and Model Routing]], [[Model Assignment]]).
2. "Complete all the open items and finish up the branch review and fixes that was left in the crimelife vault": every entry of [[Open Items]], and the heist-layers final review with its fixes ([[2026-11-17 Heist Layers]]).

## What changed

### Controller changes
- Rules: new [[Vault Skills Only and Model Routing]], [[Model Assignment]] (Opus and Sonnet, Fable out), links in the Rules MOC, Tools MOC, [[Batch Workflow]], [[Roblox Skills]] and [[Home]]. `Documents/Roblox/CLAUDE.md`: primary place updated and the skills and model rule added.
- Studio: `ServerStorage.CityQuarantine.LooseTycoon.TycoonSpawn` set `Enabled = false` (attribute `DisabledBy`).
- Read, no change: `workspace.ModelStreamingBehavior` is not a script-readable member; the JakeDev pack and the outfit staging folder are not in the city.
- Dispatched the heist-layers whole-branch final review (Opus, read-only), then ordered the tasks by risk: police, the heist fix wave (C1 is a money exploit), weapons, UI and saves, heist tests, then gamepasses and notifications last (it reads every earlier report).

### Task 1: police and enemy AI (`894c845`)
City 265 / 265 / 0, heist 707 / 0.
- A character reset keeps the wanted stars. The server records damage in `hurtAt[player]` (a surviving `HealthChanged` drop, or a Blaster `Tagged` hit with no ForceField). A death within `RESET_DAMAGE_SECONDS` (5) of damage clears heat as before; otherwise heat stays and the search window and drain timer restart. Measured: heat 2 kept through the reset, 4 police kept through the dead window, 2 to 1 at t51, 1 to 0 at t59. Damage then reset: heat 0.
- A hole found on the way: police shots at a ForceField-protected robber fire `Tagged` for no damage and cleared heat 4 to 0. Fixed by ignoring `Tagged` under a ForceField (RED city 265 / 264 / 1, GREEN 265 / 265 / 0).
- Police search the last-seen spot only. A robber teleported about 275 studs away: before, the officers were seen again from t12 and walked toward him; after, they went to the last-seen spot (5, 3, 5, 5 studs by t8) and never saw him in t1 to t20.
- Enemies with an ally in the line: `EnemyAI:_allyInLine` holds the shot and `_sidestep` moves 4 studs (`ALLY_SIDESTEP`) across the line. A ring of 6 Offenders at 8 studs: 4 of 6 hitting (ally rays 15 and 19) before, 6 of 6 hitting after (ally rays 0, 0, 1, 0, 0, 0). Melee is exempt (7 Thugs at 3 studs, all 7 hitting both times).
- The 120 ms police step did not reproduce: builds are already one per frame, worst step 43.9 ms against a 45.1 ms no-police baseline. No change.
- Review (Sonnet): Approved, 0 Critical, 0 Important. Its Minor 1 (`hurtAt` not cleared when a damage death clears heat) was done in Task 2.

### Task 2: heist-layers final review fixes and layer leftovers (`7c0309c`)
City 267 / 267 / 0, heist 733 / 0 (RED city 265 / 2, heist 702 / 31). The review said Ready with fixes: 1 Critical, 2 Important, 4 Minor; all fixed ([[2026-11-17 Heist Layers]], section "Final review (2026-11-18)").
- **C1**: `LockedDoor._onStopRequested` asks `_canStillPick(player)` on every click (reach `MaxActivationDistance + 6`, a living character, `canAttempt`). RED `no bar given, expected 0, got 1`. Play: a solve from 221 studs is refused (screen closed, no gold). The check is in the shared lock, so the SlowFoods, Gas2Go and NewsStation doors have it too.
- **I1**: carriers cannot rob: storage safe `isBlocked`, deposit boxes `canAttempt`, broadcast desk `isBlocked` (Go Live refused with `carrying_supplies`, carriers dropped from the payees).
- **I2** (ruling "the timer's eject never moves loot"): `Forfeit:Eject` consumes a heavy carry inside the building (`ForfeitSpec`, RED `no payout, expected 0, got 1`).
- **M1** `enforceHold` on `RobbableObject` (storage safe). **M2** `maxLatencyCompensation`, deposit boxes `DepositBoxClickWindow` 0.25 s. **M3** opt-in `checkReach` on `SupplyObject` and `RobbableObject`. **M4** `LockedDoor:Forget` on leave.
- Leftovers: heavy carries get the getaway widget (ATM, gold bar) counting to 200 studs, Play readings 152 / 105 / 0 at 49.5 / 96.4 / 202.2 studs, hidden after the bank, +9000 once; Bank gold over both ledges +8000 once at 203 studs; Gas2Go ATM rebuilt from a boot copy at `Rearm`; `GiveTo` returns the pickup result; `AddBonus` and `TryAddDuffel` bounded by `MaxBagGrant` 100,000; `Crouching` clamp (not measured); `has_duffel` text; non-participant and go-live toasts; per-player state cleared (`Forget` on leave and death); `CarryState` comment; the Bank death pit now counts as damage. Ledges: J1 and J5 10 / 10 capped, `EnemyCharacter` vs `CarrierLedge` false at runtime; `CanQuery = false` is inert while `CanCollide` is on, only the collision group filters.
- Review (Sonnet): Approved, 0 Critical, 0 Important.

### Task 3: weapons and combat (`851c388`, `eab14de`, `0f34b88`)
Final city 288 / 288 / 0, heist 732 / 1 (the Zone flake, fixed in Task 5).
- Round 0: idle burst bounded by an arrival clock (12 of 12 down to 2, honest AK47 11 / 11, APS 12 / 12); melee stamps at the press; the Burst re-press dry-fire cue is 0 (Semi control 1); `RPGBlast` numbers in `Blaster.Constants`; APS is a machine pistol (Pistol, mag 20, Price 650, buys and slots).
- **A live bug found and fixed (fix round 1, `eab14de`).** In third person the controller sent the Tool muzzle as the shot origin; for 11 long guns (AK47 5.47 to RPG 7.06 studs from the root part) `validateShot`'s 5-stud origin check refused standing shots (AK47 refused, ammo 30 to 30). Ruling: third-person shots are cast from the head toward the crosshair hit point (new `Blaster.Utility.thirdPersonAim`), the tracer and flash start at the muzzle, the server check is not loosened. By a real V press, standing: AK47, Spas 12, Itacha Mag-10, Glock 18 and RPG accepted and hit a target 50 studs ahead (origin 1.40 to 1.42 studs from the root, aim 0.00 deg off); wall-corner case all 5 hit (0.02 to 0.03 studs from the crosshair point, RPG blast 0.56); first person unchanged. 12 of 12 guns now have a barrel-end muzzle and a `FlashEmitter`.
- Fix round 2 (`0f34b88`, after the review's Important I1): `ARRIVAL_SLACK` 0.1 to 0.25 s and the tolerance into `Blaster.Constants`. A 250 ms stall refuses 0 shots (2 at 0.1); a 600 ms stall refuses 4 (pinned as accepted); idle burst 3 at 600 rpm, 6 on the MP9 (12 without the arrival clock). The no-hit aim point projects 1000 studs (`CROSSHAIR_FAR_DISTANCE`): melee miss 0.30 deg off the camera look (25.92 before). RED `ShotRate` 9 / 4, `ThirdPersonAim` 6 / 2; GREEN 13 / 13, 8 / 8. Play: a third-person Knife hit from the head, AK47 accepted.
- Not real: revolver left-hand drift (0.000 while firing), shotgun shop previews (all 9 upright).
- Reviews (Sonnet): approved with one Important (the lag-stall refusal), resolved by the slack ruling.

### Task 4: UI, quests and saves (`8a4d8af`, `668e659`)
City 288 / 288 / 0, heist 733 / 0 after the fix round (282 / 282 and heist 732 / 1 before it).
- `DeathScreenGui` is `Sibling` (Global and Sibling lists equal; drawing order unchanged); quest restore prunes unknown ids and bad states; a turn-in clears then pays; refusal toasts for accept and turn-in; the `ProfileAdoption` hydrator pin; a Police kill is pinned as counted, saved and restored; `RunUnitTest` takes an exact match ("=Name"); the `LevelingService` and `Stats.Constants` comments fixed; a streamed-in prompt restyle measured (works, no change).
- Locked Spraypaint chips: "Buy for N?" on the first click, 4 s timeout; the confirm ends on timeout or a press elsewhere but the 3D preview stays (6 / 6 parts Cobalt after 4 s, label back to "500"); a confirm in the window buys once (Spraypaint 5000 to 4500).
- **Text sweep** (fix round): 392 scripts, 469,035 instances, 9 strings changed (quest "Clean work.", three Duffel Full heist toasts, vault still locked, already breached, "%s sealed", "Vault sealed", the duffel upgrade dialog, the admin panel title). Kept: nameplates "OFC. DOYLE - LV 1" (name and tag separator), "1 - N" ranges, developer-only warns.
- Review (Sonnet): Approved, 0 Critical, 0 Important.

### Task 5: heist tests and robbery leftovers (`cd6a4a2`)
City 295 / 295 / 0, heist 749 / 0 in three runs and a final run (RED city 292 / 3, heist 733 / 8).
- `Zone` sweep is deterministic (an `overlap` seam; 0 parts walked; the 3 ms wall-clock limit is gone). The `PrimaryPart` warnings went from 1,680 to 0 per run (one cause: `VaultDoorSpec` destroyed a model mid-tween; fixture-only fix, production `VaultDoor` unchanged). `CarryGetawaySpec` cleans up (0 new Workspace children after RunAll).
- Missing specs: SlowFoods key, door and safe wiring (moved into `Heist.Services.SlowFoodsKey`), NewsStation heat, alert and payout (moved into `Heist.Services.BroadcastHooks`), Seal from caught and escaped, and a two-player Gas2Go rip race (it passed first time: no bug).
- Economy: `CurrencyService.Add` bounded by `HeistShared.Config.MaxCashCredit` 1,000,000 (before: `Add(1e300)` set Cash to 9,223,372,036,854,776,000); `CashClaimVFX` waits up to 10 s for `leaderstats.Cash`; `CashService.hydrate` merges a pre-bind credit through `PreBindBase` (RED 1000, expected 1300); the new `HeistShared.GetawayMath` is used by the server and `HeistClient` (GetawaySpec on 7 positions).
- Measured: Gas2Go and NewsStation bank-ins +once at 201 studs, unchanged at 100, 150, 199 and 250; a leaver's carry drops at the spot because `CharacterRemoving` fires before `PlayerRemoving`; the 5 placed heist NPCs carry `Invulnerable` and `Witness`; the city service is named `StarterGui` again (0 scripts used the old name).
- Ruling: the NewsStation safe hold floor stays shared across the three safes (anti-brute-force, 75 vs 225 codes per session).
- Review (Sonnet): Approved, 0 Critical, 0 Important.

### Task 6: one gamepass system, one notification style (`e8e9c64`, `24c44da`)
City 311 / 311 / 0 and heist 740 / 0 at the first commit (total 1,044 to 1,051; RED city 295 / 16, heist 729 / 11); city 315 / 315 / 0 and heist 740 / 0 after the fix round.
- **Gamepasses:** one `ServerScriptService.Monetization.Scripts.PassOwnership` (the `GamepassOwned_<key>` attribute is the only record; one confirm by `UserOwnsGamePassAsync` for every pass, 3 tries 2 s apart, off the event thread; id 0 is never owned, never prompted, no web call, and an id-0 event matches nothing). `GamepassManager` is a thin adapter. Duffel x2 / x4 and `DuffelSpeedBoost` are `shop = false` entries in `Monetization.Constants.Gamepasses` (panel stays 7 tiles). Join: RPG OWNED, six COMING SOON. Spec reconciliation: 9 cases kept, 9 moved to `PassOwnership_Test`, 2 removed, 7 city and 2 heist added.
- **Notifications:** `NotificationClient` is a thin listener over the city `NotificationController` (titles "ALARM TRIGGERED" and "NOTICE", text unchanged; a wrapping message grows the card). `HeistNotificationGui` is quarantined. A real Gas2Go alarm card came through the city stack. Five heist cards plus a city toast: at most 3 on screen, x >= 800, y 513..597 at 1100 x 679 (before: up to y -137, over the meter, the duffel and the popup).
- **UI:** puzzles register with `UI.Panels` (a city panel opened mid-puzzle closes it like its X; HUD and star meter hide while one is open); `LevelingHud.placePopup` re-lays out on a viewport resize; `UIScaleController` cap 1 (every scale read back 1.000); the safe keypad releases text focus on close (it kept `Digit1` focused before).
- **Fix round 1 (`24c44da`):** the review (Sonnet, Needs fixes) found I1 `WordScrambleClient` passed `exitWordScramble` to `Panels.opened` before the local was declared (a nil closer); reproduced (B opened the shop over the scramble, 0 server exits), fixed (B closes it, 1 exit; round 2 plays; X restores the HUD) and the other puzzle closers were checked. I2 `PassOwnership.onPurchaseFinished` had no owned or in-flight guard: fixed (owned and in-flight events make no web call, one pending retry per player and pass, `PassOwnership.forget` on leave), RED 16 / 20 then green. `NotificationClient` waits bounded to 30 s; the duffel upgrade registers once.
- Studio auto-updated and restarted at 19:52:50; the place file was written at 19:52:49 with Task 6 half applied. See the save item in [[Open Items]].

## Decisions
Fifteen picker answers (2026-11-18), in short:
1. A reset keeps the wanted stars; a death from real damage still clears them.
2. Heavy carries (ATM, gold bar) get the getaway distance widget.
3. Police search the last-seen spot, no live tracking.
4. `CLAUDE.md`: primary place and the skills and model rule.
5. Quarantine: only the JakeDev pack (not in the city). Old VFX leftovers, `Dev.UI.OverheadGui`, Plot7, Plot8 and Baseplate stay.
6. Vip pass text: leave it.
7. `DeathScreenGui` renumbered and switched to Sibling.
8. Kick text: keep it and add "Please rejoin." (it already ended "Please rejoin in a moment.").
9. APS becomes a machine pistol.
10. Locked Spraypaint chips get a confirm step.
11. Lifetime cash stat: not now.
12. Spraypaint prices: keep until a playtest.
13. Unify the two gamepass systems and the two notification styles; the casino heist and the simplification pass stay later work.
14. Fall and climb animations: defaults are fine.
15. By-hand checks: one ordered checklist for the developer at the end.

Topic notes: [[Weapon and Combat Decisions]], [[Enemy and World Decisions]], [[Robbery Decisions]], [[Cosmetics and Monetisation Decisions]], [[UI and HUD Decisions]], [[Economy and Progression Decisions]], [[Vault and Documentation Decisions]]. Claude's rulings while building are in the "2026-11-18" section of [[CrimeLife Tycoon Decisions]].

## Disproved or not real
- Revolver left-hand drift: 0.000 measured while firing.
- Shotgun shop previews upside down: all 9 upright.
- One click on a locked chip never bought (0 server fires; the two-click preview has existed since 2026-09-24). The confirm label was added.
- The kick text already ended "Please rejoin in a moment." (the vault had quoted it short).
- The rejoin-bonus fix dropping a level-up: not real (the restore overwrites the level-up it would pay).
- The 120 ms police step: did not reproduce.
- A streamed-in prompt is restyled (measured).
- The JakeDev UI Animation Pack is not in the city (it was in the FPS place only).
- The outfit staging folder is not in the city.

## Verified
Closing run (fresh Play, id `de451648-6d7d-40ea-b015-720be9b8e443`): city `[SUMMARY]` 315 run, 315 passed, 0 failed, 13.379 s; heist 740 passed, 0 failed (RunAll's return value, 47 specs). At boot, server and client had 0 non-asset errors and 1 warning each (Studio's Assistant plugin notice); after both suites the server had 0 non-asset errors and 56 warnings from the persistence specs' deliberate failure paths. After stop, in Edit: 1 enabled SpawnLocation, 0 Tmp objects, 0 Workspace attributes.

After the Studio restart, 152 / 152 `CityScripts/` files matched Studio by Adler-32 at `e8e9c64`; 1 enabled SpawnLocation; the service is named `StarterGui`; `HeistNotificationGui` is gone from it; APS Pistol mag 20; 12 / 12 `FlashEmitter`s; `TycoonSpawn` disabled; 2 CarrierLedge objects; 3 / 3 SlowFoods Cashiers `Invulnerable`.

Test totals per task: Task 1 city 265, heist 707; Task 2 city 267, heist 733; Task 3 city 288, heist 732 with 1 Zone flake; Task 4 city 288, heist 733; Task 5 city 295, heist 749; Task 6 city 315, heist 740. Every task shows its RED run first in its report.

## Not verified
- By hand and two players: every heist layer played by a person, a crew racing a key, a rip or a box, a leaver mid-broadcast, the third-person hold pose (the Tools' hold clips fail to load in Studio), how the new muzzle flashes and the dry-fire cue look and sound, a real rejoin with a saved Spraypaint balance.
- Phone: the level-up popup, the heist toast against the stack at 844 x 390 (computed only; they overlap at x 544..632), the resize re-layout by eye.
- Task 6: a real purchase, a word scramble or hack registration, the keypad focus fix with a real keyboard (through the MCP keyboard the first B press still re-focused it).
- Task 1: the search and ally hold are Play-proven only; `_sidestep`'s extra ray per shot is unmeasured.
- Task 2: the storage-safe carry gate, Use Key and broadcast refusal toasts and the removed go-live toast were read in code only; the `Crouching` clamp was not measured; the death-pit read-back has no before run.
- Task 3: a target the shoulder camera sees but the head does not (the shot hits the wall in front of the head, by design); no spec pins the `validateShot` wiring, the press stamp or the `thirdPersonAim` call.
- Task 5: `CashClaimVFX` fixes are spec only (not seen in a Play); the SlowFoods gates were not each reverted to show the case fails.
- The by-hand list goes to the developer as one ordered checklist; the open lines are in [[Open Items]].

## Closed
Removed from [[Open Items]], with the reason:
- **Publish, save and ids:** save the place (2026-11-17 known issues) and save state after the heist layers: the developer saved (`stat` Nov 18 02:08:05 and 16:31:07, after those changes). Vip pass text: developer decision, leave it.
- **City map:** two spare slab plates and the Baseplate: the developer kept them.
- **City and the FPS port:** `TycoonSpawn` enabled: disabled 2026-11-18. `CLAUDE.md` names FPS System: updated.
- **Heists in the city:** prompts need the camera aimed (a test method, already in [[Camera and Input Traps]]); two gamepass systems and two notification styles (Task 6); heist `Zone` sweep and the `CurrencyBridge_Test` gaps (Task 5); the small leftovers `CurrencyService.Add` bound, `CashClaimVFX` re-find target, the bank-in readings and `StarterGUI` (Task 5), the `QuestResponsesGui` fingerprint and the `Lighting` comparison (survey artefacts); final review minors `CashClaimVFX` needing `leaderstats.Cash`, the shared NewsStation safe interval (kept by ruling), the `hydrate` overwrite, a leaver carrying a supply, and a leaver mid-confirm (Task 6, ownership lives only in the attribute). The `Persistent` Bank markers are a known cost, now in [[Robbery Heists and Getaway]].
- **Police and the wanted level:** "Saved since" (information); the search window live position (last-seen spot only); a reset after banking clears the wanted level (a reset keeps the stars); 10 officers one 120 ms step (did not reproduce); in the deferred minors, five or more heist cards reaching the meter and heist modals not in `UI.Panels` (Task 6).
- **Heist layers leftovers:** no getaway widget for heavy loot (Task 2); test gaps and the `VaultDoor` errors and `SetPrimaryPartCFrame` warnings (Task 5); per-player state not cleared everywhere (Task 2); the `NotificationClient` timeout (Task 6); the `CarryState` comment (Task 2); Task 3 Seal from the caught and escaped state (Task 5).
- **Known issues pass leftovers:** 12 guns without a third-person `FlashEmitter` (12 of 12 now); unused `Workspace.Dev.UI.OverheadGui` (kept by the developer); `RPGBlast` numbers (`Blaster.Constants`); the `WeaponShopService` one-word note and the HQ descendant counts (information).
- **Product calls:** buy confirm for locked chips (done); lifetime cash stat (not now); APS rifle or machine pistol (machine pistol); delete JakeDev pack (not in the city); delete VFX leftovers (kept); fall and climb animations (defaults fine); kicked-player message (already specific).
- **Needs a person in a running game:** confirm the duffel-move fixes and the performance pass: post-move Parts 0, A, C, D are present in the city, B is absent by design; performance Parts 0, 1, 3 present, 2 partly (test-runner tripwire), 4 not verifiable from code (table in `task-5-report.md`).
- **Open bugs:** idle burst (12 to 3 accepted at 600 rpm, slack 0.25); `Lean` and `workspace.FX` in the FPS place (the place is frozen read-only, fixed in the city 2026-11-15, no action planned).
- **Watch list:** `PromptUiController` scan (streamed-in prompt restyled); revolver drift (0.000); shotgun preview (all 9 upright); rejoin-bonus drop (not real); `RunUnitTest` substring filter (exact match "=Name"); enemies firing with an ally in the way (ally rays 16 to 1 for police in the Task 1 runs; a ring of 6 from 4 to 6 hitting); downloaded outfit folder (not in the city); Crowbar swing delay (reads 0.2 s); the robbery getaway formula existing twice (`GetawayMath`).
- **Documentation drift:** all three: `CLAUDE.md` has no session-only or `StandardEnemy` text since the 2026-11-14 rewrite; the `LevelingService` and `Stats.Constants` comments are fixed; `CityScripts/` holds the current city copies and `FPSSystem/` is the frozen FPS-place snapshot.

Rewritten rather than closed: real gamepass ids and the duffel passes (where the ids live), ModelStreamingBehavior, heaviest models, five ScreenGuis on Global, the level-up popup layout, the deferred police minors, the Gas2Go ATM, carrier ledges, edges, small, the no-automated-test item, small known-issues leftovers, the Invulnerable list, the price curve, the skin buy, the saved Police kill counter, the hardening review list.

## Left open
In [[Open Items]]: the new save item; the sections "Needs the developer", "City map", "Heists in the city", "Police and the wanted level", "Heist layers leftovers", "Known issues pass leftovers", the new "Open items pass leftovers (2026-11-18)", "Product calls waiting" (including the APS pistol mesh), "Needs a person in a running game", the open bugs (Mossberg 590 and Spas 12 fore-ends) and the watch list.

## Models and skills used
Opus: the six task implementers and the heist final review. Sonnet: the six task reviews and the vault drafts, checked by the controller. Only the vault's `roblox-*` skills were loaded (for example `roblox-npc-ai`, `roblox-security`, `roblox-testing`, `roblox-monetization`, `roblox-ui`) ([[Vault Skills Only and Model Routing]]).

## Links
[[Police and Wanted]] [[Weapons and Blaster]] [[Robbery Heists and Getaway]] [[Robbery Puzzles]] [[Gamepasses]] [[Notifications]] [[HUD and UI Shell]] [[Economy and Cash]] [[Persistence and Saves]] [[Leveling and Renown]] [[Unit Test Runner]] [[Open Items]] [[CrimeLife Tycoon Decisions]] [[2026-11-17 Heist Layers]]

## Developer checklist (by hand, in this order)

0. **Save the place** (File > Save). The file on disk is the Studio updater's 19:52:49 copy with a half-applied Task 6.

**Solo Play, keyboard and mouse**
1. **Guns.** Fire the AK47 after standing idle a few seconds (no burst should feel cut). Press V for third person and, standing still, fire the AK47, RPG and Spas 12 at something: shots land on the crosshair. Look at the third-person muzzle flash on two or three of the 12 guns that just got one (Glock 18, HK G3, Itacha Mag-10).
2. **APS.** Buy it (Pistol tab, 650) and hold it: the mesh is still a 7-stud rifle. Decide on a pistol mesh.
3. **Melee.** Knife or Baton, swings back to back: none should be swallowed.
4. **Spraypaint chip.** Click a locked colour chip, wait 5 s (the 3D preview stays, the label goes back to the price), click again ("Buy for N?"), click again to buy.
5. **Death screen.** Die once: the banner and text look right (the banner image did not load in Studio here).
6. **Quests.** Press E on a quest giver, click a reply; try a turn-in that is not ready (a short toast should say why).
7. **Heists, one by one.** SlowFoods: chase the Manager, take the key, open the storage room and its safe. Gas2Go: rip out the ATM, the getaway widget counts down to 200 studs. NewsStation: hack, Go Live, stay near the desk for 45 s. Bank: open the vault, solve a deposit box, carry the gold bar out over the two invisible carrier ledges. Also: start a lockpick and walk away (it should close); during any puzzle press B (the puzzle closes) and then press B again (the panel must open; the keypad must not keep the keyboard).
8. **Police.** Get 2 or more stars, break line of sight behind a building: officers go to where they last saw you, not to you. Then reset (Esc > Reset) with stars: the stars stay.
9. **Notifications.** A heist alarm card appears in the city's bottom-right stack, not over the star meter; the level-up popup during a heist stays clear of the heist HUD.

**Phone emulator (844 x 390)**
10. Heist HUD, star meter, the level-up popup, and a heist toast together with a city card (computed overlap at x 544 to 632).

**Two players (Start with 2)**
11. Nameplates both ways; two players in one heist racing for one deposit box (one wins, paid once); police squads with two wanted players.

**Only you can do these**
12. Paste the real gamepass ids into `ReplicatedStorage.Monetization.Constants.Gamepasses` (RPG stand-in 10904398, duffel x2 / x4, the others; id 0 means "not configured").
13. Set `Workspace.ModelStreamingBehavior` to Legacy in the Properties panel (not scriptable).
14. Asset work: icons for the eight new guns, share the "not authorized" sounds, publish the 49 viewmodel KeyframeSequences, split the Mossberg 590 and Spas 12 fore-ends into their own meshes.

NOT saved / NOT published
