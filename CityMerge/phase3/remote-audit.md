# Remote audit: the imported Robbery code in Crimelife city.rbxl (phase 3, Task 5)

Leg 1 (audit only, no edit to the place, no Play). Read 2026-11-16 from the Studio instance `Crimelife city.rbxl`
(Edit DataModel). Line numbers are the ones read in this run. `Robbery System.rbxl` was not touched.

Verdict rule (brief, binding): FIX only when a client can (a) act on something it does not own, (b) get an
untyped, NaN or out-of-range value written into state or a save, or (c) gain cash, an item or progress without
doing the thing. A missing rate limit alone is OK plus a note, unless 100 calls a second does (c) or throws.

## Inventory (measured)

Scope: every LuaSourceContainer under a root with `ImportedFrom = "Robbery System"` (`ServerScriptService.Heist`,
`HeistServer`, `SlowFoodsServer`, `Gas2GoServer`, `SuppliesServer`, `NewsStationServer`, `PlayerData.CurrencyService`,
`ReplicatedStorage.HeistShared`, `SharedSystems`, `RestaurantShared`, `Gas2GoShared`, `NewsStationShared`, the
imported StarterPlayerScripts and StarterGui roots).

- No literal `OnServerEvent` / `OnServerInvoke` exists outside `Heist.Services.Net`. Net creates one RemoteEvent per
  name under `HeistShared.Remotes` (`Net.setup` 101-124) and wraps every inbound one in a `Net:On...` method. No
  RemoteFunction exists (Net 347-355 tripwire; the Edit-time folder holds 24 RemoteEvents, 0 RemoteFunctions).
- 8 client-to-server remotes, matched against every `FireServer` in the imported client code (HeistClient 707, 787,
  1040, 1051; WordScrambleClient 254, 348, 356; SupplierDialogueController 72). No client fires a remote without a
  server listener, and no server listener waits on a remote no client fires.
- 13 handler registrations: `SubmitSafeCode` x2 (HeistServer 637, NewsStationServer 329), `LockpickStopRequested`
  x3 and `LockpickExitRequested` x3 (one per `LockedDoor`: SlowFoods, Gas2Go, NewsStation; LockedDoor 219-228),
  the three Word Scramble remotes x1 (MasterComputer 162-170, NewsStation only), `DropSupplies` x1 and
  `SubmitSupplierChoice` x1 (SuppliesServer 113, 84).
- All other Net remotes are server-to-client only (`HeistState`, `DuffelState`, `Toast`, `PlayCue`, `ZoneOccupancy`,
  `RobberySuccess`, `OpenSafeGui`, `SupplierResult`, `OpenLockpickGui`, `LockpickUpdate`, `LockpickSolved`,
  `OpenWordScrambleGui`, `WordScrambleResult`, `RevealHackCode`, `LocationOpened`, `RobberyTriggered`).
- One client-reported engine signal: `MarketplaceService.PromptGamePassPurchaseFinished` (GamepassManager 112).
- Cash enters the city only through `CurrencyService:Add` (rejects non-number, NaN, inf, <= 0; floors; 42-48), called
  from three places: `LocationServer:_bankBag` 268-277, `HeistServer bankBag` 832-842, `SuppliesServer` 91.

## Client-to-server handlers

