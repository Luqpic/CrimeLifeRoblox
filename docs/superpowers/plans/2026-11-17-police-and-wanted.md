# Police and Wanted Level Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A server-owned wanted level (0 to 5 stars) raised by heist alarms, shooting police and witnessed crimes; police who arrive at a robbed building and hunt wanted players (armed police from 3 stars); guards in the Bank and NewsStation; a way out by breaking sight; a star meter; quest givers recast as crooked cops.

**Architecture:** A pure `HeatModel` (numbers in, numbers out) under a server `WantedService` that owns per-player heat, listens to alarms, hits and kills, evaluates "seen" twice a second and drains heat. A `PoliceDispatcher` spawns the existing `Police` and `Armed Police` templates onto the existing `EnemyAI`, which gains a target filter, a `canSee` check and a live-instance registry. The client only draws the meter from replicated attributes.

**Tech Stack:** Luau, Roblox Studio via the `Roblox_Studio` MCP; `ServerStorage.UnitTest.RunUnitTest` (city suites) and `ServerScriptService.Heist.Tests.RunAll` (heist suite).

**Spec:** `docs/superpowers/specs/2026-11-17-police-and-wanted-design.md` (sections 5 and 8 are binding: the numbers, the hooks, the answers to the builder check).

**Models:** Opus builds Tasks 1 to 5; Sonnet builds Task 6 and reviews; Fable or Opus runs the final review.

## Global Constraints

- Target place `Crimelife city.rbxl`, resolved by name before every write. Other places read only. **Never publish. Do not save the place in this run** (the developer gave no word to save; every source is exported to `CityScripts/` and committed so nothing is lost).
- Server authority: heat, stars, seen, dispatch and despawn on the server; the client only reads `WantedHeat` / `WantedStars` attributes.
- New code lives under `ServerScriptService.Wanted` (server) and `ReplicatedStorage.Wanted` (shared constants and the pure `HeatModel`). Every number in the spec's section 5 lives in `ReplicatedStorage.Wanted.Constants`, nowhere else.
- Edits to existing scripts (`EnemyAI`, `ShotResolver`, `LocationServer`, `HeistServer`, `QuestConfig`, heist guard wiring) carry `CityMergeDeviation` (append with "; ") and a row in `CityMerge/after-import.md` (new section "Police and wanted 2026-11-17", Adler-32 before and after). Every created or edited source is exported to `CityScripts/` and checked by Adler-32 (`CityMerge/transfer/export-source.luau`; start `python3 CityMerge/transfer/server.py <scratch dir>` when needed, stop it at the end).
- Gangs behave exactly as before: their spawner, caps, targets and rewards are unchanged.
- Baselines hold after every task: city 18 suites **193 / 193 / 0** plus new cases; heist suite failure set = the timing-sensitive `Zone` sweep only; exactly one enabled `SpawnLocation` in Workspace; no temporary object left.
- At most 24 police alive in the server, ever.
- Numbers measured or "not recorded". Git: one commit per task named `Batch: <topic>`, by explicit path, `.DS_Store` never, nothing pushed. No key, token, UserId or account name in any file.

## Review Focus

1. **A player who is not wanted is never targeted by police**, including the moment heat reaches 0 mid-fight, and after death and respawn. Pinned in Task 2 (filter test) and Task 6 (Play).
2. **Heat from the right sources only:** attacking a player gives none; an NPC weapon or a heist hazard gives none; a crime nobody saw gives none. Pinned in Task 1.
3. **Police never spawn in the player's sight, inside a building or a plot, or off the ground,** and never exceed 24. Pinned in Task 2 (spawn-point validator test) and Task 6 (sampled Play).
4. **The drain cannot be cheated by standing still behind a wall next to an officer who can't path to you:** "seen" is line of sight within 150 studs, so a hidden player drains even if police are near; that is the intended rule, and it is tested both ways.
5. **Phones:** client descendants and frame time at the spawn with 24 police alive, measured against the city's numbers without police.

