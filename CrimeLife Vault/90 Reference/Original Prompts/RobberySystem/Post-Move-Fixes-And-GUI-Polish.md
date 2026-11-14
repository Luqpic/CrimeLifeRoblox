# Prompt: Fix Stale DuffelBag Path + Duffel/Cash/Notification GUI Polish

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained. **Part 0 is a real regression, not a cosmetic request — fix it first.**

## Context, confirmed before writing this — read this first

- The `DuffelBag` accessory model was moved from `Workspace.DuffelBag` to `ReplicatedStorage.HeistShared.DuffelBag` (confirmed: it now lives there, `PrimaryPart` is still correctly set to its `Handle` child). **Multiple places were never updated and still reference the old, now-nonexistent `workspace.DuffelBag`** — this is a live boot-time regression, not a hypothetical one:
  - `ServerScriptService.HeistServer` — a boot assert (`workspace:FindFirstChild("DuffelBag")...`) and the actual `DuffelBagAttachment.new({ template = workspace.DuffelBag })` construction call.
  - `ServerScriptService.SlowFoodsServer` and `ServerScriptService.Gas2GoServer` — each has its own now-stale boot assert (`[SlowFoodsServer]`/`[Gas2GoServer] Workspace.DuffelBag is missing...`).
  - `ServerScriptService.Heist.Services.LocationServer` — its own `DuffelBagAttachment.new({ template = cfg.duffelTemplate or workspace.DuffelBag })` default fallback (line ~193) is what `SlowFoodsServer`/`Gas2GoServer`/`NewsStationServer` actually fall through to today, since none of them currently pass `cfg.duffelTemplate`.
  - `ServerScriptService.Heist.Tests.WorldSpec` ("Workspace.DuffelBag is a plain Model with a PrimaryPart to weld from") and `ServerScriptService.Heist.Tests.DuffelBagAttachmentSpec` both assert against the old path.
  - Re-grep the whole game for `workspace.DuffelBag` / `Workspace.DuffelBag` before considering this done — this list is what a targeted grep found during this pass, not a guarantee nothing else references it.
- The location-unification refactor (`ServerScriptService.Heist.Services.LocationServer`) and both prior GUI prompts (global notifications, per-location status billboards, the duffel bar/upgrade dialog, the timer hourglass) have all already been executed — this prompt is a set of follow-up adjustments on top of that live code, not a fresh build. Read the current state of each file named below before editing; don't work from the earlier prompts' descriptions of what *should* exist.
- The duffel widget (`HeistClient.lua`, `duffelWidget()` builder + the per-frame update loop) currently sets `widget.fill.Size = UDim2.new(ratio, 0, 1, 0)` directly, every `RenderStepped` frame, with no tween — for the three lump-sum locations (SlowFoods/Gas2Go/NewsStation), a robbed register grants cash in one discrete jump, so the bar currently snaps instantly rather than filling smoothly.
- **A persistent cash display already exists** — this is not a new build. `ReplicatedStorage.SharedSystems.CashClaimVFX:_buildPersistentGui()` already creates a `CashDisplay` ScreenGui → `CashFrame` (top-right, the same dark rounded-card style as everything else) → `CashLabel`, currently rendering plain `"Cash: %d"` text in a flat gold color, updated both by the passive `leaderstats.Cash` listener and by the burst/fly claim sequence's own incremental counter. "Revamp the money GUI" means restyle `_buildPersistentGui()`/`_render()`'s presentation to match the richer look established since (icon + bold value, no existing systems duplicated) — it does not mean building a second, parallel cash display.
- `StarterGui.NotificationGui.NotificationTemplate` is currently a fixed `300x74` `Frame` (dark card, `BackgroundTransparency 0.1`) containing exactly `UICorner`, `Header` (`TextLabel`), `Body` (`TextLabel`) — confirmed via direct inspection. `NotificationClient.lua` clones this template per notification and stacks clones via a `restingPosition(index)` function that currently assumes every card shares one constant `CARD_HEIGHT` (`template.Size.Y.Offset`, i.e. `74`) — **this assumption breaks once one notification variant becomes taller than the other** (see Part C).
- The personal "Alarm triggered. You have N minutes." toast is sent from two places: `LocationServer:TryTriggerRobbery` (via `cfg.triggerMessage`, passed in by `SlowFoodsServer`/`Gas2GoServer`/`NewsStationServer`) and separately, by hand, inside `HeistServer.lua` (the Bank, which deliberately does not use `LocationServer`) at its own `net:Toast(player, string.format("Alarm triggered. You have %d minutes.", ...))` call. Both need removing (see Part D) — fixing only the `LocationServer` copy would leave the Bank's own duplicate behind.

