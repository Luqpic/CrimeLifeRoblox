# Heist signature layers: design

Date 2026-11-17. Place: `Crimelife city.rbxl`. Code survey: `.superpowers/sdd/2026-11-17-heist-layers/survey.md` (paths and line numbers there).

## Intent
The developer: robberies "feel samey". Add layers inside each robbery so each of the four plays differently. Casino and Warehouse wait.

## What the developer decided
- Approach A: one signature layer per location, built mostly from existing pieces (chosen over a shared toolkit and over random run twists).
- The four layers as proposed (SlowFoods manager chase, Gas2Go ATM rip-out, NewsStation broadcast takeover, Bank deposit boxes).
- SlowFoods uses its existing storage room; the Bank layer goes in open space already in the Bank.
- "Proceed until you finish": every open question below is the controller's call, marked **(ruling)**.

## Goals, non-goals, anti-goals
- Goals: each layer optional, worth more than the base robbery, costing time, heat or exposure. Playable solo; a crew helps.
- Non-goals: Casino, Warehouse, random run twists, new gamepasses, new uploads (meshes, images, sounds, animations), tuning the existing heists.
- Anti-goals: a layer that breaks the existing robbery (base flow must play exactly as today when the layer is ignored); payouts that skip the getaway (no new way to bank cash without the run); any client-trusted payout.

