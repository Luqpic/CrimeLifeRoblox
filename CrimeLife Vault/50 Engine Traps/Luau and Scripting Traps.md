---
type: trap
tags: [trap, luau, scripting, signals]
updated: 2026-11-17
sources: [".superpowers/sdd/2026-11-17-police-and-wanted/task-1-report.md", ".superpowers/sdd/2026-11-17-police-and-wanted/task-2-report.md", ".superpowers/sdd/2026-11-17-police-and-wanted/task-4-report.md", "docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium)", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "70 Batches/Robbery System/Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades.md", "70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "70 Batches/FPS System/FPS-New-Guns-Missing-MuzzleAttachment-Fix.md", "70 Batches/FPS System/FPS-Enemy-Search-State-Spin-Fix.md", "70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "OBT Vault/50 Engine Traps/Luau and Scripting Traps.md (generic traps)"]
---

# Luau and Scripting Traps

Language and runtime behaviour that shipped bugs or misled a measurement.

## Signals fire deferred

### Attribute-changed signals run later, not on the write
- **Symptom:** after `player:SetAttribute("Level", 2)`, `player:GetAttribute("Spraypaint")` on the next line read the old balance (0); after one `task.wait()` it read 25.
- **Cause:** this place runs `GetAttributeChangedSignal` handlers deferred (Roblox's Deferred signal behaviour).
- **Fix:** in tests, `task.wait()` between a write and the read of anything its listeners compute. In code, never rely on a listener having run.
- **Bit us:** [[FPS-Spraypaint-Phase-2]].

### Deferred handlers coalesce same-frame writes
- 12 back-to-back `SetAttribute` gains with no yield produced one "+78" notification, not 12. Not a queue bug: the deferred signal coalesced them. [[Notification-Queue-While-Panel-Open]].

### A "suppress" flag around your own write does not work
- **Symptom:** a reversed fade and a lockpick panel that would not close.
- **Cause:** the fade set a flag, wrote the watched property, cleared the flag; the property-changed callback ran deferred, after the flag was already clear.
- **Fix:** count your own writes (or compare to the value you wrote) instead of a flag. [[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]] (Robbery System).

### Hydration order and deferral can pay rewards twice
- `SpraypaintService` seeded `lastLevel` from the `Level` attribute and listened for changes; the profile load yields, so `LevelingService.hydrate`'s `SetAttribute("Level", 12)` always landed after and fired the listener: a level-up award that never happened. The fix refuses to pay while `ProfileGateway.get(player)` is nil, so restoration is never progression **by construction**, not by ordering luck. [[FPS-Persistence-Phase-3]].

### A rate limit keyed on a Tool instance is reset by a fresh clone
- **Symptom:** the first version of the server rate of fire on `Shoot` kept its last-shot time per Tool; `SetLoadoutSlotRequest` and `EquipRequest` hand out a fresh Tool clone on every call, which had no last time, so slot-move, equip, shoot repeated swung a Crowbar every 0.22 to 0.24 s instead of every 0.67 s.
- **Cause:** the state lived on something the client can make the server replace.
- **Fix:** key per-weapon state on `player` plus `tool.Name` and clear it on `PlayerRemoving` (`validateShot`, `validateFireInterval`). Measured: before 85, 77.5, 70 (two hits), after 130, 122.5, 122.5 (refused).
- **Bit us:** [[2026-11-15 FPS Hardening In City]] (found in review, not by the first test).

### An order test on an empty GUI passes trivially
- **Symptom:** a paint-order comparison between `Global` and `Sibling` reported "equal" for a ScreenGui that held 0 objects at 25 s (`PromptUiGui`, `DamageDirectionIndicator`).
- **Cause:** the lists are both empty, so any rule gives the same order; the test cannot fail.
- **Fix:** run the tool on a known-different tree first (the notification card case must report a difference), then measure again with content live: after a notification, with arrows on screen, with the coins. `CityMerge/phase2b/paint-order.luau` has the self-check.
- **Bit us:** [[2026-11-15 FPS Hardening In City]]. See also [[UI Layout Traps]] (ZIndexBehavior) and [[Unit Test Runner]] ("A test that cannot fail is not a test").

## Strings and source edits

### string.gsub with magic characters silently replaces nothing
- `(`, `)`, `.` or `-` in a pattern change its meaning, and a no-match raises no error. After any `Source` edit, read it back, check the byte length moved, find the new text with `string.find(src, needle, 1, true)` (plain), and confirm the old text is gone. Persistence plan trap 1; [[FPS-Weapon-Skins-Phase-1]].

### A grep hit can be a comment saying the thing is absent
- Two false conclusions came from this (`DataStoreService` and `UIListLayout`). Confirm a hit is code. Persistence plan trap 7.

### bit32 loses precision past 2^53
- An FNV-1a checksum in Luau gave different hashes for identical text; Adler-32 matched Python. [[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]].

## Timing

### task.wait overshoots, so clock deadlines drop the last tick
- A 5 s bleed at 4/s dealt 16, not 20: after five one-second waits the clock was already past the deadline. Count ticks for "five ticks of bleed". [[FPS-Knife-Bleed-Melee]].

### task.wait(t) resumes on a whole frame (OBT)
- A loop of one action per wait runs at frame granularity; for a rate, act on the clock.

### A think loop repeats one-shot actions
- An enemy re-thinks four times a second; a search-state turn with no guard added another 50 degrees each time, about 20 turns in a 5 s search. Guard one-shot actions the way the patrol arrival already did. [[FPS-Enemy-Search-State-Spin-Fix]].

## Setup and structure

### One strict check at the top of a setup aborts all wiring
- The weapon setup demands `MuzzleAttachment` first; without it nothing after (equip, fire, reload listeners) connects, and the game holds the weapon as a plain object. [[FPS-New-Guns-Missing-MuzzleAttachment-Fix]].

### A Script's hydrators register at server start, not on require
- Scripts (unlike ModuleScripts) cannot be required by tests, and their hydrators throw on a table stand-in. [[Unit Test Runner]], [[FPS-Persistence-Phase-3]].

### A plugin-context `execute_luau` holds its own module copies
- **Symptom:** heat set with `require(ServerScriptService.Wanted.WantedService).addHeat(...)` from a server `execute_luau` showed on the star meter but never drained; `EnemyAI.getLive()` from the same call listed no enemies while 30 were alive.
- **Cause:** the Studio MCP runs `execute_luau` in its own (plugin) context, so `require` returns a separate copy of the module with its own state. The game's scripts share another copy. Attributes are on real instances, so they are shared; module tables are not. Measured: 0 runner steps through the patched copy.
- **Fix:** drive state through the game's own paths (a real trigger, a remote, a `BindableEvent`), or create a temporary server `Script` that requires the module (it shares the game's copy) and writes results into a `StringValue`; destroy both after. Running a test suite from `execute_luau` is fine, because the suite builds its own state. [[2026-11-17 Police and Wanted]]

