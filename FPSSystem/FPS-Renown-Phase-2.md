# Change Log: Renown, Phase 2

**Date:** 2026-09-23
**Status:** All thirteen verification rows, the damage-path-clean check, all six unit suites (71/71),
and the git-scoped no-earn-path-file-modified check confirmed live in `FPS System.rbxl` (Server/Client
datamodels, one continuous Play session for rows 1-12, a Stop/Start boundary for row 13) with real
before/after numbers — see Verification below. Rows 1 and 5 measured the earn rule
(`RenownService.awardForVictim`) directly rather than the production `Eliminated` wire; that wire
(`Eliminated -> onEliminated -> awardForVictim`) was confirmed correct by source inspection, not by a
live firing of `Eliminated` itself — both `ShotResolver` call sites pass `(shooter, taggedHumanoid,
damage)`, matching `onEliminated`'s signature, and `KillStatsService` guards identically against the
same event. Two items carry over from Phase 1, unresolved for the same reasons, and one new item joins
them: the click-driven buy-strip paths (open strip, BUY, CANCEL, equipped-ring re-tween) have never
been executed by an actual click. See Notes and the final Status section.

## Summary
Phase 2 ships Renown: a second currency, earned only from NPC kills (Thug/Criminal +2, Police +5) and
level-ups (+25 per level gained), spent on four new palettes — Cobalt 250, Verdigris 350, Ember 500,
RoseGold 750 — alongside the five Free and three Vip-gated palettes Phase 1 shipped. Session-only by
design, matching Cash and Leveling: no DataStore, balance and ownership both reset to zero on rejoin.
The shop's skin row gained a coin badge on unowned Renown chips, a buy strip (PRICE / BUY / CANCEL)
that replaces the strip in place, and a gain notification. This log is the Phase 2 close-out: no new
feature code, only measurement against the spec's thirteen-row verification table, the damage-path
check, and all six unit suites.

## Cause
The earn path modifies **no existing file**. Kills already broadcast on the `Eliminated` BindableEvent
(`ServerScriptService.Blaster.Events.Eliminated`) that `KillStatsService`'s leveling counterpart
(`LevelingService`) already subscribes to for XP, and levels already publish as a plain `Level` player
attribute that `LevelingService` writes and the HUD already reads. `RenownService` adds two more
listeners onto signals the game already fires — `RenownRunner`, a one-line `Script`, is the only thing
that connects them, and nothing else requires `RenownService` — so the earn path is additive rather than
inserted into `ShotResolver`, `KillStatsService`, or `LevelingService`. Confirmed this pass by git (Step
4/Verification): the diff scoped to Phase 2's own commits touches none of those files.

PvP kills earn nothing because a player's own character carries no `Faction` attribute — the exact
mechanism `KillStatsService` and `CashService` already rely on to exclude PvP from their own economies.
`Constants.renownForFaction` returns `0` for anything that is not a recognised NPC faction string,
which includes `nil`. Without this, two players could stand in front of each other and trade kills to
print currency; `RenownConstants_Test` and `RenownService_Test` both lock the property (a `nil`,
non-string, or unrecognised faction all pay zero), and this pass re-confirmed it live against a real
player `Instance`, not a test stand-in (Verification row 5).

Two design decisions from earlier Phase 2 tasks, carried forward here because they shape what this
pass measured:
- `RenownService.onEliminated` (the guard actually wired to `Eliminated`) is split from
  `RenownService.awardForVictim` (the reward rule). A `Player` cannot be constructed with
  `Instance.new`, so no test stand-in can ever satisfy the guard's `attacker:IsA("Player")` check —
  splitting keeps production validation strict while giving the reward rule its own seam. This pass
  used that seam deliberately (see Notes) to get a clean kill-Renown reading without a confound from
  `LevelingService`, which shares the same `Eliminated` event.
- `CosmeticsService.ownsPalette`'s Renown branch, and the client's copy in `SkinRowController`, both
  gate on `palette.source == "Renown"`, not on `palette.price` being truthy. The two are equivalent for
  today's catalogue, but a future Renown palette shipped without a price would fall through a
  price-keyed check to `return true` — free for everyone, permanently. Gating on `source` fails closed
  instead. (The client's copy briefly disagreed with the server's — fixed in Task 5's review round,
  confirmed still matching this pass.)

