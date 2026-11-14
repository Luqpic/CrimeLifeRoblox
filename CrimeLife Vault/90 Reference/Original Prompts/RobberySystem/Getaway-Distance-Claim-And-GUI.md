# Prompt: Replace the Claim Zone With a Getaway Distance + Escape GUI

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

**What this changes, in one sentence:** robbed cash no longer banks by walking into a Claim zone — it banks when the player gets at least N studs clear of the location they robbed, with a new HUD widget counting the studs down.

---

## Context, confirmed live before writing this — read this first

Every fact below was read out of the running place, not recalled. Re-read each file before editing it; do not work from this document's paraphrase of what the code does.

### The claim path exists twice, and both copies are identical

- `ServerScriptService.HeistServer` (the Bank) — a `zoneService.Entered` handler guarded on `if role ~= "Claim" then return end`, which calls `bank:Claim(player)`, bails on `amount <= 0`, then `currency:Add(player.UserId, banked)` → `net:Toast(player, "Banked %d %s.")` → `net:NotifyRobberySuccess(player)`.
- `ServerScriptService.Heist.Services.LocationServer` (SlowFoods, Gas2Go, NewsStation) — the same handler, byte-for-byte the same body, guarded on `self.claimRole` (which defaults to `"Claim"` via `cfg.claimRole or "Claim"`).

The Bank is deliberately NOT a consumer of `LocationServer` — see that module's own header comment for the four reasons why, all of which still hold. Do not "fix" that as part of this work.

### The payout is gated on the session still being Active

`ServerScriptService.Heist.BankInstance`:

```lua
function BankInstance:Claim(player): number
	if self._state ~= ACTIVE then return 0 end
	if not self:IsParticipant(player) then return 0 end
	...
```

Its comment calls this "the second half of the dupe fix". **Do not relax either guard.** The consequence, which is intended and was decided explicitly: the escape run must finish before the session timer expires, or `_seal` → `VoidDuffel` takes the bag. Losing the run to the clock is the intended failure mode.

### The world geometry, measured

`StatusBillboardAnchor` exists in all four markers folders and sits directly over each location's interior zone (horizontal distance to the interior zone centre is 0 for the Bank). The anchors float high for billboard reasons — the Bank's is at Y=136.4 above a lobby at Y=18.5.

| Location | Markers folder | Anchor (X, Y, Z) | Its ExitSpawn's XZ distance from that anchor |
|---|---|---|---|
| Bank | `HeistMarkers` | 176.2, 136.4, -131.4 | 80 |
| SlowFoods | `SlowFoodsMarkers` | 100.0, 62.8, -278.1 | 55 |
| Gas2Go | `Gas2GoMarkers` | -101.4, 48.0, -318.0 | 61 |
| NewsStation | `NewsStationMarkers` | -266.5, 57.0, -334.5 | 54 |

Anchor-to-anchor spacing: Bank↔SlowFoods 165, SlowFoods↔Gas2Go 205, Gas2Go↔NewsStation 166, Bank↔Gas2Go 334, SlowFoods↔NewsStation 371, Bank↔NewsStation 487.

**The Bank's `VaultZone` is 314 studs horizontally from the Bank's own anchor.** This is the single most important number in this document. The vault is where the Bank's duffel actually fills, so a naive "distance from the anchor ≥ N" check with any N below ~314 would bank the Bank's cash the instant it entered the bag, with no getaway at all. Part 1's arming condition is what prevents this; do not simplify it away.

### The arming condition already exists and is already replicated

`HeistServer`'s `updateZoneOccupancy` computes `inside` as `Lobby OR Vault OR BankVaultZone` — the lobby, the vault, and the whole underground gauntlet between them — with the comment "Claim is deliberately excluded (it's outside)". `LocationServer:_updateZoneOccupancy` does the equivalent for its single `interiorRole`. Both push it to the owning client through `net:BroadcastZoneOccupancy`, and `HeistClient` already keeps it in `zoneOccupancy[location]`.

So "the player is outside the whole building" is already computed server-side AND already on the client. Neither side needs a new signal for it.

### Session durations and the clock budget

