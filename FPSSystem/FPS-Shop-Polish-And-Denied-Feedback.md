# Shop Polish, Slot/Card Outlines, Denied Feedback

**Place:** `FPS System.rbxl` · Follows `FPS-Nameplate-Scaling-And-Death-Hud-Hide.md`

Eight reported. Six verified live, one verified structurally, one **cannot be verified yet** — see
bug 6.

---

## 1 — Prompts stand down while a card is open

`UI.Panels` gained `onChanged(callback)`: anything that must yield to an open panel subscribes, and
the module fires it on every open and close (and once immediately on subscribe, so a late subscriber
starts in the right state).

`PlayerNameplates` subscribes and toggles `prompt.Enabled` across every prompt it has created. The
registry uses **weak keys**, so a prompt destroyed with its character is not held alive by it. New
characters spawning while a card is open start disabled rather than assuming they may show.

## 2 — Quest badge to the corner

The badge was anchored right but positioned at `(1, -22)` — 22px back *inwards* — which on a 76px
button with a 32px badge put it near the centre. Now `(1, 6), (0, -6)`, so it overhangs the top-right
corner. Verified: badge right edge at 82 against a button right edge of 76.

## 3 — Filled loadout slots outlined

`refreshInventoryColumn` now sets each slot's stroke to acid at 2px when occupied, hairline at 1px
when empty. Verified live: Slot1 filled → acid/2, Slots 2-4 empty → line/1.

## 4 — Quest progress bar overflow

`ProgressBar.Fill` had `Position = {0,0},{0.5,0}` — **half the track's height down**, while being a
full height tall, so it hung out of its own bar. Now `{0,0},{0,0}`.

## 5 — Best-value card outlined

The best-value tier takes an acid 2px stroke as well as its badge; the badge alone read as
decoration on an otherwise identical card. Verified live: `Cash100K` → ACCENT/2, all five others →
line/1.

## 6 — Gamepass owned highlight — **written, NOT verifiable yet**

The owned branch of `GamepassShopController.refresh()` now sets the whole tile's stroke to acid 2px,
and the unowned branch resets it.

**It cannot run today.** Every gamepass in `Monetization.Constants` still has a placeholder
`gamepassId` of `000000000`, so `Constants.isConfigured()` is false and `refresh()` returns at the
"COMING SOON" branch *before* reaching the ownership check. Confirmed live — all six tiles read
`COMING SOON` with the default stroke.

The highlight will work the moment real gamepass ids are filled in. Nothing else is needed.

## 7 — Click sound

`UI.Sounds.CLICK_SOUND_ID` → `rbxassetid://8816939097`. Since all five HUD buttons were unified onto
`Sounds.bind` in an earlier pass, this one constant covers all of them. Verified live: the live
`UIClickSound` instance carries the new id.

## 8 — Denied feedback on insufficient funds

New `Sounds.denied()` (`rbxassetid://138405257788302`) and a `denyAction()` in
`WeaponaryShopController` that flashes the action button `#FF4B4B` and tweens it back.

`performAction` now computes the cost — upgrade (`COST_PER_LEVEL × nextLevel`) or purchase
(`Price` attribute) — compares it against `leaderstats.Cash`, and refuses before firing the remote.

**This is feedback only.** The server still validates every purchase and upgrade, so the client-side
check cannot be used to buy anything; removing it would only bring back the silent no-op.

Verified structurally (`denyAction` defined, check placed before `FireServer`, denied sound wired).
Not exercised in game: the test account has 10,000 cash and every catalogue weapon is affordable, so
the refusal branch was never reached.

---

## Verification (live, Play mode)

```
BUG7 UIClickSound = rbxassetid://8816939097                          PASS
BUG2 badge anchor 1,0 pos {1,6},{0,-6}; right edge 82 vs button 76   PASS
BUG4 Fill pos {0,0},{0,0} size {0,0},{1,0}                           PASS
BUG3 Slot1 acid/2 (filled), Slots 2-4 line/1 (empty)                 PASS
BUG5 Cash100K ACCENT/2, five others line/1                           PASS
BUG1 Panels.onChanged present; PlayerNameplates subscribes           PASS (structural)
BUG8 denyAction + pre-FireServer affordability check + denied sound  PASS (structural)
BUG6 all six tiles COMING SOON - owned branch unreachable            BLOCKED
```

## Not verified in game

- **Bug 1's actual toggle** — solo playtest has no second player, so no prompt exists to observe.
- **Bug 8's refusal** — needs an account that cannot afford something.
- **Bug 6** — needs real gamepass ids.

## Still open

- `ReplicatedStorage.UI.Theme` remains dead code.
- Quest CLAIM/ACTIVE swap unobserved with a genuinely claimable quest.
- Two-player test: nameplate at distance, view-card prompt, prompt toggling.
