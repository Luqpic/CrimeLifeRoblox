---
type: tool
tags: [tools, multiplayer, testing]
updated: 2026-11-14
sources: ["70 Batches/FPS System/FPS-Player-Nameplates-And-LevelUp-Fix.md", "70 Batches/FPS System/FPS-Nameplate-Scaling-And-Death-Hud-Hide.md", "70 Batches/FPS System/FPS-Quest-Overflow-And-Dead-Code-Removal.md", "70 Batches/FPS System/FPS-RPG-Gamepass-Launcher.md", "70 Batches/FPS System/FPS-Spraypaint-Phase-2.md", "70 Batches/Robbery System/Getaway-Distance-Replaces-Claim-Zone.md", "OBT Vault/40 Tools/Two-Player Test.md (generic parts)"]
---

# Two-Player Test

How to test anything that needs two players. **No two-player test of CrimeLife is recorded**; several change logs list one as still needed.

## Still waiting on one

- Nameplates at distance and the view-card prompt round trip ([[FPS-Player-Nameplates-And-LevelUp-Fix]], [[FPS-Nameplate-Scaling-And-Death-Hud-Hide]]); prompt toggling, and whether two nameplate systems double up ([[FPS-Quest-Overflow-And-Dead-Code-Removal]]).
- RPG knockback on another **player**: a player's character is physics-owned by their own client, so a server-applied push may land softer ([[FPS-RPG-Gamepass-Launcher]]).
- Spraypaint's guard against two players trading kills ([[FPS-Spraypaint-Phase-2]]): no two-player run of it is recorded.
- Robbery getaway with more than one robber ([[Getaway-Distance-Replaces-Claim-Zone]]).

Track these in [[Open Items]].

## Only the developer can start one

The MCP's `start_stop_play` runs solo Play only. A real test (Test > Clients and Servers > Start, 2 players) starts only when **the developer clicks Start**; ask for it in the picker round ([[Ask First Then Build]]).

**Never close the developer's test windows.** On OBT, closing them to reload pushed code left no way to start a new test. Do every multiplayer step in the test they left, put fixes into Edit, and leave the retest for their next Start.

## Finding the windows (OBT, same MCP)

- The server and each client register with the MCP as their own Studio id. `list_roblox_studios` lists them; `get_studio_state` says Server or Client; `LocalPlayer.Name` says which player.
- Players are `Player1` (UserId -1) and `Player2` (UserId -2). A solo check that fakes a player with UserId -1 collides with a real test player.
- Stop your own solo Play first: four Studio processes swapped the Mac.

## Gotchas (OBT)

- Move a character from its own Client; a server `PivotTo` of a client-owned character is overwritten.
- A check right after a teleport can run before the other player streams in: wait for their parts.
- Simulated ping: `settings().Network.IncomingReplicationLag = 0.25` from Edit applies to the next Play; reset it to 0 after. `GetNetworkPing` still reads about 0 in Studio.
- Solo Play runs client and server in one process: a slow server behind a normal client needs a Start test.

Related: [[Tools MOC]] · [[Streaming and Replication Traps]]