---

## Part 0 — Fix the stale `workspace.DuffelBag` references (do this first)

1. Update every reference identified above (`HeistServer`, `SlowFoodsServer`, `Gas2GoServer`, `LocationServer`'s default, `WorldSpec`, `DuffelBagAttachmentSpec`) to point at `ReplicatedStorage.HeistShared.DuffelBag` instead of `workspace.DuffelBag`. Re-grep afterward to confirm zero remaining hits.
2. Verify boot-time: enter Play mode and confirm none of the four location scripts throws on the now-corrected asserts, and that a robbed duffel still visually attaches to a player's back exactly as before (the model itself didn't change, only its storage location).
3. Run the full spec suite (`TestRunner`/`RunAll`) and confirm `WorldSpec`/`DuffelBagAttachmentSpec` pass against the corrected path.

## Part A — Duffel widget: rename header, tween the fill bar

1. In `HeistClient.lua`, change every place the duffel widget's header is set to the literal string `"Robbing..."` (both the initial `duffelWidget()` builder default and the per-frame reassignment in the main `RenderStepped` loop) to `"DuffelBag"`. Leave the separate `"DUFFEL FULL"` state text exactly as it is — only the `"Robbing..."` string was asked to change.
2. Replace the direct `widget.fill.Size = UDim2.new(ratio, 0, 1, 0)` assignment with a tween. Guard it the same "edge-triggered" way this file already guards `timerShown`/`duffelShown` elsewhere: track each widget's last-applied ratio (e.g. `widget._lastRatio`), and only create/play a new `TweenService:Create(widget.fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(ratio, 0, 1, 0) })` when the ratio actually changed since last frame — creating a fresh Tween on every one of 60 frames/second even when nothing changed would be wasteful and would fight itself. Keep a reference to the in-flight tween per widget so a rapid re-trigger cancels the stale one rather than layering tweens, the same discipline `UITransitions`'s own `activeTweens`/`cancelActive` already applies elsewhere in this project.

## Part B — Cash display revamp (`CashClaimVFX.lua`)

Restyle `_buildPersistentGui()` and `_render()` only — do not touch `PlaySequence`'s burst/fly logic, `_targetPosition()`, or the passive-listener grace-window handling; none of that needs to change.

1. Add a small icon to `CashFrame` — a 💵 (or similar) emoji `TextLabel`, matching the same "Use Emojis for now, confirm it actually renders" placeholder approach already established for the status billboards — positioned left of the numeric value.
2. Change `CashLabel`'s text from `"Cash: %d"` to just the formatted number (e.g. `"%d"`, comma-grouped if you want to match the reference image's `13,760` styling — Roblox has no built-in thousands-separator formatting, so this needs a small manual formatter if you want it), in a bold, slightly larger style consistent with the duffel widget's own `AmountText` treatment (`Font = GothamBold`) rather than the current flat gold text.
3. Keep the same overall card chrome (dark background, `UICorner`) already used everywhere — this is a content/typography refresh, not a new visual language.
4. Since `_targetPosition()` derives entirely from `CASH_FRAME_POSITION`/`CASH_FRAME_SIZE`/`CASH_FRAME_ANCHOR`, any resize to fit the new icon just needs those three constants kept consistent with each other — don't hardcode a second position anywhere else.

## Part C — Notification card: add an "Alarm Triggered!" inset box

This applies to the **robbery-triggered** notification variant only (`"<player> is robbing <location>."`), not the location-reopened variant.

