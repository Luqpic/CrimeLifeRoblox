# Figma UI — Bug Fix Pass 5

**Place:** `FPS System.rbxl` · Follows `FPS-Figma-UI-Bugfix-Pass-4.md`

Seven reported. **Six done and verified. Bug 7 (PVP nameplates + proximity prompt) is NOT done** —
see the end.

---

## 1 — Notification slides from the top

`NotificationController`'s container moved from bottom-left (`AnchorPoint 0,1` at `20, 1, -20`,
sliding on X) to top-centre (`AnchorPoint 0.5,0` at `0.5, 0, 20`), list layout `Top` + `Center`, and
the slide is now vertical: `OFFSCREEN_Y = -140` down to 0, then back up. Verified live.

## 2 — Enemies show their real type

Two causes stacked.

`EnemySpawner` sets `character.Name = "Enemy"` for every type — deliberately, because targeting,
tagging and damage validation all key on that name, so it cannot be changed. The spawner now writes
the real `enemyType` onto the nameplate instead.

That alone did nothing, because `EnemyGUI.GUI.Info.Name.Text` was a Script doing
`script.Parent.Text = <model>.Name` — it ran after the spawner and stamped "Enemy" back over every
plate. Script removed; the spawner owns the label now (it is the only place `EnemyGUI` is cloned).

Verified live across 15 spawned enemies: `BANDITS ×4, SMUGGLER ×4, SABOTEUR, DISRUPTERS ×2, THUG ×2,
OFFENDER ×2` — no generic "Enemy" left.

## 3 — Enemy health bar to the Figma

Name in white display type with a dark text shadow; track `#0E1016` with a `#2A2F3C` hairline and
full rounding; fill `#FF4B4B`; value right-aligned in white. Stray `UIGradient`s on both the info
and health frames removed — they were tinting the new colours.

`HealthManager` now prints the remaining health alone (`90`) rather than `90 / 90`, matching the
reference.

## 4 — Level-up popup

`#171A22` fill, radius 14, **acid 2px outline**, a muted `LEVEL UP` caption at 15px, and the level
line in acid display type at 32px. Verified live: caption present, stroke acid at thickness 2.

## 5 — Player card stats

The three rows are now label + right-aligned value over a coloured track, per the reference:

| Row | Label | Track fill |
|---|---|---|
| HealthRow | HEALTH | `#FF4B4B` |
| LevelRow | XP | `#CBF23C` |
| CashRow | CASH | `#FFD54A` |

Row pills/strokes removed (the bar carries the meaning now). `LevelLabel` is hidden — the level is
already on the `LevelChip` above — and that row's value column shows `xp / nextLevelXp`. Health now
drives its own fill, which it never did before. Verified live: `HEALTH 100 / 100`, `XP 0 / 30`,
`CASH 10,000` with the three fill colours correct.

## 6 — Quest entry claim state

`QuestEntry` gained a `Status` pill and a right-aligned `ProgressLabel`, and the count moved out of
the description sentence into its own column. `QuestLogController` drives the two states:

- **claimable** → acid pill, dark `CLAIM` text, pill stroke off, **entry outline acid**
- **active** → inset pill, muted `ACTIVE` text, hairline stroke, entry outline `#2A2F3C`

Structure verified live. The CLAIM/ACTIVE swap itself was not observed in game because no quest was
in the ready-to-turn-in state during the test — worth one manual check when you next finish a quest.

---

## 7 — PVP nameplates + proximity prompt — NOT DONE

This is a feature addition rather than a fix, and it needs:

1. A player nameplate/health billboard on every character, with
   `Humanoid.DisplayDistanceType = None` and `HealthDisplayType = None` to suppress Roblox's default.
2. A `ProximityPrompt` on each player's character that opens that player's card.
3. `PlayerCardController` exposing `openCard(target)` to that prompt — it is currently a local
   function, though `/view` already calls it with an arbitrary player, so the hard part is done.

I stopped rather than write it unverified at the end of a long session. Two bugs in this
conversation (the death scrim, the `UIPadding` pill collision) came from changes that looked right
and were not actually checked in game; this one touches character spawning for every player and
deserves its own pass with a real two-client playtest.

---

## Verification (live, Play mode)

```
BUG1 container anchor=0.5,0 pos=(0.5,0),(0,20) vAlign=Top hAlign=Center   PASS
BUG2 15 enemies: BANDITS/SMUGGLER/SABOTEUR/DISRUPTERS/THUG/OFFENDER       PASS
BUG3 track #0E1016, fill #FF4B4B, value right-aligned, health="90"        PASS
BUG4 caption="LEVEL UP", stroke acid thickness 2                          PASS
BUG5 HEALTH 100/100 red | XP 0/30 acid | CASH 10,000 gold                 PASS
BUG6 Status pill + ProgressLabel present, controller drives both states   PASS (structure)
```

## Note

`info.Name` in Luau returns the **instance's name string**, not a child called "Name" — it threw
`attempt to index string with 'Size'` on the first run of the restyle. Use `FindFirstChild("Name")`.

## Still open

- **`StarterGui.ScreenGui.MultiExport`** — 1,155 instances, no script references, still replicating.
- Bug 7 above.
- `ReplicatedStorage.UI.Theme` still dead code.
