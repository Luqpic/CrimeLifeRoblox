---
type: system
tags: [system, robbery, puzzles, ui]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/NewsStation-Hacking-Randomize-Word-Button.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/UI-Bug-Fixes-Notification-HUD-Lockpick-Titles.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Shared-UI-Effects-FOV-Blur-And-Sounds.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Figma-Slices-Imported-To-Studio.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/RobberySystem/Performance-Optimization-And-Unification.md"]
---

# Robbery Puzzles

**Skills:** `roblox-ui`, `roblox-security`, `roblox-networking` (load these for work here)

**Robbery System place** only.

## What it does
The obstacles inside each robbery ([[Robbery Heists and Getaway]]): lockpicking locked doors, the NewsStation word-scramble hack, the safe keypad, and the Bank's gauntlet (Terminal 1 -> Terminal 2 -> C4 -> vault). Opening a puzzle panel puts the player in focus mode.

## Where it lives
- Server: `ServerScriptService.Heist.Components.MasterComputer` (NewsStation hack), `ReplicatedStorage.SharedSystems.LockedDoor` (lockpick), Bank components (Terminals, C4, GuardPost, VaultDoor), NewsStation Safe / oil hazard.
- Client: `StarterGui.LockpickGui`, `HackCodeGui`, `WordScrambleGui` (+ `StarterPlayerScripts.WordScrambleClient`), the safe keypad in `HeistClient`, focus mode in `StarterPlayerScripts.UiButtonEffects`.
- Remotes in `ReplicatedStorage.HeistShared.Remotes` via `Net` (one remote per event, e.g. `RandomizeWordRequested` / `Net:OnRandomizeWordRequested`).
- Specs under `ServerScriptService.Heist.Tests` (e.g. `MasterComputerSpec`).

## How it works
- **Word scramble:** 3 sequential anagram rounds from a 24-word pool (words 5-9 letters). "Randomise Word" gives **3 re-rolls per attempt, not per round** (developer's call); a swapped word is marked used so it cannot return in the same attempt. Letter tiles are built natively so any word length fits.
- **Lockpick:** the drawn success arc is rebuilt at the server's exact zone widths and picked by nearest match, so the drawn arc equals the hit test (wrong clicks now play the error cue). Ring sprites are white and tinted at runtime.
- **Guards:** `LockedDoor` and `MasterComputer` ignore a trigger from a player who already has an attempt in flight (server-side, not a client hide).
- **Focus mode:** opening a puzzle panel fades the rest of the HUD out and back (`ReplicatedStorage.UI.Transitions`), with FOV pull and blur from `MenuFovBlur` ([[HUD and UI Shell]], [[Camera Authority]]).
- Puzzle GUIs are Studio-authored (convention: no runtime `Instance.new()` for custom puzzle GUIs); static text baked into Figma slices, live values native.

## Extend it
- New puzzle: a component under `Heist.Components`, its remote pair in `Net`, a Studio-authored ScreenGui, a spec pinning its rules (the randomise spec pins "3 total" so it is not silently reverted).
- Guard re-entry on the server.

## Watch out
- `HackCodeGui.DialogFrame.CloseButton` is the 320x48 "GOT IT" confirm, not an X; it stays on the `rotate` effect.
- Fade code must count its own writes; a suppress flag fails because property-changed callbacks run deferred.
- A disabled ScreenGui never fires `MouseLeave`; effects reset buttons to rest when hidden.
- Breach / completion screens need their own artwork: boxes and buttons are baked into the panel.

## History
- 2026-09-19: re-trigger guard on `LockedDoor` and `MasterComputer`; GUI fades; focus mode with FOV/blur and shared button effects; close buttons via `UI.Effects.bindClose`. [[Puzzle-Prompt-Guard-Cash-Logo-And-GUI-Fades]] [[Shared-UI-Effects-FOV-Blur-And-Sounds]] [[Close-Button-Unified-With-FPS]]
- 2026-09-18: lockpick arcs match the hit test; breach panel; safe keypad boxes normalised; puzzles on Figma slices. [[UI-Bug-Fixes-Notification-HUD-Lockpick-Titles]] [[Figma-Slices-Imported-To-Studio]] [[Slice-Transparency-And-Anchor-Fixes]]
- 2026-09-12: "Randomise Word" button, 3 per attempt. [[NewsStation-Hacking-Randomize-Word-Button]]

See [[Batch Log]].