1. Add a new child to `StarterGui.NotificationGui.NotificationTemplate` (Studio-authored, alongside the existing `Header`/`Body`): an inset sub-panel (e.g. a small `Frame` with its own subtle background/`UICorner`, or a plain `TextLabel` if a sub-panel reads as overkill once actually laid out) reading `"Alarm Triggered!"`, positioned below `Body`. Leave it `Visible = false` by default in the template (so the location-reopened variant, which clones the same template, doesn't show it).
2. In `NotificationClient.lua`, the `RobberyTriggered` handler needs to reveal this element on its own cloned card and grow that clone's `Size.Y` to fit it — **but the stacking math currently assumes one shared `CARD_HEIGHT` for every card, which breaks the moment two variants have different heights.** Change `restingPosition`/`reflow` to read each card's own actual `Size.Y.Offset` at reflow time instead of the single template-derived constant, so a mix of tall (robbery-triggered) and short (location-opened) cards stacks correctly regardless of order.
3. The `LocationOpened` handler's card should NOT show this element — confirm its clone leaves the sub-panel hidden and sized as before.

## Part D — Remove the now-redundant personal "Alarm triggered" toast

The new global `RobberyTriggered` notification (`NotifyRobberyTriggered`, `FireAllClients`) already reaches the triggering player too, so the old personal toast is now duplicate information for exactly the person who most needs a clear signal, not less.

1. In `LocationServer.lua`'s `TryTriggerRobbery`, remove the `self.net:Toast(player, message)` call and, since that was `_triggerMessage`'s only remaining use, remove `_triggerMessage`/`cfg.triggerMessage` entirely — the field, its constructor assert, and the local `message` variable — rather than leaving now-dead plumbing behind.
2. Remove the corresponding `triggerMessage = ...` argument from every `LocationServer.new({...})` call site (`SlowFoodsServer.lua`, `Gas2GoServer.lua`, `NewsStationServer.lua` — confirm each one's exact current call shape before editing, they may not be identical).
3. In `HeistServer.lua` (the Bank, which does not go through `LocationServer`), remove its own separate `net:Toast(player, string.format("Alarm triggered. You have %d minutes.", ...))` call at its own trigger success point.
4. Update `ServerScriptService.Heist.Tests.LocationServerSpec` — it currently constructs its test fixture with `triggerMessage = "Alarm triggered. You have two minutes."` and asserts the exact toast text (`expect.equal(lastToast[2], "Alarm triggered. You have two minutes.", ...)`) — remove or rewrite that assertion to match the new, no-personal-toast behavior rather than leaving a test that now asserts removed behavior.
5. Confirm the four locations' own `NotifyRobberyTriggered` calls (already in place) are unaffected — this Part only removes the personal `Toast`, not the global notification.

---

## Verification checklist

- [ ] Full spec suite passes, including the corrected `WorldSpec`/`DuffelBagAttachmentSpec` and the updated `LocationServerSpec`.
- [ ] All 4 locations boot cleanly in Play mode with no stale-path assert errors; robbing at each location still visually attaches/detaches the duffel bag accessory correctly.
- [ ] Duffel widget reads "DuffelBag" instead of "Robbing...", and its bar visibly tweens/fills smoothly on a lump-sum grant rather than snapping — confirmed by screenshot or description of an actual Play-mode robbery at a lump-sum location (SlowFoods/Gas2Go/NewsStation).
- [ ] Cash display (top-right) shows the new icon + revamped number styling, still updates correctly both passively (leaderstats change) and via the claim burst sequence, with no regression to the fly-to-target animation.
- [ ] Triggering a robbery shows a global notification card with the "Alarm Triggered!" sub-box visible; a location reopening shows a card without it; both stack correctly together when both are on screen at once (confirm with the two variants triggered close together).
- [ ] The player who triggers a robbery no longer sees a separate personal "Alarm triggered. You have N minutes." toast — only the global notification card.
- [ ] Nothing else on the HUD (timer, billboards, other dialogs) regressed.