## Shared pieces (ruling: built once, used by several layers)
1. **Bonus loot rides in the bag over the cap.** `BankInstance:AddBonus(player, amount) -> (ok, reason?)`: like `TryAddDuffel` (Active + participant + amount > 0) but with no cap check, fires `DuffelChanged(..., "add")`. Banked, voided and forfeited exactly like the bag. Used by the SlowFoods safe, the broadcast payout and Bank box cash. Reason: the base caps (4000 SlowFoods) would refuse any meaningful lump, and the bag already carries all the risk rules.
2. **Heavy loot** (Gas2Go ATM, Bank gold bar) is a `CarryState` carry, so: shooting is already blocked by the Tool swap, death/removal already drops it (`SuppliesServer`), robbing is already refused while carrying, the client Drop button works through `IsSupplyCarryTool = true`.
   - **Slow carry:** `CarryState:PickUp` sets the character attribute `CarrySpeedCap` when the carry object has a `speedCap`; `Drop`/`Consume`/`Forget` clear it. `Animate2`, `SprintAuthority` and `Crouching` cap WalkSpeed at it and grant no sprint while it is set. The name and the number (12; walk baseline is 20) live in `ReplicatedStorage.Movement.Constants`.
   - **Banking:** a second `Getaway` per location (`Heist.Services.CarryGetaway` wraps it): when a heavy-loot carrier is outside the building and 200 studs (the location's `EscapeDistance`) from the anchor, `carryState:Consume` and `currency:Add(value)` with a toast. It does not need an active session (ruling: heavy loot follows the supply rules, so it outlives the timer and drops on death).
   - **Supplier refuses heavy loot** (`bankOnly = true` on the carry object; `SupplierSale` refuses with a toast). Otherwise the supplier would be a getaway-free cash-out.
   - Heavy loot uses `SupplyObject` for its world model (steal prompt, hide on pickup, `DropAt` with re-pickup prompt and despawn timer). It gains `bankOnly`, `speedCap` and, for the gold bar, a start-hidden mode with a `GiveTo(player)` method.
   - No client getaway widget for heavy loot (the widget is keyed off the duffel); the pickup toast says where to take it. Left as an Open Item.
3. **Server-side truth:** every new prompt is re-measured on the server (distance) and every timed hold is timed on the server, as `Safe` does. Per-player state is keyed by the player value (fake players in specs) and cleared on `Seal`, `Rearm`, death and leave.
4. **Base loot keeps the capped path.** Registers, ATMs and safes still use `TryAddDuffel`; only layer loot uses `AddBonus`. The bag can therefore show more than its cap: the builder checks the `HeistClient` duffel bar and text with an over-cap bag and clamps the bar fill at full if it overflows (ruling, builder check).
5. **Heavy-loot carriers count as robbing for the police.** `CarryGetaway` registers `WantedService.addActiveRobbery(carrying this location's heavy loot and near)` so a carrier is treated like a bag holder (ruling, builder check).
6. **Numbers** go in each location's Config module (frozen tables), never inline.

## The four layers

### SlowFoods: the fleeing manager (session 120 s)
- A **Manager** NPC (clone of the Cashier template, renamed, its own `NPCSpawner` with `NPCTemplate = "Manager"` behind the counter; keeps `Witness` and `Invulnerable`). An overhead name "Manager" (ruling: lets players find him).
- On the alarm (`OnSessionStart`) he unanchors and runs, by `PathfindingService` (the `GuardPost:_moveToCover` pattern), to a new marker `ManagerEscapePoint` in `SlowFoodsMarkers` at the restaurant's back exit. Measured target: about 15 s at his walk speed, so a player who reacts within about 10 s catches him.
- A participant within `ManagerKeyRange` (10 studs, server re-measured) holds **"Take Key"** (hold 1) on him: that player gets the key (attribute `SlowFoodsKey` on the player, one key per run), he stops and cowers (Scared track). If he reaches the escape point he vanishes until `Rearm`: no key this run.
- **The key opens the storage room and its safe** (ruling, builder check: the room may be reachable only through the existing lockpick door `Workspace.SlowFoods.LockedDoor`, and lockpick + chase + safe may not fit 120 s). The key holder gets a "Use Key" prompt on that door that opens it at once (`LockedDoor` gains `Open(player)`, shared with the Bank layer); the lockpick stays for everyone else. A new safe model in the storage room (clone of a Bank safe model, untagged), a `RobbableObject` with `deferUnlock`, unlocked at session start, and `isBlocked` = "no key" with its own refusal toast ("You need the manager's key."; `RobbableObject` gains a `blockedReason` dep). Pays `ManagerSafeAmount` 3000 through `AddBonus`.
- Seal/Rearm: key attribute cleared, manager respawned at his spawner.

### Gas2Go: rip out the ATM
- The ATM keeps "Rob ATM" (hold 8, 3000 into the bag). A second prompt **"Rip Out ATM"** (hold 10, server-timed) on the same model; using either closes the other for the run.
- Rip-out: the ATM model becomes a `SupplyObject`-style heavy loot (hidden on pickup); the player carries `Gas2GoShared.ModelTemplates.ATMCarryTool` (built in Studio from a copy of the ATM parts welded to a Handle; `IsSupplyCarryTool = true`). Slowed to 12, cannot shoot, dropped when downed (re-pickup prompt, despawns after the supply despawn time).
- Banked by `CarryGetaway` at 200 studs outside the Station zone for `ATMRipAmount` 9000 (3x). Supplier refuses it.

### NewsStation: broadcast takeover (session 600 s)
- `MasterComputer` gains an optional `onBreached(player)` dep fired where the hack completes. The first breach of a session arms the **broadcast desk** for every participant.
- A new **BroadcastDesk** model in the newsroom near `MasterComputer` (built in Studio from existing parts, e.g. a copy of one of the three `Computer` props plus a `Highlight` and a Studio-authored BillboardGui showing "LIVE m:ss" as a live native value). Prompt **"Go Live"** (hold 1).
- "Go Live" is pressed once by any participant; nobody has to keep holding it. Going live: the server counts `BroadcastSeconds` 45 of air time; time counts only while at least one living participant is within `BroadcastRange` 12 studs of the desk; it pauses (does not reset) when nobody is. One broadcast per session.
- At go-live: a city-wide card "**X** hijacked the News Station broadcast!" (new `Net` remote + `NotificationClient` listener on the existing template, no new art); every participant's heat raised to at least 3 stars (`WantedService.addHeat`); every NewsStation guard alerted (`GuardPost:Alert()`, new: sets the activation latch so it engages targets in sight range at once).
- When air time completes: each participant within `BroadcastRange` gets `BroadcastPayout` 6000 through `AddBonus`, and a toast.

### Bank: deposit-box room (in the vault level)
- A wall of `DepositBoxCount` 8 boxes built in Studio in open floor of the vault level (the vault room behind the Vault Door, where the placeholder part `PlaceWhatYouWawnt` sits, or the open room next to it), each a small model with a hinged door part and a part named `ProximityPart Handle`. Only reachable after the vault door opens (boxes unlock with the existing `vaultDoor.isOpen` latch).
- Each box is a `LockedDoor` (the existing lockpick screen) with three additions to `LockedDoor`: an optional `onSolved(player)` dep; an optional `objectText` ("Deposit Box"); and **one active lockpick attempt per player across all doors** (module-level guard; today one click is evaluated by every door the player has an attempt on).
- Contents rolled per session by a pure function `DepositBoxLoot.roll(rng, count) -> {"cash"|"empty"|"gold"}`: at most one gold bar per run with probability `GoldBarChance` 0.5; of the rest, two thirds cash (`DepositBoxCash` 1500 each through `AddBonus`) and one third empty. The box tells the solver by toast ("Empty.", "+1,500", "Gold bar!").
- Gold bar: a start-hidden `SupplyObject` (gold bar model built in Studio from parts) given to the solver with `GiveTo(player)`; slowed to 12; banked by `CarryGetaway` (`isInsideBank` false, 200 studs from the Bank anchor) for `GoldBarValue` 8000. **The gold bar must be able to leave the vault**: the builder walks the whole route (vault, return teleporter, lobby, street, 200 studs) with a carrying player and fixes whatever refuses a carrier on the way out (it is a must, not a nice-to-have). Hazards (lasers, death volume) keep working on carriers as on anyone.

## Approaches considered
- A (chosen): signature layer per location: most variety, four builds.
- B: shared toolkit (keycard room, camera, stay-longer push) at all four: cheaper, risks sameness again.
- C: random twist per run: varies repeats, not locations; may follow A later.

## Constraints (standing, from the project)
- Place `Crimelife city.rbxl` only, resolved by name before writes; never publish; **no save** unless the developer gives the word for the run; no uploads; no asset permission changes.
- Removed pieces go to `ServerStorage.CityQuarantine.<Reason>`; nothing visible deleted.
- Every edited script: `CityMergeDeviation` attribute (append with "; "), a row in `CityMerge/after-import.md` (Adler-32 before/after), exported to `CityScripts/` and checked by Adler-32.
- Baselines: city suites 262 / 262 / 0 plus new cases; heist suite 620 passed / 1 failed, the failure set only `Zone` "real occupancy sweep". One enabled SpawnLocation; no temporary objects left.
- New tagged instances must be reflected in boot asserts and `WorldSpec`.
- Vault updated at the end (batch note, Batch Log, systems notes, Open Items, Decisions); one git commit per task, explicit paths, never `.DS_Store`, nothing pushed.

## Left to the builder
- Exact placement of the Manager spawner and escape point, the safe, the desk and the box wall (measured, collision-checked, reachable).
- Model building from existing parts; prompt templates (clone existing ones).
- Exact pathfinding parameters; whether the manager escape point needs a door opening.

## Rulings the developer should check
1. The key opens the storage-room door at once and the safe; others can still lockpick the door.
2. Layer cash rides in the bag over the cap (`AddBonus`).
3. Heavy loot outlives the timer and the supplier refuses it.
4. Numbers: safe 3000, ATM rip 9000, broadcast 6000 each, box cash 1500, gold 8000, carry speed 12, broadcast 45 s.
5. The broadcast pays every participant at the desk, and pauses rather than resets when the desk is left.