| # | Remote | Handler : line | Arguments and type check | Ownership (what the client names, and the proof) | NaN / range | 100 calls/s | Verdict |
|---|---|---|---|---|---|---|---|
| 1 | `SubmitSafeCode` (Bank) | Net 192 -> `HeistServer` 637-659 -> `Safe:TrySubmitCode` 172-209 | `safeId` number, `digits` string (638) | `safeId` is a lookup key into the server's own `safeById` (644); unknown id -> return. A guess counts only if this player opened THIS safe's GUI through the server prompt (`_pending[player]`, set in `_onTriggered` 160, consumed one-shot at 179-180). Code is server-held (`SafeCode` 35-42) and compared as a string (186). Amount is server data (`Config.SafeRobAmount` = 5000), banked into the bag via `TryAddDuffel` (Active + participant + cap, BankInstance 297-309); `Robbed` attribute makes it once per safe per session (182, 198) | NaN / inf safeId -> `safeById[NaN]` is nil (measured: NaN read on a table returns nil) -> return. Non-numeric digits never equal the code | 0.5 s per-player debounce (635-642), set before the lookup; one guess per prompt trigger anyway | OK. Note: the Bank code is shown on the vault's `Code Combination` display by design, so brute force buys nothing |
| 2 | `SubmitSafeCode` (NewsStation) | Net 192 -> `NewsStationServer` 329-348 -> `Safe:TrySubmitCode` | same (330) | same, keyed into `newsStationSafeById` (ids 1001-1003, 331); code is the server-held `MasterComputer._code` (297), revealed only after the Word Scramble chain (row 7). Amount 5000 (312) into the bag | as row 1 | 0.5 s debounce (333-336); one guess per prompt trigger (`RobSafePrompt` HoldDuration 8) | OK. Note: brute force is at most 2 guesses a second against 10,000 codes in a 600 s session (about 12 % per session at best, and only if the server skips the 8 s hold), and the Word Scramble is cheaper to automate than that |
| 3 | `DropSupplies` | Net 202 -> `SuppliesServer` 113-119 | none | Drops only the caller's own carry (`CarryState:IsCarrying` 114), at the caller's own root `CFrame * (0,0,-2)` (66-70); no position from the client | no numbers | after the first call the player is not carrying -> return | OK |
| 4 | `SubmitSupplierChoice` | Net 215 -> `SuppliesServer` 84-109 | none | `CarryState:Consume` (86-93) re-checks the carry at the click and clears it before paying, so one carry pays once; amount is the server-held `supplyObject.cashOutAmount` (10000 SlowFoods / Gas2Go, 20000 NewsStation camera, NewsStationServer 240). **No check that the player is at the Illegal Supplier.** The conversation is opened client-side (SupplierDialogueController 75-81); the server never measures the distance | no numbers | after a sale `Consume` returns false -> `SupplierResult "no_supplies"` FireClient only | **FIX** (c): cash for a delivery that never happened. Measured: Gas2Go barrels are 1044 / 1054 studs from the supplier, the NewsStation cameras 926 / 929, the SlowFoods boxes 31 / 33. A client fires the remote the moment it picks up and is paid 10,000 or 20,000 without the carry |
| 5 | `LockpickStopRequested` | Net 240 -> `LockedDoor:_onStopRequested` 289-372 (x3) | `clientClickTime` optional; used only if `type == "number"` (302) | acts only on the caller's own server-held attempt at that door (`_attempts[player]`, 290-291); the needle angle is the server's formula on its own `startTime` (305); progress is server state | NaN -> `math.clamp` returns NaN -> `withinZone` false -> a miss (measured). inf -> serverNow, -inf -> serverNow - 1 (measured). The client can choose any instant in the last 1 s (`MAX_LATENCY_COMPENSATION` 110) | each call is a hit or a miss; a miss resets `startTime` and lowers progress; 4 hits open the door | OK. Note: the client already gets zoneAngle, zoneWidth, angularSpeed and startTime to render the needle (273-280), so a script can time a perfect click with or without the 1 s window; the window does not widen what an auto-clicker can do. The three doors share the remote, so one Stop is evaluated at every door where the player has an open attempt (each needs its own prompt trigger) |
| 6 | `LockpickExitRequested` | Net 263 -> `LockedDoor:_onExitRequested` 233-235 (x3) | none | clears only the caller's own attempt | no numbers | idempotent | OK |
| 7 | `SubmitWordScrambleGuess` | Net 283 -> `MasterComputer:_onSubmitGuess` 248-281 | `guess` any; `tostring`, whitespace stripped, upper-cased (252) | acts only on the caller's own attempt (249-250), which exists only after the server prompt (`_onTriggered` 196-210, Active only 176); the word is server-held and never sent (only `scramble(word)`); 3 rounds, then `_hackedBy` + `RevealHackCode` (258-263). The reward is the safe code, not cash | a table or number guess becomes `"TABLE:0X..."` / digits, never equal to a word (measured) | no rate limit; wrong guesses only FireClient "incorrect". The word list is 24 entries (23-28), so a client can try every word in under a second | OK. Note: brute force is equivalent to anagram-solving the scrambled letters the client already has; skipping the puzzle yields only the code row 2 still has to spend in person. A very long string costs one `gsub` per call |
| 8 | `WordScrambleExitRequested` | Net 307 -> `MasterComputer:_onExitRequested` 283-285 | none | clears only the caller's own attempt | no numbers | idempotent | OK |
| 9 | `RandomizeWordRequested` | Net 317 -> `MasterComputer:_onRandomizeRequested` 220-241 | none | caller's own attempt; budget 3 per attempt, server-held (226-229) | no numbers | ignored once the budget is 0 | OK |

