---
type: system
tags: [system, combat, hud]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Damage-Direction-Indicator-And-Prompt-Range.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Damage-Direction-Indicator-And-Prompt-Range.md"]
---

# Damage Direction

**Skills:** `roblox-ui`, `roblox-networking` (load these for work here)

## What it does
A fading screen-edge arrow points toward whatever just damaged the player, enemy or another player, so hits from outside the view are readable. Several hits from different directions show several arrows at once.

## Where it lives
- `ServerScriptService.Blaster.Scripts.DamageDirectionService`
- `ReplicatedStorage.Blaster.Remotes.DamageDirection` (RemoteEvent)
- `StarterPlayer.StarterPlayerScripts.DamageDirectionIndicator` (LocalScript), visuals cloned from a template in `ReplicatedStorage.GuiTemplates`.

## How it works
- The service listens to the existing hit-resolution event (no second "you got hurt" signal) and fires the attacker's position to the victim's client.
- The client flattens camera look and attacker direction onto the horizontal plane; the signed angle is `atan2` of cross and dot, with `toAttacker:Cross(lookVector)` in that order (0 = ahead, positive = right, ±180 = behind).
- Each hit spawns its own arrow on its own thread; `FADE_TIME` 1.2 s in the original prompt, arrow destroyed after about 1.35 s (prompt's expected value, not a recorded measurement).
- Since 2026-09-11 the arrow is cloned from a template, editable in Studio.

## Extend it
Change the look in the template under `ReplicatedStorage.GuiTemplates`, not in code. A new damage source only needs to go through `ShotResolver`'s hit path ([[Weapons and Blaster]]) to be relayed.

## Watch out
- Arrow mirrored left/right means the cross-product order is wrong, not the position formula.
- Its ScreenGui uses `ZIndexBehavior = Global`; per-element `ZIndex` must then be set by hand or content can render invisibly (the trap that blanked the notification card). See [[Notifications]].
- Bleed ticks (Knife) go through `TakeDamage` directly; whether they fire an arrow is not recorded.
- No change log recorded a live measurement of the arrow; status was "Applied" only.

## History
- 2026-09-24: listed among the `Global` ScreenGuis at risk of the blank-content trap. [[Notification-Blank-Card-ZIndexBehavior]]
- 2026-09-11: arrow converted to a cloned template. [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]]
- 2026-09-11: indicator added. [[FPS-Damage-Direction-Indicator-And-Prompt-Range]]

See [[Batch Log]].
