# Prompt: Timer Hourglass Icon + Duffel Bar Redesign with Gamepass Upgrade Button

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained. Two GUI changes to `HeistClient.lua`'s existing per-location HUD elements, one of which (the duffel "+" button) is a UI front-end for a monetization system that **already exists in code but is not yet wired to any button or usable Gamepass IDs** — read the Context section fully before writing anything.

## Context, confirmed before writing this — read this first

- Both elements being changed today (`timerLabels[location]`, `duffelLabels[location]`) are built via runtime `Instance.new()` directly inside `HeistClient.lua`'s `label()` helper, in the file's older established style (shared with the Toast label) — distinct from the newer "pre-built in StarterGui, referenced by path" convention used for triggered dialogs (`SupplierDialogGui`, `LockpickGui`, `HackCodeGui`, `WordScrambleGui`, and the recently-added `NotificationGui`). **Keep the ambient always-present timer/duffel HUD elements in the older runtime-built style for consistency with their immediate siblings in the same file** — but the new duffel-upgrade dialog below (a triggered modal, not an ambient HUD strip) should follow the **newer** pre-built-in-Studio convention, matching its closer relatives.
- **The "pay for x2/x4 duffel size" system already exists**, fully implemented, in `ReplicatedStorage.SharedSystems.GamepassManager`: real Roblox Gamepasses (`GamepassManager.GamepassConfig.DuffelCapacityX2`/`DuffelCapacityX4`, multipliers 2x/4x, highest-tier-wins, no stacking) already drive `BankInstance:GetDuffelCapMultiplier` server-side, and `GamepassManager:Init()` already listens for `MarketplaceService.PromptGamePassPurchaseFinished` and updates its ownership cache the instant a purchase completes. **Nothing anywhere currently calls `MarketplaceService:PromptGamePassPurchase` to actually show the purchase dialog** — today's task is exactly that missing trigger, a UI front-end for an already-complete backend. Do not build a second currency/upgrade system; wire into this one.
- Because the multiplier is re-read fresh on every `Accrue`/`GetDuffelCap` call (never cached per-session), **a purchase completing mid-robbery takes effect immediately, with zero additional server-side work needed** — confirm this rather than adding redundant plumbing.
- **Blocker the project owner must clear, not something Studio/code can resolve:** every `Id` in `GamepassManager.GamepassConfig` is still the placeholder `0` (an explicit `TODO(project owner)` already in the file) — these are real Roblox Gamepasses that must be created via the Creator Dashboard (a monetization/business decision, outside what an automated session should do) before purchases can be tested end-to-end. Build and wire everything below regardless; verify the dialog opens/closes and both buttons attempt to call `PromptGamePassPurchase` correctly, but flag clearly (don't silently pretend it's fully verified) that a real purchase round-trip can't be tested until real IDs are filled in.
- `GamepassManager` lives under `ReplicatedStorage` specifically so both server and client can reach it — the module's own header comment restricts *server-side robbery/gameplay logic* (e.g. `BankInstance`) from requiring it directly (that code must only see injected multiplier results, to stay unit-testable). That restriction does not apply to client-side purchase UI, which has no way to call `MarketplaceService:PromptGamePassPurchase` without knowing the real Gamepass Id — requiring `GamepassManager` directly from the new client dialog script is the correct, intended use, not a violation of that rule.
- `ReplicatedStorage.SharedSystems.UITransitions` (`SlideIn`/`SlideOut`, generic per-instance slide animation) is already established and reused for exactly this kind of thing (see the recent Notification cards) — use it for the new dialog's slide-in/out too, don't write a bespoke tween.
- Keep both changes visually consistent with the rest of this project's HUD: dark, semi-transparent background (`BackgroundColor3 = Color3.fromRGB(15, 15, 18)`, `BackgroundTransparency` around `0.35`), `Font = Enum.Font.GothamBold`, `UICorner` rounding — the same palette/typography already established in `HeistClient.lua`'s `label()` helper. The reference images' green fill-bar/button colors are additions on top of that base card style, not a replacement for it.

---

## Part A — Timer: hourglass icon, drop the "HEIST" word

Reference: countdown reads just `05:46` beside a small hourglass icon, no state-name text.

1. In `HeistClient.lua`, change `timerLabel.Text = "HEIST  " .. formatClock(remaining)` to just `formatClock(remaining)`.
2. Add a small hourglass icon beside the countdown text, inside the same card. Two viable approaches — pick whichever renders correctly once actually tested:
   - A second `TextLabel` (or the same label, text-concatenated) containing the Unicode hourglass glyph (⌛ or ⏳) — simplest, but confirm live in Play mode/a screenshot that the chosen `Font` actually renders it as a real glyph rather than a missing-character box (the same caveat already flagged for the billboard emoji in the earlier prompt).
   - If the glyph doesn't render acceptably, fall back to a small `ImageLabel` with any suitable built-in Roblox icon asset instead — don't ship a broken-looking tofu box either way.
