# Prompt: Global Robbery Notifications + Per-Location Status Billboards

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained. Two independent features, both driven by infrastructure that already exists — read this Context section fully before writing anything.

## Context, confirmed before writing this — read this first

- Every location (`Bank`, `SlowFoods`, `Gas2Go`, `NewsStation`) already broadcasts its own state to **every** client on every transition, via `Net:BroadcastState(location, state, endsAt, cooldownEndsAt)` → `HeistState:FireAllClients(...)` (`ServerScriptService.Heist.Services.Net`). States are exactly `"Idle"`, `"Active"`, `"Cooldown"`. **This is the seam both features below hook into — neither needs a new state remote.**
- `BankInstance`'s `StateChanged` signal only ever fires on a real transition (`_setState` calls inside `TryStart`/`_seal`/`_rearm`) — the very first `Idle` at server boot is set as a plain field in `BankInstance.new()`, never through `_setState`, so it **never fires the signal**. This means "listen for `StateChanged` firing `"Idle"`" is already exactly "a genuine re-open after a Cooldown," with no extra boot-time special-casing needed.
- Each location script (`HeistServer`, `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer`) already has its own `bank.StateChanged:Connect(function(state) ... net:BroadcastState(...) ... end)` handler and its own `bank:TryStart(player)` call site (SlowFoods/Gas2Go/NewsStation call it from `tryTriggerRobbery(player)`; confirm Bank's own trigger path in `HeistServer` before assuming it matches — it may differ in surrounding flow even though it still calls `TryStart`). **If the per-location unification refactor from the earlier optimization prompt has already landed (a shared `LocationServer`-style factory), add both new hooks there once, not in 4 separate files — check which state the codebase is actually in before choosing where to add them.**
- `ReplicatedStorage.SharedSystems.UITransitions` (`SlideIn`/`SlideOut`) is a fully generic, per-instance-keyed slide animation already used for the Toast/timer/duffel labels — it takes any `GuiObject` + a resting `UDim2` + a direction, and re-targeting an already-visible frame to a *new* resting position tweens smoothly from wherever it currently is (confirmed by reading the module) rather than re-snapping off-screen. **This is directly reusable for a stacking queue of notification cards with zero changes to the module** — see Part A.
- The lockpick puzzle already establishes the exact "swap a `UIStroke.Color` between named state colors" pattern (`StarterGui.LockpickGui.Track.Ring.RingStroke`, toggled between idle/hit/miss in `HeistClient.lua`) — reuse this identical technique for the billboard outlines in Part B, don't invent a new coloring mechanism.
- `Workspace.HeistMarkers` (Bank), `Workspace.SlowFoodsMarkers`, `Workspace.Gas2GoMarkers`, `Workspace.NewsStationMarkers` already exist as the established per-location "misc positional marker" folders (currently holding each location's exit-spawn marker, etc.). **Put each new billboard anchor part in its own location's existing folder — don't create a new folder structure.**
- `HeistClient.lua` (`StarterPlayer.StarterPlayerScripts`) already has a `LOCATIONS = { "Bank", "SlowFoods", "Gas2Go", "NewsStation" }` list and a per-frame loop over it that already reads `session.state` for each location, fed by its own existing `HeistState` listener. **Extend that existing loop for Part B's billboard coloring rather than adding a second parallel `HeistState` listener.**
- Recent GUI additions in this project (`SupplierDialogGui`, `LockpickGui`, `HackCodeGui`, `WordScrambleGui`) are all pre-built in `StarterGui` via Studio/`execute_luau` and only referenced by path from LocalScripts — this is the current established convention (superseding the older raw-`Instance.new()`-in-LocalScript style still visible in parts of `HeistClient.lua`). **Follow the newer convention for both new GUIs below.**
- Placeholder display names below (`"the Bank"`, `"SlowFoods"`, `"the Gas Station"`, `"the News Station"`) are a judgment call, not confirmed by the project owner — cheap to change in one place if wrong.

---

## Part A — Global Notification Popups

**Behavior:** every player in the server sees a bottom-right toast-style card, sliding in from off-screen-bottom, when (1) a location re-opens after being sealed, or (2) a player successfully triggers a robbery. Multiple cards can be visible and stacked at once (per the reference image) — a new card doesn't replace an existing one.

### Server

1. In `Net.lua`: add two remotes to `REMOTE_NAMES` (`LocationOpened`, `RobberyTriggered`) and two small dedicated methods, matching the file's existing one-method-per-event style exactly:
   ```lua
   function Net:NotifyLocationOpened(location: string)
   	self.remotes.LocationOpened:FireAllClients(location)
   end

   function Net:NotifyRobberyTriggered(location: string, playerName: string)
   	self.remotes.RobberyTriggered:FireAllClients({ location = location, playerName = playerName })
   end
   ```
2. In each location's `bank.StateChanged` handler, when the new state is `"Idle"`: call `net:NotifyLocationOpened(<locationName>)`, right alongside the existing `net:BroadcastState(...)` call.
3. At each location's `bank:TryStart(player)` success branch (where a personal `net:Toast(player, "Alarm triggered...")` is already sent): also call `net:NotifyRobberyTriggered(<locationName>, player.Name)`.
4. Add one small display-name lookup (placement: `HeistShared.Config` or `Net.lua` itself — your call, but one shared table, not duplicated per file):
   ```lua
   local LOCATION_PHRASE = {
   	Bank = "the Bank",
   	SlowFoods = "SlowFoods",
   	Gas2Go = "the Gas Station",
   	NewsStation = "the News Station",
   }
   ```
   Used to build `"<Capitalized phrase> is open."` and `"<playerName> is robbing <phrase>."` — confirm these read naturally once composed; adjust the table if a phrase capitalizes awkwardly.

### Client

1. Build a new `NotificationGui` `ScreenGui` in `StarterGui` (Studio-authored, per the established convention) containing a template card `Frame` (`NotificationTemplate`, initially not a live child — either kept `Archivable`/disabled for cloning, or stored under `ReplicatedStorage.HeistShared.ModelTemplates`/a new sibling folder next to it, matching how other one-off templates in this project are stored): dark rounded card (`UICorner`), a bold red `"Notification!"` header `TextLabel`, and a body `TextLabel` supporting a bold leading name/segment + a lighter trailing segment (matching the reference screenshot's two-tone body text — e.g. two separate `TextLabel`s or `RichText` bold tags on one label, whichever this project's existing text style leans toward).
2. New LocalScript (`StarterPlayer.StarterPlayerScripts.NotificationClient`, its own file — matches the recent-precedent pattern of one dedicated LocalScript per feature, e.g. `WordScrambleClient`, rather than growing `HeistClient.lua` further) that:
   - Listens to `LocationOpened` → composes `"<Phrase> is open."` (capitalize the phrase's first letter for the sentence-initial case) and `RobberyTriggered` → composes `"<playerName> is robbing <phrase>."` — client mirrors the same `LOCATION_PHRASE` table (client can't require a server-only module; duplicate the small table or move it into a `ReplicatedStorage` location both sides can require — prefer the latter, it's the same "one shared source of truth" discipline this project already applies elsewhere, e.g. `HeistConfig.SupplyCarryingRefusalMessage`).
   - Maintains an ordered Lua list of currently-visible notification card clones.
   - On a new notification: clone `NotificationTemplate`, set its text, parent it under the `NotificationGui`, insert it at the front of the list (closest to the corner), then recompute every card's resting position from its list index and call `UITransitions.SlideIn(card, itsRestingPosition, "Bottom")` for every card in the list — including already-visible ones, whose resting position just changed. Per the module's own documented behavior, an already-visible frame re-targeted this way tweens smoothly to its new spot instead of re-entering from off-screen, which is exactly the "make room, shift up" effect needed.
   - After a fixed display duration (match the existing Toast's 5-second convention unless you have reason to differ), `UITransitions.SlideOut` that card, remove it from the list once hidden (the module already only flips `Visible = false` on the tween's actual completion — destroy the clone at that point, e.g. via a one-shot `GetPropertyChangedSignal("Visible")` check or a matching `task.delay`), and re-run the same "recompute every remaining card's resting position and re-`SlideIn`" step so the stack closes the gap.
3. Anchor the stack bottom-right (e.g. the container `Frame`/`NotificationGui` root using `AnchorPoint (1,1)` and a fixed inset from the corner) — confirm in Play mode this doesn't overlap the existing bottom-left `DropSuppliesButton` or any other corner element `HeistClient.lua` already places.

---

## Part B — Per-Location Status Billboards

**Behavior:** one always-visible, world-space badge floating above each of the 4 locations' buildings: a centered emoji "logo" inside a circular badge, with a colored ring outline reflecting that location's current state — **green = Idle (available), yellow = Active (being robbed), red = Cooldown (sealed)**.

### World placement

1. For each location, add one new anchored, non-collide `Part` (name it consistently, e.g. `StatusBillboardAnchor`) into that location's **existing** markers folder: `Workspace.HeistMarkers` (Bank), `Workspace.SlowFoodsMarkers`, `Workspace.Gas2GoMarkers`, `Workspace.NewsStationMarkers`.
2. Compute a starting position above each location's main building model (`workspace.Bank`, `workspace.SlowFoods`, `workspace.Gas2Go`, `workspace.NewsStation` — for Bank, use the main `Bank` model, not `BankVault`, since the badge should mark the entrance building) via that model's bounding box top-center plus a fixed clearance (e.g. 15-20 studs above the highest point) — **this is a placeholder height, not a confirmed final position; the project owner should hand-adjust each one in Studio afterward to actually clear their specific building's roofline and sightlines.**
3. Parent a `BillboardGui` on each anchor part: `AlwaysOnTop = true`, a sensible `MaxDistance` (placeholder, e.g. `300` studs, so far-away badges don't clutter the whole screen — tune freely), `Size` fixed in Offset (e.g. `UDim2.new(0, 60, 0, 60)`).

   **Addendum (confirmed requirement):** the badge must render at a constant on-screen pixel size regardless of the player's distance from it — no growing as you approach, no shrinking as you move away. A `BillboardGui.Size` expressed purely in Offset (as specified above, with `0` Scale on both axes) already behaves this way natively — do not add any script that recomputes `Size` based on distance from the camera/player, and do not use Scale components on `Size` for this element. Confirm this visually in Play mode by walking toward and away from a badge and checking it stays the same size on screen.

### Badge contents

Inside each `BillboardGui`: a circular `Frame` (`UICorner` with `CornerRadius = UDim.new(1, 0)`, plus an `UIAspectRatioConstraint` of 1 so it stays circular at any size) containing:
- A centered `TextLabel` showing the location's emoji as plain text (placeholders — confirm these actually render as emoji glyphs in Play mode/a screenshot rather than a missing-glyph box for whatever `Font` is used, and pick a different `Font` or a real icon `ImageLabel` later if they don't):
  - Bank → 🏦, SlowFoods → 🍔, Gas2Go → ⛽, NewsStation → 📰
- A `UIStroke` on the circular frame — this is the exact same mechanism already used for `LockpickGui`'s `RingStroke` (`.Color` swapped between named state colors); reuse that technique directly:
  - Idle → green (e.g. `Color3.fromRGB(80, 220, 100)`, matching the lockpick puzzle's own `ZONE_HIT_COLOR`)
  - Active → yellow (e.g. `Color3.fromRGB(255, 200, 80)`, matching the existing "Duffel Full" amber already used elsewhere)
  - Cooldown → red (e.g. `Color3.fromRGB(220, 60, 60)`, matching the lockpick puzzle's own `RING_MISS_COLOR`)

### Client wiring

Extend `HeistClient.lua`'s **existing** per-frame `LOCATIONS` loop (the one already reading `session.state` to drive the timer label) — don't add a second `HeistState` listener:
1. `WaitForChild` each location's `StatusBillboardAnchor` once, up front, alongside the existing per-location label setup.
2. Inside the existing loop, after the current timer/duffel logic, set that location's badge `UIStroke.Color` from `session.state` (`Idle`/`Active`/`Cooldown` → green/yellow/red) via a small lookup table, same pattern as the lockpick puzzle's own idle/hit/miss color constants.
3. No tween/animation needed here beyond the plain color swap — the user's animation request (Part A) is scoped to the notification cards, not the billboards.

---

## Verification checklist

- [ ] Full existing spec suite still passes (adding remotes/methods to `Net.lua` should be additive and non-breaking; if `NetSpec` asserts an exact remote count or list, update it deliberately rather than letting it silently drift).
- [ ] Play-test: triggering a robbery at each of the 4 locations shows a "`<player> is robbing <phrase>`" card to **every** connected player (test with 2+ players/clients if possible), sliding in bottom-right.
- [ ] Play-test: letting a session fully seal and then rearm (or use `Config.Debug.FastLifecycle` to shorten this for testing) shows a "`<phrase> is open.`" card to every player at the moment it reopens, not at server boot.
- [ ] Triggering two notifications close together shows both cards stacked, not one overwriting the other; each independently slides out and the stack closes the gap after its own display duration elapses.
- [ ] All 4 billboards are visible above their respective buildings without blocking the entrance/robbery interaction points, confirmed via screenshot from a normal approach angle.
- [ ] Each billboard's outline is green at Idle, flips to yellow the instant a robbery starts there, and flips to red once sealed — confirmed live across a full trigger → active → cooldown → reopen cycle at each location.
- [ ] Emoji actually render as emoji (not missing-glyph boxes) in Play mode — if any don't, note it back rather than shipping a broken-looking badge.
- [ ] Nothing about the existing Toast, timer, or duffel HUD elements regressed (no new overlap, no stolen focus/`Visible` state).
