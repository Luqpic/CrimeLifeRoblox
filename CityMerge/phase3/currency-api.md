# Robbery currency API (`ServerScriptService.PlayerData`), for Task 2

Read whole in this run (`Robbery System.rbxl`, 4 ModuleScripts: `CurrencyService` 79 lines, `CurrencyAdapter` 79, `DataStoreBackend` 111, `MemoryBackend` 30). Callers by `script_grep` over the whole Robbery place (`CurrencyService`, `PlayerData`, `currency`, `currency:`, `leaderstats`).

## What `require(PlayerData.CurrencyService)` returns

A single `CurrencyAdapter` instance (a singleton: the module builds it once per require tree). Every function is a method (`currency:Name(...)`); `userId` is `player.UserId`.

| Function | Parameters | Returns | Yields | Writes | Creates `leaderstats` |
|---|---|---|---|---|---|
| `Load` | `userId: number` | the loaded balance (number) | yes (`DataStoreBackend:Load`: `UpdateAsync` with up to 5 retries, 0.5 s doubling back-off; the memory backend does not yield) | `_balances[userId]`; calls `mirror` (below); the backend writes the session lock into key `player_<userId>` | yes, through `mirror` |
| `Get` | `userId` | cached balance, 0 if not loaded | no | nothing | no |
| `Add` | `userId`, `amount` | the new balance (the unchanged balance when `amount` is not a number, NaN, infinite or <= 0) | no (persists later) | `_balances[userId] = current + math.floor(amount)`; marks dirty; calls `mirror` | yes, through `mirror` |
| `PendingCount` | none | number of dirty entries | no | nothing | no |
| `Save` | `userId` | boolean (true if clean or written) | yes (backend `UpdateAsync` with retries) | backend key `player_<userId>`: `balance = math.max(old.balance, balance)`, lock fields; clears dirty on success | no |
| `FlushAll` | none | nothing | yes (one `Save` per dirty user) | as `Save` | no |
| `Release` | `userId` | nothing | yes (`Save`, then `ReleaseLock`) | backend lock cleared; drops `_balances` and `_dirty` for the user | no |

Gameplay code uses `Add` only. `Load`, `Release`, `FlushAll` are driven by `CurrencyService` itself; `Get` and `PendingCount` have no caller outside `CurrencySpec`.

## What `CurrencyService` does at require time (the bridge must replace all of it)

- Picks a backend: `DataStoreBackend.new()` (store name `HeistShared.Config.DataStoreName` = `HeistCurrency_v1`) inside `pcall`; on failure warns and uses `MemoryBackend` (no persistence).
- `mirror(userId, balance)`: finds the player; **creates** `Player.leaderstats` (Folder) if missing and `leaderstats.<Config.CurrencyName>` (IntValue, name `Cash`) if missing; **sets** `value.Value = balance` (absolute assignment, not an increment).
- `Players.PlayerAdded` -> `currency:Load(player.UserId)` (loads the Robbery DataStore balance and writes it over `leaderstats.Cash`); `Players.PlayerRemoving` -> `Release`; `game:BindToClose` -> `FlushAll`; a loop `task.wait(Config.AutosaveInterval)` (120 s) -> `FlushAll`. It does not iterate players already in the game at require time.
- Config values read from `HeistShared.Config`: `DataStoreName` "HeistCurrency_v1", `CurrencyName` "Cash", `AutosaveInterval` 120, `SessionLockStaleAfter` 90.

## Other things `PlayerData` does

Its own DataStore (`HeistCurrency_v1`, key `player_<userId>`, record `{ balance, lock, lockedAt }`, session lock stale after 90 s, `UpdateAsync` with retry). It writes only `leaderstats.Cash`; it creates no other value, GUI or remote. Nothing else in the Robbery place creates `leaderstats` (`CashClaimVFX` and `Net` only read it).

## Callers across the Robbery place

| Caller | Line | Use |
|---|---|---|
| `ServerScriptService.Heist.Services.LocationServer` | 87 | `realCurrency()` returns `require(ServerScriptService.PlayerData.CurrencyService)`; line 121 `currency = cfg.currency or realCurrency()` (injectable) |
| same | 272 | `self.currency:Add(player.UserId, banked)` in `_bankBag` (SlowFoods, Gas2Go, NewsStation), then toast `Banked %d Cash.`, then `NotifyRobberySuccess` (comment: "fired after `currency:Add` so `leaderstats.Cash.Value` has already replicated") |
| `ServerScriptService.HeistServer` | 45 | `local currency = require(PlayerData.CurrencyService)` |
| same | 836 | `currency:Add(player.UserId, banked)` (Bank claim); line 839 comment repeats the ordering |
| `ServerScriptService.SuppliesServer` | 22 | `local currency = require(PlayerData.CurrencyService)` |
| same | 91 | `currency:Add(player.UserId, supplyObject.cashOutAmount)` |
| `Heist.Tests.CurrencySpec` | 4, 5, 11, 79 | requires `PlayerData.CurrencyAdapter` and `PlayerData.MemoryBackend` directly (11 cases) |
| `Heist.Tests.LocationServerSpec` | 110-112, 243, 303-310 | injects a fake `currency` with `Add` only |
| `ReplicatedStorage.SharedSystems.CashClaimVFX` | 79, 165 | read `leaderstats.Cash.Value` on the client (not `PlayerData`) |

The only functions the heist code depends on: `require(...CurrencyService)` and `:Add(userId: number, amount: number)`. Behaviour to keep: `amount` floored; non-positive, NaN and infinite amounts ignored; the balance is already updated when `Add` returns.

## City side (for the bridge; read live in this run)

`ServerScriptService.Weapons.Scripts.CashService` owns `Player.leaderstats.Cash` (IntValue; created by `onPlayerAdded` or by the profile hydrator, whichever runs first; starting value `Schema.template.cash` 500). Every writer simply does `cash.Value += n` (drop pickup, level-up, shop, quests, monetisation); one `GetPropertyChangedSignal("Value")` listener per player mirrors the value into the profile (`ProfileGateway.mirror`, `profile.Data.cash`). `CashService` exports no module API. A bridge `Add` that does `leaderstats.Cash.Value += math.floor(amount)` for a sane amount is therefore persisted by the existing listener; the Robbery `Load`/`mirror` absolute assignment must not run (it would overwrite the city balance with the Robbery DataStore value).
