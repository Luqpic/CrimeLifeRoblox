---
type: system
tags: [system, ui, player-card]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Player-Card-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/Player-Card-XP-Bar.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-4.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Figma-UI-Bugfix-Pass-5.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Player-Nameplates-And-LevelUp-Fix.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Player-Card-System.md", "CrimeLifeRoblox/FPSSystem/Stats/KillStatsService.luau"]
---

# Player Card

**Skills:** `roblox-ui`, `roblox-text-chat` (load these for work here)

## What it does
A HUD button opens a card with the player's display name, Roblox profile photo, criminal rank, level chip, and HEALTH, XP and CASH rows. Other players' cards open with `/view <username>` or by pressing E on another player (View Card prompt).

## Where it lives
- `StarterGui."Custom Inventory".playerCardButton` (HUD button, with `ClickSound`).
- `ReplicatedStorage.GuiTemplates.PlayerCard`: `RankLabel`, `LevelChip`, `StatsContainer` with `HealthRow`, `LevelRow` (`Track.Fill`), `CashRow`, each with an `Icon`; banner plate with the baked title; `CloseButton`.
- `StarterPlayer.StarterPlayerScripts.PlayerCardController`: opens and fills the card (`openCard(target)`, `refreshLevel`), registers `/view`.
- `ReplicatedStorage.UI.OpenPlayerCard` (BindableEvent) fired by `ViewCardPrompt` from `StarterPlayerScripts.PlayerNameplates`.
- Kill counters `CriminalKills` / `PoliceKills` (player attributes) come from `ServerScriptService` `KillStatsService`, whose header calls them "for the player card"; whether the card renders them is not recorded in any change log.

## How it works
- No new networking: the card reads data that already replicates (`leaderstats`, `Level` / `XP` / `NextLevelXP` attributes, the Humanoid), so `/view` shows any player.
- Rows: HEALTH (red `#FF4B4B`, drives its own fill), XP showing `xp / nextLevelXp` (fill light blue `RGB(120, 200, 255)` since 2026-09-19), CASH showing the current `leaderstats.Cash` balance (yellow `#FFD54A`). `LevelLabel` is hidden; the level is on `LevelChip`.
- Rank from `Leveling.Constants.rankForLevel` in the tier colour ([[Leveling and Renown]]).
- `ViewCardPrompt`: E, 12 studs, no line-of-sight, on every other player's `HumanoidRootPart`; none on yourself.
- Opens and closes through `UI.Panels` (one panel at a time, HUD hidden behind it), fades in and out, closes through the shared `bindClose`, button feedback from `UI.Effects` ([[HUD and UI Shell]]).

## Extend it
- New row: clone `HealthRow` so it matches exactly, then drive it from `PlayerCardController`.
- New stat: prefer data that already replicates (attributes) over a new remote.
- The 2026-09-22 cosmetics spec proposed showing the equipped skin or owned skins here; not built ([[Cosmetics and Skins]]).

## Watch out
- `AnchorPoint` and `Position` must agree: the XP fill was anchored `(0, 0.5)` at `Y = 0` and hung half outside its track.
- CASH is the current balance, not lifetime earnings; nothing tracks lifetime cash (a lifetime stat was offered to the developer on 2026-09-18; not built).
- The View Card prompt and the BindableEvent round trip have not been exercised with a real second client.

## History
- 2026-09-24: `RankLabel` under the name; `StatsContainer` moved 11 px down. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- 2026-09-24: Health and Experience icons on the HEALTH and XP rows. [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- 2026-09-23: notification queue verified by opening the real card. [[Notification-Card-Fix-And-Weapon-HUD-Move]]
- 2026-09-19: XP fill centred on its track and coloured light blue. [[Player-Card-XP-Bar]]
- 2026-09-19: card fades in and out; banner title re-centred; close button unified. [[FPS-Banner-Title-Centring-And-UI-Fades]], [[Close-Button-Unified-With-Robbery]]
- 2026-09-18: View Card prompt on other players via `UI.OpenPlayerCard`. [[FPS-Player-Nameplates-And-LevelUp-Fix]]
- 2026-09-18: rows restyled label + value over coloured tracks. [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-18: level text white; `CashRow` added. [[FPS-Figma-UI-Bugfix-Pass-4]]
- 2026-09-18: second level bar behind the card was the HUD; hidden while a panel is open. [[FPS-Figma-UI-Bugfix-Pass-3]]
- 2026-09-18: banner art wired. [[FPS-Figma-1to1-Image-Export-And-Font-Fix]]
- 2026-09-16: hover and click effects. [[FPS-UltimateUIPack-Effects-Integration]]
- 2026-09-12: blank profile photo fixed (wrong enum name). [[FPS-Upgrade-Button-Sounds-Recoil-Respawn-Hotbar-PFP-Landing]]
- 2026-09-11: card, button and `/view` created. [[FPS-Player-Card-System]]

See [[Batch Log]].