`SessionDuration`: Bank 600s, SlowFoods 120s, Gas2Go 300s, NewsStation 600s. `StarterPlayer.CharacterWalkSpeed` is 16. Starting from the ExitSpawn (54–80 studs out), reaching 200 studs is a 120–145 stud run ≈ 8–9 seconds. That is comfortable even against SlowFoods' 120-second session.

### The timer widget, which the new GUI copies

Built in `HeistClient` by the `imagePanel(name, key, position)` helper: a 240×76 `ImageLabel` (`UITheme.Assets.TimerNormal` = `rbxassetid://129938094868701`, `UITheme.Size.TimerNormal` = `Vector2.new(240, 76)`), `AnchorPoint` (0.5, 0), with exactly one live child — a `TextLabel` named `Time` at `UDim2.fromOffset(34, 12)`, size 190×32, `UITheme.Font.Display`, `TextSize` 28, `UITheme.Color.accent`, `ZIndex` 2. The "TIME REMAINING" caption and the accent edge are **baked into the image**; only the clock is live. Urgency under 60s swaps the whole slice to `UITheme.Assets.TimerUrgent` and recolours the text to `UITheme.Color.danger`, guarded on an actual change because the loop runs every frame and reassigning `.Image` re-triggers a texture fetch.

### The HUD stack is derived, not hardcoded

```lua
local HUD_TOP, HUD_GUTTER = 12, 8
local TIMER_POSITION  = UDim2.new(0.5, 0, 0, HUD_TOP)
local DUFFEL_TOP      = HUD_TOP + 76 + HUD_GUTTER          -- below the 76px timer
local DUFFEL_POSITION = UDim2.new(0.5, 0, 0, DUFFEL_TOP)
local TOAST_POSITION  = UDim2.new(0.5, 0, 0, DUFFEL_TOP + 92 + HUD_GUTTER) -- below the 92px duffel
```

Its comment states the intent explicitly: "Deriving the offsets means a future size change moves everything below it automatically instead of re-introducing the same bug." Insert the new widget into this chain; do not hardcode a new literal.

### The client already resolves the anchor Parts

`HeistClient` has `MARKER_FOLDERS = { Bank = "HeistMarkers", SlowFoods = "SlowFoodsMarkers", Gas2Go = "Gas2GoMarkers", NewsStation = "NewsStationMarkers" }` and already does `workspace:WaitForChild(MARKER_FOLDERS[location], 10)` → `folder:WaitForChild("StatusBillboardAnchor", 10)` to hang the status billboards off it. Reuse that resolution rather than adding a second one — but note it currently keeps only the `StatusImage` descendant, so it needs to also retain the anchor Part itself.

### The zone parts that become dead

| Part | Role | Position |
|---|---|---|
| `Workspace.HeistZones.ClaimZone` | Claim | 109.6, 18.5, -131.4 |
| `Workspace.SlowFoodsZones.RestaurantClaimZone` | Claim | 45, 7, -272.4 |
| `Workspace.Gas2GoZones.Gas2GoClaimZone` | Claim | -101.4, 11.2, -240 |
| `Workspace.NewsStationZones.NewsStationClaimZone` | Claim | -215, 7, -269.6 |

`HeistServer`'s boot validation asserts `#zones == 6` over the `HeistZone` tag and asserts `roles.Lobby and roles.Vault and roles.Claim and roles.BankVaultZone`. `ServerScriptService.Heist.Tests.WorldSpec` asserts per-location manifest counts. Both break the moment a Claim part is deleted.

---

## Part 1 — New shared service: `ServerScriptService.Heist.Services.Getaway`

One implementation, two consumers, following the exact shape of the sibling services `Forfeit`, `AlarmEffects` and `DuffelBagAttachment` (constructor takes an injectable dependency table; no global state; unit-testable without touching `workspace`).

**Why a service and not an inline check in both files:** the payout gate is the last thing in this codebase that should exist in two copies, and `LocationServer`'s entire reason for existing was eliminating exactly this duplication. It also keeps the distance maths testable without a DataModel.

1. Create the module with a `Getaway.new(cfg)` taking:
   - `anchor` — the location's `StatusBillboardAnchor` Part (or, for testability, `getAnchorPosition` returning a `Vector3`).
   - `escapeDistance` — N, read from that location's Config (Part 2).
   - `isInsideBuilding(player) -> boolean` — injected by the consumer, since the Bank's definition is a three-role union and the others' is a single role. **Do not reimplement the union inside this service**; the consumers already own that logic.
   - `getDuffel(player) -> number`, `onEscaped(player)`, `getPlayers()`, and a `getPosition(player)` defaulting to the player's character pivot.
