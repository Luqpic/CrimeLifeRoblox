---
type: system
tags: [system, robbery, ui, prompts, shared]
updated: 2026-11-16
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Figma-ProximityPrompt-Redesign.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Figma-ProximityPrompt-Redesign.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Size-And-Ring-Starts-Empty.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Liquid-Fill-And-Animations.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Liquid-Shape-And-Hover-Lift.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Circle-Liquid-And-Glow.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Prompt-Closes-When-Disabled.md"]
---

# Robbery Prompts

**Skills:** `roblox-ui`, `roblox-input` (load these for work here)

Built for the Robbery System place; the same two scripts run **byte-identical in the FPS System place** too, and in Crimelife City, where `PromptUiController` (edited there only for `ZIndexBehavior = Sibling`, phase 2b) restyles every prompt, the four heists' included.

## What it does
Replaces Roblox's default proximity prompt everywhere with the project's own face: a circle carrying only the key letter (no action or object text), a faint accent halo, and a liquid fill that rises bottom-to-top while the key is held. It pops in, fades out, lifts on hover or press, and closes when its prompt is disabled.

## Where it lives
- `ReplicatedStorage.UI.PromptUI`: builds the billboard, owns the fill and animations.
- `StarterPlayer.StarterPlayerScripts.PromptUiController`: forces every prompt to `Style = Custom`, drives create / fill / destroy off `ProximityPromptService`.
- Figma file `Roblox`, page `05 · ProximityPrompt` (reference states; the shipped prompt no longer uses its slices).
- Counts converted on 2026-09-19: 11 prompts in Robbery (holds up to 8 s on safes and barriers), 22 in FPS (holds 0 and 1 s).

## How it works
- **One frame, one shape, one gradient:** a circle via `UICorner` 0.5 on the frame that draws, border from its `UIStroke`, fill as a two-keypoint hard stop in its `UIGradient` (rotation 90). Nothing rotated, clipped, stacked or masked.
- `Root` is a `CanvasGroup` sized `BOX` (76 px; plate 52 px) so the halo fits. Entrance: transparency 1 -> 0 with a 0.82 -> 1 scale pop, Back easing, 0.16 s. Exit: fade with slight shrink, 0.10 s, then destroy.
- Progress is assigned every frame from the hold's elapsed time (not tweened), with a skip when unchanged. Triggering drains the meter.
- Hover and hold share one lifted state: prompt swells to 1.07, halo brightens 0.82 -> 0.55; the letter does not move. The billboard has `Active = true` so the cursor reaches it; where the mouse is locked (aiming) the hold path drives the same state.
- `HoldDuration = 0` prompts fire instantly and stay an empty outline.
- While a face is up the controller watches its prompt's `Enabled`; going false fades and destroys the face (disabling a shown prompt does not fire `PromptHidden`).
- `Style = Custom` is saved on each prompt **and** re-asserted at runtime, so a prompt added later cannot draw Roblox's text.

## Extend it
- Change size by `BOX` only; every other measurement derives from it.
- Edit both places together: the files are kept byte-identical (checksum them).
- A new prompt needs nothing: the controller picks it up. Gate it with `Enabled` and the face closes itself.

## Watch out
- `ClipsDescendants` does not clip a rotated descendant; `UICorner` does not affect `ClipsDescendants`; two coincident soft-edged shapes bleed a ~1 px rim; `UICorner` does not mask a `CanvasGroup`. Each cost an attempt (2026-09-19).
- `BillboardGui.Active` defaults to false: an `Instance.new` billboard gets no input.
- `screen_capture` returns a blank frame in Play, so every check was numeric; the final look was confirmed by eye by the developer only for the circle version.
- Automation could not trigger `Style = Custom` quest prompts in the FPS place on 2026-09-24; a person should press E once ([[Quests and Dialogue]]).
- **Automation shows a prompt only while its part is on screen.** In the city's first run a prompt could be held through `InputHoldBegin` / `InputHoldEnd` only with the camera aimed at its part; with the first-person camera facing away, `InputHoldBegin` and a real E press did nothing ([[Open Items]]).
- Prompts on NPCs whose prompt part sits inside the rig need `RequiresLineOfSight = false`.

## History
- 2026-11-20: holding a robbery prompt (and an open lockpick, hack or word-scramble minigame) plays a clip on the player's character that everyone sees (`StarterPlayerScripts.InteractionAnimations`, ids in `ReplicatedStorage.Combat.Clips`). [[2026-11-20 Interaction Animations and Takedown Prompt]]
- 2026-11-16 (city): the heist prompts (registers, terminals, C4, `Go to Vault`, `Vault Door`, `Return to Lobby`) run on this face; of the city's 26 old leftover prompts, 2 went with the quarantined art buildings and 4 are still in `Workspace.Map` (casino, warehouse), all saved `Default` and forced to `Custom` at runtime; where the other 20 are is not recorded (Open Item). [[2026-11-16 Robbery Systems Into City]]
- 2026-09-19: circle with `UIGradient` liquid and halo, settled after four failed outline fixes (confirmed by the developer). [[Prompt-Circle-Liquid-And-Glow]]
- 2026-09-19: disabled prompts close their face. [[Prompt-Closes-When-Disabled]]
- 2026-09-19: liquid takes the plate's shape; hover and hold lift. [[Prompt-Liquid-Shape-And-Hover-Lift]]
- 2026-09-19: ring replaced by liquid fill (48 segments -> 8 instances); entrance and exit. [[Prompt-Liquid-Fill-And-Animations]]
- 2026-09-19: half-disc ring broken (rotated clip), rebuilt as 48 segments; `BOX` 116 -> 76. [[Prompt-Size-And-Ring-Starts-Empty]]
- 2026-09-19: Figma prompt design replaces the default face in both places. [[Figma-ProximityPrompt-Redesign]]

See [[Batch Log]].
