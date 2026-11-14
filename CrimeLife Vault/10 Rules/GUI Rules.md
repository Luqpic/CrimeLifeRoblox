---
type: rule
tags: [rule, gui, ui]
updated: 2026-11-14
sources: ["CLAUDE.md (Systems: UI; Known traps)", "70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "70 Batches/FPS System/Close-Button-Unified-With-Robbery.md", "70 Batches/FPS System/FPS-Dialogue-Responses-Clickable-Fix.md", "70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md", "OBT Vault/10 Rules/GUI Rules.md (generic parts)"]
---

# GUI Rules

## Rule

- **Route through the shared UI modules.** `UI.Panels` owns HUD visibility and panel exclusivity; `UI.Effects` owns hover, click and close-button behaviour; `UI.Transitions` owns fades; `UI.Theme` holds the look; `Modules.CameraAuthority` arbitrates camera claims; `Modules.MenuFovBlur` reference-counts blur; `Modules.NotificationController` owns toasts. A new panel uses them; it does not rebuild them ([[Shared Code Extended by Attributes]]).
- **Clickable UI lives under the player's PlayerGui.** A GUI parented into the world is drawn but never hit-tested for the mouse; point a PlayerGui GUI at the world object with `Adornee` instead ([[Billboard and World GUI Traps]]).
- **Panel art is Figma-exported slices at 4x** via the REST `/v1/images` pipeline ([[Figma and UI Art Pipeline]]). **Titles are baked into the banner artwork**, so re-centring a title is an export change, not a layout property.
- **No text may overlap or clip**, and no outline may be cut off. Measure with `AbsolutePosition` / `AbsoluteSize`, not with the arithmetic you intended ([[Verify in Edit and by Screenshot]]).
- **A layout owns what it stacks.** Never animate Position or Size of a child under a `UIListLayout` or `UIGridLayout`; animate a `UIScale` or a wrapper ([[UI Layout Traps]]).
- **Mind the Known traps** before any GUI change: `UIPadding` offsets children; a `CanvasGroup` does not fade its own `UIStroke`; `ZIndexBehavior` is per ScreenGui; `AnchorPoint` and `Position` must agree; `AbsolutePosition` sits below the top-bar inset. All in [[UI Layout Traps]].
- **Clicks must work on touch** (no hover-only action; a drag is not a click). [[Phones First and Keep Optimised]]

## Why

- `CLAUDE.md`: "Most historical bugs in this place came from five panels each reimplementing the same widget."
- [[FPS-Dialogue-Responses-Clickable-Fix]]: replies in a world-parented billboard were visible but dead to the mouse; two wrong theories (the weapon's mouse lock, drawing through walls) were tried first.
- [[FPS-Banner-Title-Centring-And-UI-Fades]]: "The titles are baked into the plate artwork, so centring them is an export change, not a layout property."
- [[FPS-Figma-UI-Bugfix-Pass]]: two panels had `ClipsDescendants = true` and cut off the banner overhang where the title sits.
- [[Close-Button-Unified-With-Robbery]]: the close button was unified across both places through the shared effect code.

## How to apply

- Before a GUI change, read [[HUD and UI Shell]] and the panel's own system note.
- After it: read back `AbsolutePosition`, `AbsoluteSize`, `AbsoluteCanvasSize` for every touched element, and screenshot when the viewport renders ([[Screen Captures]]).