2. Give it a `Step()` method that, for each player: returns early unless they hold a bag (`getDuffel > 0`); returns early if `isInsideBuilding(player)`; computes **horizontal** distance from the anchor — zero out Y on both vectors before `.Magnitude`, because the anchors float 40–120 studs above their buildings and a 3D distance would be wrong everywhere; and calls `onEscaped(player)` once when that distance is ≥ `escapeDistance`.
3. Expose `DistanceRemaining(player) -> number?` returning the studs still needed (nil when not armed). The server does not send this anywhere — it exists so a spec can assert against the same number the client renders.
4. Guard `onEscaped` against double-firing within one bag, the same edge-triggered discipline `duffelFullNotified` and `timerShown` already use elsewhere. Clear the latch when the player's duffel returns to 0, so a second bag escapes independently.
5. Handle a missing character or a nil `PrimaryPart` by treating the player as not-yet-escaped, never by erroring — this runs on a heartbeat and must not take the loop down mid-session.

## Part 2 — `EscapeDistance = 200` in each location's Config

Add `EscapeDistance` to all four config modules: `ReplicatedStorage.HeistShared.Config`, `RestaurantShared.Config`, `Gas2GoShared.Config`, `NewsStationShared.Config`. Per-location rather than one shared constant, matching how `SessionDuration`/`DuffelCap`/`CooldownDuration` are already organised — and these configs are in `ReplicatedStorage`, so the client can read the same number without a new remote.

Set all four to `200` initially. The reasoning, so a later tuning pass has it: the ExitSpawns sit 54–80 studs out, so 200 is a 120–145 stud run (≈8–9s at WalkSpeed 16), and with neighbouring locations 165–205 apart it reads as "about one block over" without forcing the player through another location's grounds.

Add a comment recording that any value at or above ~314 would let a Bank player satisfy the gate from inside the vault if the arming condition were ever removed.

## Part 3 — Wire it into both servers, and delete the Claim handlers

