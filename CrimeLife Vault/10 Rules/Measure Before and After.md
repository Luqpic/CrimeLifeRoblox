---
type: rule
tags: [rule, testing, tdd, performance]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work in this project, items 1-2)", "OBT Vault/10 Rules/Measure Before and After.md (adapted)", "70 Batches/FPS System/FPS-Landing-Jolt-Root-Cause.md", "70 Batches/FPS System/FPS-Shotgun-Kill-Knockback.md", "70 Batches/FPS System/FPS-Knife-Bleed-Melee.md"]
---

# Measure Before and After

## Rule

- **Read before you edit.** Confirm the real instance path and the current code in Studio before changing anything. The instance tree in `CLAUDE.md` and older notes was derived from the change-log archive, not a live read.
- **Reproduce first, then measure.** Demonstrate the fault with numbers before altering code (nearest-neighbour distances, climb rate, loudness peaks, absolute positions, counts, timings), then re-measure after. A change log (now a batch note) that cannot cite a before and after number is not finished.
- **Root cause first.** A fix is not done until the measured cause is named. Write down the theories the numbers disproved.
- **Test first where a test can exist.** Write the case in `ServerStorage.UnitTest.Cases`, see it fail for the right reason, build, see it pass ([[Unit Test Runner]]). If a test was written with the code and never seen red, say so.
- **Measure the honest quantity.** A velocity on the frame of a shot proves an impulse, not that it survived; the settled distance does ([[FPS-Shotgun-Kill-Knockback]]).

## Why

- `CLAUDE.md`: "The established practice here is to demonstrate a fault with numbers before altering code ... and to re-measure after."
- [[FPS-Landing-Jolt-Root-Cause]]: measuring the camera lean at touchdown found `math.max(WalkSpeed, 0.01)` turning a 0 WalkSpeed into a ~2500x amplifier (leanTarget -18.542 where about 0.02 is normal). Guessing had not found it.
- [[FPS-Knife-Bleed-Melee]]: "caught by measuring": a 5 s bleed at 4/s dealt 16, not 20, because `task.wait` overshoot pushed the fifth tick past an `os.clock()` deadline.
- [[FPS-Shotgun-Kill-Knockback]]: an earlier entry's claim that the fling worked was wrong; the reading had been taken on the frame of the shot.

## How to apply

- Put the before and after numbers in the batch note's Verified section.
- When a harness result looks like a code fault, cast the rays or read the positions by hand first: in [[FPS-Shotgun-Kill-Knockback]] a target placed with the shooter's full `CFrame` sat at Y = -0.65 and every pellet hit `Workspace.SpawnLocation`.
- Performance: [[Performance Measurement]]. Verification: [[Verify in Edit and by Screenshot]]. Reporting: [[Reporting Rules]].
