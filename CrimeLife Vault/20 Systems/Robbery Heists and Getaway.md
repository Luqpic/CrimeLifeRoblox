---
type: system
tags: [system, robbery, heist, economy, hud]
updated: 2026-11-14
sources: ["CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Getaway-Distance-Replaces-Claim-Zone.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Performance-Optimization-And-Unification.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Post-Move-Fixes-And-GUI-Polish.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Timer-Hourglass-And-Duffel-Upgrade-GUI.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Global-Notifications-And-Location-Status-Billboards.md", "CrimeLifeRoblox/CrimeLife Vault/70 Batches/Robbery System/Supplier-Dialogue-On-Shared-Billboard-Engine.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/RobberySystem/Getaway-Distance-Claim-And-GUI.md", "CrimeLifeRoblox/CrimeLife Vault/90 Reference/Original Prompts/RobberySystem/Performance-Optimization-And-Unification.md"]
---

# Robbery Heists and Getaway

**Skills:** `roblox-game-systems`, `roblox-networking`, `roblox-testing` (load these for work here)

**Robbery System place** (separate from the FPS place; never edit it unless it is named).

## What it does
Four robbery locations, Bank, SlowFoods, Gas2Go and NewsStation. A player triggers a robbery, works the location's puzzles ([[Robbery Puzzles]]), fills a duffel bag against a session timer, and banks the cash by getting 200 studs clear of the location from outside the building. Death or the timer running out voids the bag. Every player sees a notification when a location is robbed or reopens, and a status badge over each location. An Illegal Supplier NPC buys carried supplies.

## Where it lives
- Engine: `ServerScriptService.Heist` with `BankInstance` (session state machine), `ComponentRegistry`, `Components/` (~15), `Services/` (incl. `LocationServer`, `Getaway`), `Tests/` (spec suite, `TestRunner`/`RunAll` in `ReplicatedStorage.HeistShared`).
- Location scripts: `ServerScriptService.HeistServer` (Bank, deliberately **not** on `LocationServer`), `SlowFoodsServer`, `Gas2GoServer`, `NewsStationServer` (on `Heist.Services.LocationServer`). `SuppliesServer` for supplies.
- Per-location `Config` modules (`SessionDuration`, `CooldownDuration`, `EscapeDistance`, ...); marker folders `HeistMarkers` (Bank), `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`, each with a `StatusBillboardAnchor`.
- `ReplicatedStorage.SharedSystems`: `GamepassManager`, `RobbableObject`, `SupplyObject`, `LockedDoor`, `CarryState`, `NPCSpawnManager`, `NPCReactionAnimator`, `CashClaimVFX`, `UITheme`; `ReplicatedStorage.HeistShared` (`Net`, `Remotes`, `DuffelBag` model).
- Client: `StarterPlayer.StarterPlayerScripts.HeistClient` (timer, duffel, toast, getaway widget, safe keypad, billboard colours), `NotificationClient` + `StarterGui.NotificationGui`, `StarterGui.DuffelUpgradeGui`, `SupplierDialogueController`.