### `Humanoid.Died` does not fire for a bare test rig
- **Symptom:** a stand-in character for a death test never fired `Died`: not for a bare Model with a Humanoid, and not for one with a body on `Health = 0` within 1.5 s.
- **Fix:** weld a root and a head to the Humanoid's model and call `ChangeState(Enum.HumanoidStateType.Dead)`; that fires it. [[2026-11-17 Police and Wanted]] (Task 1)

### A ModuleScript's hooks connect only when something requires it
- `PersistenceRunner` exists for that reason: one line that requires `ProfileGateway` and calls `start()`.

### A hard-coded instance path goes stale when someone moves the instance
- Moving `DuffelBag` to `ReplicatedStorage.HeistShared` left a default template path pointing at nothing. Re-read live state after the developer changes things in Studio. [[Performance-Optimization-And-Unification]], [[Post-Move-Fixes-And-GUI-Polish]].

### Importing root by root drops cross-root `ObjectValue` references
- **Symptom:** after the four heist locations were imported one root at a time, both `LinkedTeleporter` ObjectValues (Bank lobby and vault) were nil and `Go to Vault` had no target.
- **Cause:** each root is serialized on its own, so a reference from one root to an instance in another has nothing to point at. The same holds for joints, constraints and `PrimaryPart` links that cross roots.
- **Fix:** before importing, scan every `ObjectValue`, joint, constraint and `PrimaryPart` for targets outside its own root (here exactly two, found in the source place), and re-link them by hand after. [[2026-11-16 Robbery Systems Into City]]