3. Keep the existing red-under-60-seconds urgency color behavior (`remaining < 60 → Color3.fromRGB(255, 90, 90)`) completely unchanged — this is existing, working UX, not part of what's being redesigned.
4. This still needs to exist independently per location (4 instances, same as today) with the same show/hide (`UITransitions.SlideIn`/`SlideOut`) and zone-gating logic already in place — only the label's own contents/layout change, not when or why it appears.

## Part B — Duffel bar redesign + Gamepass upgrade button

Reference: a card reading `Robbing...` above a horizontal green progress bar showing `10000 / 20000` (filled proportionally to amount/cap), with a small green "+" square button at the bar's right end.

### B.1 — Redesign the existing duffel display

Replace each location's plain `duffelLabel` `TextLabel` with a small composite widget (still built via `Instance.new()` in `HeistClient.lua`, alongside its neighbors — see Context above for why):
- A header `TextLabel` reading `"Robbing..."` (static text, shown/hidden together with the rest of the widget under the same existing `wantDuffel` gating logic already in place).
- A bar: a background/track `Frame` (a muted dark green) containing a foreground fill `Frame` whose `Size.X.Scale` is set to `amount / cap` each frame (clamped `0..1`) in a brighter green — same place in the code that already computes `amount`/`duffel.cap` today.
- The existing `"%d / %d"` amount text, centered and overlaid on the bar (on top of both track and fill, highest `ZIndex` in the widget) rather than as the whole label's text.
- Preserve the existing "DUFFEL FULL" amber-colored state when `amount >= cap` — reflect it either as the header text changing, the bar fill color changing to amber, or both; keep the existing one-shot `DuffelFullSound` cue exactly as-is.

### B.2 — The "+" button and its upgrade dialog

1. Add a small square "+" `TextButton` (green, rounded, bold white `+`) anchored at the bar's right edge, part of the same per-location widget.
2. Build a new `DuffelUpgradeGui` `ScreenGui` in `StarterGui` (Studio-authored, matching the newer pre-built-dialog convention — see Context) containing a dialog frame with:
   - A short prompt (e.g. "Upgrade your duffel capacity") and an exit/close control, same dismissal convention already used elsewhere (an "X"/exit button, no penalty for backing out).
   - Two buttons: "x2 Capacity" and "x4 Capacity".
3. New LocalScript wiring (can live alongside the duffel widget's own code in `HeistClient.lua`, or its own file if that reads cleaner — your call, but don't split the "+" click handler and the dialog it opens across two disconnected places):
   - Clicking "+" opens `DuffelUpgradeGui` via `UITransitions.SlideIn(...)` from a screen edge (right, to match the button's own position — adjust if it reads better from the left once actually laid out) rather than `Bottom`/`Top` (keep those directions reserved for the toast/notification stack so the two don't read as the same kind of thing).
   - Clicking "x2 Capacity" or "x4 Capacity": `require(ReplicatedStorage.SharedSystems.GamepassManager)`, read the corresponding `GamepassConfig.DuffelCapacityX2.Id`/`DuffelCapacityX4.Id`, and call `MarketplaceService:PromptGamePassPurchase(player, id)`. Wrap in `pcall` — an `Id` of `0` (today's placeholder state) may error; fail soft (e.g. a console warning) rather than crashing the LocalScript.
   - Close the dialog (`UITransitions.SlideOut`) after either button is pressed — Roblox's own native purchase dialog takes over from there; nothing further needs to happen client-side (the server already reacts to a completed purchase via the existing `PromptGamePassPurchaseFinished` listener).
4. Optional, not required for this pass: query `MarketplaceService:UserOwnsGamePassAsync` (or `GamepassManager:PlayerOwnsGamepass`, callable client-side for the LocalPlayer) to show an "Owned" state instead of a buy button for a tier the player already has. Roblox's native purchase prompt already handles an already-owned gamepass gracefully on its own, so skip this if it adds meaningfully more work than value.

---

## Verification checklist

- [ ] Timer shows just `mm:ss` + a legible hourglass icon, no leftover "HEIST" text; still slides in/out exactly when it did before (Active + player inside zone), still turns red under 60 seconds.
- [ ] Duffel widget shows "Robbing..." + a proportionally-filled bar + centered "amount / cap" text + a visible "+" button, at all 4 locations, still gated by the same existing visibility/zone rules as before.
- [ ] "DUFFEL FULL" state (amber, one-shot sound) still behaves identically to before the redesign.
- [ ] Clicking "+" slides in `DuffelUpgradeGui`; clicking its exit control slides it back out without side effects.
- [ ] Clicking "x2 Capacity"/"x4 Capacity" calls `MarketplaceService:PromptGamePassPurchase` with the configured (currently placeholder) Id, wrapped safely so a `0` Id doesn't crash the client.
- [ ] Confirmed (by reading the code, not assumed): a completed purchase requires no additional server wiring beyond what `GamepassManager:Init()` already does — the next accrual tick already reflects the new cap.
- [ ] Explicitly reported back: real Gamepass Ids still need to be created and filled in by the project owner before this can be purchase-tested for real; this is not something left silently unverified.
- [ ] No regression to the existing Toast/Notification stack, Safe GUI, or any other HUD element sharing screen space with these two.
