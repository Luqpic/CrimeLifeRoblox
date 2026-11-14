# Task 8 report — play-mode verification

**Status: PASS.** The distance getaway works end to end at all four locations, and the Bank's
inside-the-building gate holds: a full 15,000 duffel sat in the vault at **313.4 studs** horizontally
from the Bank anchor for ~96 seconds (~960 heartbeat ticks) and paid out **nothing**.

Studio instance `009e370d-dae2-402e-88e9-379b254ec753` ("Robbery System", placeId 130328863401144).
One Play session, one player (`SolarAudio`, UserId 58662576, cash started at 0 — DataStore API access
is off in Studio so there was no persisted balance). Place left in **Edit mode**. No script, world
instance or place setting was modified.

---

## Method — what was real and what was substituted

Read this before the tables; it qualifies every number in them.

**Real (no substitution):**

- **Every robbery trigger** was the genuine server-side path: a `Tool` tagged `HeistConfig.Tags.Weapon`
  (`StarterPack.PlaceholderPistol_TODO_ReplaceWithRealAsset`) equipped while the player stood inside
  the interior zone. Two entry points were exercised — `Humanoid:EquipTool` while already inside
  (SlowFoods, Bank) and walking/arriving into the zone with the weapon already equipped (Gas2Go,
  NewsStation). No `TryStart` was ever called directly.
- **Every bag fill** was genuine. The non-Bank bags were filled by holding real `ProximityPrompt`s
  via `prompt:InputHoldBegin()` / `InputHoldEnd()` from the **Client** datamodel — i.e. exactly what
  holding `E` does, through `RobbableObject.Triggered` → `bank:TryAddDuffel`. Each hold ran its full
  8-second `HoldDuration`. The Bank bag was filled by the real 10 Hz heartbeat's
  `bank:Accrue(player, dt)` while standing in the real `VaultZone`.
- **The Bank's full gauntlet was played**: Terminal 1 → Terminal 2 → "Attach C4" (5 s hold) →
  detonation countdown → "Go to Vault" prompt on `TeleporterBankA`. That transit is the **only**
  code path that calls `bank:AddParticipant` for the Bank (`Teleporter:118`), so participation was
  earned, not injected. The return leg used the real "Return to Lobby" prompt on `TeleporterBankB`.
