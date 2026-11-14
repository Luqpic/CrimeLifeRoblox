---
type: howto
tags: [howto, ui, panels]
updated: 2026-11-14
sources: ["CLAUDE.md (Systems: UI; Known traps)", "CrimeLifeRoblox/FPSSystem/Cosmetics/WeaponaryShopController.luau", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Close-Button-Unified-With-Robbery.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Figma-Image-Export-Pipeline.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Skins-Card-Detached-And-Palette-Expansion.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md"]
---

# Add a Menu Panel

A new full-screen or HUD-opened panel built on the shared UI modules. Never rebuild a widget that a shared module already owns (five panels with five close buttons is how the X button drifted). System: [[HUD and UI Shell]]. Rules: [[GUI Rules]].

Skills: `roblox-ui`, `roblox-input` (if it claims the camera or mouse).

## Steps
1. **Design in Figma** and export the chrome as slices ([[Figma and UI Art Pipeline]]). Static titles are baked into the banner art; anything that changes at runtime stays native.
2. **Build a template** in `ReplicatedStorage.GuiTemplates.<Panel>`; the controller clones it (not `Instance.new`). Instance names are an API: controllers index by name.
3. **Controller** in `StarterPlayer.StarterPlayerScripts`, wired to:
   - `UI.Panels`: `Panels.opened("<Panel>", closeFn)` on open and `Panels.closed("<Panel>")` on close. It owns exclusivity and HUD hiding (`HUD_GUIS`, `setHudHidden`); [[Notifications]] queue while `Panels.current()` is set.
   - `Modules.MenuFovBlur.open()` / `.close()` (reference-counted).
   - `Modules.CameraAuthority` for any camera property; never write the camera directly ([[Camera Authority]]).
   - `UI.Effects.bindClose()` for the X (shared slice, `CLOSE_SIZE` 36), and `UI.Effects` hover and click behaviour.
   - `UI.Sounds.bind(button)` (or `hover` / `click` / `denied`).
   - `UI.Transitions.fade` for open and close; `UiTransitionBinder` fades panel frames on visibility.
4. **Opener:** a HUD button in `StarterGui."Custom Inventory"`; scripts cannot be parented there, so sound and motion are driven from the controller.
5. **Respawn:** `ResetOnSpawn = false`, like every GUI in this game.
6. **Layering:** `ZIndexBehavior` is a ScreenGui-wide setting. A panel that must sit beside another GUI without re-layering it gets its own `Sibling` ScreenGui with a higher `DisplayOrder` (the Skins card).
7. **Grids** that can grow are ScrollingFrames from the start (the Gamepass shop overflowed at its seventh card).

## Files to touch
`GuiTemplates.<Panel>`, a new controller, the HUD button. Mirror controllers into `FPSSystem/<area>/`.

## Check
- Open it by a real click on the HUD button, not by forcing `Visible`.
- Read back `AbsolutePosition` / `AbsoluteSize` / `AbsoluteCanvasSize`; add `GuiService:GetGuiInset()` when comparing with an inset-ignoring GUI.
- One hover sound and one click sound per action; close returns HUD, blur and camera.

## Done before
[[FPS-Weaponary-Shop-Refactor]], [[FPS-Player-Card-System]], [[FPS-Figma-1to1-Image-Export-And-Font-Fix]], [[Close-Button-Unified-With-Robbery]], [[FPS-Banner-Title-Centring-And-UI-Fades]], [[FPS-Skins-Card-Detached-And-Palette-Expansion]], [[FPS-Gamepass-Shop-Scrolling-Grid]].
