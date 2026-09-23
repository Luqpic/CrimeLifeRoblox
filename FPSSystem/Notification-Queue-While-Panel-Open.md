# Change Log: Notification Queue While A Panel Is Open

**Date:** 2026-09-23
**Status:** Confirmed live in `FPS System.rbxl` (one Play session, Client/Server datamodels). See
Verification and Notes for exactly what was, and was not, directly observed.

## Summary
Notifications now queue instead of drawing while a full-screen panel is open, and flush staggered
(~0.12s apart) once the panel closes, so they animate into the stack in sequence rather than dumping
at once. Public `NotificationController.show(message, title?)` is unchanged; both callers
(`QuestFeedbackController`, `SpraypaintHud`) needed no changes. Built entirely on `UI.Panels`'s
existing `current()` / `onChanged()` -- no second tracking of "which panel is open" was added.

## Cause
Notifications were just moved to a bottom-right overlapping-card stack (previous change log).
Measured: the stack occupies `x[460,880] y[381,501]`, and the weapon shop panel occupies
`x[27,873] y[63.8,597]` -- so a notification lands directly over the shop's own BUY button, the exact
moment a player is looking at their balance. The shop is near-fullscreen and nothing on screen clears
both it and the ammo HUD (`x[753.5,880] y[585,641]`), so no margin adjustment fixes it. Queueing was
chosen over suppressing.

## Changes
- `ReplicatedStorage.Modules.NotificationController` -- `show`'s old body (clone/tween/evict) moved
  unchanged into a private `displayNow`. `show` now checks `Panels.current()`: `nil` displays
  immediately (unchanged behaviour), non-nil pushes `{message, title}` onto a private `queue`.
- Queue capped at 8; over cap, the oldest entry is dropped (`table.remove(queue, 1)`) -- a long
  shopping trip should surface a player's recent gains, not the first ones from when they walked in.
- One `Panels.onChanged` subscription (module scope, fires once at require time): `nil` ->
  `flushQueue()`, non-nil -> `stopFlush()`.
- `flushQueue` runs in a cancellable `task.spawn` thread, `task.wait(0.12)` between cards. A panel
  reopening mid-flush is handled by that same `onChanged` subscription calling `stopFlush`, which
  cancels the thread; whatever hadn't been shifted off `queue` yet is simply still sitting there, so
  the next close flushes it -- no separate re-queue path was needed.
- `UI.Panels` itself untouched, as required.

## Verification
All in one Play session. `execute_luau`'s own `require()` was confirmed to build a separate module
instance from the one the live game scripts share (see Notes), so every row below drives the *real*
callers through genuine engine-level events -- attribute changes and actual clicks via
`user_mouse_input` -- never by calling `.show()` or `Panels.opened()` directly against a throwaway
copy.
- **Baseline, no panel open:** incrementing `Quest_Level1Thugs_Completions` and `Spraypaint`
  (LocalPlayer attributes) produced two immediate cards -- "QUEST COMPLETE / A Warning to Thugs" and
  "SPRAYPAINT / +7 Spraypaint" -- confirming both real callers still work unchanged.
- **Queueing:** opened the real weapon shop with a genuine click on `weaponaryButton` (confirmed via
  `shop.Visible = true` and the HUD's `"Custom Inventory".Enabled = false`). Pushed 12 distinct
  Spraypaint gains (+1..+12, one `task.wait()` between each -- back-to-back `SetAttribute` calls with
  no yield between them coalesce under Roblox's deferred attribute-changed signal; a first attempt
  with no yields produced a single "+78" notification instead of 12, confirming the coalescing rather
  than a queue bug). Zero cards appeared on screen while the shop stayed open.
- **Cap and flush:** closed the shop with a genuine click on `CloseButton`. Flush produced exactly 8
  cards, "+5 Spraypaint" through "+12 Spraypaint" in that order -- the oldest four (+1..+4) correctly
  dropped by the cap -- spanning 0.927s across the 8 arrivals (~0.132s/gap against the 0.12s target;
  the difference is scheduling overhead at the reduced frame rate noted below, not a stagger bug).
- **Stack-of-3 cap** (pre-existing, unmodified `displayNow` logic, re-checked because it sits
  downstream of the new flush path): 6 rapid `show()` calls against an isolated module copy settled to
  exactly the newest 3 ("Stack cap test 4/5/6"), confirming the flush path doesn't bypass it.
- **Tweens:** `workspace.CurrentCamera.ViewportSize` read `900, 719` (not collapsed) and
  `RenderStepped` measured ~15 fps over 1s -- non-zero, so tweens could and did advance, just at a
  reduced rate for this automated session rather than a smooth 60fps.
- **Source edit, verified per the standing trap list:** read `Source` back after editing, confirmed
  all nine new symbols present with a plain `string.find(src, needle, 1, true)`, and byte length moved
  7132 -> 8901.

## Notes
- `execute_luau`'s own `require()` builds a separate module instance from the one the live game
  scripts share -- confirmed directly: a second `NotificationGui` appeared under `PlayerGui` the
  moment `NotificationController` was required from that context, and it never received any card the
  real callers displayed. Calling `.show()` or `Panels.opened()` from that context therefore never
  touches the real queue or the real panel state; it was used only for the isolated stack-of-3 check
  above, never for anything claiming to exercise the real system.
- Per the standing trap list (a previous agent broke live notifications by destroying this module's
  cached GUI instance while probing it): neither `NotificationGui` -- the real one or the incidental
  duplicate created above -- was destroyed. Both are session-only PlayerGui children and clear on
  Stop; no cleanup was needed or attempted.
- Rapid same-frame `SetAttribute` calls collapsing into one deferred change (the "+78" result) is a
  Roblox engine behaviour (Deferred signal semantics), not something this change touches -- noted here
  because it cost a first test attempt and would cost another agent the same time if unrecorded.
