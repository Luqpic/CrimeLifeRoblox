# Notification card rendered blank — ZIndexBehavior, not transparency

**Status:** Fixed and confirmed live by looking at the rendered result, not by reading properties.
One line changed in `ReplicatedStorage.Modules.NotificationController`. Repo mirror updated to match.

## Summary

Spraypaint notification cards drew as solid dark plates with no text. The background, the rounded
corner and the drop shadow all rendered; the title, the message and the acid accent edge did not.

The text was never missing. It was rendered correctly and then painted over by its own card.

## Cause

`Instance.new("ScreenGui")` defaults to `ZIndexBehavior.Global`. Under Global every descendant of the
ScreenGui is sorted into one flat order by its absolute `ZIndex`, rather than each subtree drawing
with its parent.

`reseat` assigns each card `ZIndex = MAX_VISIBLE + 1 - depth`, so the three visible cards take 4, 3
and 2 to stack the depth effect. The `Notification` template's own children were authored at
`ZIndex 1` (`TitleLabel`, `MessageLabel`) and `ZIndex 2` (`AccentEdge`).

So a front card sat at 4 and its text at 1: under Global, the card's opaque background drew **over**
its own children.

Measured live, mid-display:

```
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
CARD  zi=4  bgT=0.00
  TitleLabel    zi=1  tT=0.00  bounds=88.5, 15   TXT="SPRAYPAINT"
  MessageLabel  zi=1  mT=0.00  bounds=61.5, 13   TXT="+3 Spraypaint"
  AccentEdge    zi=2
```

Every label present, at full opacity, with real text bounds, and invisible.

This was a regression introduced by the depth-stacking work itself. Before cards carried a per-depth
`ZIndex`, every element sat at the default 1 and drew in tree order, which put content above its
background by accident.

## Changes

- `ReplicatedStorage.Modules.NotificationController` — set `gui.ZIndexBehavior =
  Enum.ZIndexBehavior.Sibling` on the notification `ScreenGui` before parenting it.

Sibling is the behaviour this layout already assumed: a subtree draws with its parent and `ZIndex`
orders siblings. Cards therefore still stack by depth under the container, and each card's content
draws above its own background.

The alternative — raising every child's `ZIndex` above the highest card's — was rejected. It would
have to be re-bumped per depth on every reseat, and it leaves the same trap armed for the next person
who adds an element to the template.

## Verification

Before: card `ZIndex 4`, labels `ZIndex 1`, `Global` — blank plate.
After: `ZIndexBehavior = Sibling`, same ZIndex values unchanged — title, message and accent edge all
render. Confirmed by screen capture of a live two-card stack, not by reading properties back.

Depth stacking still correct after the change, front to back: `bgT 0.00 / 0.30`, with title and
message transparency tracking the card at `0.00 / 0.30`.

## Notes

**Two earlier rounds looked in the wrong place, and the reason is worth recording.** The reported
symptom was "blank card", and an earlier genuine bug in this module *was* a transparency fault — a
receded card snapping its content to invisible while its background stayed mostly opaque. That fix
was correct and is still in place. It also made the second occurrence look like a relapse of the
first.

The tell that should have redirected this sooner was visible in the user's own recording: **receded
cards showed faint text while the front card showed none.** That is backwards for a transparency
bug, where the front card is the most legible. It is exactly right for an occlusion bug: a receded
card's background dims to 0.3 or 0.6, so the text behind it bleeds through, while the front card at
0.00 hides it completely.

**The debugging error underneath it:** the properties were read and declared correct — `Text` was
right, `TextTransparency` was 0 — and that was treated as proof. It proved the label's *state*, not
that anything reached the screen. This repo's own rule covers it: verify the result, not the
arithmetic. A label can hold the right string at full opacity and still be behind something. The
check that settled it in seconds was a screen capture.

**Reproduction needed the real trigger.** Firing the notification by setting the `Spraypaint`
attribute server-side produced no card at all: `SpraypaintHud` compares against a cached `previous`,
and the replicated value had already landed before the comparison. Driving the attribute from the
client fires the same deployed handler and reproduces faithfully — worth knowing for the next test
that touches an attribute-driven HUD.

**This trap is already documented in the project's operating context** ("`ZIndexBehavior` is a global
on the `ScreenGui`, not a per-element property") and it was still walked into, because the depth
stacking that introduced the per-card `ZIndex` did not look like a `ZIndexBehavior` question at the
time. Any new `ScreenGui` created with `Instance.new` in this codebase inherits `Global` and has the
same trap armed; the ones created in Studio do not. A survey of the live place shows the split is
real and arbitrary: `PlayerCardGui`, `StaminaGui`, `LevelingGui`, `BlasterGui`, `ReticleGui` and
`BlasterTouchGui` are `Sibling`; `NotificationGui`, `CashShopGui`, `GamepassShopGui`,
`WeaponaryShopGui`, `QuestLogGui`, `DeathScreenGui`, `PromptUiGui`, `AdminLevelGui`,
`DamageDirectionIndicator`, `Custom Inventory` and `Freecam` are `Global`. Each of those is one
per-element `ZIndex` away from the same invisible-content failure.