### `UserOwnsGamePassAsync` can return a stale false right after a purchase
- **Symptom (by reading, not seen live):** a player who buys a pass is told it is theirs by `PromptGamePassPurchaseFinished`, but a cached `false` from an earlier check keeps them without it for the session.
- **Cause:** the ownership call may answer the old value for a short time after the purchase, and a cache that stores the first answer keeps it.
- **Fix:** on `wasPurchased` clear the cached entry and confirm with up to 3 pcall'd calls 2 s apart; cache only a confirmed true. Never trust the client-reported flag alone. A read that starts before a confirm can still overwrite a `true` with a stale `false` for a few hundred ms. [[2026-11-16 Robbery Systems Into City]]

### A divide-by-zero guard can be an amplifier
- `math.max(x, 0.01)` stops a crash but turns 0 into a 100x divisor. Floor at a sane reference value ([[Camera and Input Traps]]).

## Generic (OBT)

- A weak-keyed table whose value refers to its key never lets go (Luau has no ephemerons).
- Callback members (`OnServerInvoke`, `OnInvoke`) can be set but never read: expose handlers from the module for tests.
- `Clone()` copies attributes, not connections: never mark "already wired" with an attribute.
- On a client, `os.clock()` counts from the app's start, not the join.
- A `local function` declared below its caller is nil inside that caller.
- `ipairs` stops at the first nil.
- A `--` comment put mid-line swallows the code after it; compile-check edited scripts.
- A respawn empties PlayerGui of loose objects (BindableEvents, Folders).
- A `CollectionService` added-signal fires again for every stream-in: remember what you wired.

## Free-model backdoors
- **Symptom:** a map built from free models carries hundreds of loose scripts that nobody on the team wrote; the Studio output shows `Terrain.Fix` and `HD Admin.Settings.Loader` trying to download assets. In `Crimelife city.rbxl` there were 636 scripts in Workspace, none CrimeLife code.
- **Cause:** free models and "admin" kits ship a hidden loader that `require`s a numeric asset id at run time, so whoever owns that asset runs code on your server. Three kinds were found: five copies of `ServerScriptService.ClientReplicator` (one obfuscated line, `getfenv` plus a reversed-string `require` with a numeric id, active only when not in Studio); `Workspace.Terrain.Fix`, a 69,317-character infector (mostly blank lines before the payload, header "Removing this may cause severe damage to your game"); and the HD Admin loader `require(3239236979)`.
- **How it was found:** a source scan over every `LuaSourceContainer` in every service, with three needles: a numeric `require(<id>)`, `getfenv`, and `loadstring`; then a check for `HttpService`, `InsertService`, `MarketplaceService`, `TeleportService` and `MessagingService` (none hit). Scripts were grouped by Adler-32 hash so each distinct source was read once.
- **Fix:** save every source first (`CityCleanup/removed-scripts/`, 82 files), then destroy; do not disable, because a disabled backdoor still travels with the place. Anything you want to keep for a decision goes to `ServerStorage` with `Enabled = false`. Do not publish a place file from before the cleanup: the on-disk copies still contain the backdoors. Bit us: [[2026-11-14 City Baseline and Cleanup]].

Related: [[Engine Traps MOC]] · [[Studio MCP Gotchas]] · [[Unit Test Runner]]
