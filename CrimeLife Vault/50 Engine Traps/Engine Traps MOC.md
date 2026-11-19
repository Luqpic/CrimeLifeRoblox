---
type: moc
tags: [trap, moc, engine]
updated: 2026-11-20
sources: ["CLAUDE.md (Known traps)", "70 Batches/ (Notes and Cause sections of the change logs)", "OBT Vault/50 Engine Traps/ (generic traps)"]
---

# Engine Traps MOC

Roblox engine behaviour that cost a debugging session, grouped by area. Each trap gives the symptom, the cause, the fix and the change log where it bit us (`[[Change-Log-Name]]`). Every item of the `CLAUDE.md` "Known traps" list is here, marked "(Known trap)". Traps marked "(OBT)" were found on the developer's other project and are generic Roblox behaviour; they have not bitten CrimeLife yet.

Quirks of the Studio MCP harness and the Mac (not the engine) are in [[Tools MOC]], mainly [[Studio MCP Gotchas]], [[Screen Captures]] and [[Studio Host and Instance Id]].

## Trap notes

- [[UI Layout Traps]]: UIPadding offsets children, AnchorPoint vs Position, the top-bar inset and `IgnoreGuiInset`, layouts owning their children, ClipsDescendants vs rotation and UICorner, CanvasGroup limits, ZIndexBehavior Global, RichText, `Name` / `Text` collisions, ResetOnSpawn.
- [[Billboard and World GUI Traps]]: world GUIs never clicked, Scale is studs and Offset is pixels, custom prompts and `Enabled`, StudsOffsetWorldSpace, SurfaceGui faces.
- [[Camera and Input Traps]]: every Tool's controller hearing a global key (2026-11-20), LockCenter breaking click tests, stray mouse-moves starting drags, the WalkSpeed-0 camera amplifier, camera claims on respawn, ProximityPrompt key order, a prompt's hold time enforced only on the client, touch controls.
- [[Sound and Asset Traps]]: group animation assets loading only in a group-owned place (2026-11-20), PlaybackLoudness ignoring Volume, unauthorized sound assets, dead animation assets, AnimSaves, opaque-alpha slices, decal ids.
- [[Tween and Render Traps]]: a sleeping Mac display stopping Play rendering (2026-11-20), render-driven tweens and a collapsed viewport, preview pivots, SpecialMesh plastic, Metal, float properties.
- [[Physics and Character Traps]]: joints that are AnimationConstraints (2026-11-20), hits absorbed by carried tools, line of sight blocked by allies, Humanoids climbing each other, impulse vs settled distance, client-owned characters, rig hubs.
- [[Luau and Scripting Traps]]: the Write tool stripping trailing whitespace and a quadratic trim pattern (2026-11-20), deferred attribute signals, `string.gsub` magic characters, grep hitting comments, a rate limit keyed on a Tool instance reset by a fresh clone, an order test on an empty GUI, `task.wait` overshoot, setup checks that abort wiring, stale instance paths, cross-root `ObjectValue` references lost by a root-by-root import, a stale `UserOwnsGamePassAsync` false after a purchase, a plugin-context `execute_luau` holding its own module copies, `Humanoid.Died` silent on a bare test rig, free-model backdoors (numeric `require`, `getfenv`).
- [[Streaming and Replication Traps]]: a Player attribute replicating to every client (2026-11-20), ServerStorage does not replicate, hydration that raises an attribute after the client seeded it, client scripts that index a separately-arriving instance race under a heavier place, ownership, session locking only testable when published, streaming (if enabled).

## The Known traps list, by note

| Known trap (`CLAUDE.md`) | Note |
|---|---|
| `UIPadding` offsets its children | [[UI Layout Traps]] |
| A `CanvasGroup`'s `GroupTransparency` does not fade its own `UIStroke` | [[UI Layout Traps]] |
| A `UIListLayout` owns position and size of what it stacks | [[UI Layout Traps]] |
| A world-parented GUI is drawn but never hit-tested | [[Billboard and World GUI Traps]] |
| `ZIndexBehavior` is a global on the `ScreenGui` | [[UI Layout Traps]] |
| `Instance.Name` collides with a custom `Name` property | [[UI Layout Traps]] |
| `Sound.PlaybackLoudness` ignores `Volume` | [[Sound and Asset Traps]] |
| `AnchorPoint` and `Position` must agree | [[UI Layout Traps]] |
| `BillboardGui` size: Scale is studs, Offset is pixels | [[Billboard and World GUI Traps]] |
| `AbsolutePosition` is measured below the top-bar inset | [[UI Layout Traps]] |
| `ServerStorage` does not replicate | [[Streaming and Replication Traps]] |
| Equipping sets `MouseBehavior` to `LockCenter` | [[Camera and Input Traps]] |
| TweenService is render-driven; a collapsed viewport stops it | [[Tween and Render Traps]] |

## Adding a trap

When a trap costs time, add it to the matching note above (or a new note here if no area fits) with Symptom / Cause / Fix / Bit us, cite the batch note, and link it from this MOC. See [[Vault Conventions]].

## Related

[[GUI Rules]] · [[HUD and UI Shell]] · [[Weapons and Blaster]] · [[Enemies and Spawner]]