---

### Task 1: Heat model and WantedService

**Files:** Create `ReplicatedStorage.Wanted.Constants`, `ReplicatedStorage.Wanted.HeatModel`, `ServerScriptService.Wanted.WantedService` (ModuleScript) and its runner Script, `ServerScriptService.Blaster.Events.Damaged` (BindableEvent); cases `HeatModel_Test`, `WantedService_Test`. Modify `ShotResolver` (fire `Damaged`), `Heist.Services.LocationServer` and `HeistServer` (call `WantedService.onAlarm`).

**Interfaces (produced):**
- `HeatModel.raise(heat: number, amount: number): number` (clamped 0..5), `HeatModel.atLeast(heat: number, level: number): number`, `HeatModel.stars(heat: number): number`, `HeatModel.drainStep(heat: number): number` (to the integer below, or minus 1 when integral, not below 0).
- `WantedService.getHeat(player): number`, `WantedService.addHeat(player, amount: number, reason: string)`, `WantedService.onAlarm(locationName: string, players: {Player})`, `WantedService.clear(player)`, `WantedService.setSeenProvider(fn: (Player) -> boolean)`, signal `WantedService.Changed(player, heat, stars)`. Attributes `WantedHeat`, `WantedStars` on the player.

- [ ] **Step 1: Failing tests.** `HeatModel_Test`: raise clamps at 5 and 0; `stars(2.75) == 2`; `atLeast(0.5, 1) == 1`, `atLeast(3.2, 1) == 3.2`; `drainStep(2.75) == 2`, `drainStep(2) == 1`, `drainStep(0) == 0`. `WantedService_Test` (stand-in players, as `ProfileAdoption_Test` builds them; time and seen injected): an alarm at "Bank" sets 3, at "Gas2Go" 1; a second lower alarm does not lower heat; unseen for 8 s drops one step, seen at 7 s restarts the timer; death clears; a hit on police +0.25, a police kill +1; a player-on-player hit adds nothing; attributes match heat and stars after each step.
- [ ] **Step 2: Run, red.**
- [ ] **Step 3: Implement** `Constants` (every number in spec section 5), `HeatModel`, `WantedService` (heartbeat at 2 Hz for the drain; `Players.PlayerRemoving` and `Humanoid.Died` clear). `ShotResolver` fires `Damaged(attacker, humanoid, amount)` where it applies damage to a humanoid, attacker a `Player` only. `WantedService` listens to `Damaged` and `Eliminated`: police victim (attribute `EnemyTemplate` of `Police` or `Armed Police`) gives the police heat; any other NPC victim gives the public-crime heat only if a witness sees it (Task 3 provides witnesses; until then the witness check returns false). The alarm hook goes where each robbery path already calls `NotifyRobberyTriggered`, passing the robbery's participants.
- [ ] **Step 4: Run, green.** Both new suites pass; baselines hold.
- [ ] **Step 5: Play check.** Trigger a SlowFoods robbery through its real path (as `CityMerge/phase3/first-run.md` drove it): the robber's `WantedStars` becomes 1; with no police yet (Task 2), the seen provider says false, so heat drains to 0 within about 8 s. Record.
- [ ] **Step 6: Commit** `Batch: wanted level, heat and alarms`.

### Task 2: Police on the enemy AI, and the dispatcher

**Files:** Modify `ServerScriptService.Enemy.Scripts.EnemyAI` (target filter, `canSee`, registry). Create `ServerScriptService.Wanted.PoliceDispatcher`, `ReplicatedStorage.Wanted.SquadPlan` (pure); cases `SquadPlan_Test`, `PoliceSpawnPoint_Test`, `EnemyTargetFilter_Test`.

