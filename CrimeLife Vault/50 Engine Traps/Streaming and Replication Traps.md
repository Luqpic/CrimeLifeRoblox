---
type: trap
tags: [trap, streaming, replication, network]
updated: 2026-11-15
sources: ["CLAUDE.md (Known traps)", "70 Batches/FPS System/FPS-Monetization-Cosmetics-Spec.md", "70 Batches/FPS System/Notification-Blank-Card-ZIndexBehavior.md", "70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "70 Batches/FPS System/FPS-Persistence-Phase-3.md", "OBT Vault/50 Engine Traps/Streaming and Replication Traps.md (generic traps)"]
---

# Streaming and Replication Traps

What replicates, who owns what, and instance streaming. Whether FPS System has `StreamingEnabled` on is **not recorded**: read `workspace.StreamingEnabled` before relying on the streaming traps below.

## Replication

### Client scripts that index a separately-arriving instance at start race under a heavier place
- **Symptom:** in a heavy place (the city, 30,541 client instances against 8,261 in the FPS place) a client script errors at its first lines with `X is not a valid member of ...` or never builds its UI, in some Plays and not others. Seen 2026-11-15: `Lean` errored at line 25 (`HumanoidRootPart is not a valid member of Model`) in every city Play; `WeaponaryShopController` line 20 failed in 2 of 3 Plays, so the weapon shop and skins card were never built (PlayerGui 19 children instead of 21). The same scripts ran clean in the FPS place.
- **Cause:** a LocalScript indexes with `.` an instance that reaches the client separately from the script: a sibling in `PlayerScripts`, a `PlayerGui` child, a character part. Replication order is not guaranteed and a heavier place stretches it. Measured: `Lean` starts about 39 ms before its `HumanoidRootPart` exists (from `CharacterAdded`: `Lean` 0.032 s, `LowerTorso` 0.064 s, `HumanoidRootPart` 0.071 s; the model had 0 children at `CharacterAdded`); in one Play `StarterGui`'s copy into `PlayerGui` arrived more than 5 s late (7 scripts logged `Infinite yield possible` on `PlayerGui:WaitForChild("Custom Inventory")`).
- **Fix:** `WaitForChild` (with a timeout and a quiet return where a missing part is acceptable) on every such lookup: `WaitForChild(name, 10)` in `Lean`, `require(script.Parent:WaitForChild("SkinsCardController"))` in `WeaponaryShopController`. Fix the class, not the instance.
- **The list:** `CrimeLifeRoblox/CityMerge/client-load-order-audit.md` has every client script row (138 rows: 4 FIX, 134 SAFE). The 85 `ReplicatedStorage` rows are SAFE by observation only (0 errors in 10 Plays); if one ever misses, the same change applies. Open: `Lean` line 41 `lowerTorso.Root` is still a direct index ([[Open Items]]).
- **Bit us:** [[2026-11-15 FPS Systems Into City]].

### ServerStorage does not replicate (Known trap)
- **Symptom:** a client cannot find a template.
- **Cause:** `ServerStorage` is server-only. Per-weapon models live in `ServerStorage.Weapons`, so a client needing a weapon model for a viewmodel or a shop preview cannot read it there.
- **Fix:** put client-needed templates in `ReplicatedStorage` (or send what the client needs). [[FPS-Monetization-Cosmetics-Spec]].

### A server-set attribute can land before a client HUD compares it
- Setting `Spraypaint` on the server produced no notification card: `SpraypaintHud` compares against a cached `previous`, and the replicated value had already landed before the comparison. Driving the attribute from the client fires the same handler and reproduces faithfully. Use the real trigger for attribute-driven HUD tests. [[Notification-Blank-Card-ZIndexBehavior]].

### The client owns its character
- A server push or `PivotTo` on a player can be overwritten by their client. RPG knockback on another player is unverified for this reason ([[FPS-RPG-Gamepass-Launcher]]).

### Network ownership goes back to automatic (OBT)
- `SetNetworkOwner(nil)` holds only for that assembly; a ragdoll's rebuilt joints make a new assembly owned by the nearest client. Re-claim after such moments. Ragdoll and stagger code restores ownership to a player for their own character ([[FPS-Baton-Stun-Becomes-A-Stagger]]).

### Ping is about 0 in Studio (OBT)
- `GetNetworkPing` reads about 0 even with `IncomingReplicationLag` set; lag-aware code needs a Studio-only override.

### A busy server reads a burst of remotes in one frame (OBT)
- After a server hitch, everything a client sent arrives together; rate checks timed by the server's clock refuse honest input. Stamp client actions with `workspace:GetServerTimeNow()` and clamp on the server.

## Persistence across servers

### Session locking and restart durability cannot be tested unpublished
- `StartSessionAsync` returns nil when another server holds the key (the policy is to kick). Cross-server locking, durability across a real restart, and the 30 s load deadline were all DEFERRED: "unmeasurable on an unpublished place". [[FPS-Persistence-Phase-3]], [[Persistence and Saves]].

## Streaming (OBT, if enabled)

- A streamed model can arrive empty: parts replicate after the model; wait for them.
- A `CollectionService` tag can arrive before its model's children; wait in a spawned thread.
- A RemoteEvent naming a just-spawned model can reach the client before its parts.
- Taking a part out inside its own stream-in is refused: `task.defer` the re-parent.
- A model moved every frame on the client must be Atomic, or late parts stay behind.
- Teleporting onto an unstreamed spot falls through: `RequestStreamAroundAsync` first, and hold the body until ground is near.
- Streaming properties cannot be read by script ("lacking capability"); read them in Properties.

Related: [[Engine Traps MOC]] · [[Two-Player Test]] · [[Physics and Character Traps]]