Engine signal (client-reported):

| # | Signal | Handler : line | What it trusts | Verdict |
|---|---|---|---|---|
| 10 | `MarketplaceService.PromptGamePassPurchaseFinished` | `GamepassManager:Init` 112-115 | Caches ownership `true` for `(player, gamepassId)` on `wasPurchased`, with no `UserOwnsGamePassAsync` re-check. All three pass Ids are the placeholder `0` (18-22), so one cached `(player, 0) = true` would turn on DuffelCapacityX4 (cap 15000 -> 60000) and DuffelSpeedBoost (x1.5 accrual) at once | OK, **unsure**: (c) only if the server-side event can be raised without a real purchase, which I could not verify in Edit. Phase 2b rated the city's own use of the same signal (MonetizationService 146-156) OK. Cheapest hardening if ruled FIX: re-check `UserOwnsGamePassAsync` before caching true, and ignore Id 0 |

## ProximityPrompt `Triggered` handlers that pay or advance a heist (server side)

Template reach read this run: `RobATMPrompt`, `RobRegisterPrompt` (both folders), `RobSafePrompt`,
`StealSuppliesPrompt`: Max 10, LOS false, Hold 8. `RepickupSuppliesPrompt` Max 10, Hold 0. `AttachC4Prompt` Max 12,
Hold 5. `GoToVaultPrompt` Max 12, Hold 2. Illegal Supplier prompt Max 10, Hold 0 (client-only handler).
The engine checks `MaxActivationDistance` on the server for `Triggered`; `RequiresLineOfSight` and `HoldDuration`
are client-side only.

