---
type: system
tags: [system, ui, death]
updated: 2026-11-18
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Death-Screen-Leveling-Tween-LevelUp-VFX.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Death-Screen-Text-Stuck-Fix-V2.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Death-Screen-You-Died-And-Alignment.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-2.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-4.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-report.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/task-4-review.md", "CrimeLifeRoblox/.superpowers/sdd/2026-11-18-open-items-pass/progress.md"]
---

# Death Screen

**Skills:** `roblox-ui`, `roblox-characters-animation` (load these for work here)

## What it does
On the local player's death: every other GUI hides, a red "YOU DIED" banner, a random taunting phrase and a respawn countdown fade in together, then a black curtain covers the respawn instant and fades back out. The HUD returns afterwards.

## Where it lives
- `StarterPlayer.StarterPlayerScripts.DeathScreen` (`runDeathSequence`).
- `ReplicatedStorage.GuiTemplates.DeathScreen`: `BlackOverlay`, `TextContainer` (a `CanvasGroup`, ZIndex 2 since 2026-11-18) with `BannerPlate`, `Phrase`, `Countdown`. `DeathScreenGui` is `ZIndexBehavior.Sibling` since 2026-11-18.
- Respawn timer: `ServerScriptService.Ragdoll.Scripts.PlayerRagdoll` ([[Ragdoll]]).
- Camera reset on death: `ReplicatedStorage.Blaster.Scripts.BlasterController`.

## How it works
- Respawn countdown is 5 s (raised from 2 on 2026-09-12, server timer matched).
- `TextContainer.GroupTransparency` tweens 1 -> 0 over `FADE_IN_TIME` 0.5 s (Quad-Out); banner, phrase and countdown fade as one.
- The banner text is pixels in `BannerPlate` (`rbxassetid://131786443590898`, 641x98, Figma group `BannerPlate · Export`, 4x). Children sit at offsets `-71 / +19 / +90` from a shared `0.5` centre.
- `BlackOverlay` is only the respawn curtain (no scrim).
- **Paint order (2026-11-18, developer decision: "renumber and switch to Sibling").** Template: `DeathScreen` z1, `BlackOverlay` z10, `TextContainer` z2 (was 5; `BackgroundTransparency` 1, no `UIStroke`, so it draws nothing itself), and `Phrase`, `Countdown`, `BannerPlate` z2. Measured with `CityMerge/phase2b/paint-order.luau`: before, the Global and Sibling lists differed by 3 swapped pairs, all overlapping (the three children against `TextContainer`); after, Global and Sibling give the same list (0 swapped pairs). The drawn objects paint in the same order before and after: Phrase, Countdown, BannerPlate, BlackOverlay. A literally identical list is impossible under Sibling, because a parent always paints before its children while Global painted `TextContainer` after them; only `TextContainer` moved, and it draws no pixels. Death in Play, 1.0 to 1.5 s after: every part at the same position and size before and after (DeathScreen and BlackOverlay 1100 x 679 at (0, -58), Phrase 1100 x 34, Countdown 300 x 60, BannerPlate 641 x 98).
- On death, `DeathScreen` records every `LayerCollector` in `PlayerGui`, disables all but its own, and restores the recorded values in the guaranteed-cleanup block (normal end, error or timeout).
- The respawn counter is captured synchronously at the instant of death; the wait for respawn is a bounded poll; the text is fully hidden between deaths.

## Extend it
- Any new element in the template takes the same ZIndex as its siblings (2), or Sibling order will put it under or over its neighbours.
- Changing the banner words is a Figma export through the same 4x pipeline, then an `Image` swap.
- The Figma frame also has a `by THUG` line and a respawn pill that the Studio template does not use (left out deliberately on 2026-09-19).

## Watch out
- `DeathScreenGui` uses `IgnoreGuiInset = true`; measure its centre against `viewport.Y / 2 - GuiService:GetGuiInset().Y` (a naive read is 58px high).
- The banner image `rbxassetid://131786443590898` does not load in a Studio session (`IsLoaded` false, `PreloadAsync` Failure, "Authentication required to access Asset"), so a Studio capture shows the phrase and the countdown pill but no banner. That is the asset-fetch class of the other ContentId lines and has nothing to do with `ZIndexBehavior`.
- Template values are the clone's resting state: a scrim set on the template sat over the HUD from spawn (2026-09-18 regression).
- Restore recorded GUI states, never `true`: `BlasterGui`, `ReticleGui`, `BlasterTouchGui`, `AdminLevelGui` are legitimately off at times.
- A fast manual respawn can race the sequence's baseline capture; keep the capture synchronous.

## History
- 2026-11-18: `DeathScreenGui` renumbered (`TextContainer` ZIndex 5 to 2) and switched to Sibling: Global and Sibling lists equal, drawn order unchanged. [[2026-11-18 Open Items Pass]]
- 2026-09-19: "YOU DIED", centred as one block (0.00px horizontal spread); fade measured, not rebuilt. Appearance not eyeballed. [[FPS-Death-Screen-You-Died-And-Alignment]]
- 2026-09-18: death hides every other GUI and restores recorded states. [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]]
- 2026-09-18: scrim removed (it dimmed the whole HUD during death). [[FPS-Figma-UI-Bugfix-Pass-4]]
- 2026-09-18: countdown centred; scrim regression on the template fixed. [[FPS-Figma-UI-Bugfix-Pass-2]]
- 2026-09-18: rebuilt to Figma: baked red banner, acid respawn pill. [[FPS-Figma-UI-Bugfix-Pass]]
- 2026-09-12: stuck text, real root cause (respawn race), from a screen recording. [[FPS-Death-Screen-Text-Stuck-Fix-V2]]
- 2026-09-12: countdown 2 -> 5 s. [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: unconditional cleanup (also the "inventory button behind a black box" bug). [[FPS-Death-Screen-Stuck-Crowbar-Desync-Lean-Turning-Errors]]
- 2026-09-11: camera no longer stuck in first person after dying while equipped. [[FPS-Rifle-Enemy-Balance-Death-Camera-Cleanup]]
- 2026-09-11: first death screen (blur, phrase, black-screen respawn). [[FPS-Death-Screen-Leveling-Tween-LevelUp-VFX]]

See [[Batch Log]].