1. In `LocationServer.new`, construct a `Getaway` (injectable via `cfg.getaway` for tests) with `isInsideBuilding = function(player) return self.zoneService:IsInside(self.interiorRole, player) end` and the anchor resolved from the location's markers folder. Add a `cfg.markerFolder` argument, since the Bank's is `HeistMarkers` rather than `BankMarkers` and the three consumers' names are not derivable from `cfg.name` either.
2. Call `self.getaway:Step()` from `LocationServer:Tick()`, alongside the existing `self:_updateZoneOccupancy()`. The heartbeat already runs at `1 / self.config.HeartbeatRate`; do not add a second loop.
3. Point `onEscaped` at the **existing** claim body, moved verbatim out of the `zoneService.Entered` handler: `bank:Claim(player)` → bail on `<= 0` → `currency:Add` → `net:Toast(player, "Banked %d %s.")` → `net:NotifyRobberySuccess(player)`. The ordering comment ("Fired after currency:Add so leaderstats.Cash.Value has already replicated...") must move with it — it is still load-bearing for `CashClaimVFX`.
4. Delete the `if role ~= self.claimRole then return end` handler and the now-unused `claimRole` field and its `cfg.claimRole or "Claim"` default.
5. Do the same three things in `HeistServer`: construct a `Getaway` with `isInsideBuilding` = the existing `Lobby OR Vault OR BankVaultZone` union (reuse `insideBuilding`/`updateZoneOccupancy`'s own expression rather than writing a second copy), call `Step()` from the same loop that already calls `updateZoneOccupancy()`, move its claim body into `onEscaped`, and delete its `if role ~= "Claim" then return end` handler.
6. Update `HeistServer`'s toast literal `"Duffel Full — head back to claim it."` and `LocationServer`'s `REFUSAL_MESSAGES.cap_exceeded` (`"Duffel Full -- head back to claim it."`) — "head back" is now exactly wrong advice. Use wording that says to get clear of the building instead.

## Part 4 — Retire the Claim zones

**Do not delete world parts without confirming with the user first.** Present the four parts from the table above and get explicit approval before removing any of them.

Once approved:

1. Delete the four `*ClaimZone` parts listed in the context section.
2. `HeistServer`'s boot validation: change `#zones == 6` to `5`, drop `Claim` from the role assert and from both message literals.
3. `ServerScriptService.Heist.Tests.WorldSpec`: update the per-location zone manifest counts. Re-run it; do not assume which assertions move.
4. Re-grep the whole game for `Claim` afterwards. `BankInstance:Claim`, `CashClaimVFX` and `RobberySuccess` all legitimately keep the name — the point of the grep is to catch any *zone-role* reference this document did not enumerate.

## Part 5 — Figma: design the getaway widget

Do this before touching `UITheme`, per the project's established design-first flow.

1. Run `whoami` first and confirm the account is `muhammadluqmanhayyan@gamuda.tech`. The personal Google account has a View seat and returns a hollow file — pages present, `childCount: 0`, no error. If it is wrong, re-authenticate before concluding anything about the file's contents.
2. Work in the Figma file `Roblox`, page `02 · Redesign`, alongside the existing 23 exported slices. Reuse the library's tokens rather than new values: accent `#CBF23C`, accentDim `#9FC024`, panel `#171A22`, raised `#1E222C`, inset `#12141A`, line `#2A2F3C`, muted `#8A92A6`, danger `#FF4B4B`. Fonts are Archivo Black (display) and Barlow Semi Condensed (UI/body).
3. Design a **240×76** frame matching the existing `TimerNormal` slice's construction, so the two stack as a visual pair:
   - A baked `GET AWAY` caption in the same position and weight the timer's baked `TIME REMAINING` caption uses.
   - A baked accent edge matching the timer's.
   - A baked `STUDS` unit label. It is static text, so it belongs in the bake — only the number itself is live.
   - Clear space for the live number on the timer's `Time` label baseline (the timer's label is at offset 34,12, size 190×32), sitting immediately left of the baked `STUDS`. The number will **right-align** against that fixed unit label, since it shrinks from three digits to one over the run.
   - A thin progress track in the band below the number — the 76px height leaves roughly 32px under the 32px number row, which is ample for a slim strip and keeps the widget the same height as the timer. Design the **empty track only**; the fill is a live `Frame`, not pixels.
4. Produce a second **near-complete** bake for the last stretch of the run, following the mechanics of the timer's `TimerUrgent` swap but **not its colour language**. Being close to N is a good thing for the player, not a warning — so this bake reads affirmative, in the same `gold` the duffel widget's `DuffelFull` state uses, rather than `danger` red.
5. Export at 4x through the REST `/v1/images` endpoint, serve locally over `http.server`, and upload with `upload_image`. Keep every exported slice under Roblox's 1024px texture cap — choose the scale per slice rather than letting Roblox silently downscale.
6. Pin the new asset ids and their 1x display sizes in `ReplicatedStorage.SharedSystems.UITheme`, in both the `Assets` and `Size` tables, following the existing `TimerNormal`/`TimerUrgent` entries exactly.

**Static text is baked; dynamic values stay native.** The studs number and the bar fill must be live instances — a countdown and a filling bar cannot be pixels.

## Part 6 — The getaway widget in `HeistClient`

**It needs no new remote.** The client already has everything: `zoneOccupancy[location]` (the arming condition), the per-location duffel amount, `sessionStates[location]`, the anchor Part, and `EscapeDistance` from the `ReplicatedStorage` config. It computes the distance itself every frame and renders it smoothly, while the server independently computes the same number as the authority.

This is the pattern the lockpick needle already uses, and for the reason its own comment gives: "the client rendering its own locally-smooth animation based on the same formula/start-time rather than being told the angle every frame" — zero extra network traffic per frame. Pushing studs-remaining from the server at heartbeat rate would be both jittery and needless traffic.