## Changes
Shipped in earlier Phase 2 tasks, confirmed present and correct by this pass (byte-exact against this
repo's mirrors under `FPSSystem/Renown/`, checked live):
- `ReplicatedStorage.Renown.Constants` (ModuleScript, 1722 bytes) — `ATTRIBUTE = "Renown"`,
  `KILL_RENOWN = { Criminal = 2, Police = 5 }`, `LEVEL_RENOWN = 25`, `renownForFaction`,
  `ownedAttributeFor`.
- `ReplicatedStorage.Renown.Remotes.BuySkinRequest` (RemoteEvent) — the one client-to-server purchase
  entry point, taking `(paletteKey, weaponName)`.
- `ServerScriptService.Renown.Scripts.RenownService` (ModuleScript, 7741 bytes) — `balanceOf`, `grant`,
  `spend`, `onEliminated`/`awardForVictim`, `onLevelChanged`, `handleBuyRequest`, `start`.
- `ServerScriptService.Renown.Scripts.RenownRunner` (Script, 179 bytes) — the sole caller of
  `RenownService.start()`; requiring the module alone connects nothing.
- `StarterPlayer.StarterPlayerScripts.RenownHud` (LocalScript, 1084 bytes) — the Renown gain
  notification.
- `ServerStorage.UnitTest.Cases.RenownConstants_Test` (8 cases), `RenownService_Test` (20 cases),
  `RenownTier_Test` (8 cases) — the three new suites re-run below.

Existing files modified, scoped to this phase's own commit range (`9cd5d10..HEAD`, i.e. everything
after Phase 1's own change-log commit):
- `ReplicatedStorage.Cosmetics.Palettes` (4412 bytes) — extended from 8 to 12 entries: `Cobalt` (250),
  `Verdigris` (350), `Ember` (500), `RoseGold` (750), all `source = "Renown"`. `Palette` type gained an
  optional `price: number?`, present only on Renown entries. `Palettes.priceOf` added.
- `ServerScriptService.Cosmetics.Scripts.CosmeticsService` (4782 bytes) — `ownsPalette` gained the
  Renown branch described in Cause, gated on `source`, failing closed.
- `StarterPlayer.StarterPlayerScripts.SkinRowController` (10901 bytes) — a `Coin` badge on each Renown
  chip, a `BuyStrip` (sibling of `SkinRow`, identical rectangle) with PRICE/BUY/CANCEL, the purchase
  path firing `BuySkinRequest`, and `refreshLocks()` called on initial chip build (a bug this phase's
  own review caught: without it, the coin badge stayed hidden on unowned Renown chips until the first
  ownership change).

This pass created no new shipped instances and left none behind: all victim stand-ins (thrown-away
`Model`+`Humanoid` pairs) and every test balance/ownership attribute this pass wrote were either
overwritten by later steps or wiped clean by row 13's Stop/Start boundary.

## Verification
Rows 1-12 were measured live in one continuous Play session against `FPS System.rbxl` (`Roblox_Studio`
MCP, Server and Client datamodels); row 13 spans that session's end and a fresh one. Player: `SolarAudio`
(UserId `58662576`, the same UserId `LevelingService` gates its admin `/setlevel` command to).

1. **Kills award Renown — PASS.** Baseline `Level=4 Renown=75`. Called `RenownService.awardForVictim`
   directly (methodology explained in Notes) against the real player `Instance` with a freshly created
   `Model`+`Humanoid` victim: `Faction="Criminal"` (Thug's own template value) paid **Renown 75 → 77
   (+2)**; `Faction="Police"` paid **77 → 82 (+5)**. `Level` read `4` both before and after — pinned,
   no confound.
2. **Level-ups award Renown — PASS.** `player:SetAttribute("Level", 2)` from `1`, then
   `player:GetAttribute("Renown")` immediately read **`0`** (unchanged) and only after one `task.wait()`
   read **`25`** — this place's attribute-changed signals fire deferred, not synchronously (see Notes;
   this is the mechanism behind a trap already on record from Task 2). **Renown 0 → 25 (+25), exact.**
3. **Joining awards nothing — PASS.** Read at the very first query after entering Play, before any test
   action: **`Level=1 Renown=0`**. Independently reconfirmed at row 13's fresh session: `Level=1
   Renown=0` again.
4. **A multi-level jump pays per level — PASS.** From `Level=2 Renown=25`, set `Level` to `4` (a
   two-level jump) and `task.wait()`. Result: **`Level=4 Renown=75`, delta +50** — exactly `2 ×
   LEVEL_RENOWN(25)`, not a flat 25 for "a" level-up.
5. **PvP kills award nothing — PASS.** Called `awardForVictim(player, player.Character.Humanoid)` —
   the player's own **real, live Character's Humanoid**, which (per Cause) carries no `Faction`
   attribute, exactly the real PvP shape rather than a constructed stand-in. **Renown 82 → 82 (+0).**
6. **Purchase deducts and grants — PASS.** Seeded `Renown=1000` server-side, fired the real
   `BuySkinRequest:FireServer("Cobalt", "AK47")` from the **Client** datamodel. Result: **`Renown 1000 →
   750` (exact −250), `SkinOwned_Cobalt=true`, `EquippedSkin_AK47="Cobalt"`.**
7. **Insufficient funds refused — PASS.** Seeded `Renown=100`, fired
   `BuySkinRequest:FireServer("Verdigris", "AK47")` (price 350). Result: **`Renown` stayed `100`,
   `SkinOwned_Verdigris` stayed `nil`** — refused, nothing changed.
8. **Double purchase refused — PASS.** Seeded `Renown=1000`, fired
   `BuySkinRequest:FireServer("Ember", "AK47")` **twice**, back to back with no yield between the two
   `FireServer` calls. Result: **`Renown 1000 → 500`** — fell exactly once at the 500 price, not to 0 —
   and `SkinOwned_Ember=true`.
9. **A Vip key cannot be bought with Renown — PASS.** Seeded `Renown=99999` (ruling out "insufficient
   funds" as the refusal reason) with `GamepassOwned_Vip=false` confirmed. Fired
   `BuySkinRequest:FireServer("Gold", "AK47")`. Result: **`Renown` stayed `99999`,
   `GamepassOwned_Vip` stayed `false`, `EquippedSkin_AK47` stayed `"Ember"`** — refused by the `source
   == "Renown"` gate, not by balance.
10. **Forged request refused — PASS.** Seeded `Renown=0`. Fired both
    `BuySkinRequest:FireServer("RoseGold", "AK47")` (an unowned Renown palette) and
    `BuySkinRequest:FireServer("Gold", "AK47")` (the Vip key) at zero balance. Result: **`Renown` stayed
    `0`, `SkinOwned_RoseGold` stayed `nil`, `GamepassOwned_Vip` stayed `false`** — both refused.
11. **Phase 1 still passes — PASS.** Run in Play (fresh `require` cache; see Notes for why Edit mode is
    not trusted here): **`Palettes` 10/10, `SkinApplier` 14/14, `CosmeticsOwnership` 11/11** — all three
    exactly matching Phase 1's own numbers, unaffected by the four new Renown palettes or the
    `ownsPalette` Renown branch.
12. **The panel is undisturbed — PASS.** Read `AbsolutePosition`/`AbsoluteSize` for the same five
    witnesses Task 5 used (`DetailViewport`, `PriceLabel`, `ActionButton`, `EquipButton`,
    `StatsContainer`) with `BuyStrip.Visible` false → true → false, all within one session:
    ```
    DetailViewport: 296, 192.399994 | 116, 116
    PriceLabel:     308.799988, 310 | 103.200005, 11.1999998
    ActionButton:   424, 326 | 80, 21.6000004
    EquipButton:    508, 326 | 68, 21.6000004
    StatsContainer: 424, 242.799988 | 152, 76
    ```
    Byte-identical across all three states, and identical to the figures Task 5's own log recorded in
    an earlier session — consistent across sessions as well as within this one.
13. **Nothing persists — PASS.** End-of-first-session state (after rows 1-12 had written test balances
    and ownership): `Level=4 Renown=0 SkinOwned_Cobalt=true SkinOwned_Verdigris=nil SkinOwned_Ember=true
    SkinOwned_RoseGold=nil EquippedSkin_AK47="Ember"`. Stopped Play, started a fresh Play session. Same
    player, freshly joined: **`Level=1 Renown=0 SkinOwned_Cobalt=nil SkinOwned_Verdigris=nil
    SkinOwned_Ember=nil SkinOwned_RoseGold=nil EquippedSkin_AK47=nil`** — every earned and spent figure
    from the prior session is gone, matching the no-DataStore design.

**Damage path is still clean — PASS (`clean`).** Ran the spec's exact check: neither
`ServerScriptService.Blaster.Scripts.ShotResolver` nor
`ServerScriptService.Weapons.Scripts.WeaponUpgradeService`'s `Source` contains `"Renown"` or
`"Cosmetics"`.

**No existing earn-path file was modified by Phase 2 — PASS.** The brief's literal range
(`git diff --stat 96e40fd..HEAD -- FPSSystem/`) surfaces `WeaponShopService.luau`, exactly as the brief
warned it would — that file was touched by **Phase 1**, before Renown existed, since `96e40fd` predates
even Phase 1's own change-log commit (`9cd5d10`). Re-scoped to Phase 2's own range
(`git diff --stat 9cd5d10..HEAD -- FPSSystem/`, i.e. everything after Phase 1's close-out), the same
grep (`ShotResolver|KillStats|Leveling|CashService|WeaponShopService|WeaponUpgradeService`) returns
**`no earn-path file modified`**. The phase's own diff touches exactly: three new files under
`FPSSystem/Renown/` (`Constants.luau`, `RenownService.luau`, `RenownRunner.luau`) plus their two test
mirrors and `RenownHud.luau`, `Palettes.luau`, `CosmeticsService.luau`, `SkinRowController.luau`, and
one correction to `FPS-Weapon-Skins-Phase-1.md`'s own suite-count prose (a change-log fix, not code).

**Unit suites — all PASS**, run in a fresh Play-mode Server datamodel:
- `RenownConstants_Test`: **8/8**
- `RenownService_Test`: **20/20**
- `RenownTier_Test`: **8/8**
- `Palettes_Test`: **10/10**
- `SkinApplier_Test`: **14/14**
- `CosmeticsOwnership_Test`: **11/11**
- **Total: 71/71, 0 failed.**

## Notes

**Methodology for rows 1 and 5: direct calls, not the shared `Eliminated` event, and why.** The
`Eliminated` BindableEvent is not Renown's alone — `LevelingService` also listens to it and grants XP
on every kill, independent of faction, and that XP can cross a level threshold and trigger its own
Renown grant (`+25`, via `onLevelChanged`). Firing `Eliminated:Fire(player, victimHumanoid)` for a kill
test therefore risks the exact trap this project's ledger already recorded once this phase: "the
implementer's first combined kill reading showed afterPvP=30... a coincidental level-up... masqueraded
as a broken PvP rule." Rather than firing the shared event and hoping no level-up sneaks in, this pass
called `RenownService.awardForVictim` (and, for row 5's real-Faction-less case, the exact same function)
**directly** — the identical function `RenownService.start()` wires to `Eliminated` via `onEliminated`,
confirmed by reading `RenownService`'s source — against the **real, live player `Instance`** (not a
fake table, unlike the unit suite's stand-ins) with freshly created `Model`+`Humanoid` victims, and for
row 5, the player's own real Character Humanoid. `Level` was read before and after and confirmed
bit-for-bit unchanged (`4` → `4`), proving the reading is clean rather than merely unconfounded by luck.

**Discovery: attribute-changed signals fire deferred in this place, not synchronously.** Testing row 2
turned up the actual mechanism behind the trap described above, not just its symptom. Setting
`player:SetAttribute("Level", 2)` and reading `player:GetAttribute("Renown")` in the very next line,
same Luau thread, no yield, read the **unchanged** balance (`0`); only after a `task.wait()` did the
listener wired via `player:GetAttributeChangedSignal("Level")` in `RenownService.start()` run and
produce `25`. This means a script that writes `Level` and reads `Renown` back-to-back with no yield will
always see the stale figure — not a bug, but a sharp edge worth recording alongside the trap it explains.
Every Level-dependent row in this table (2, 3, 4) accounts for this with an explicit `task.wait()`
between the write and the read.

**Stale Edit-mode module cache — avoided, not re-hit.** Per the trap already on record from Phase 1 and
from this phase's own Task 4 ledger entry, `require()`-ing anything that touches `Palettes` or
`CosmeticsService` from an **Edit**-mode command can return a stale cached module after an in-session
edit. This pass ran every suite (row 11) from a **fresh Play-mode Server datamodel**, never Edit, and
used Edit-mode `execute_luau` only for read-only property/attribute/`Source`-length checks (never
`require`), which carry no such staleness risk. No false failure was hit this pass — the trap was
designed around rather than rediscovered.

**`RunUnitTest`'s unanchored substring filter — already fixed, reconfirmed here.** Task 3 this phase
found that `run("Palettes")` originally swept up `RenownPalettes_Test` too (returning 18, not Phase 1's
10) because `RunUnitTest`'s filter is a plain, unanchored `string.find`, and `"RenownPalettes_Test"`
contains `"Palettes_Test"` as a substring. The fix was a rename (`RenownPalettes_Test` →
`RenownTier_Test`), not a filter change — `RunUnitTest` itself is unmodified and the underlying design
issue (any future case name that is a superstring of an existing one will recollide) is still open,
recorded rather than fixed, same as Task 3 left it. This pass's row 11 (`Palettes` 10/10, isolated)
confirms the rename still holds.

**The coincidental level-up that looked like a broken PvP rule.** Recorded in the phase ledger from
Task 2: an early combined kill reading showed `afterPvP=30` — read straight, that looks exactly like a
Renown-earning PvP kill. It was not: a level-up happened to land inside a ~0.2s wait window between two
separate measurements, coincidentally worth the same `+25` `LEVEL_RENOWN` figure as the number being
measured. Re-isolated with `Level` snapshotted at both edges, the true reading was `Police +5, PvP +0`.
This pass's rows 1 and 5 route around the whole confound class by construction (see Methodology above)
rather than re-risking it.

**The collapsed viewport.** `ViewportSize` reported `1, 1` and `RenderStepped` fired 0 times/second for
this whole session, the same environmental trap on record from Phase 1 and from this phase's own Task
5. No GUI click could be simulated (three independent input routes were tried and failed in Task 5;
not re-attempted here, same conclusion holds) and `TweenService` cannot advance at 0 FPS. Row 12's
five-witness check does not need a click — `BuyStrip.Visible` was toggled directly by script, which is
layout-affecting regardless of whether anything renders — but the click-driven paths themselves (opening
the strip by clicking a chip, `BUY`, `CANCEL`, the equipped-ring re-tween) remain unexercised by an
actual click, for the same reason they were unexercised in Task 5. `screen_capture` was not attempted;
it is documented to return a magenta placeholder in Play mode.

**Two `PriceLabel`s now live under `DetailPanel`.** Phase 1's stats-panel `PriceLabel` sits directly
under `DetailPanel` at `y=310`; Task 5's buy-strip `PriceLabel` (this phase) sits one level deeper,
inside `BuyStrip`, at `y=372`. A recursive lookup — `DetailPanel:FindFirstChild("PriceLabel", true)` —
is ambiguous now: which one it returns depends on child/descendant iteration order, not on which one
the caller meant. Every existing call site names the exact path it wants (`detailPanel.PriceLabel` for
Phase 1's, `buyStrip.PriceLabel` for the strip's) and is unaffected, but any future recursive-search
code touching this panel needs to know both exist.

**Mirrors confirmed byte-exact.** Every file this phase touched or added was re-read live from Studio
and compared to this repo's copy under `FPSSystem/`: `Constants.luau` 1722, `RenownService.luau` 7741,
`RenownRunner.luau` 179, `RenownHud.luau` 1084, `Palettes.luau` 4412, `CosmeticsService.luau` 4782,
`SkinRowController.luau` 10901 bytes — all identical, confirming the repo mirror is not stale relative
to the shipped Studio state at the moment this log was written.

## Status
- **Confirmed live, with numbers, this pass:** all thirteen verification rows, the damage-path-clean
  check, the git-scoped no-earn-path-file-modified check, and all six unit suites (71/71 total:
  `RenownConstants` 8/8, `RenownService` 20/20, `RenownTier` 8/8, `Palettes` 10/10, `SkinApplier` 14/14,
  `CosmeticsOwnership` 11/11). Carve-out: rows 1 and 5 measured the earn rule directly
  (`RenownService.awardForVictim`), not the production wire. The `Eliminated -> onEliminated ->
  awardForVictim` wire itself was confirmed by source inspection rather than by a live firing of
  `Eliminated` — both `ShotResolver` `Fire` sites pass `(shooter, taggedHumanoid, damage)`, matching
  `onEliminated`.
- **Needs a person — the click-driven paths have never been executed.** The server side of the buy flow
  is proven by firing the real `BuySkinRequest` remote (rows 6-10 above), and the buy-strip connection
  leak fix from Task 5 was proven structurally (0 → 2 → 0 → 2, bounded regardless of how many weapons
  are switched through). But nobody has clicked a skin chip to open the strip, pressed `BUY`, pressed
  `CANCEL`, or watched the equipped-ring re-tween, in this environment or any prior task this phase —
  the collapsed viewport (`ViewportSize 1,1`, 0 `RenderStepped`/s) has made every click-simulation route
  fail since Task 5 first hit it. A person with a working Studio viewport needs to click through the
  whole buy strip once.
- **Needs a person — carried from Phase 1, still unresolved.** The Acid palette's equipped chip ring
  remains confirmed geometrically (a 2px `#CBF23C` stroke at the chip border, 3px `#171A22` gap before
  the swatch) but never visually — `screen_capture` is unusable in this environment (magenta placeholder
  in Play mode). The `Vip` game pass id is still unconfigured until the place is published to Roblox;
  the pass tile is disabled by existing handling and cannot prompt a purchase here. A person with
  publish access and a working screenshot path (or eyes on a live client) should confirm both before
  calling the cosmetics feature fully done end to end.
