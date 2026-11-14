---
type: rule
tags: [rule, architecture, shared-code, weapons]
updated: 2026-11-14
sources: ["CLAUDE.md (How to work in this project, items 6-7; Systems)", "70 Batches/FPS System/FPS-Carried-Weapons-Absorbed-Hits.md", "70 Batches/FPS System/FPS-Clustered-Enemies-Stop-Attacking.md", "70 Batches/FPS System/FPS-New-Guns-Magazines-And-Pump-Forends.md"]
---

# Shared Code Extended by Attributes

## Rule

- **Prefer the shared module over a local rebuild.** If a behaviour exists in `ReplicatedStorage.UI.*` or `ReplicatedStorage.Modules.*`, route through it. Do not reimplement a widget per panel.
- **Extend weapons by attribute, not by fork.** Weapon behaviour is data on the Tool (`infiniteAmmo`, `knockbackForce`, ADS zoom, burst mode, ray count, `stunDuration`). Add an opt-in attribute that the shared blaster code reads; never branch the shared code per weapon.
- **Fix the root cause once, in the code every caller routes through.** Grep every caller of a shared function before changing it.
- **Name the shared function changed and the callers checked** in the batch note.

## Why

- `CLAUDE.md`: "Most historical bugs in this place came from five panels each reimplementing the same widget." and "Weapon behaviour is data on the Tool ... do not branch the shared code per weapon."
- [[FPS-Carried-Weapons-Absorbed-Hits]] and [[FPS-Clustered-Enemies-Stop-Attacking]] were both fixed in the shared hit path (`ShotResolver` / the ray cast), which fixed every weapon and enemy at once.
- [[FPS-New-Guns-Magazines-And-Pump-Forends]]: new joints were picked up "untouched, because joints are collected generically from Motor6Ds": data, not a branch.

## How to apply

- Shared homes: `ReplicatedStorage.Blaster` (`Constants`, `Scripts.BlasterController`, `Scripts.ViewModelController`, `Utility.canDamageHumanoid`), `ServerScriptService.Blaster.Scripts.ShotResolver`, `ReplicatedStorage.UI.*` (`Theme`, `Panels`, `Effects`, `Transitions`, `CashBurst`, `PromptUI`), `ReplicatedStorage.Modules.*` (`CameraAuthority`, `MenuFovBlur`, `NotificationController`).
- Recipes: [[How-To MOC]]. Systems: [[Weapons and Blaster]], [[HUD and UI Shell]].