**Interfaces:**
- `EnemyAI.new(..., config)` accepts `config.targetFilter: ((Player) -> boolean)?`; `EnemyAI:canSee(character: Model): boolean`; `EnemyAI.getLive(): {EnemyAI}` (instances alive), each with `self.character` and `self.config.faction` (`"Police"` for police).
- `SquadPlan.target(stars: number): (police: number, armed: number)`; `SquadPlan.allocate(requests: {{player: any, stars: number, alive: number}}, cap: number): {[any]: number}` (spawns allowed now per player, highest stars first, never above the cap).
- `PoliceDispatcher.isValidSpawn(position: Vector3, player: Player?): (boolean, string?)` — on road or footpath ground, not inside a plot or robbery building box, not in the player's line of sight, reachable by pathfinding.

- [ ] **Step 1: Failing tests.** `SquadPlan_Test`: the spec table for 0 to 5 stars; `allocate` with three wanted players at 5, 3 and 1 stars and a cap of 24 gives at most 24 in total, the 5-star player first, nobody above their target, and nothing for a 0-star player. `EnemyTargetFilter_Test`: a filter that refuses a stand-in makes `_findVisibleTarget` skip it (call the method with a stub player list through a seam, or test the filter call through the smallest extraction the builder needs). `PoliceSpawnPoint_Test`: positions inside a plot box, inside a robbery building box, and in the air are refused (pure box and ground checks; line of sight and pathfinding checked in Play).
- [ ] **Step 2: Run, red.**
- [ ] **Step 3: Implement.** `EnemyAI`: the filter in `_findVisibleTarget`; `canSee` on its existing line-of-sight check; the registry. Gangs pass no filter. `PoliceDispatcher`: every 5 s for each wanted player, `SquadPlan.allocate`, then spawn from the `Police` / `Armed Police` templates the same way `EnemySpawner` builds an enemy (scripts stripped, weapon prepared, collision group, `EnemyGUI`), with `config.targetFilter` = wanted and `faction = "Police"`, tag `Witness`, attribute `EnemyTemplate` kept; first squad after an alarm around the location's `StatusBillboardAnchor` (60 to 120 studs), later ones 90 to 160 studs from the player, out of sight; an officer whose player is cleared or dead takes another visible wanted player or walks away out of sight and despawns. Wire `WantedService.setSeenProvider` to "any live police or guard within 150 studs `canSee` the character" (guards via the helper in Task 3; until then police only).
- [ ] **Step 4: Run, green; baselines hold;** gangs: in a Play, 30 gang enemies as before, none with a filter.
- [ ] **Step 5: Play check.** SlowFoods robbery: police spawn (count = target for 1 star), none in the robber's view at spawn (check `canSee` false from each spawn position at spawn time), they reach and shoot the robber; the robber dies: heat 0, the squad leaves and despawns within 30 s. Then a 3-star Bank alarm: 4 police + 2 armed police. Then 5 stars forced through `addHeat`: 10, and with a second wanted stand-in impossible in Solo, the cap is checked by `allocate`'s test only (say so).
- [ ] **Step 6: Commit** `Batch: police squads on the enemy AI`.

### Task 3: Witnesses and NewsStation guards

**Files:** tags on `HeistShared.ModelTemplates.BankClerk`, `RestaurantShared.ModelTemplates.Cashier`, `NewsStationShared.ModelTemplates.NewsWorker`, `ServerStorage.GuardTemplate`; guard posts in `NewsStation`; the guard wiring for NewsStation (in `NewsStationServer` or `LocationServer`, as the Bank wires its `GuardPost`s); `ServerScriptService.Wanted.Witnesses` (helper); case `Witnesses_Test`.

