# Prompt: Optimize, Unify, and Clean Up the Robbery System (Bank / SlowFoods / Gas2Go / NewsStation)

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Context, confirmed before writing this — read this first

This is a live, working, TDD-covered multi-location robbery system (Studio place: "Robbery System"). Four independent robbery locations — **Bank** (`ServerScriptService.HeistServer`), **SlowFoods** (`SlowFoodsServer`), **Gas2Go** (`Gas2GoServer`), **NewsStation** (`NewsStationServer`) — plus a fifth orchestrator, `ServerScriptService.SuppliesServer` (not yet read), share one generic engine under `ServerScriptService.Heist/` (`BankInstance` session state machine, `ComponentRegistry`, ~15 `Components/`, 5 `Services/`) and a `ReplicatedStorage.SharedSystems/` layer (`GamepassManager`, `NPCReactionAnimator`, `NPCSpawnManager`, `RobbableObject`, `SupplyObject`, `LockedDoor`, `CarryState`, plus `PlayerData.CurrencyService`). A full `Tests/` spec suite already exists under `ServerScriptService.Heist.Tests` (~30 specs) with a `TestRunner`/`RunAll` in `ReplicatedStorage.HeistShared` — **this project practices real TDD; treat the existing specs as the safety net for every change below, not an optional nicety.**

Confirmed structural facts (read directly from the four location scripts and the game tree, not assumed):