## How it works
- **Session.** `BankInstance` runs Idle -> Active -> Cooldown. `Claim` pays only while Active and only to a participant (the "dupe fix"; do not relax). Session lengths read live before 2026-09-20: Bank 600 s, SlowFoods 120 s, Gas2Go 300 s, NewsStation 600 s.
- **Getaway (since 2026-09-20).** `Heist.Services.Getaway` owns the payout: horizontal distance from the location's `StatusBillboardAnchor` must reach `EscapeDistance` = 200 studs **and** the player must be outside the building (Bank: `Lobby OR Vault OR BankVaultZone`, one `isInsideBank` helper). Callbacks are injected so it is unit-testable (`GetawaySpec`, 14 tests). No new remote: `HeistClient` recomputes the same distance from replicated zone occupancy, like the lockpick needle.
- The old `*ClaimZone` parts were **untagged, not deleted** (tag and `ZoneRole` removed): re-adding one tag reverts.
- **HUD** (`HeistClient`, Figma slices pinned in `UITheme`): timer (hourglass, urgency slice under 60 s), duffel bar with `+` upgrade button, toast (`TOAST_SECONDS` 2.5), and the 240x76 getaway widget (`GetawayNormal`, gold `GetawayNear` at 50 studs left). Only one timer and one getaway widget are ever shown. Slots derive from the element above.
- **Duffel upgrades** x2 / x4 are Roblox gamepasses resolved in `GamepassManager`; `DuffelUpgradeGui` calls `MarketplaceService:PromptGamePassPurchase` ([[Gamepasses]]).
- **Notifications and status.** `Net` remotes `NotifyLocationOpened` / `NotifyRobberyTriggered` fire to all; `NotificationClient` stacks cards ([[Notifications]]). Each anchor's badge stroke is green / yellow / red for Idle / Active / Cooldown, driven from `HeistClient`'s per-frame loop off the existing `HeistState` broadcast.
- **Cash.** Banking credits `PlayerData.CurrencyService`; `CashClaimVFX` flies coins to the cash card; robbed objects burst the coin icon from a pre-placed `CashBurstEmitter` each ([[Economy and Cash]]).
- **Illegal Supplier** runs on the FPS place's `DialogModule` billboard engine ([[Quests and Dialogue]]): offer, explainer (names the diner, gas station and the news station camera that pays double), decline. The sale is server-decided via `SubmitSupplierChoice` / `SupplierResult`, re-checking `CarryState:Consume` at the click.

## Extend it
- New location: consume `LocationServer` with a `markerFolder`, a Config with `EscapeDistance`, a `StatusBillboardAnchor`; add boot asserts and `WorldSpec` entries.
- Tune the getaway per location in its Config (one line each).
- Pay down the debt below before touching the distance maths.

## Watch out
- **The getaway distance formula exists twice** (`Getaway` and inline in `HeistClient`). They agreed to zero difference across 104 samples per location, but nothing guards it. If you edit one, edit both, or hoist it into a shared `HeistShared.GetawayMath` (deferred deliberately on 2026-09-20).
- The Bank vault is 314 studs from its anchor: a distance check without the inside-building gate would pay instantly.
- Anchors float 40-120 studs up; distance must stay horizontal.
- 200 studs is a starting value, not tuned: SlowFoods to Gas2Go clears it by 5 studs; a Gas2Go job cannot bank at NewsStation.
- The place has **no version control**; `LocationServer` and its spec once vanished mid-session (2026-09-20) and were reconstructed. Save often.
- `GamepassManager.GamepassConfig` duffel `Id`s are placeholder `0`s until the developer creates the passes.
- `Workspace.BankVault.AlarmSpeaker.AlarmSound` is reused by literal path from three other locations.
- Spec gate: compare the failure **set**, not the count; a minimised Studio stops `RenderStepped` and fails tween specs (594/14 swung to 581/28 with no code change).
- `multi_edit` with `replace_all` can report success while missing call sites.

## History
- 2026-09-20: getaway distance replaces the claim zones; getaway widget; timer stays up during the escape; "get clear of the building to bank it" wording. [[Getaway-Distance-Replaces-Claim-Zone]]
- 2026-09-19: supplier on the shared dialogue engine; supplier billboard clickable, toast 5 -> 2.5 s; robbed objects burst the real coin icon. [[Supplier-Dialogue-On-Shared-Billboard-Engine]] [[Supplier-Billboard-Input-And-Toast-Duration]] [[Cash-Burst-Emitter-Icon]]
- 2026-09-18: HUD on Figma slices via `UITheme`; HUD slots derived, notification text measured. [[Figma-Slices-Imported-To-Studio]] [[UI-Bug-Fixes-Notification-HUD-Lockpick-Titles]] [[GUI-Audit-And-Figma-Redesign]] [[Slice-Transparency-And-Anchor-Fixes]]
- 2026-09-13: stale `workspace.DuffelBag` references after the developer moved it to `HeistShared`; duffel/cash/notification polish (drafted, execution not confirmed). [[Post-Move-Fixes-And-GUI-Polish]]
- 2026-09-12: `LocationServer` unification (Part 1 confirmed; Parts 0, 2-4 unverified); global notifications and status billboards; hourglass timer, duffel widget and upgrade dialog. [[Performance-Optimization-And-Unification]] [[Global-Notifications-And-Location-Status-Billboards]] [[Timer-Hourglass-And-Duffel-Upgrade-GUI]]

See [[Batch Log]].
