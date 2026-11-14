---
type: decision
tags: [decision, ui, hud]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Shop-Hover-Sound.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-3.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-4.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-5.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Banner-Title-Centring-And-UI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Death-Screen-You-Died-And-Alignment.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Landing-Camera-Jolt.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Card-Fix-And-Weapon-HUD-Move.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Notification-Queue-While-Panel-Open.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CLAUDE.md (How to work in this project, rule 6; Systems, UI)"]
---

# UI and HUD Decisions

Calls about panels, the HUD, toasts and the camera. The code is in [[HUD and UI Shell]], [[Notifications]], [[Death Screen]], [[Inventory and Hotbar]] and [[Camera Authority]].

## Standing rules

- **Prefer the shared module over a local rebuild.** If a behaviour exists in `ReplicatedStorage.UI.*` or `ReplicatedStorage.Modules.*`, route through it; most historical UI bugs came from five panels each reimplementing one widget. (`CLAUDE.md`, rule 6)
- **Panel art is Figma-exported slices at 4x**; titles are baked into the banner artwork, so re-centring a title is an export change. (`CLAUDE.md`, Systems)

## Newest first

- **2026-09-24: the kill toast reads "KILLED <Name>"**; the XP line appears only on the Spraypaint kill toast. [[FPS-Kill-Toast-Title-Buy-To-Equip-Knife-Backstab]] [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- **2026-09-23: notifications queue while a panel is open** instead of being dropped, and flush on close. [[Notification-Queue-While-Panel-Open]]
- **2026-09-23: the weapon HUD moves to middle-right**, "at the user's request". [[Notification-Card-Fix-And-Weapon-HUD-Move]]
- **2026-09-19: the death banner reads "YOU DIED"**, not "YOU WERE ELIMINATED". [[FPS-Death-Screen-You-Died-And-Alignment]]
- **2026-09-19: the landing jolt fix stays light.** Two heavier options (remove the camera bob; strip its roll terms) were declined. [[FPS-Landing-Camera-Jolt]]
- **2026-09-19: FPS and Robbery UI behave the same.** Title centring and fades came over from Robbery; the shared modules stay byte-identical across the two places because they are meant to merge later; the close button is defined once in `UI.Effects`. [[FPS-Banner-Title-Centring-And-UI-Fades]] [[Shared-UI-Effects-FOV-Blur-And-Sounds]] [[Close-Button-Unified-With-Robbery]]
- **2026-09-18: notifications slide in from the top-centre** (later moved; see [[Notifications]]). [[FPS-Figma-UI-Bugfix-Pass-5]]
- **2026-09-18: no death scrim**: in game it dimmed the whole HUD and read as a fault. [[FPS-Figma-UI-Bugfix-Pass-4]]
- **2026-09-18: panels close with the X button**, "as asked". [[FPS-Figma-UI-Bugfix-Pass-3]]
- **2026-09-16: inventory slots and category tabs stay silent on hover** (crossing the panel chimed several times). [[FPS-Shop-Hover-Sound]]