- **Every outcome was read from real state**: `player.leaderstats.Cash.Value` for payout, the live
  `ZoneOccupancy` / `DuffelState` / `Toast` / `RobberySuccess` / `HeistState` remotes observed from
  the **Client** datamodel, and the actual HUD `GuiObject` properties (`Visible`, `Image`, the fill
  bar's `Size.X.Scale`, the studs `TextLabel.Text`).
- **Gas2Go and NewsStation escapes were genuinely walked** — `PathfindingService:ComputeAsync` plus
  `Humanoid:MoveTo` along every waypoint, from inside the premises out past 200 studs. No teleport.

**Substituted, and labelled as such:**

- **Teleported** (`Model:PivotTo`), not walked: getting between distant map locations; getting from
  the teleporter-B arrival point through the underground gauntlet into `VaultZone`; the dense Bank
  inside-the-building sample points; the SlowFoods escape sampling; and the Bank's outbound escape
  sampling (0 → 204 studs). Teleporting is a gameplay action, not an edit, but it is not walking, and
  it is called out in the tables below.
- **Walkability of the SlowFoods and Bank escapes was proved separately** (Step 4) by actually
  pathfinding-walking both routes end to end, rather than during the scored run.
- `screen_capture` was **not** used. It returns a uniform magenta frame in Play mode on this place,
  as three prior agents found. All visual claims below are property read-backs, not screenshots.

**Not simulated at all:** no injected remote payload, no direct call into `Getaway`, `LocationServer`
or `BankInstance`, no forced `Cash` write, no god-mode, no health manipulation.

---

## Step 1 + Step 2 — per-location results

| Location | Triggered? | Bag filled? | Fill method | Inside-gate held? | hDist at payout | Cash delta | Escape |
|---|---|---|---|---|---|---|---|
| **SlowFoods** | Yes — weapon equipped in `RestaurantZone` | **4,000 / 4,000** (cap) | 2 register prompts, 8 s holds | Yes — nothing at 199.0 | **206.0** | 0 → **4,000** | teleport steps |
| **Gas2Go** | Yes — entered `Gas2GoZone` weapon-equipped | **4,000 / 4,000** (cap) | 2 register prompts, 8 s holds | Yes | **204.0** | 4,000 → **8,000** | **walked** (pathfinding, 13 s) |
| **NewsStation** | Yes — entered `NewsroomZone` weapon-equipped | 7,000 / 10,000 | 2 registers + 1 ATM, 8 s holds | Yes | **203.9** | 8,000 → **15,000** | **walked** (pathfinding, 16 s) |
| **Bank** | Yes — weapon equipped in `BankZone` (Lobby) | **15,000 / 15,000** (cap), then 6,575 on the second attempt | real heartbeat accrual in `VaultZone` | **Yes — see below** | **204.0** | 15,000 → **21,575** | teleport steps |

NewsStation was filled to 7,000 of its 10,000 cap rather than to cap: the remaining 3,000 sits behind
the three `Safe` models, which need the `SafeCode` / `MasterComputer` minigame. That is a
deliberate scope call, not a failure — a 7,000 bag exercises the payout path identically.

### Widget behaviour (Step 1's HUD requirements)

All four requirements confirmed by property read-back, on all four locations:

- **Appears only outside.** `getawayWidget.Visible` was `false` at every inside-the-building sample
  and flipped to `true` on the first sample outside.
- **Counts down.** SlowFoods read 160 → 110 → 50 → 10 → 1 studs; Gas2Go 148 → 133 → … → 0;
  NewsStation 123 → … → 0; Bank 110 → 50 → 10 → 4 → 2.
- **Bar fills.** `fill.Size.X.Scale` tracked progress covered: 0.195 → 0.447 → 0.747 → 0.947 → 0.995
  at SlowFoods, and equivalently elsewhere, reaching 0.999 at 1 stud remaining.
- **Gold near-complete bake at the last 50 studs.** The root `ImageLabel.Image` swapped from
  `rbxassetid://140089160384517` (normal) to `rbxassetid://132824223302657` (near) at exactly the
  `remaining <= escapeDistance * 0.25` boundary. Observed crossing points: SlowFoods between
  studs=110 and studs=50 (the 50 sample already showed the gold bake); Gas2Go the sample reading
  studs=50 was gold while studs=67 was not; NewsStation between 54 and 42; Bank between 110 and 50.
- **Toast + cash burst.** `Toast: "Banked N Cash."` and `RobberySuccess` fired on every one of the
  four payouts. No `CashClaimVFX` runtime error appeared in the console during play (its 12 unit-test
  failures are a pre-existing test-harness issue, not a live one).

### Step 2 — the Bank regression, in detail

This is the check the whole design exists for. The Bank's `VaultZone` centre is **314.0 studs**
horizontally from `HeistMarkers.StatusBillboardAnchor` — 114 studs beyond `EscapeDistance`.

The bag was accrued by the real heartbeat while standing in the vault, and `leaderstats.Cash.Value`
was polled throughout. Cash was 15,000 on entering the vault and stayed there.

**Accrual phase — stationary in `VaultZone` at hDist 313.4, `inside=true` the whole time:**

| t | duffel | cash | t | duffel | cash |
|---|---|---|---|---|---|
| 6 s | 2,062 | 15,000 | 60 s | 9,262 | 15,000 |
| 12 s | 2,868 | 15,000 | 66 s | 11,098 | 15,000 |
| 18 s | 3,649 | 15,000 | 72 s | 11,889 | 15,000 |
| 24 s | 4,469 | 15,000 | 78 s | 12,687 | 15,000 |
| 30 s | 5,266 | 15,000 | 84 s | 13,494 | 15,000 |
| 36 s | 6,055 | 15,000 | 90 s | 14,287 | 15,000 |
| 42 s | 6,864 | 15,000 | **96 s** | **15,000 (cap)** | **15,000** |
| 48 s | 7,660 | 15,000 | | | |
| 54 s | 8,467 | 15,000 | | | |

At cap the server sent `Toast: "Duffel Full — get clear of the building to bank it."` — and still no
payout. That is ~96 seconds at 10 Hz, i.e. roughly **960 consecutive `Getaway:Step` calls** with a
full bag 113 studs past `EscapeDistance`, every one of them correctly refusing.

**Dense outward sample, full 15,000 bag, teleported between points:**

| Sample point | actual position | hDist from anchor | `inside` | duffel | cash |
|---|---|---|---|---|---|
| `VaultZone` | 322, 51, 146 | **313.4** | true | 15,000 | 15,000 |
| `VaultZone` edge | 310, 51, 133 | **296.3** | true | 15,000 | 15,000 |
| `BankVaultZone3` | 322, 51, 120 | **290.6** | true | 15,000 | 15,000 |
| `BankVaultZone3` b | 300, 3, 62 | **229.6** | true | 15,000 | 15,000 |
| (death pit) | 320, 22, 52 | 233.0 | true→false | 0 | 15,000 |

Four inside-the-building samples, **all above 200 studs**, all with a full bag, and cash never moved.
The 229.6 sample is the sharpest single data point: comfortably past `EscapeDistance`, unambiguously
inside, zero payout.

**I fell into the `DeathVolume` at (320, 22, 52) partway through the sample** — `hp` hit 0, the server
logged `[Forfeit] run 1: SolarAudio forfeited 15000 (death_pit)`, the client got
`Toast: "You fell. Bag lost."`, and **cash stayed at 15,000**. That was not planned, but it is a clean
bonus result: a 15,000 bag destroyed on the death path with no credit.

**Then the payout half, on the same still-Active session.** I respawned, re-transited Teleporter A
(genuine prompt, re-joining the roster), accrued a fresh bag in the vault, and left via the genuine
"Return to Lobby" prompt on Teleporter B:

| Sample | position | hDist | `inside` | cash | widget | studs | fill |
|---|---|---|---|---|---|---|---|
| lobby (after Teleporter B) | 224, 11, -112 | 51.9 | true | 15,000 | hidden | — | — |
| r=90 | 86, 3, -131 | 90.0 | false | 15,000 | shown | 110 | 0.447 |
| r=150 | 26, 3, -131 | 150.0 | false | 15,000 | shown (gold) | 50 | 0.747 |
| r=190 | -14, 3, -131 | 190.0 | false | 15,000 | shown (gold) | 10 | 0.947 |
| r=197 | -21, 3, -131 | 197.0 | false | 15,000 | shown (gold) | 4 | 0.984 |
| r=199 | -23, 3, -131 | **199.0** | false | **15,000** | shown (gold) | 2 | 0.995 |
| r=204 | -28, 3, -131 | **204.0** | false | **21,575** | hidden | 0 | — |

`Toast: "Banked 6575 Cash."` + `RobberySuccess`. The Bank banks normally once outside and past 200,
and only then.

**Verdict on `isInsideBank`: correct.** It refused at 313.4, 296.3, 290.6 and 229.6 studs inside, and
at 199.0 studs outside, and fired at 204.0 studs outside. Nothing I could do made it pay out
underground.

---

## Step 3 — timer visibility

Confirmed on every run, and specifically:

- The heist timer (`<Location>Timer`) stayed `Visible = true` across the entire escape run, at every
  sample from inside the building out to 199 studs — including while the player was outside every
  zone, which is the case the old zone-gated logic could not have covered.
- It hides the instant the bag banks (payout at 204 studs → `timerVis=false`), because the getaway
  widget is gone and the player is in no zone. That follows the code's own resolution order and is
  by design.
- **It slides away when the session ends.** Observed directly in the expiry test below: the player
  stood outside with a live bag at 149.9 studs, timer `Visible=true` at T-1 s, then `Visible=false`
  at T+1 s as the state went `Active → Cooldown`. The getaway widget went with it and its fill bar
  was reset to 0 on the hide edge, as intended.

---

## Step 4 — reachability of 200 studs

**Answer: yes, at every location, with room to spare.** Established two ways.

**(a) Navmesh paths.** `PathfindingService:ComputeAsync` from each location's own ExitSpawn to a
point 210 studs from its anchor, in all four compass directions:

| Location | ExitSpawn hDist | N | S | E | W |
|---|---|---|---|---|---|
| Bank | 79.8 | NoPath* | Success (245 studs) | Success (337) | **Success (133)** |
| SlowFoods | 55.2 | Success (231) | Success (235) | Success (335) | **Success (164)** |
| Gas2Go | 60.6 | Success (316) | **Success (171)** | NoPath* | Success (294) |
| NewsStation | 54.1 | Success (477) | **Success (203)** | NoPath* | Success (383) |

\* The three `NoPath` results are artefacts of my sampling, not map deficiencies: those probe points
landed on a **roof** (Bank N on a `CanopyPart` at y=28.8; Gas2Go E on a part at y=41.3; NewsStation E
on a part at y=30), so there is no navmesh there. Every location has at least three of four
directions reachable.

The reason the map's ~490-stud built extent is not a constraint: `Workspace.Baseplate` is
**2048 × 2048 studs** centred on the origin, flat at y=0, and the built locations sit well inside it.
A player running away from any location is on open baseplate within 100 studs.

**(b) Actually walked.** Four routes walked by `Humanoid:MoveTo` along real pathfinding waypoints:

| Route | From | To | Walk time | Result |
|---|---|---|---|---|
| Gas2Go escape (with a 4,000 bag) | inside the station | 204.0 studs | **13 s** | banked |
| NewsStation escape (with a 7,000 bag) | outside the ATM | 203.9 studs | **16 s** | banked |
| Bank reachability | `HeistMarkers.ExitSpawn` | 206.6 studs west | **8.2 s** | reached |
| SlowFoods reachability | `SlowFoodsExitSpawn` | 207.0 studs west | **9.9 s** | reached |

So from an ExitSpawn the remaining run is roughly 8–10 seconds at default WalkSpeed, and from deep
inside a building 13–16 seconds. `EscapeDistance = 200` is comfortably achievable everywhere.

**One caveat worth a human's eye.** Pathfinding from *inside the Bank lobby* to an outside target
returned `NoPath` — the lobby interior does not appear to be on the navmesh. Walking out of the Bank
by hand (`MoveTo` in a straight line) also snagged on interior geometry, as it did at Gas2Go before
I switched to pathfinding. I do **not** read this as "the Bank exit is blocked" — the exterior route
from the ExitSpawn walks fine, and the interior geometry is simply not navmesh-friendly. But I did
not personally walk a character from the Bank vault out of the front door, so I cannot claim it.
See "Not verified" below.

---

## Step 5 — failure path (session expiry mid-escape)

SlowFoods, second session. Triggered genuinely, robbed one register (2,000 bag), then parked
**outside** the restaurant at **149.9 studs** — deliberately short of 200 — and let the 120-second
session run out while holding the bag.

| | state | cash | getaway widget | timer |
|---|---|---|---|---|
| T-11 s … T-1 s | Active | 21,575 | shown, 51 studs, fill 0.747 | visible |
| T+1 s | **Cooldown** | **21,575** | **hidden**, fill reset to 0 | **hidden** |

- Bag lost: `DuffelState` went to **0**; server logged `[Forfeit] run 2: SolarAudio forfeited 2000 (timer_expired)`.
- **No cash credited** — 21,575 before, 21,575 after.
- Widget and timer both slid away on the state change.

**One honest note on messaging.** The brief expected "the existing 'Run failed'/'died' messaging".
There was **no toast** on expiry, and that is correct per the code, not a bug: both
`LocationServer:145` and `HeistServer:160` explicitly `return` early for `cause == "timer_expired"`
("timer_expired stays suppressed: a player who has physically moved on … unlike 'died', which is
always immediate personal feedback"). The `died` branch does toast — proven independently by the
Bank death pit, which produced `Toast: "You fell. Bag lost."`. So the messaging behaved exactly as
written; the expiry case is deliberately silent and the visible signal is the HUD sliding away.
This suppression predates the getaway change.

---

## Step 6 — suite run

`TestRunner.freshRequire(game.ServerScriptService.Heist.Tests.RunAll)()`, Edit mode, after Play stopped.

**Run 1: 586 passed, 22 failed. Run 2: 594 passed, 14 failed.**

Same 608 tests both times — eight tests flipped, none appeared or vanished. The eight are the
render-driven tween assertions that CLAUDE.md and task 7 both flag as environmental:
`Hazard` (1: templight red fade), `UITransitions` (3: SlideIn/SlideOut settling),
`CounterBarrier` (4: fade-to-invisible completion). `RenderStepped` was measured at **~15 FPS** during
run 1, which is enough to run but not enough for a 0.25 s tween to settle inside a fixed wait. Run 2
is the clean reading.

**Run 2's 14 failures are exactly the known baseline, none of them mine:**

- `RestaurantConfig` 3/1 — `CooldownDuration (20 minutes) — expected 1200, got 60`
- `Gas2GoConfig` 3/1 — `CooldownDuration (10 minutes) — expected 600, got 60`
- `CashClaimVFX` 0/12 — every one `ReplicatedStorage.SharedSystems.CashClaimVFX:176: attempt to index nil with 'WaitForChild'`

**The suites that matter here are all green:** `Getaway` 14/0, `LocationServer` 17/0, `World` 50/0
(no `ClaimZone` floor-probe row — it is gone because the zones are untagged, as intended).

**Deviation from the brief's expectation.** The brief predicted `593 passed, 15 failed`. The actual
stable figure is **594 / 14** — one more pass, one fewer failure. That matches task 7's own measured
result exactly (594/14), so the brief's "15" appears to be an off-by-one in the expectation rather
than a change in the code. Reported rather than explained away: I did not find a 15th baseline
failure, and nothing regressed.

---

## Clean boot

Server boot log, single Play session, no errors from any heist script:

```
[Gas2GoServer] Gas2Go booted: Gas2GoAccessBarrier=27 Gas2GoRegister=2 Gas2GoATM=1 pulseLights=7, zones=1
[HeistServer] Bank booted: CounterBarrier=4 HeistAccessBarrier=1 HeistC4Point=1 HeistDeathVolume=1
              HeistGate=5 HeistGuardPost=4 HeistLaser=16 HeistTeleporter=2 HeistTerminal=2
              ATM=2 BankRegister=3 Safe=2, zones=5, alarmLights=0, templights=12
[NewsStationServer] NewsStation booted: ... Safe=3, zones=1
[SlowFoodsServer] SlowFoods booted: SlowFoodsAccessBarrier=3 CashRegister=4, zones=1
```

The only console noise across the whole session was pre-existing and unrelated: DataStore 403s
(`StudioAccessToApisNotAllowed` — API access is off in Studio), `Failed to load sound rbxassetid://90`,
the tommy-gun `GetConnectedParts` warnings, and CoreGui `GetGameName` promise rejections. **No
`Getaway`, `LocationServer`, `HeistServer` or `CashClaimVFX` runtime error occurred.**

---

## What I could NOT verify

Listed plainly, so none of it is mistaken for proven.

1. **A Bank run walked on foot from the vault to the payout.** The Bank's interior does not appear on
   the navmesh (`ComputeAsync` from the lobby returns `NoPath`), and the underground gauntlet has
   lasers, guards and a death pit I fell into once. Every Bank position after the Teleporter-A transit
   was reached by `PivotTo`. The **exterior** leg is proven walkable (8.2 s from ExitSpawn to 206.6
   studs); the interior leg is not. A human playtest should confirm a player can actually walk the
   vault → lobby → street route in a reasonable time within the 600 s session.
2. **The SlowFoods and Bank escapes as continuous walks.** Both were sampled by teleport steps; their
   walkability was proved separately, from the ExitSpawn, outside a live session.
3. **Anything visual beyond property values.** No screenshots — `screen_capture` returns a uniform
   magenta frame in Play mode here. I read `Visible`, `Image`, `Text` and `Size` back, which tells you
   the right slice is on screen with the right number on it, but not that it *looks* right. The
   slide-in/slide-out tweens themselves were only observed as before/after `Visible` states, and the
   viewport was running at ~15 FPS, so animation smoothness is unverified.
4. **The NewsStation safes and the full 10,000 cap.** Filled to 7,000; the `SafeCode` /
   `MasterComputer` minigame path was not exercised.
5. **Multiplayer.** One player only. The one-timer / one-widget arbitration under two concurrent
   sessions was left to the existing unit tests — although I did incidentally have Gas2Go, NewsStation
   and Bank sessions Active simultaneously for a stretch with no HUD conflict, since only one bag was
   live at a time.
6. **A second Bank session.** The Bank's 1,800 s cooldown allowed exactly one, so the Bank result
   rests on a single (thorough) run rather than a repeat.
7. **Guard/laser interaction during an escape.** I took laser damage at Terminal 2 (100 → 8 HP) and
   fell into the death pit once, but I never had a guard engage me while carrying a bag.
8. **DataStore persistence of banked cash.** Studio API access is off, so every save attempt 403'd.
   Payouts were verified on `leaderstats.Cash.Value` in-session only.
