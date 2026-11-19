---
type: system
tags: [system, leveling, progression, ranks]
updated: 2026-11-20
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Leveling-System.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/FPS System/FPS-Persistence-Phase-3.md", "CrimeLifeRoblox/.superpowers/sdd/2026-09-23-renown-phase-2/spraypaint-rename-report.md", "CrimeLifeRoblox/FPSSystem/Weapons/LevelingService.luau", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/FPSSystem/FPS-Kill-Leveling-System.md", ".superpowers/sdd/2026-11-18-open-items-pass/task-6-report.md", "70 Batches/2026-11-20 Admin Animations Third Person.md"]
---

# Leveling and Renown

**Skills:** `roblox-game-systems`, `roblox-ui`, `roblox-data-stores` (load these for work here)

## What it does
Kills (AI and PvP) and quest hand-ins grant XP; levels up to a cap of 70 pay a small max-health bonus and a cash bonus, fire a level-up popup and a world burst, and set a criminal **rank** shown on the [[Player Card]] and on the overhead plate other players see.

"Renown" was the working name of the earned cosmetic currency in the 2026-09-23 Phase 2 spec and plan (`docs/superpowers/*/2026-09-23-renown-phase-2*`). It was renamed **Spraypaint** the same day, in Studio and in the repo; that currency lives in [[Spraypaint]]. The rank ladder below is the progression "renown" a player shows off.

## Where it lives
- `ReplicatedStorage.Leveling.Constants`: XP per kill tier, the curve (`xpToNextLevel`), `LEVEL_CAP`, rewards, `RANKS` + `rankForLevel(level)`, `XP_ICON_ID` / `HEALTH_ICON_ID` (single owner of both ids), `totalXp(level, xp)`.
- `ReplicatedStorage.Leveling.Remotes.SetLevelRequest` (owner-only since 2026-11-20; see "Admin set level").
- `ServerScriptService.Weapons.Scripts.LevelingService` (mirror `CrimeLifeRoblox/FPSSystem/Weapons/LevelingService.luau`).
- `StarterPlayer.StarterPlayerScripts.LevelingHud` (XP bar + popup), `.LevelUpVFX`. (`.AdminLevelController` was retired 2026-11-20: [[Admin Panel]].)
- `ReplicatedStorage.VFX.LevelUpBurst` (current burst rig); `ReplicatedStorage.VFX.LevelUpShine` (unreferenced since 2026-09-19).
- Rank shown by `GuiTemplates.PlayerCard.RankLabel` and `StarterPlayerScripts.PlayerNameplates` (`Rank` line).

## How it works
- XP comes from the shared `ServerScriptService.Blaster.Events.Eliminated` signal (the same one [[Quests and Dialogue]] and kill stats listen to) and from quest payouts. XP tier is read off the killing weapon (fire mode / infinite ammo), so Smuggler and Bandits pay at pistol rate (accepted, 2026-09-17).
- PvP kills grant XP by design; cash stays enemy-only ([[Economy and Cash]]).
- Replicated as `leaderstats.Level` and player attributes `Level`, `XP`, `NextLevelXP`. `XP` resets on each level-up, so the client uses `Leveling.Constants.totalXp` to derive a kill's XP (no extra remote).
- `grantXp` loops so one grant can cross several levels; at the cap extra XP is dropped and `XP`/`NextLevelXP` read 0.
- `MaxHealth = 100 + MAX_HEALTH_PER_LEVEL * (level - 1)` (`MAX_HEALTH_PER_LEVEL` 4 since 2026-11-20, was 2), re-applied on every spawn.
- Ranks, seven equal tiers of ten (the cap falls inside the last): Rookie Thug (1-10, street grey), Street Hustler (11-20, green), Gang Enforcer (21-30, cyan), Made Man (31-40, blue), Mafia Hitman (41-50, purple), Capo (51-60, orange), Godfather (61-70, gold).
- HUD: the XP bar is always visible above the hotbar, tweens its fill, carries a white Experience icon inside its left end; the popup reads `LEVEL {n}` under a `LEVEL UP` caption. The kill toast carries a `+N EXP` line under the Spraypaint line ([[Notifications]]).
- Level-up burst: `LevelUpBurst` cloned on level-up, welded at foot height, emits for `EmitSeconds` 1.5, destroyed after the last particle (4.5 s total). Client-side only.
- Admin: `SetLevelRequest` is gated server-side to the owner role (`Admin.Roles`) since 2026-11-20 (before: one hard-coded account id, removed); clamps to 1..cap.
- Persisted since 2026-09-23: `level` and `xp` mirror into the profile; `NextLevelXP` is derived and recomputed on load ([[Persistence and Saves]]).

## The level-up popup layout (2026-11-18)
`LevelingHud.placePopup` scales with the heist HUD's `UIScale` (`fullScale = heistScale / levelingScale`, the small-screen fit clamped to it) and places the popup again on a `ViewportSize` change while it is shown; it follows the camera as `WantedHud` does. `UIScaleController` caps every scale at 1 (read back 1.000), so the popup never grows above the heist card. At 1100 x 679 it sits at (370, 262) 360 x 90, scale 1, overlapping nothing. The phone branch (844 x 390: 256 x 64, scale 0.71, 2 px under the star meter) is computed, and the resize re-place was not exercised live ([[HUD and UI Shell]], [[Open Items]]).