1. Keep the anchor Part when resolving the markers folders — the existing loop currently discards it after reaching `StatusImage`.
2. Build one widget per location in the same `for _, location in ipairs(LOCATIONS)` loop that already builds `timerWidgets` and `duffelWidgets`, via the same `imagePanel` helper. Live children: the studs `TextLabel` and the bar's fill `Frame`.
3. Insert its slot into the derived position chain rather than hardcoding: place it below the duffel and above the toast, and let `TOAST_POSITION` re-derive itself. Slide it in with `UITransitions.SlideIn`/`SlideOut` on the same edge-triggered `shown[location]` discipline the timer and duffel already use.
4. Visibility per location: session Active, duffel amount > 0, and `zoneOccupancy[location] == false`. Compute horizontal distance from the anchor with Y zeroed on both vectors — same as Part 1, for the same reason.
5. Reuse the existing `commas()` formatter for the number, right-aligned so it sits against the baked `STUDS` label as it shrinks. Drive the bar through `setFillRatio`'s edge-guarded tween rather than assigning `.Size` every frame — the three lump-sum locations grant cash in discrete jumps, which is exactly why that tween exists.
6. Swap to the near-complete bake when remaining studs fall to **25% of N or below** (50 studs at N=200), recolouring the number to `UITheme.Color.gold` to match. Guard the swap on an actual change — reassigning `.Image` every frame re-triggers a texture fetch, which is exactly why the timer and duffel both guard theirs.

### Un-gate the heist timer while escaping — carefully

Today `wantTimer` is `session.state == "Active" and session.endsAt ~= nil and zoneOccupancy[location]`, so the timer slides away the moment the player leaves the building. Under a distance gate, that hides the clock exactly when it starts mattering.

Change the condition to `zoneOccupancy[location] or <holding a bag from this location>`. **Do not simply drop the `zoneOccupancy` term** — the 2026-09-06 spec addendum removed "a heist is active somewhere" deliberately, and un-gating it unconditionally would reinstate exactly the behaviour that addendum deleted. The new term must be the escaping player specifically.

### Known latent overlap — flag it, do not widen it

Every location's HUD elements rest at the same on-screen position. That is safe for the timer because it is zone-gated and a player can only be inside one location at a time. It is **already not safe** for the duffel widget, whose own comment notes its visibility is deliberately not zone-gated — two simultaneous active sessions can already overlap two duffel widgets at one position.

The getaway widget inherits this and would make it more visible, since escaping is by definition outside all zones. Render only one getaway widget at a time — the location with the fewest studs remaining. Leave the duffel widget's pre-existing overlap alone, but report it; it is a real bug and a separate fix.

## Part 7 — Tests

1. New `ServerScriptService.Heist.Tests.GetawaySpec`: armed only when outside and holding a bag; horizontal distance ignores Y entirely (assert with an anchor 120 studs above the player); fires exactly once per bag; re-arms after a second bag; a player at the Bank's vault offset (314 studs horizontally, but inside) does **not** escape.
2. `LocationServerSpec` currently drives the claim through zone entry and asserts `NotifyRobberySuccess`/`CurrencyAdd`. Rewrite those to drive distance instead. Its fixture will need a stub `getaway` or a stub anchor position.
3. `WorldSpec` per Part 4.
4. Run the whole suite via `TestRunner`/`RunAll` and report the actual pass/fail output, not a claim that it passed.

## Part 8 — Verify in Play mode

Script-level correctness is not enough here; this changes the core payout loop.

1. At **each of the four locations**: trigger a robbery, fill a bag, walk out, and confirm the widget counts down and the cash banks at 0 with the existing toast and cash burst.
2. **At the Bank specifically**, confirm the bag does not bank while the player is down in the vault or anywhere in the underground gauntlet — this is the failure mode the 314-stud measurement predicts if the arming condition is wrong.
3. Confirm the heist timer stays on screen during the escape run and still slides away when the session ends.
4. Confirm there is genuinely 200 studs of walkable space available from every location — the map is only ~490 studs across at its widest. If any location cannot reach N in some direction, report it rather than quietly lowering N.
5. Let a session expire mid-escape and confirm the bag is lost with the existing "Run failed" messaging, and that no cash is credited.
6. Screenshot the new widget at each location.

---

## Notes

- N = 200 is a starting value chosen against measured map geometry, not a tuned one. Expect to adjust it after playtesting; that is why it lives in the configs.
- The Bank's 314-stud vault offset is the load-bearing constraint in this whole design. If a future change moves the Bank's anchor, vault, or the zone-role union, re-measure it.
- Nothing in this document relaxes `BankInstance:Claim`'s `ACTIVE`/`IsParticipant` guards. If an implementation finds itself wanting to, stop and raise it — that pair is the anti-dupe guarantee.
