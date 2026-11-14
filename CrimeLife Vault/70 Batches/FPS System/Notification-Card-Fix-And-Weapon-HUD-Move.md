# Change Log: Notification Card Fixed And Resized, Weapon HUD Moved To Middle-Right

**Date:** 2026-09-23
**Status:** Confirmed live in `FPS System.rbxl`, multiple Play sessions (Client/Server datamodels).
All numbers quoted below were measured within a single session at a time (see Notes on why
`AbsolutePosition` cannot be compared across sessions). The one piece not directly re-read after
edit is the `GuiTemplates.Notification` child layout, whose new values are the ones this log wrote
and Studio echoed back at write time -- see Changes.

## Summary
Two user-reported bugs, fixed together because the second frees the space the first needed:
1. The notification card rendered as a large blank rectangle on the user's viewport. Root cause
   turned out to be different from the incoming hypothesis (see Cause) -- fixed by making a
   receded card's text and background fade together, and by giving the card's `ScreenGui` its own
   `UIScale` so `UIScaleController` no longer blows it up on wide viewports.
2. The ammo/weapon HUD (`GuiController`) moved from bottom-right to middle-right, at the user's
   request, which also gave the notification card room to sit lower and smaller.
Card size dropped from 420x100 to 280x64. Public APIs (`NotificationController.show`, `GuiController`
methods) are unchanged.

