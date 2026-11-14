# Quest Bar Overflow (real cause) + Dead Code Removal

**Place:** `FPS System.rbxl` · Follows `FPS-Shop-Polish-And-Denied-Feedback.md`

---

## Quest bar overflow — three causes, and my earlier fix addressed none of them

Measuring first was what found it. The bar was **already geometrically inside** its entry
(x 276..624 against an entry of 260..640 — 16px margins each side), so the `Fill.Position` change
last pass, while a genuine defect, was never the overflow.

**Cause 1 — `ScrollingDirection = XY`.** A quest log never scrolls sideways, but the list was set to
scroll on both axes. The entry was `{1, 0}` — exactly the 380px frame width — and its 1px border
stroke is drawn *outside* that box, so the canvas measured 382 against a 380 window. That is real
horizontal overflow, and the list was configured to let it scroll. Now `ScrollingDirection = Y`.

**Cause 2 — zero horizontal breathing room.** The entry filled the clip region exactly, so its
border stroke fell outside the clipping `ScrollingFrame` and the 4px scrollbar sat on top of the
card's right edge. Now 2px padding on the list and the entry at `{1, -10}`.

**Cause 3 — the ZIndex hunch was right.** `QuestLogGui.ZIndexBehavior` is `Global`, where equal
ZIndex renders in tree order rather than by nesting. Every element in the entry sat at the default
1, the same as the panel, so nothing *guaranteed* the bar drew above the card instead of through it.
Now explicit: entry 2, children 3, fill/status 4, status label 5.

### Verified live with a real entry instantiated in the list

```
QuestList x=414..794  ScrollingDirection=Y  canvasX=380
entry     x=416..782  (stroke extends 1px each side -> 415..783)
bar       x=432..766

stroke fully inside clip region                  PASS
no horizontal overflow (canvas 380 <= window 380) PASS
bar within entry                                  PASS
ZIndex entry=2 bar=3 fill=4
```

---

## Dead code removed

Audited all **170 scripts** by collecting every source once and asking what nothing references.

| Removed | Why |
|---|---|
| `ReplicatedStorage.UI.Theme` (289 lines) | Required by nothing. Verified twice — every hit was a comment. Its asset-id registry is preserved in these changelogs. |
| `GuiTemplates.QuestResponsesBillboard` (12 desc.) | Duplicate. `DialogModule` reads `StarterGui.QuestResponsesGui`; this copy was never cloned. I had been styling both every pass purely to stop them drifting. |
| `GuiTemplates.WeaponStatPanel` (25 desc.) | Referenced by nothing; the shop's `DetailPanel` superseded it. |

**40 instances freed.** `GuiTemplates` is down from 16 children to 13.

### Kept, with reasons — two were false positives

- **`ServerStorage.UnitTest.Cases.PropertyAuthority_Test`** — the audit flagged it, but
  `RunUnitTest` discovers cases via `Cases:GetDescendants()`. Name-based search cannot see dynamic
  loading. **Not dead.**
- **`ServerScriptService.UnitTestRunner`** — `Disabled` on purpose; a test runner is meant to be off
  in a running place.
- **`workspace."UI Animation Pack - by JakeDev"`** (166 instances) — reference material, not code.
  The effects in use were copied out of it long ago. Deleting it is your call, not mine; it is inert
  at runtime but it does replicate to every client.

## Fixed: an error that had fired on every playtest of this entire session

`Workspace.UI.OverheadGui.InformationLabel.Script` indexed `.Head` unconditionally. `workspace.UI` is
a **Part used as a template** that `IndicatorClient` clones onto characters — so while the template
sat in Workspace, where the grandparent is a Part with no Head, it threw **every frame from the
moment the place loaded**.

Now guarded, and moved from `while wait()` to `RunService.Heartbeat` — this is per-frame visual sync,
and `wait()` is both slower and less precise than the frame signal it was standing in for.

Console after this change contains only the pre-existing weapon-sound
`User is not authorized to access Asset` batch.

## Worth your attention

`IndicatorClient` clones `OverheadGui` (a name label) onto characters, and `PlayerNameplates` now
also puts a name above every player. **These may double up in multiplayer.** Only the template exists
in a solo test, so I could not confirm it. If you see two names above a player, `IndicatorClient` is
the one to retire.

## Still open

- Two-player test: nameplate at distance, view-card prompt, prompt toggling, and the possible
  `OverheadGui` / `PlayerNameplates` duplication above.
- Quest CLAIM/ACTIVE swap unobserved with a genuinely claimable quest.
- Gamepass owned-highlight blocked on real gamepass ids.
- Weapon-sound assets not owned by this account.
