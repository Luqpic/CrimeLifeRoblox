---
type: system
tags: [system, ui, hud]
updated: 2026-11-18
sources: ["70 Batches/2026-11-17 Known Issues Pass.md", "70 Batches/2026-11-17 Police and Wanted.md", ".superpowers/sdd/2026-11-17-police-and-wanted/task-4-report.md", "CLAUDE.md (Instance tree, Systems, Known traps)", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-1to1-Image-Export-And-Font-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md … Pass-5.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Polish-And-Denied-Feedback.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Close-Button-Unified-With-Robbery.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-UltimateUIPack-Effects-Integration.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-6-report.md"]
---

# HUD and UI Shell

**Skills:** `roblox-ui`, `roblox-architecture`, `roblox-audio` (load these for work here)

## What it does
The frame every screen sits in: the five HUD buttons (weaponary, player card, quests, cash shop, gamepass), panel exclusivity, HUD hide while a panel is open, menu blur, shared hover/click/close-button behaviour and sounds, fades, responsive scale, and the Figma-exported art (icons, baked banners). Shared with the Robbery place by byte-identical modules so the two can be merged.

## Where it lives
- `ReplicatedStorage.UI.Panels`: panel exclusivity, `HUD_GUIS`, `setHudHidden`, `current()`, `onChanged(callback)`.
- `ReplicatedStorage.UI.Effects`: hover / press styles, `CLOSE_IMAGE`, `CLOSE_SIZE`, `bindClose()`. Byte-identical with the Robbery copy.
- `ReplicatedStorage.UI.Sounds`: `bind`, `CLICK_SOUND_ID` (`rbxassetid://8816939097`), `denied()` (`rbxassetid://138405257788302`).
- `ReplicatedStorage.UI.Transitions` + `StarterPlayer.StarterPlayerScripts.UiTransitionBinder`: fades. Same module as the Robbery place.
- `ReplicatedStorage.Modules.MenuFovBlur` (reference-counted blur + FOV pull, see [[Camera Authority]]).
- `StarterPlayer.StarterPlayerScripts.HudButtonEffects`: one binder for all five HUD buttons.
- `StarterPlayer.StarterPlayerScripts.UIScaleController`: gives each `ScreenGui` a `ResponsiveScale` `UIScale` (`MAX_SCALE = 1`) unless it ships its own.
- `ReplicatedStorage.GuiTemplates.*`: panel templates (WeaponaryShop, PlayerCard, QuestLog, DeathScreen, Notification, WeaponCard, EnemyGUI, ...).
- `StarterGui."Custom Inventory"`: the HUD button column and hotbar ([[Inventory and Hotbar]]).
- `ReplicatedStorage.Blaster.Scripts.GuiController`: ammo / weapon-name HUD (desktop: middle-right).
- City, `ZIndexBehavior = Sibling` (one line after `Instance.new("ScreenGui")`, each script marked `CityMergeDeviation`): `StarterPlayerScripts.PromptUiController`, `AdminLevelController`, `DamageDirectionIndicator`, `ReplicatedStorage.UI.CashBurst`. Audit: `CityMerge/phase2b/zindex-audit.md`; tool: `CityMerge/phase2b/paint-order.luau`.
- City, 2026-11-17: `StarterPlayer.StarterPlayerScripts.WantedHud` builds the `WantedHud` star meter in code ([[Police and Wanted]]).
- Robbery place: `StarterPlayerScripts.UiButtonEffects` (focus mode), `Modules.PropertyAuthority`, `Modules.CameraAuthority`.

## How it works
- **One panel at a time.** Each panel hands `UI.Panels` its own close function; opening another calls it, so the panel closes through its own code path. Opening any panel hides `Custom Inventory`, `StaminaGui`, `LevelingGui`, `BlasterGui`, `ReticleGui`, `BlasterTouchGui` and restores each to its prior value (the blaster GUIs are per-equip, so never restored blindly to `true`). Exit is the X.
- **`Panels.onChanged`** fires on every open/close and once on subscribe. Subscribers: player nameplate prompts ([[Nameplates and Billboards]]), the notification queue ([[Notifications]]).
- **Close buttons:** one 36x36 `ImageButton` on the shared Figma slice via `Effects.bindClose()`; hover grows 36 to 39.6 with one hover sound, click sound on press. Call sites: PlayerCard, QuestLog, CashShop, GamepassShop, WeaponaryShop, AdminLevel.
- **HUD buttons:** `HudButtonEffects` reproduces the UltimateUIPack motion (hover 1.1, click bounce) plus `Sounds.bind`; base size/position captured once at bind time. Per-button scripts cannot live in `Custom Inventory` (restricted `Capabilities`).
- **Menu blur:** WeaponaryShop and PlayerCard raise/lower `MenuFovBlur`, reference-counted so closing one of two open menus does not drop the effect.
- **Fades:** `UiTransitionBinder` fades the HUD chrome and the four panel frames; combat elements fade faster than chrome.
- **Art:** Figma `iRetcvpbMMD190DJA9Mwrm`, page "02 · Redesign", exported via REST `/v1/images` at 4x. Icons whitened so `ImageColor3` can tint them (accent `#CBF23C`). Panel titles are baked into banner images in real Archivo Black; re-centring a title is a re-export.
- **Fonts:** only the Roblox catalogue resolves; Archivo/Barlow do not. Dynamic Archivo Black -> `Montserrat Heavy`, Barlow Semi Condensed 600/500 -> `RobotoCondensed SemiBold/Medium`.

## Puzzles in `UI.Panels` (city, 2026-11-18)
- The heist modals register with `UI.Panels` through their owners, each with a closer that is its own X path and calls `Panels.closed`: `HeistClient` (duffel upgrade dialog: its slide-out, registered once; safe keypad: `closeSafeGui`; lockpick: `exitLockpick`, which also tells the server) and `WordScrambleClient` (word scramble: `exitWordScramble`; hack code: `closeHackCodeGui`). Opening a city panel mid-puzzle closes the puzzle like its X; the HUD and star meter hide while a puzzle is open; heist cards queue behind it. A closer must be declared before the `Panels.opened` call that uses it (a forward use passed nil, caught and fixed in the Task 6 fix round: B over the scramble opened the shop with 0 server exits, now 1).
- The safe keypad releases the text focus of each digit box on close (it kept `Digit1` focused after a seal, death or panel close). A real-keyboard check is still open.
- `LevelingHud.placePopup`: the popup's scale follows the heist HUD's `UIScale` (`fullScale = heistScale / levelingScale`, the small-screen fit clamped to it); a `ViewportSize` change while the popup is shown (hold and fade) places it again; the camera is followed as `WantedHud` does. At 1100 x 679 the popup is (370, 262) 360 x 90, scale 1, overlapping nothing; 844 x 390 is computed (256 x 64, scale 0.71).
- `UIScaleController` caps every scale at 1 (`MAX_SCALE`), read back 1.000 on `LevelingGui`, `HeistHUD`, `HeistModals`, the shops and the puzzles; `NotificationGui` and `WantedHud` own a `UIScale` 1.000. So `LevelingGui` is never raised above 1; the ratio only matters below the fit (a viewport under 447 px wide shrinks `HeistHUD`, under 383 px `LevelingGui`).

## The star meter (city, 2026-11-17)
[[2026-11-17 Police and Wanted]]. `WantedHud` (LocalScript) builds a ScreenGui in code: `ZIndexBehavior = Sibling`, `ResetOnSpawn = false`, `ScreenInsets = CoreUISafeInsets`, its own `UIScale` of 1 (so `UIScaleController` leaves it alone).
- A 148 x 36 `UITheme` plate (`Color.panel` at 0.15, `UICorner` 8, `UIStroke` in `Color.line`) with five U+2605 text glyphs in `UITheme.Font.Display`: filled `Color.gold`, empty `Color.muted` at 0.55. No star slice exists and nothing was uploaded.
- Each star is a `ClipsDescendants` frame whose width maps the fraction over the glyph's ink: `round((24 - ink) / 2 + fraction * ink)`, ink = measured `TextBounds.X` (16.5).
- While `WantedSeen`: the stroke turns `Color.danger` and pulses (transparency 0.8 to 0, thickness 1 to 2.5). While `WantedDraining`: the next star to go blinks. Hidden at 0 heat and while a `UI.Panels` panel is open.
- Position: top centre, `(0.5, +160, 0, 6)` left-anchored (desktop: right of the heist column, clear of the chat bar); when the viewport's smaller side is under `Blaster.Constants.UI_SMALL_SCREEN_THRESHOLD` 500, `(0.5, -160, 0, 6)` right-anchored (clear of the heist cards). Re-placed on every `ViewportSize` change and on a camera swap (nil-safe `CurrentCamera`).
- Measured at 1080 x 659 during a real robbery: 0 overlaps with 40 drawn elements and 98 heist and HUD elements; 844 x 390 computed, not measured. From the fifth simultaneous heist card at 1080 wide, the cards reach the meter (computed).

## Extend it
- A new panel: register with `UI.Panels` (its own close function), use `Effects.bindClose()`, raise `MenuFovBlur`, route camera through [[Camera Authority]]. Reuse `WeaponCard` for card templates (cosmetics spec).
- A new `ScreenGui` built with `Instance.new`: set `ZIndexBehavior = Sibling` explicitly. To flip an existing one, measure its paint order under both modes first (`CityMerge/phase2b/paint-order.luau`) and flip only when the order is equal.
- Keep `UI.Effects` / `UI.Transitions` byte-identical across both places; change both or neither.

## Watch out
- `UIPadding` offsets children as well as text; give a button a `Label` child instead (cost two passes on the shop's price pill).
- A template's property values are the clone's resting state. Anything that fades needs its hidden state asserted in code for every sub-element (death scrim, dialogue plate, level-up popup twice).
- A `CanvasGroup`'s `GroupTransparency` does not fade its own `UIStroke`.
- `ZIndexBehavior` is per `ScreenGui`. In the city since 2026-11-15 `NotificationGui`, `PromptUiGui`, `AdminLevelGui`, `DamageDirectionIndicator` and `CashSpendBurst` are `Sibling` (paint order measured equal). `DeathScreenGui` joined them on 2026-11-18 after its `TextContainer` was renumbered 5 to 2 ([[Death Screen]]). Still `Global`: `CashShopGui`, `GamepassShopGui`, `WeaponaryShopGui`, `QuestLogGui` and `Custom Inventory`, because `Sibling` would change their order (swapped pairs 233, 51, 609, 2, 123 in the 2026-11-15 audit) ([[Open Items]]). `Freecam` was not measured.
- `PromptUiController` restyles a streamed-in prompt (checked 2026-11-18): a non-persistent prompt that the server leaves at `Default` held Style Custom on the client (28 client prompts), the client dropped it when the character was moved 1,722.7 studs away (8 prompts after 12 s), and on return to 5.41 studs with line of sight it was back with Style Custom while the server still read Default (29 prompts, all Custom) and `PromptUiGui` held an enabled `PromptUI` billboard adorned to it. No change was needed. Test from a spot with a clear line: at 6.0 studs the camera ray hit `Bar+Stage.Part107`.
- A `ScreenGui` with no `UIScale` of its own gets scaled up by `UIScaleController` on wide viewports.
- Images lazy-load: `IsLoaded = false` on a hidden GUI is not a bad asset id.
- `multi_edit` `replace_all` has reported success while under-applying, in both places; grep for the inserted text after editing.
- `ReplicatedStorage.UI.Theme` was dead code and was deleted on 2026-09-18 (its asset registry survives in the Figma change logs). Styling lives on instances.

## History
- 2026-11-18: heist puzzles register with `UI.Panels`; `LevelingHud` re-lays out on a viewport resize; `UIScaleController` cap 1 confirmed (every scale 1.000); safe keypad focus released on close; `WantedHud` header comment only. [[2026-11-18 Open Items Pass]]
- 2026-11-18: `DeathScreenGui` joined the `Sibling` list; the admin panel title reads "Admin: Set Level" (it used a spaced hyphen after "Admin", `AdminLevelController`); the streamed-in prompt restyle was measured and left unchanged. Name/tag separators (the hyphen between a quest giver's name and its level on the nameplate) are kept, like the one in "Name - [$Price]". [[2026-11-18 Open Items Pass]]
- 2026-11-17: level-up popup placement: `LevelingHud.placePopup` reads the live heist HUD boxes; desktop, the popup's top sits on the toast's bottom edge (centred, full size); a smaller side under `UI_SMALL_SCREEN_THRESHOLD` 500 scales it to the gap left of the duffel (0.71 at 844 x 390) and centres it on the duffel vertically; no heist HUD, the template's place. Measured live at 1100 x 679: the popup overlaps nothing (before: the getaway widget 240 x 34, the toast 360 x 48). 1080 x 659 and 844 x 390 are computed, not seen; the phone layout (clearing the star meter by 2 px) never ran live. [[2026-11-17 Known Issues Pass]]
- 2026-11-17 (city): the `WantedHud` star meter. [[2026-11-17 Police and Wanted]]
- 2026-11-15 (city): four ScreenGuis flipped to `Sibling` where the paint order is unchanged; six left `Global` with counts recorded. [[2026-11-15 FPS Hardening In City]]
- 2026-09-23: ammo/weapon HUD moved bottom-right to middle-right (`AnchorPoint (1,0.5)`); touch layout untouched. [[Notification-Card-Fix-And-Weapon-HUD-Move]]
- 2026-09-19: close buttons unified on `Effects.bindClose()` (five sizes/shapes/behaviours -> one 36px slice). [[Close-Button-Unified-With-Robbery]] / [[Close-Button-Unified-With-FPS]]
- 2026-09-19: titles re-centred in banner plates; `UI.Transitions` + `UiTransitionBinder` fades ported from Robbery. [[FPS-Banner-Title-Centring-And-UI-Fades]]
- 2026-09-19 (Robbery): `UI.Sounds`, `UI.Effects`, `PropertyAuthority`, `CameraAuthority`, `MenuFovBlur` ported verbatim; focus mode hides the HUD around puzzles; effects reset when a button is hidden. [[Shared-UI-Effects-FOV-Blur-And-Sounds]]
- 2026-09-19 (Robbery): `UI.Transitions` written; counts its own writes because deferred property signals defeat a suppress flag. [[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]]
- 2026-09-18: `Panels.onChanged`; click sound id; `Sounds.denied()` + red flash on unaffordable buy (client feedback only, server still validates). [[FPS-Shop-Polish-And-Denied-Feedback]]
- 2026-09-18: dead-code audit of 170 scripts: `UI.Theme`, `QuestResponsesBillboard`, `WeaponStatPanel` removed; `Workspace.UI.OverheadGui` per-frame error fixed. [[FPS-Quest-Overflow-And-Dead-Code-Removal]]
- 2026-09-18: Figma UI passes 1-5: banner clipping, price pill, stat bars, stamina stroke fade, `UI.Panels` exclusivity, `HudButtonEffects`, PlayerCard stats. [[FPS-Figma-UI-Bugfix-Pass]], [[FPS-Figma-UI-Bugfix-Pass-2]], [[FPS-Figma-UI-Bugfix-Pass-3]], [[FPS-Figma-UI-Bugfix-Pass-4]], [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-18: 59 of 95 text instances were on a fallback font; icons and five baked banners exported from Figma at 4x. [[FPS-Figma-1to1-Image-Export-And-Font-Fix]]
- 2026-09-18 (Robbery): GUI audit and Figma redesign on the FPS library's theme; slice background/anchor fixes. [[GUI-Audit-And-Figma-Redesign]], [[Slice-Transparency-And-Anchor-Fixes]], [[UI-Bug-Fixes-Notification-HUD-Lockpick-Titles]]
- 2026-09-16: menu blur via `MenuFovBlur`, cursor reactions from UltimateUIPack; shared hover tick and menu-button click sounds. [[FPS-UltimateUIPack-Effects-Integration]], [[FPS-Shop-Hover-Sound]]
- 2026-09-11: stamina, leveling, stat panel and damage arrow converted to `GuiTemplates`. [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]]

See [[Batch Log]].
