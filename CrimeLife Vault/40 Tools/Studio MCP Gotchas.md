---
type: tool
tags: [tools, mcp, testing, gotchas]
updated: 2026-11-14
sources: ["docs/superpowers/plans/2026-09-23-persistence-phase-3.md (The medium)", "70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "70 Batches/FPS System/FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel.md", "70 Batches/FPS System/FPS-Quest-Givers-Law-Enforcement-Outfits.md", "70 Batches/FPS System/FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget.md", ".superpowers/sdd/uploaded-asset-ids.md", "OBT Vault/40 Tools/Studio MCP Gotchas.md (generic parts)"]
---

# Studio MCP Gotchas

Quirks of the `Roblox_Studio` MCP harness itself: `execute_luau`, `user_mouse_input`, `user_keyboard_input`, `screen_capture`, `upload_image`. Engine behaviour that would also hit real players is in [[Engine Traps MOC]]; capture quirks are in [[Screen Captures]]. Items marked "(OBT)" were found on the developer's other project with the same MCP server and have not been re-tested on CrimeLife.

## execute_luau

- **It runs in its own Luau VM with its own `require` cache, on the client as well as in Edit.** A manual `require` of the already-loaded `SkinsCardController` from `execute_luau` built a second, independent `SkinsCardGui` in the same PlayerGui ([[FPS-Skins-Card-Detached-And-Palette-Expansion]]). Do not monkey-patch a module and expect running scripts to see it; do not call a module directly to "test" it. Drive verification through real engine events, or add a temporary diagnostic inside the real script, then remove it and re-diff against the mirror.
- **Instances are shared.** Property reads on real instances are reliable from any call; module state is not.
- **An Edit `require` serves a stale module after an in-session edit** and does not invalidate on its own. Suites run that way gave false failures (127 / 132) and passed in a fresh Play ([[Unit Test Runner]], [[FPS-Viewmodel-Hands-Off-Weapon]]). Require a `:Clone()` or read `Source` in Edit.
- **Separate calls miss short-lived things.** One call to fire a gain and a later call to poll the card missed its ~4.4 s lifecycle entirely. Fire and poll inside a **single** call ([[Notification-Card-Fix-And-Weapon-HUD-Move]]).
- **Calls run one at a time.** A `user_mouse_input` call cannot be merged into an `execute_luau` call; a check that needs a click in between must widen its own windows (that pass widened `HOLD_TIME` to 25 s temporarily).
- **`datamodel_type` is `"Edit"`, `"Server"` or `"Client"`**, capitalised.
- **Source edits:** after any edit, read `Source` back, check its length moved as expected, find the new text with `string.find(src, needle, 1, true)` and confirm the old text is gone. `string.gsub` with `(`, `)`, `.` or `-` in the pattern silently replaces nothing ([[Luau and Scripting Traps]]).
- **Checksums:** compare Studio and the mirror with Adler-32. An FNV-1a attempt in Luau gave different hashes for identical text (`bit32` products past 2^53 lose precision) ([[FPS-Skins-Card-Sticky-Fix-Responsive-Scale-Budget]]).
- One reply is capped near 100k characters; a script's `Source` cannot reach 200,000 characters through the call (OBT).

## user_mouse_input and keyboard

- **Nothing can be clicked while the viewport is collapsed.** With `ViewportSize` 1, 1 and 0 RenderStepped per second, simulated clicks do not land, `screen_capture` hangs or returns magenta, and tweens freeze ([[FPS-Skins-Card-Detached-And-Palette-Expansion]], [[FPS-Spraypaint-Phase-2]]). Read `workspace.CurrentCamera.ViewportSize` first; recorded working sizes include 1120 x 719, 812 x 719, 900 x 719 and 1208 x 719.
- **An equipped weapon locks the cursor at screen centre** (`MouseBehavior` `LockCenter`). A click test measures cursor movement, never a distance to a frame ([[Camera and Input Traps]]).
- **Drags are unreliable.** "Simulated mouse input drives drags unreliably": a long drag released over empty space could not be re-confirmed on demand ([[FPS-Hotbar-Icon-Clash-And-Drag-Drop-Feel]]).
- **Quest prompts could not be triggered by automated input** on 2026-09-24, with or without an outfit; talking to a quest giver needs a person pressing E ([[FPS-Quest-Givers-Law-Enforcement-Outfits]]).
- Coordinates are viewport coordinates, already below the top-bar inset: use `AbsolutePosition` directly (OBT).
- A failed call can leave the virtual button down ("duplicate button state"); send a `mouseButtonUp` first. A click off-screen hangs the harness (OBT).
- `user_keyboard_input` takes `key_code`; it cannot press Esc to close Roblox's menu, and every key fails while `GuiService.MenuIsOpen` (OBT).
- A TextBox is typed from a Client call: `box:CaptureFocus()`, set `Text`, `box:ReleaseFocus(true)` (OBT).
- A fake purchase prompt leaves an invisible dialog that eats later clicks: record prompts through a seam in tests (OBT).

## Other tools

- **`upload_image` takes http / https URLs only, never a local path.** Serve the PNGs from a temporary localhost HTTP server and stop it straight after ([[Icon Pipeline]]; asset ids in `CrimeLifeRoblox/.superpowers/sdd/uploaded-asset-ids.md`).
- **`start_stop_play`** runs solo Play only; a multiplayer test needs the developer ([[Two-Player Test]]).
- The MCP cannot press Studio's own toolbar (device emulator, Test > Clients and Servers) ([[Phone Testing]]).
- `script_grep`, `script_search`, `script_read`, `search_game_tree`, `inspect_instance` read the live place: the cheapest way to "read before you edit" ([[Code Graph]]).

## Moving the tester

- The client owns its character: a server `PivotTo` of a player is overwritten; move it from the Client (OBT; [[Physics and Character Traps]]).
- Enemies walk: a target placed and shot a beat later has moved. Place with position only, not the shooter's full `CFrame` (which put a target at Y = -0.65 under the floor) ([[FPS-Shotgun-Kill-Knockback]]).

Related: [[Tools MOC]] · [[Screen Captures]] · [[Studio Host and Instance Id]]
