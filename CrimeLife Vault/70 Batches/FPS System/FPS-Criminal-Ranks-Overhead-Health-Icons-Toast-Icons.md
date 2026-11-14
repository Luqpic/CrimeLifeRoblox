# Change Log: Criminal Ranks, Health Icons on Overheads, Icons on Both Toast Lines

**Date:** 2026-09-24
**Status:** Applied. Everything below was verified live in play by screenshot and readback. The player
overhead was checked on the local character through a temporary test copy of the script, which was
deleted afterwards; a real second player has not seen it. The place is not saved to disk by this change.

## Summary
- **Ranks.** Every player now has a criminal rank by level, shown on the player card under the name and
  on the overhead plate other players see, right above the name, in the tier's colour:

  | Levels | Rank | Colour |
  |---|---|---|
  | 1–10 | Rookie Thug | street grey |
  | 11–20 | Street Hustler | green |
  | 21–30 | Gang Enforcer | cyan |
  | 31–40 | Made Man | blue |
  | 41–50 | Mafia Hitman | purple |
  | 51–60 | Capo | orange |
  | 61–70 | Godfather | gold |

- The XP bar's Experience icon is now **inside** the bar and **white**. Before, it sat beside the bar in the
  fill colour and would have vanished into the fill.
- The kill toast's Spraypaint line now leads with the spray-can icon, matching the EXP line under it.
- Every overhead health bar, both enemies' and players', has a white Health icon inside its left end.

## Changes
- `ReplicatedStorage.Leveling.Constants` — `RANKS` (minLevel, title, colour) and `rankForLevel(level)`.
- `ReplicatedStorage.Modules.NotificationController` — `message` accepts `string | Line`, where
  `Line = { text, icon?, iconColor? }`, the same shape as `detail`. One `prependIcon` places the icon on
  either line, and every icon on a card fades and re-seats together. Plain-string callers are unchanged.
- `StarterPlayerScripts.SpraypaintHud` — the message line carries `Spraypaint.Constants.ICON_ASSET_ID`
  in the Spraypaint accent (#CBF23C).
- `StarterPlayerScripts.LevelingHud` — the XP icon is a child of the bar: left inset 4 px, 80% of the
  bar's height, white, drawn above the fill.
- `ReplicatedStorage.GuiTemplates.EnemyGUI` — `GUI.HealthGUI.HealthIcon`: white, square from the bar's
  height (75%), left end, level with the number (z 3). The spawner clones the template, so every enemy
  picks it up.
- `StarterPlayerScripts.PlayerNameplates` — the same Health icon in the bar, plus a `Rank` line. The plate
  grew 1.2 → 1.6 studs; name and bar keep their exact stud sizes and the plate moved up 0.2 studs, so the
  bar sits where it did. The rank listens to the Player's `Level` and disconnects with the plate.
- `ReplicatedStorage.GuiTemplates.PlayerCard` — `RankLabel` under the name; `StatsContainer` moved 11 px
  down into space that was empty. `PlayerCardController` sets it in `refreshLevel`.

## Bug found and fixed on the way
`PlayerNameplates.buildNameplate` used `FindFirstChild("Head")` and returned silently when the head had
not arrived yet, while the View Card prompt, which waits for its root part, still appeared. Measured: the
prompt was present and the plate was absent, and a probe BillboardGui on the same head survived. So
nothing was deleting plates; they were never built. It now waits for the Head (10 s). This affects real
remote players too whenever a character's head lands after `CharacterAdded`, for example under streaming.

## Verification (play mode)
- Toast readback: card 280 × 84. Both icons at x = 24 (14 × 14), both texts at x = 42. Spray icon
  #CBF23C, XP icon #61F0EE, both fully visible.
- Screenshots: XP bar icon white over the filled bar; Bandit plates with the icon in the bar; player plate
  "MAFIA HITMAN" (Level 45) and then "ROOKIE THUG" after a level change, updating live; player card "CAPO"
  at Level 51.
- Rank table check: every tier boundary (1, 10, 11, 30, 31, 41, 50, 51, 61, 70) maps correctly.
- 0 server errors. The 2 client warnings were Studio's own notice that the test script changed the
  camera.

## Notes
- The ladder is one criminal career. The first three tiers are street-level (thug → hustler → gang
  enforcer). The last four follow the mafia hierarchy: made man, then Mafia Hitman as the family's feared
  specialist, then capo, then Godfather at the top. Seven equal tiers of ten, so the cap (70) falls inside
  the last tier. Renaming a rank or changing a colour is one line in `RANKS`.
- You never see your own overhead plate (by design, so it does not block aim in third person); your rank
  shows on your player card, and other players see it over your head.