| # | Prompt | Handler : line | Gate | Reach | Verdict |
|---|---|---|---|---|---|
| P1 | Register / ATM (SlowFoods, Gas2Go, NewsStation, Bank ATM, Bank register) | `RobbableObject:_tryRob` 119-151 | `Robbed` once per session (123, 141); not carrying (125); `TryAddDuffel`: Active, participant, cap (BankInstance 297-309); amount server-side (73). Synchronous, no yield, so no double-rob race. Bank copies `deferUnlock` until the vault door opens (HeistServer 1046-1051) | engine Max 10, LOS off | OK. Note: no LOS, so a participant can rob through a thin wall within 10 studs |
| P2 | Safe (Bank x2, NewsStation x3) | `Safe:_onTriggered` 150-162 | Robbed, Active, server re-measures distance against the prompt's Max (153-154, set at `Unlock` 262), not carrying; only opens the GUI | Max 10 re-measured | OK. Note: the pending GUI has no distance re-check at submit (row 1/2), so a player may walk off and submit later; the bag still needs the getaway |
| P3 | Steal / re-pick supplies | `SupplyObject:_onTriggered` 327-363 | visible (330), not carrying (331), no duffel (336); armed only between `OnSessionStart` and `Seal` (438-459). No participant check | Max 10 | OK (the cash gate is row 4) |
| P4 | Locked door (x3) | `LockedDoor:_onTriggered` 248-281 | not open, Active, one attempt per player; opens only the lockpick GUI | default Max 10 | OK |
| P5 | Master Computer | `MasterComputer:_onTriggered` 175-211 | Active; repeat reveals the code to a player who already hacked | default Max 10, Hold 1 | OK |
| P6 | Bank terminals 1, 2 | `Terminal:Press` 63-89 | 0.5 s debounce, Active, not pressed, server re-measure vs Max (72-74). No participant check | Max 12 (`maxDistance` from the prompt, 54) | OK. Note: a bystander can press a terminal for the team |
| P7 | C4 "Attach" | `C4Charge:PressAttach` 163-185 | Active, not breached, no countdown, both terminals, server re-measure vs the template's Max 12 | Max 12 | OK |
| P8 | C4 "Go to Vault" -> Teleporter A | `C4Charge:PressGoToVault` 289 -> `Teleporter:Use` 94-121 | Active, distance, vault breached (16-18); enrols the player as a participant (117-119); moves by `PivotTo` (31-36) | Max 12 re-measured | OK |
| P9 | Teleporter B "Return to Lobby" | `Teleporter:Use` | Active, distance; `PivotTo` | Max 12 | OK |
| P10 | Vault door handle / button | `VaultDoor:Toggle` 212-220 | Active, not mid-animation. No participant or distance re-check | Max 12, LOS on (client-side only), Hold 10 | OK. Note: anyone, including a non-participant, can close the vault on the team (griefing, no cash) |

`DeathVolume` is a `Touched` hazard, not a client entry point that pays; it forfeits (HeistServer 477-490).

## Extra block (controller): a character removed without dying keeps its bag (ruled FIX for Leg 2)

Where each location voids a bag today:

| Location | Voids on | Never voids on |
|---|---|---|
| SlowFoods, Gas2Go, NewsStation (`LocationServer`) | `Humanoid.Died` -> `forfeit:Die` (`_watchCharacter` 330-337, only when Active and a participant); session end `_seal` -> `onForfeit` -> `Forfeit:Eject` -> `VoidDuffel` (BankInstance 126-135, LocationServer 163-166); `PlayerRemoving` -> `ForgetPlayer` (429-431, 340-350, drops the entry) | the character being removed or replaced without a death |
| Bank (`HeistServer`, not a LocationServer user) | `Humanoid.Died` -> `forfeit:Die` (`watchCharacter` 934-944); death volume `forfeit:Die` (477-490); `_seal` -> `onForfeit` (185-188); `PlayerRemoving` (952-972) | same gap |

Why it banks: the bag is keyed by Player in `BankInstance._duffels`, not by character. The new character spawns at the
city's one enabled SpawnLocation, which is 782 (SlowFoods), 1083 (Gas2Go), 1585 (NewsStation) and 1244 (Bank) studs
horizontally from each anchor, all past `EscapeDistance = 200`. `Getaway:Step` (86-113) sees a bag, outside the
building, past 200, and calls `_bankBag` / `bankBag`; `Claim` pays because the player is still a participant and the
session is Active.

Where the hook goes: one `player.CharacterRemoving` connection beside the existing `CharacterAdded` wiring, calling
`forfeit:Die(bank, player, cause)` under the same `GetState() == "Active" and IsParticipant(player)` guard:
`LocationServer:Start` PlayerAdded block 422-427 (covers all three) and `HeistServer` PlayerAdded 947-950 (the Bank).
`Forfeit` latches per player per runId (28-33), so a normal death (Died, then CharacterRemoving at respawn) forfeits
once; after a death the player is no longer a participant, so the second signal is skipped anyway.

