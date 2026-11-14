---
type: rule
tags: [rule, performance, mobile]
updated: 2026-11-14
sources: ["OBT Vault/10 Rules/Phones First and Keep Optimised.md (adapted)", "70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "70 Batches/FPS System/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md"]
---

# Phones First and Keep Optimised

## Rule

Every addition keeps the game cheap enough for phones. It is part of "done", not a separate pass.

- **Nothing periodic does work it does not need.** A loop re-applies only what changed. No fast server loops that write properties (every write replicates to every client); cosmetic motion runs on the client.
- **No whole-world scans at runtime** (`workspace:GetDescendants()` in a loop). Use CollectionService tags or a known folder (`Workspace.EnemySpawns`, `Workspace.Quests`).
- **Clone, don't build per hit.** Effects and coins come from templates and shared modules (`UI.CashBurst`, `ServerStorage.Cash`).
- **Touch works.** The blaster has a touch HUD (`BlasterTouchGui`); new HUD elements need a touch path; no hover-only actions; a drag is not a click.
- **Measure what you added** and say what was not measured ([[Performance Measurement]]).

## Why

- Carried from the developer's OBT rules (same developer, 2026-10-09: "whenever there's a new addition or change, please be mindful to keep the world and gameplay optimised"). Adopted for CrimeLife on 2026-11-14. No CrimeLife-specific frame-rate target is recorded.
- CrimeLife's own lag pass: [[Performance-Optimization-And-Unification]] (Robbery System, 2026-09-12) found ~85% duplicated per-location orchestration scripts and Bank / BankVault models of 572 / 624 descendants against 18 to 51 for the other three locations. It was a structural read, not a profiler pass.

## How to apply

- Report the measured cost in the batch note, before and after ([[Measure Before and After]]).
- Phone layout has never been checked in an emulator for CrimeLife (not recorded): see [[Phone Testing]] and ask for the emulator in the picker round when a batch touches the HUD.