## Admin set level (2026-11-20)
`SetLevelRequest` is no longer gated to one hard-coded account. The closure body became `setLevel(player, level)` (level, XP 0, `NextLevelXP`, max health, save) registered as `Admin.Hooks.setLevel`; the remote now checks `Admin.Roles.get(player) == "owner"`, and the panel's `setLevel` action is the real entry point ([[Admin Panel]]). Measured: level 12 gave Level 12, leaderstats 12, XP 0, `NextLevelXP` 195, max health 122, profile level 12 (Spraypaint 275 came from the existing 25-per-level award). `AdminLevelController` (F2 panel and `/setlevel`) is retired into `ServerStorage.CityQuarantine.AdminReplaced`. `SetLevelRequest` stays as an owner-only dead entry point (its only sender is retired).

## Toughness by level (2026-11-20)
- `Leveling.Constants.maxHealth(level)` = 100 + 4 x (level - 1): 100 at level 1, 104 at level 2, 376 at level 70 (`MAX_HEALTH_PER_LEVEL` 2 to 4, was 238 at 70). `LevelingService.applyMaxHealth` uses it; the module's first mirror is `CityScripts/ReplicatedStorage.Leveling.Constants.luau`.
- **Armor.** NPC damage to a player is cut 0.4 % per level above 1, at most 25 % (level 70: x0.75, one Offender hit 8 to 6.00 read back). The level is the server-set `Level` attribute. Applied in `ShotResolver.applyDamage` in the NPC branch only (`Combat.armor`, `Combat.npcDamage`); players, falls, lasers and the death pit are not reduced.
- **Regen.** `StarterPlayer.StarterCharacterScripts.Health` replaces Roblox's default Health script: 6 % of max health a second once 6 s have passed since the last loss, asleep at full health, it only raises Health. Level 70 measured: held at 200 until 5.98 s, then about 22.9 a second.
- A level-up still fully heals, even mid-fight (open item).
Details: [[2026-11-20 Readable Gunfights and Level Toughness]]; trap in [[Luau and Scripting Traps]].

## Extend it
- Rename a rank or recolour it: one line in `RANKS`.
- New XP source: call into `LevelingService` from the server; never trust the client. Read `Eliminated` rather than adding a second kill signal.
- New readout of XP gained: difference `totalXp`, not the raw `XP` attribute.

## Watch out
- Templates rest in their authored state: the popup template must rest fully transparent, and `LevelingHud` forces all four transparencies to 1 at startup (2026-09-18 regression, twice).
- `LevelingService`'s header comment said "Session-only ... does not add a DataStore" (stale since [[FPS-Persistence-Phase-3]]); fixed on 2026-11-18 with `Stats.Constants`' matching comment. [[2026-11-18 Open Items Pass]]
- Spraypaint pays 25 per level gained off the `Level` attribute; hydration on join once paid a phantom award on every rejoin (Critical, fixed 2026-09-23). Any change to how `Level` is set on join must be re-checked against that.
- You never see your own overhead plate; your rank shows on your card.
- The level-up rig's `PointLight` (brightness 300, range 6) may read as a flashbang up close: needs an eye.
- The XP and spray icon ids were uploaded as white glyphs so `ImageColor3` can tint them.

## History
- 2026-11-20: max health +4 a level, level armor against NPC damage, the `Health` regen script. [[2026-11-20 Readable Gunfights and Level Toughness]]
- 2026-11-20: set level moved behind `Admin.Hooks` and the owner role; the hard-coded account gate and the old F2 panel are gone. [[2026-11-20 Admin Animations Third Person]]
- 2026-11-18: `LevelingHud.placePopup` re-lays out on a viewport resize and follows the heist HUD's scale; `UIScaleController` cap 1 confirmed. [[2026-11-18 Open Items Pass]]
- 2026-09-24: criminal ranks on the card and overhead; XP icon inside the bar, white. [[FPS-Criminal-Ranks-Overhead-Health-Icons-Toast-Icons]]
- 2026-09-24: `+N EXP` line on the kill toast; Experience icon on every leveling readout; `totalXp`. [[FPS-Kill-Toast-XP-Line-Gun-Icons-Leveling-Icons]]
- 2026-09-23: level and XP persist through `ProfileGateway`; phantom rejoin level-up award found and fixed. [[FPS-Persistence-Phase-3]]
- 2026-09-23: Renown currency renamed Spraypaint; earns 25 per level gained. [[FPS-Spraypaint-Phase-2]]
- 2026-09-19: authored `LevelUpBurst` replaces the dormant shine emitter. [[FPS-Melee-Hit-And-LevelUp-VFX]]
- 2026-09-18: popup stuck on screen (new caption not faded; template resting opaque) fixed. [[FPS-Player-Nameplates-And-LevelUp-Fix]]
- 2026-09-18: popup restyled (acid outline, `LEVEL UP` caption). [[FPS-Figma-UI-Bugfix-Pass-5]]
- 2026-09-17: Smuggler and Bandits pay pistol-rate XP (accepted). [[FPS-Enemy-Roster-Rework-3-New-Recruits]]
- 2026-09-16: cap raised to 70; `/setlevel` and F2 admin panel (not driven live at the time). [[FPS-Quest-Expansion-5-New-Levels-Admin-SetLevel]]
- 2026-09-16: quest payouts grant XP. [[FPS-Quest-System-Level1-KillThugs]]
- 2026-09-11: leveling bar converted to a template, always visible above the hotbar. [[FPS-Gui-Template-Conversion-Cash-Sound-Static-Leveling-Bar]]
- 2026-09-11: XP bar tweens; level-up shine. [[FPS-Death-Screen-Leveling-Tween-LevelUp-VFX]]
- 2026-09-11: kill-based leveling created, session-only at the time. [[FPS-Kill-Leveling-System]]

See [[Batch Log]].
