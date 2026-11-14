---
type: tool
tags: [tools, phone, testing, emulator]
updated: 2026-11-14
sources: ["70 Batches/FPS System/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md", "70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "OBT Vault/40 Tools/Phone Testing.md (generic parts)"]
---

# Phone Testing

How to test CrimeLife on a phone layout in Studio. **No phone or emulator pass of CrimeLife is recorded.** The blaster has a touch HUD (`BlasterTouchGui`, hidden with the other blaster GUIs on death, [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]]), and the weapon HUD has a separate touch branch ([[Notification-Card-Fix-And-Weapon-HUD-Move]]).

## Claude cannot switch the device

The MCP sends mouse and keys into the running game only, not into Studio's chrome. Claude **cannot press Studio's device emulator toggle** or any toolbar button. When a batch touches the HUD, ask the developer (in the picker round) to set the emulator to a phone before they leave, then test in that state. ([[Ask First Then Build]])

## What to check (generic, from OBT)

- Every panel opens, closes and fits (read `AbsolutePosition` / `AbsoluteSize` against `ViewportSize`).
- Nothing is hover-only; a drag is not a click.
- Full-screen covers on notched phones need `ScreenInsets = None`, or the world shows in side strips.
- After an emulator pass, re-check the desktop layout (emulator off). Something tested only on desktop is "NOT seen in a phone emulator" in the batch note.

## Gotchas (OBT, same MCP)

- The touch-only emulator ignores MCP mouse clicks: select the button through `GuiService.SelectedObject` and press Enter, which fires `Activated` like a tap.
- Missing thumbstick and jump after such a "tap" is not a bug: the last input stays Keyboard, so Roblox's PlayerModule hides touch controls until a real touch.
- The emulator reports mouse and keyboard for a moment after Play starts: layout code reads the input type at layout time and on change, never once at load.
- A Frame with AutomaticSize XY around a wrapping UIListLayout measured 21,495,824 px wide on a phone emulator ([[UI Layout Traps]]).

Related: [[Tools MOC]] · [[Phones First and Keep Optimised]] · [[HUD and UI Shell]]
