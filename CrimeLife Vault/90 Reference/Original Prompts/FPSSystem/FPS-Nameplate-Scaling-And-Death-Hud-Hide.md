# Nameplate Scaling, Own-Plate Hiding, Death HUD Hide

**Place:** `FPS System.rbxl` · Follows `FPS-Player-Nameplates-And-LevelUp-Fix.md`

Three fixes, two of them in the nameplate code from the previous pass.

---

## 1 — Nameplate grew with distance

`BillboardGui.Size` is a `UDim2` where the two components mean different things:

- **Scale** is **studs** — world space, so the plate shrinks as the camera pulls away.
- **Offset** is **screen pixels** — constant on screen, so the plate stays the same size while the
  character it labels gets smaller. That is the ballooning in the screenshot.

I had used `UDim2.fromOffset(250, 64)`. Now `UDim2.fromScale(5, 1.2)` — the exact studs the
`EnemyGUI` template already uses, so player and NPC plates match at every distance. `MaxDistance`
dropped 120 → 50 and `AlwaysOnTop` true → false to match as well, so plates are no longer drawn
through walls.

## 2 — No plate over your own head

`onCharacter` now returns early for the local player, before building the plate. It still sets
`Humanoid.DisplayDistanceType = None` first, so Roblox's default overhead name and health bar stay
suppressed on your own character too — you get neither the custom plate nor the stock one.

Your own health is on the player card, and the prompt was already skipped for yourself.

## 3 — Death hides every GUI except the death screen

`DeathScreen` now records each `LayerCollector` in `PlayerGui`, disables all of them except its own,
and restores them in the **guaranteed-cleanup block** — so the HUD returns whether the sequence
finished normally, errored, or hit its timeout. Leaving a living player with no HUD would be worse
than the original complaint.

Recording the prior state matters: `BlasterGui`, `ReticleGui`, `BlasterTouchGui` and `AdminLevelGui`
are legitimately disabled at various times, and a blind restore to `true` would switch them on.

---

## Verification (live — character actually killed, then respawned)

```
BUG2 own nameplate=absent | DisplayDistanceType=None                     PASS
BUG1 plate now UDim2.fromScale(5, 1.2), MaxDistance 50
     EnemyGUI Size={5,0},{1.2,0} MaxDistance=50  <- matched

BUG3 before death: 13 enabled, 4 already disabled
     during death:  DeathScreenGui enabled, 16 others hidden             PASS
     after respawn: HUD back (Custom Inventory + Stamina + Leveling)     PASS
                    AdminLevelGui/BlasterGui/BlasterTouchGui/ReticleGui
                    still disabled - nothing wrongly forced on           PASS
BUG2 after respawn: own nameplate still absent                           PASS
```

## Not verified

Bug 1's on-screen result. With one player in a solo playtest there is no second plate to look at, so
the fix is verified as *matching the EnemyGUI template's proven sizing* rather than by eye. The
enemy plates in the same world use identical values and behave correctly, which is decent but not
the same as seeing it.

## Still open

- Two-player test: nameplate at distance, and the view-card prompt round trip.
- `ReplicatedStorage.UI.Theme` still dead code.
- Quest CLAIM/ACTIVE swap still unobserved with an actually-claimable quest.