- `SlowFoodsServer`, `Gas2GoServer`, and `NewsStationServer` are ~85% line-for-line identical boilerplate: boot-validation asserts, `Forfeit`/`BankInstance`/`ZoneService`/`ComponentRegistry` construction, `AlarmEffects` setup, `DuffelBagAttachment`, a `tryTriggerRobbery`/`watchCharacter`/`PlayerAdded`/`PlayerRemoving` block, and one `task.spawn` heartbeat loop calling `bank:Step()`, `zoneService:Update()`, `alarm:Update()`, `updateZoneOccupancy()`. `HeistServer` (Bank) has **not** been read in this pass but is very likely the same skeleton plus Bank-only extras (Terminals, C4, GuardPost, VaultDoor) — confirm this before assuming it fits the same mold.
- `Workspace.Bank` has **572 descendants** and `Workspace.BankVault` has **624 descendants** — an order of magnitude heavier than `SlowFoods` (51), `NewsStation` (20), or `Gas2Go` (18). This is the single most concrete lead for "the game is heavy" and should be profiled first, not assumed to be a scripting problem.
- `NPCSpawnManager` unconditionally destroys-and-reclones NPCs (Cashiers/NewsWorkers/BankClerks) on every session cooldown-end, for the life of the server — a recurring cost that compounds over a long-running server if old instances (rig parts, `Animate` LocalScript, `Animator`) aren't fully destroyed.
- `AlarmEffects` clones a shared alarm-sound template into each location's zone for the duration of every active session (plus a pulsing-light Tween for Gas2Go's `RobberyAlarmLights`) — another recurring per-cycle allocation whose cleanup needs verifying.
- `StarterGui` holds exactly 4 `ScreenGui`s (`SupplierDialogGui`, `LockpickGui`, `HackCodeGui`, `WordScrambleGui`), each traced to a real `RemoteEvent` pair already in `ReplicatedStorage.HeistShared.Remotes` — no dead GUI found at that depth, but their LocalScripts have not been read yet.
- `SoundService` is empty — sounds are hosted as static, pre-placed `Sound` instances per-object (per `HeistShared.Config`'s own comments), not centrally, so "unused sounds" (if any) will be scattered per-location, not in one place.

None of the above is a confirmed root cause of lag — it's what a structural read-through surfaces. **Do not delete, merge, or rewrite anything based on this list alone; profile first (Part 0), then act only on what both this list and your own live profiling agree on.**

---

## Ground rules for every part below

1. **Never delete an instance, script, or asset without first using `script_grep`/`script_search` across the whole game for every way it could be referenced** (by name, by CollectionService tag, by hard-coded path like `workspace.Bank.LockedDoor`) **and confirming zero live references.** Several components here are referenced by literal path, not by tag — a rename or move without updating every reference will break a location silently at runtime, not at compile time.
2. **Run the existing spec suite (`ServerScriptService.Heist.Tests` via `TestRunner`/`RunAll`) before touching anything, and again after each Part.** A part is not done until the suite passes at the same or better count than the baseline, with any change in results explicitly noted.
3. **Play-test all four locations end-to-end after each Part**, not just once at the end: trigger the robbery, complete the location-specific puzzle (Bank: terminals + C4 + vault; SlowFoods/Gas2Go: registers/ATM + lockpick; NewsStation: MasterComputer hack + safes + oil hazard), claim the duffel, confirm cash is banked. Describe or screenshot what you actually observed — "should still work" is not verification.
4. **Preserve every player-visible behavior and every tunable `Config` value exactly**, unless a value is provably dead code (zero references). This is a performance/structure pass, not a rebalance.
5. If a Part needs touching `HeistServer` (the Bank) or `SuppliesServer` and you haven't read them yet, read them in full first — every assumption above about "the same skeleton" needs confirming against the real file before you refactor it.

---

## Part 0 — Profile before you touch anything

Do this first, and let it steer which of Parts 1–3 actually matter:

1. Enter Play mode. For each of the 4 locations in turn, trigger a robbery solo and run it to completion (claim the duffel).
2. While each session is Active, capture Studio's Script Performance / MicroProfiler stats — identify which script or component is actually spending the most time per frame, and whether memory/Instance count (especially inside `Workspace.Bank`/`BankVault`) climbs and fails to return to baseline after the session ends and cooldown completes.
3. Repeat the NPC-respawn cycle (trigger → let it cool down → trigger again) 2–3 times per location and confirm the NPC/Instance count returns to baseline each time, not upward.
4. Write down the actual top 3–5 costs you found. If `Workspace.Bank`/`BankVault`'s raw part count turns out to be the dominant cost rather than scripts, say so explicitly — the fix there is level-design/geometry work (merging parts, unanchoring fewer of them, `StreamingEnabled` tuning), which is out of scope for this prompt; report it back rather than attempting a geometry rewrite.

## Part 1 — Unify the duplicated per-location orchestration

Confirmed duplication (see Context above): `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer` (and, pending your read, `HeistServer`) repeat the same boot-validation / Forfeit / BankInstance / ZoneService / ComponentRegistry / AlarmEffects / DuffelBagAttachment / trigger-and-lifecycle / heartbeat skeleton.

- Extract a single shared factory/module (e.g. `Heist.Services.LocationServer`, named consistently with the existing `Services/` folder) that takes a per-location config table (Config module, tags, model, zone role names, claim-role name, hazard component classes, extra components to register) and returns the wired `bank`/`zoneService`/`net`/etc., plus starts the shared heartbeat loop.
- Each location script becomes: boot-validation for its own location-specific tag counts (these genuinely differ per location — keep them explicit) + a call into the shared factory + its own location-only extras (Bank's Terminals/C4/GuardPost/VaultDoor; NewsStation's MasterComputer/Safe/oil hazard/LightSphere; SlowFoods & Gas2Go's registers/ATM/supply objects, which are also near-identical to each other and worth a second shared helper if it doesn't fight the first).
- Migrate one location at a time — run the spec suite and a full play-test after each migration. Never migrate all locations in one shot.
- This must be a straight behavior-preserving refactor: every `Config` value, every remote payload shape, every message string stays identical. If the existing spec suite doesn't already cover a per-location script directly (it likely only covers the shared `Heist.*` modules), say so and add the minimal spec needed to pin the current externally-observable behavior (state transitions, remote broadcasts) before refactoring it out from under yourself.

## Part 2 — Audit for genuinely unused GUI / sound / script instances

1. Read the 4 `StarterGui` ScreenGuis' LocalScripts and confirm each of `SupplierDialogGui`, `LockpickGui`, `HackCodeGui`, `WordScrambleGui` is actually driven by a live remote listener with no dead code paths inside.
2. Search for every `Sound` instance and `SoundId` across the game; for each, confirm it's reachable from at least one of the 5 orchestrator scripts or a Component/Service — anything with zero references is a real deletion candidate (apply Ground Rule 1 first).
3. Check `ServerScriptService.PlayerData` (4 ModuleScripts) and `ServerScriptService.SlowFoods.Components` (a folder distinct from `Heist.Components` — read what's actually in it) for anything superseded by the shared `Heist` framework and never called.
4. Confirm `ReplicatedStorage.HeistShared.TestRunner` / `Heist.Tests.RunAll` are never invoked from a live (non-Studio) code path — gate them behind `RunService:IsStudio()` if they currently aren't, so the full spec suite never executes on a published server.
5. List every deletion candidate with its zero-reference proof before deleting anything, then delete, then re-run the spec suite and play-test.

## Part 3 — Lifecycle / leak audit

1. `NPCSpawnManager`: confirm the previous cycle's NPC model (and everything under it — rig parts, `Animate` LocalScript, `Animator`, any `AnimationTrack`s) is fully `:Destroy()`'d before/when a new one is cloned in, across at least 3 respawn cycles per location (per Part 0 step 3).
2. `AlarmEffects`: confirm the cloned alarm-sound instance (and, for Gas2Go, the `RobberyAlarmLights` pulse Tween) is destroyed/cancelled on `Stop()`, not merely muted or left playing at zero volume, across multiple Start/Stop cycles.
3. Any other per-session-cloned instance (duffel bag attachment, C4 explosion effect/sound at the Bank, supply-object drop timers) — same check: destroyed on both the success path and the forfeit/timeout path.
4. Any dangling `RBXScriptConnection`s from `PlayerRemoving`/`CharacterAdded` handlers across the 5 orchestrators — confirm every per-player `:Connect()` has a matching disconnect or is naturally scoped to die with the character/player.

## Part 4 — Explorer/hierarchy organization

*(Read "director of the game" as "directory" / Explorer hierarchy — if something else was meant, correct this Part rather than guessing further.)*

- Group each location's Workspace assets consistently. `Zones`/`Markers`/model folders already follow a per-location naming convention for SlowFoods/Gas2Go/NewsStation — confirm Bank/BankVault follow the same shape or are legacy-named differently, and align them if it's safe to (see below).
- Before moving or renaming **any** top-level instance, grep the entire game for its exact path string (e.g. `workspace.Bank`, `workspace.SlowFoods.LockedDoor`, `workspace.NewsStation.MasterComputer`, `workspace.BankVault.AlarmSpeaker.AlarmSound` — this last one is reused by literal path from 3 other locations' `AlarmEffects` setup, so it cannot move without updating all of them) and update every call site in the same change.
- Prefer grouping/renaming Explorer folders over moving deeply-referenced singletons; if a singleton absolutely must move, do it as its own isolated step with its own grep-verify-move-reverify cycle, not bundled with anything else.

---

## Master verification checklist

- [ ] Part 0 profiling data recorded; Parts 1–3 prioritized by what it actually showed, not by assumption.
- [ ] Full existing spec suite passes after every Part, same or better than the baseline run.
- [ ] All 4 locations play-tested end-to-end (trigger → puzzle → claim → cash banked) after every Part, not just once at the end.
- [ ] NPC and per-session-instance counts return to baseline after 2–3 respawn/session cycles per location (no climbing memory/instance count).
- [ ] No `Config` value or player-visible string/behavior changed anywhere.
- [ ] Nothing deleted or moved without a documented zero-reference grep check first.
- [ ] Any finding not actually fixable within this prompt's scope (e.g., raw Bank/BankVault geometry weight) is reported back explicitly rather than silently attempted.