- [ ] **Step 1: Failing test** `Witnesses_Test`: with stand-in witness positions and an injected line-of-sight function, a crime at 100 studs in sight counts; at 130 studs it does not; out of sight it does not.
- [ ] **Step 2: Implement** `Witnesses.sees(position: Vector3): boolean` over `CollectionService:GetTagged("Witness")` (live humanoids only), the line of sight from each witness's head; plug it into `WantedService`'s public-crime check and into the seen provider for guards.
- [ ] **Step 3: NewsStation guards.** Read how `HeistServer` places and wires the Bank's guard posts (`GuardPost`, `GuardTemplate`, tag names), then place 3 guard posts inside NewsStation on walkable floor, one covering the safe and one the hacking computer, and wire them the same way. Check in Play: 3 guards stand at their posts before any robbery; they engage the robber after the NewsStation alarm; SlowFoods and Gas2Go have none.
- [ ] **Step 4: Play check.** Kill a gang member with a cashier in sight (move the player beside SlowFoods's cashier): +0.5 heat. The same kill far from any witness: 0.
- [ ] **Step 5: Commit** `Batch: witnesses and NewsStation guards`.

### Task 4: The star meter

**Files:** Create `StarterPlayer.StarterPlayerScripts.WantedHud` (LocalScript) and its module if needed.

- [ ] **Step 1: Build** five stars (existing Figma slices or `UITheme` shapes; the report names which), filled per star, the next one partly filled by the fraction, a pulse while seen (server publishes `WantedSeen` boolean attribute: add it in `WantedService`), a slow blink on the next star while draining, hidden at 0. ScreenGui `ZIndexBehavior = Sibling`.
- [ ] **Step 2: Place** it where it overlaps nothing in the city HUD or the heist HUD at 1080 x 659 (read live) and 844 x 390 (computed; say so).
- [ ] **Step 3: Play check:** set heat to 2.5 and then 0 from the server: the meter shows 2 filled and a half, then hides. A capture if one works.
- [ ] **Step 4: Commit** `Batch: wanted star meter`.

### Task 5: Quest givers as crooked cops

**Files:** `ReplicatedStorage.Quests.QuestConfig` (lines), each `Workspace.Quests.<giver>.Head.gui` name label.

- [ ] **Step 1:** Rewrite each giver's lines in `QuestConfig` so they read as a crooked officer paying a criminal off the books to wipe out a rival gang; same quests, levels, rewards, counts and enemy names. Short, in the existing lines' length and tone; no slurs, no real brands. List old and new in the report.
- [ ] **Step 2:** Change each giver's shown name (the billboard label) to a crooked-cop title (for example "Sgt. ... (off duty)"); model names and `npcName` unchanged.
- [ ] **Step 3: Check:** `QuestReach_Test`, `QuestSave_Test` and the quest round trip (accept, kills, turn-in, as `CityMerge/phase2b/final-run.md`) still pass; every line fits its billboard (`TextBounds` within the label).
- [ ] **Step 4: Commit** `Batch: quest givers become crooked cops`.

### Task 6: End to end, closing run and vault

- [ ] **Step 1: The loop in Play.** Rob SlowFoods: 1 star, 2 police arrive, chase. Escape: break sight (move behind a building out of every officer's line of sight): heat drains one step per 8 s to 0; police leave. Rob again and bank at 201 studs while seen: the cash banks once and the stars stay. Die while wanted: haul lost (existing forfeit), heat 0. Bank alarm: 3 stars, 4 police and 2 armed police; NewsStation: 2 stars and the 3 guards.
- [ ] **Step 2: Load.** With heat forced to 5 (10 police) and with as many as Solo allows: client descendants and memory at the player, frame time; police alive never above 24 (sampled every second for 2 minutes).
- [ ] **Step 3: Five Plays** from the city spawn without wanting: 0 client and server script errors other than asset lines; gangs and quests as before; both suites.
- [ ] **Step 4: Vault:** batch note, Batch Log, a new `20 Systems/Police and Wanted.md`, updates to Enemies and Spawner, Robbery Heists and Getaway, Quests and Dialogue, HUD and UI Shell, Open Items (the numbers to tune in playtests, two-player checks, phone readings), Decisions (the developer's answers quoted, Claude's calls), Engine Traps if new.
- [ ] **Step 5: Commit** `Batch: police and wanted level`.

## Not in this plan

Police cars, roadblocks, arrests, a saved wanted level, police at the plots, the known-issues pass (its own plan), phone performance.
