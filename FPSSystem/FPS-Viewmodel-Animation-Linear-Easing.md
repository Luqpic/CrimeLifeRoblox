# Viewmodel animations switched to linear easing

Status: Applied and verified live in `FPS System.rbxl` (Edit mode). Studio was in Play mode on
arrival; play was stopped so the edit would persist to the place file rather than being discarded.

## Summary

The viewmodel animation pass interpolated every authored keyframe with a smoothstep curve. The
brief was to drive the viewmodel in linear mode, matching `Enum.PoseEasingStyle.Linear` in the
Animation Editor. `ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` now interpolates
linearly. Movement and shooting behaviour was explicitly out of scope and is untouched.

## Cause

`WeaponViewmodelMotion` defined `smooth(t) = t*t*(3-2*t)` and routed both of its interpolation
sites through it: the keyframe sampler `sample()` (which drives equip, reload, and melee swing
tracks for all 28 viewmodels) and the reload-cancel recovery blend. Smoothstep eases in and out,
so the pose velocity between two keys varied from 0 at the endpoints to 1.5x the mean at the
midpoint. Linear keyframes hold a constant velocity across each segment.

## Changes

`ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion` — three edits:

- `smooth(t) = t*t*(3-2*t)` replaced by `ease(t) = t`, kept as a named hook so a future easing
  swap remains a one-line edit rather than a hunt through call sites.
- `sample()` now calls `ease(...)`.
- The reload-cancel recovery blend now calls `ease(...)`.

Mirrored to `FPSSystem/ViewmodelAnimations/WeaponViewmodelMotion.luau`.

Nothing else was touched. `ViewModelController` holds no easing of its own: it contains no
`LoadAnimation`, no `:Play()`, no `TweenInfo`. Its only read of the `Animations` folder harvests
the melee `Shoot`/`Shoot2`/`Shoot3` names for variant selection, so the shipped `Animation` asset
references stay inert and available for rollback.

## Verification

Before/after on the AK47 equip draw-in, sampling the Body `Motor6D.C0.Z` at eight even slices of
`equipTime`:

- After: -0.8153, -0.9065, -0.9976, -1.0888, -1.1799, -1.1821, -1.1620, -1.1419.
  Per-step deltas on the draw segment are -0.0912, -0.0911, -0.0912, -0.0911 — constant, i.e.
  linear. The second segment past the 0.65 key runs at its own constant +0.0201.
- Under the previous smoothstep the same segment's deltas would have swept from ~0 at the
  endpoints to 1.5x the mean at the midpoint.

Live smoke test over all 28 rigs (equip, sustained fire, aim in/out, reload, reload-cancel,
second full reload, sprint, destroy): 28/28 constructed and stepped without error, 0 non-finite
or out-of-range joint positions.

Melee contact timing is unchanged, as expected — the easing swap alters the path between keys,
not the key times. Crowbar swing pose peaks at t = 0.250s against `swingDelay` = 0.250.

## Notes

Only the authored keyframe tracks became linear. The frame-rate-independent exponential blends
for aim, sprint and move weighting, and the critically damped recoil spring, are deliberately
left alone: they are movement and shooting feel, which the brief placed out of scope, and they
are not keyframe interpolation — a linear ramp there would reintroduce the frame-time
amplification already diagnosed in `FPS-Landing-Jolt-Root-Cause.md`.

The inventory read that prompted this change is worth recording. 28 viewmodels share only 11
unique `AnimationId` values across three generic kits: a rifle kit on 19 weapons, a pistol kit on
7, and a melee kit on Crowbar and Baton that borrows the pistol Idle/Equip/Reload. That is why
the animation pass is procedural in the first place — per-weapon character came from authored
joint poses, not from the assets. Any asset-based refactor should be authored against the nine
mechanical classes the module already distinguishes (rock, rifle, bullpup, top, pistol, revolver,
shell, pump, melee), not against the 28 weapons or the shop categories.

The melee `Reload` asset slot is vestigial: `Motion:reload` returns early for `kind == "melee"`.
