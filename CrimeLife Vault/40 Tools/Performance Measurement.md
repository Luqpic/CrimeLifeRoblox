---
type: tool
tags: [tools, performance, measurement]
updated: 2026-11-14
sources: ["70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "OBT Vault/40 Tools/Performance Measurement.md (generic parts)"]
---

# Performance Measurement

How to measure CrimeLife performance in Studio. The rule is [[Phones First and Keep Optimised]].

## What CrimeLife has measured so far

- [[Performance-Optimization-And-Unification]] (Robbery System, 2026-09-12): a structural read-through, **not a live profiler pass**. Bank / BankVault models had 572 / 624 descendants against 18 to 51 for SlowFoods, Gas2Go and NewsStation; the per-location orchestration scripts were about 85% duplicated. Status: Part 1 confirmed; Parts 0 and 2 to 4 not independently verified.
- No FPS System profiler pass is recorded.

## First: is it the Mac? (OBT, same Mac)

1. Read `game.Stats.PerformanceStats.Memory:GetValueString()`. Past about 10 GB, ask the developer to save and restart Studio before any hunt.
2. A whole-process stall shows no Lua time: check `vm_stat` and `sample <studio pid>` before blaming game code.
3. A collapsed viewport renders nothing at all (`ViewportSize` 1, 1): no frame or render number means anything then ([[Studio Host and Instance Id]]).

## Frame time is unreliable here

An unfocused Studio renders at about 9 to 16 FPS and GPU time reads 0 on this Mac; real phones cannot be measured. Read instead:

- `Stats.FrameRateManager` (PerformAverage, RenderThreadAverage, Batches) and `Stats.RenderBreakdown`.
- Instance and part counts for what you added (`#model:GetDescendants()`), before and after.
- The script profiler. Server: `ScriptProfilerService:ServerStart(1000)`, wait, `ServerRequestData()`, `ServerStop()`; `OnNewData` fires only on request. Client: `ClientStart(LocalPlayer, 1000)`.
- `gcinfo()` in an MCP call reads the tool's VM, not the game's: per-VM numbers need an in-game probe (a temporary Script or LocalScript that measures and writes an attribute).

## Measuring right

- In a Studio Play, client and server run in one process: a long client frame shows as a long server frame. Profile both sides before blaming the server.
- Compare two versions in the same spot; take 3 readings a few seconds apart, single RenderBreakdown readings jump.
- The Luau "threads" stat counts dead threads until the GC runs, and "Infinite yield possible" prints even for a cancelled `WaitForChild`: neither is a leak signal.
- A ParticleEmitter's Rate is capped near 450; cost = capped emitters x lifetime.

Related: [[Tools MOC]] · [[Measure Before and After]]