## Cause
**Oversized card:** `StarterPlayer.StarterPlayerScripts.UIScaleController` gives every `ScreenGui`
under `PlayerGui` a `ResponsiveScale` `UIScale` sized to its widest offset-sized descendant, *unless*
that `ScreenGui` already ships its own `UIScale` ("a GUI that already ships its own UIScale owns its
own scaling policy" -- controller comment). `NotificationGui` had none, so on a wide viewport it was
scaled up along with everything else on screen -- consistent with the user's "covers half the
screen."

**Blank card -- NOT what was suspected.** The incoming hypothesis was that `expireAndDestroy`'s fade
let the background and text drift out of sync during the ~0.18s expire tween. Tested directly: a
single card was polled every 0.1s from arrival through destruction (41 samples, one `execute_luau`
call so the ~4.4s lifecycle couldn't be missed by inter-call latency -- see Notes). `BackgroundTransparency`,
`TitleLabel.TextTransparency` and `MessageLabel.TextTransparency` were numerically identical at
every single sample, arrival through the Back-In overshoot to destruction. The expire tween was
never the problem; all four properties already shared the same `TweenInfo` end to end.

The real cause was in `reseat`'s handling of a card once it is no longer the front one. Live-fired
two gains back to back and read the resulting depth-1 card directly:
`BackgroundTransparency = 0.3` (70% opaque) while `TitleLabel`/`MessageLabel.TextTransparency = 1`
(fully invisible) -- a large, solid-looking plate with nothing on it. This is not rare: it happens
every time two notifications land within `HOLD_TIME` of each other (two kills, a kill plus a quest
turn-in, etc.), which is routine gameplay, not an edge case. Combined with the oversized base card
and the viewport scale-up above, this reads exactly as "renders blank, covers half the screen."

## Changes
- `ReplicatedStorage.Modules.NotificationController`
  - `CARD_WIDTH`/`CARD_HEIGHT`: 420x100 -> 280x64. A gain toast is one title word and one short line
    ("+7 Spraypaint"); 420x100 was sized for copy this card never carries.
  - `NotificationGui` now gets its own `UIScale` (`Scale = 1`), so `UIScaleController` skips it (see
    Cause). Comment cites the controller's own opt-out language.
  - `BOTTOM_MARGIN`: 160 -> 24. The weapon HUD moved off bottom-right (see below), so the margin
    only has to clear the screen edge now, not dodge another HUD element.
  - `reseat`'s `contentTransparency` (drives `TitleLabel`/`MessageLabel`/`AccentEdge`) now equals the
    same `dim` value driving the card's own `BackgroundTransparency`, instead of snapping to `1` for
    any depth above 0. Background and content can no longer numerically disagree, at any depth, in
    any tween.
  - `depthGeometry`'s comment updated to describe the new coupled fade instead of the old
    "shapes, not text" design it replaced.
- `ReplicatedStorage.GuiTemplates.Notification` (Instance properties, not a script -- edited directly
  in Studio, no Source to mirror into the repo): `Notification` Frame `Size` -> `280x64`;
  `AccentEdge` `Position (10,10)` `Size (5,44)`; `TitleLabel` `Position (24,12)` `Size (240,18)`
  `TextSize 15`; `MessageLabel` `Position (24,34)` `Size (240,18)` `TextSize 13`. The template's
  child layout was authored for a 420x100 parent (offset positions, not scale), so shrinking the
  script's runtime size alone would have clipped/overflowed the labels against the new
  `ClipsDescendants = true` card -- a self-inflicted second blank-card bug avoided by resizing both
  together.
- `ReplicatedStorage.Blaster.Scripts.GuiController`, `updateAlignment`'s desktop branch: bottom-right
  anchor/position (`AnchorPoint (1,1)`, `Position (1,0),(1,0)`) -> middle-right
  (`AnchorPoint (1,0.5)`, `Position (1,-20),(0.5,0)`). Touch branch untouched. No other method
  touched -- ammo text, weapon name and enable/disable logic are unaffected by an anchor change.

## Verification
All in Play sessions against `FPS System.rbxl`, all timing-sensitive checks combined into a single
`execute_luau` call (fire + poll together) after separate fire-then-poll calls reliably missed the
~4.4s card lifecycle to inter-call latency (see Notes).

- **Ordering, as directed:** weapon HUD moved first, then the notification's `BOTTOM_MARGIN` was
  chosen against the freed space, then both rects were measured together in the same session
  (viewport `900, 719`):
  - Weapon HUD (Crowbar, infinite ammo): `AbsolutePosition (797.5, 302.5)`,
    `AbsoluteSize (62.5, 56)` -> y-range `[302.5, 358.5]`.
  - Weapon HUD (AK47, 30-round mag, confirms ammo count and name render correctly in the new spot):
    `AbsolutePosition (1041.5, 302.5)`, `AbsoluteSize (126.5, 56)`, `NameLabel.Text = "AK47"`,
    `Ammo.MagazineLabel.Text = "/30"`, ammo readout showing `30` (different session, viewport
    `1208, 719` -- not compared cross-session, position formula only).
  - Notification card (front, depth 0): `AbsolutePosition (600, 573)`, `AbsoluteSize (280, 64)` ->
    y-range `[573, 637]`.
  - **Verdict: no intersection.** The two y-ranges (`[302.5, 358.5]` vs `[573, 637]`) are separated
    by 214.5px; x-overlap is irrelevant once y does not overlap.
- **Card size:** `AbsoluteSize` read back as exactly `280, 64` with `NotificationGui`'s `UIScale.Scale
  = 1` -- i.e. not blown up, unlike the pre-fix card on a wide viewport.
- **Labels visible at rest:** front card `BackgroundTransparency = 0`, `TitleLabel.TextTransparency =
  0`, `MessageLabel.TextTransparency = 0` ("SPRAYPAINT" / "+7 Spraypaint").
- **Full expiry watched, never blank:** single card polled every 0.1s, 41 samples, one call. Compacted
  to only the samples where a value changed: `t0` all-`1` (pre-arrival) -> overshoot to `-0.1` (Back
  Out) -> settle to `0` for ~35 samples (steady, visible) -> overshoot to `-0.096` at expire start ->
  `0.161` mid-fade -> destroyed. `BackgroundTransparency`, `TitleLabel.TextTransparency` and
  `MessageLabel.TextTransparency` matched exactly at every single sample -- the card was never
  visible with disagreeing background/text.
- **Stack-of-3, fix confirmed under real stacking:** fired 3 gains back to back, read all 3 live
  cards by depth: depth 0 `bg/titleT/msgT = 0/0/0` (`280x64`), depth 1 `= 0.3/0.3/0.3` (`252x64`),
  depth 2 `= 0.6/0.6/0.6` (`224x64`). Every property matches its own depth's `dim` exactly -- no
  card is ever background-visible with hidden text.
- **Max 3 visible, unmodified logic re-checked:** fired 4 gains rapid-fire; exactly 3 cards remained
  (`+2`, `+3`, `+4`), oldest (`+1`) evicted immediately, matching `MAX_VISIBLE = 3`.
- **Queue while a panel is open, unmodified logic re-checked:** opened the real `PlayerCard` panel
  via a genuine `user_mouse_input` click on `playerCardButton`; a Spraypaint gain fired while it was
  open produced zero cards in the stack (queued, not drawn). Closed via a genuine click on
  `PlayerCard.CloseButton`; the queued card then appeared with `TitleLabel.Text = "SPRAYPAINT"`,
  `MessageLabel.Text` matching the gain, `BackgroundTransparency = 0`, `TitleLabel.TextTransparency =
  0`. (`HOLD_TIME` was temporarily widened to 25s in Studio to make this catchable across tool
  round-trip latency, then reverted to `4` and the reverted `Source` was read back to confirm --
  not part of the shipped diff.)
- **Source edits verified per the standing trap list:** both scripts read back in full after editing;
  every changed region matched the intended text exactly (no silent `string.gsub` failures to guard
  against here -- edits went through `multi_edit`'s exact-match replace, which fails loudly on a
  miss rather than silently matching nothing).
- **Tweens:** `workspace.CurrentCamera.ViewportSize` read non-zero (`900x719` / `1208x719` across
  sessions) throughout, so tweens could and did advance.

## Notes
- The incoming hypothesis (expire-fade desync) did not hold up under direct measurement -- see
  Cause. Worth recording since it was the natural first guess and cost nothing to rule out, but
  the actual bug was one snap-to-hidden line in `reseat`, not a tween-timing race.
- **Environment trap, cost real time here:** two separate `execute_luau` calls -- one to fire a
  gain, a later one to poll the resulting card -- reliably missed the card's ~4.4s lifecycle
  entirely (the card had already arrived, sat, and been destroyed by the time the second call's code
  started running). Every timing-sensitive check in this pass was rewritten to fire and poll inside
  a *single* call; the queue/flush check additionally needed `HOLD_TIME` temporarily widened to 25s
  because it also needed a `user_mouse_input` call (a separate tool) sandwiched in between, which
  cannot be merged into one call the way two `execute_luau` calls can.
- **New environment observation, not a game bug:** in one session, calling
  `Players.LocalPlayer:SetAttribute("Spraypaint", n)` from the Client `execute_luau` context
  *after* a Server-context `execute_luau` call had already written that same attribute in the same
  session threw `Unable to cast Font to Font` and silently ended the Play session. Avoided for the
  rest of this pass by keeping all test writes to a given attribute on one side (client-only) within
  a session. Recorded here since it would cost another agent the same confusion.
- `ReplicatedStorage.GuiTemplates.Notification`'s child layout has no Source to export -- it is an
  Instance property change, live only in `FPS System.rbxl`, not mirrored in this repo.
- No mirror of `ReplicatedStorage.Blaster.Scripts.GuiController` existed in this repo before this
  change; created at `FPSSystem/Cosmetics/GuiController.luau`.
