---
type: trap
tags: [trap, luau, scripting, signals]
updated: 2026-11-14
sources: ["docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium)", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "70 Batches/Robbery System/Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades.md", "70 Batches/FPS System/FPS-Knife-Bleed-Melee.md", "70 Batches/FPS System/FPS-New-Guns-Missing-MuzzleAttachment-Fix.md", "70 Batches/FPS System/FPS-Enemy-Search-State-Spin-Fix.md", "70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "OBT Vault/50 Engine Traps/Luau and Scripting Traps.md (generic traps)"]
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

### A ModuleScript's hooks connect only when something requires it
- `PersistenceRunner` exists for that reason: one line that requires `ProfileGateway` and calls `start()`.

### A hard-coded instance path goes stale when someone moves the instance
- Moving `DuffelBag` to `ReplicatedStorage.HeistShared` left a default template path pointing at nothing. Re-read live state after the developer changes things in Studio. [[Performance-Optimization-And-Unification]], [[Post-Move-Fixes-And-GUI-Polish]].

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

Related: [[Engine Traps MOC]] · [[Studio MCP Gotchas]] · [[Unit Test Runner]]