In-heist moves that must not void: the Bank vault teleport (`Teleporter.defaultMove` 31-36, `character:PivotTo`),
the Return-to-Lobby teleporter (same), and both forfeit ejects (HeistServer 149-152, LocationServer 138-141) all move
the existing character with `PivotTo`; none removes it, so none fires CharacterRemoving. No imported or city server
script calls `LoadCharacter` or destroys a player character (city-wide grep; the only `character:Destroy()` hits are
enemy NPCs and test specs). `Players.CharacterAutoLoads = true`, `RespawnTime = 3`.

Related, not in the ruling: `SuppliesServer` drops a carry only on `Died` (125-133); a character removed while
carrying destroys the tool with the character but leaves `CarryState` set, so the player can still sell (row 4) and
stays blocked from triggering robberies until they do. The same CharacterRemoving hook in `SuppliesServer` would close
it.

## Notes on OK rows

- **Rate limits.** Only `SubmitSafeCode` (0.5 s) and the prompt debounces (Terminal 0.5 s, Teleporter 1 s, robbery
  trigger 1 s) have one. No imported handler yields or makes a web or DataStore call per request; 100 calls a second
  costs FireClient traffic and table writes only.
- **Gamepass lookups.** With Id `0`, `UserOwnsGamePassAsync` failing is not cached (GamepassManager 54-58), so
  `GetDuffelCap` / `GetAccrualRate` may make a web call on every Bank accrual tick and every `TryAddDuffel`. Not a
  remote finding; worth a look when the real Ids are set.
- **`BankInstance` dupe fix.** `Claim` pays only while Active and only to a participant (281-289) and zeroes the bag
  before returning; nothing in this audit relaxes it.

## Leg 2: controller rulings and fixes (2026-11-16)

| Row | Ruling | Fix (see `after-import.md`, Phase 3 Task 5) | Test |
|---|---|---|---|
| 4 `SubmitSupplierChoice` | FIX | `Heist.Services.SupplierSale.try`: living character's root within 15 studs of `Illegal Supplier.Interaction`, checked before `CarryState:Consume`; a refusal keeps the carry and answers nothing | `SupplierSaleSpec` 5 / 5 (red: module missing). Play: a fired sale from 786 studs left Cash 500 and the carry; at 6 studs Cash 500 -> 10,500 |
| Extra block (character removed) | FIX | `player.CharacterRemoving` -> `forfeit:Die` under Active + participant: `LocationServer:_onCharacterRemoving` (wired in `Start`) and `HeistServer` PlayerAdded | `LocationServerSpec` +2 (red: missing method). Play, Bank: full duffel 15,000, `LoadCharacter` (Died not fired) -> Toast "Bag lost", duffel 0, Cash and profile 10,500 unchanged at 1,245 studs; then a normal re-entry banked 2,033 (Cash and profile 12,533) |
| Carry on removal (controller item 3) | FIX | `SuppliesServer`: `CharacterRemoving` drops a carry where the character stood | Play: carrying -> `LoadCharacter` -> not carrying, the supply's `DropAt` ran once |
| 10 `PromptGamePassPurchaseFinished` | FIX | `GamepassManager:_onPurchaseFinished` confirms with `pcall(UserOwnsGamePassAsync)` and caches only a confirmed true | `GamepassManagerSpec` +4 through the `_ownershipCheck` seam (red: missing method) |
| 2 NewsStation `SubmitSafeCode` | FIX | `Safe` opt-in `enforceHold`: attempts per player at least the prompt's own `HoldDuration` apart (read at `Unlock`), shared across opted-in safes; `too_soon` keeps the try. NewsStation opts in; the Bank does not (its code is on display) | `NewsStationSafeSpec` +2 (red: accepted inside the floor) |
| 5 `LockpickStopRequested` | OK plus the note in row 5 | none | none |

Not changed: the `died` cause is reused for a removal, so the toast reads "You died before banking. Bag lost." after a `LoadCharacter`.
