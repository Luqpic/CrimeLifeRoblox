# Police and Wanted Level: Design

Status: written 2026-11-17 from the developer's answers; the developer approved the shape ("Looks right, write the design. And apply it until the end as I will sleep now") and asked for it to be built without further review. Calls marked **(Claude's call)** are open to correction.

## 1. Intent

The heists have no threat outside the Bank's guards and the timer. The approved game design always meant NPC police to chase a robber ("Leaving the building starts the haul. NPC police pursue."). This adds that: robbing makes you wanted, police come, and you either shake them or die and lose the haul. The open city should feel watched, not only the robbery buildings.

The player is a criminal. The developer, 2026-11-17: "A criminal; givers go rogue". The six quest givers who pay you to kill gang members stop being law enforcement and become rogue figures paying you for turf war.

## 2. Goals, non-goals, anti-goals

Goals:
- A wanted level of 0 to 5 stars per player, raised by heist alarms, shooting police and crimes in public.
- Police who arrive at a robbed building after its alarm, then chase and fight the robber; armed police only at a high wanted level.
- Security guards stationed in the Bank and NewsStation before any robbery.
- A way out that rewards using the city: break every officer's sight and the stars drain.
- A star meter on the HUD.

Non-goals (now): police cars, roadblocks, arrests or jail, player police, a saved wanted level, police at the plots (the tycoon is parked), new art.

Anti-goals: police who flood a phone; police that make normal city play (quests, gang fights) miserable for a player who is not wanted; a robber who can bank and walk away while still at 5 stars with nothing following; police who shoot through walls or spawn in sight of the player.

## 3. The developer's decisions (2026-11-17, quoted or picked)

- Player role: "A criminal; givers go rogue".
- Heat from: "Heist alarms", "Shooting police", "Crimes in public". Not from attacking players.
- Police act: "Escalate in stars".
- Caught: "Die, lose the haul" — police shoot to kill; dying drops the duffel (the existing heist forfeit) and clears the wanted level; banked cash is safe.
- Escape: "Break sight, then cool down" — out of every officer's sight a star drains after a few seconds unseen, one at a time; being seen again pauses it.
- Banking: "No, you still have to escape" — banking pays, the stars stay.
- Shape: "when you rob the bigger robbery systems like Bank, and NewsStation, there's like security guards, and when you trigger the alarm, there's polices as well. Polices initially aren't there in the robbery buildings but appear once you start robbing. Security guards only exist in bank and newsstation. Armed Police appear when you have high wanted level".
- Accepted with the playback: SlowFoods and Gas2Go alarms also bring police, fewer; police and gangs ignore each other; a server-wide cap of about 24 officers.

## 4. Approaches considered

| Approach | Trade-off | Verdict |
|---|---|---|
| **A. Reuse the enemy system** | A `WantedService` owns stars; police are the existing `Police` and `Armed Police` enemy templates on the existing `EnemyAI`, filtered to target wanted players only. Least new code; fights like the gangs already tuned. No cars. | **Chosen**, with dispatch anchored to the robbed building on an alarm (the developer's shape). |
| B. New police AI | Road pursuit, cars, sirens, roadblocks. Several times the work; duplicates the enemy AI; wants the phase 6 car. | Not now. |
| C. Heist guards respond | Guards chase near the building only. No police in the open city, so two heat sources mean nothing. | Kept only for what guards already do. |

## 5. How it works

### Heat and stars
- Each player has a heat value from 0 to 5 (a number, saved nowhere). Stars shown = `math.floor(heat)`; a fraction is progress toward the next star. Replicated as player attributes `WantedHeat` (number) and `WantedStars` (integer).
- **Heist alarm** (both robbery paths, at the point they already announce `NotifyRobberyTriggered`): heat becomes at least the location's alarm level: Gas2Go 1, SlowFoods 1, NewsStation 2, Bank 3 **(Claude's call)**. Every participant of that robbery gets it.
- **Shooting police:** each hit on a police officer +0.25, each kill +1 **(Claude's call)**.
- **Crimes in public:** killing any NPC (gang member, heist civilian) or hurting a heist civilian while a **witness** sees it: +0.5 for a kill, +0.25 for a hurt **(Claude's call)**. Witnesses are police officers, security guards and heist civilians (cashiers, clerks, news workers) within 120 studs with line of sight to the player **(Claude's call: the city has no other civilians, so these are the eyes)**.
- Heat never exceeds 5. Raising heat resets the drain timer.

### Being seen and the drain
- A wanted player is **seen** while any police officer or security guard within 150 studs has line of sight to them (the AI's own line-of-sight check).
- Unseen for 8 seconds, heat drops by 1 (to the integer below if fractional), then again every 8 seconds while still unseen **(Claude's call)**. Seen at any moment: the 8-second timer restarts.
- Heat 0: not wanted. Police who were after that player stop targeting and leave (walk away out of sight, then despawn) **(Claude's call)**.
- Death clears heat to 0. Leaving the game clears it. Banking does not change it.

### Police dispatch
- Police exist only for wanted players: none stand in the city or in a robbery building before an alarm.
- Each wanted player has a squad target by stars **(Claude's call)**:

| Stars | Police | Armed Police | Total |
|---|---|---|---|
| 1 | 2 | 0 | 2 |
| 2 | 4 | 0 | 4 |
| 3 | 4 | 2 | 6 |
| 4 | 4 | 4 | 8 |
| 5 | 4 | 6 | 10 |

- "Armed Police appear when you have high wanted level": high = 3 stars and up.
- **On an alarm**, the first squad spawns at dispatch points around that building (outside it, about 60 to 120 studs away, on road or footpath, not in the player's line of sight), and heads for the building.
- **Otherwise** (top-ups, a wanted player away from a robbery), officers spawn 90 to 160 studs from the player on road or footpath, out of the player's line of sight, reachable by pathfinding, never inside a plot or a robbery building.
- The squad is topped up every 5 seconds toward its target; the server-wide cap is 24 police alive **(accepted)**; when the cap binds, squads share it in order of stars, highest first.
- One squad per wanted player; an officer targets only wanted players and prefers its own squad's player when that player is visible.

### Police behaviour
- The `Police` and `Armed Police` templates in `ServerStorage.EnemyTemplates` (kept since 2026-09-17, not spawning) on the existing `EnemyAI`: patrol, chase, attack, search. Their targeting is filtered: only players with `WantedStars >= 1`. Gangs keep targeting every player as today. Police and gangs never target each other (they target players only, as today).
- Police spawn from a new dispatcher, not from `Workspace.EnemySpawns`; they are not quest targets, and the existing gang spawner and caps are unchanged.
- Killing police counts on the existing saved `PoliceKills` counter and pays XP and the 30 % cash drop like any enemy **(Claude's call: risk and reward while wanted)**.

### Security guards
- The Bank keeps its guard posts as they are (heist `GuardPost` components and `ServerStorage.GuardTemplate`).
- NewsStation gets guard posts of the same kind: 3 inside the building **(Claude's call on the number)**, placed by the builder on walkable floor covering the safe and the hacking computer, wired the way the Bank wires its guard posts. Guards are witnesses and see wanted players (they count for "seen").
- SlowFoods and Gas2Go get no guards: "Security guards only exist in bank and newsstation".

### The star meter
- A HUD element: five star icons, filled for each full star, the next star partly filled by the fraction; while the player is seen, the meter pulses; while draining, the next star to go blinks slowly. Hidden at 0.
- Placed where it overlaps nothing in the city HUD or the heist HUD at 1080 x 659 and 844 x 390 (measured), on `UITheme` and the project's Figma style; built in code, `ZIndexBehavior = Sibling`.

### The quest givers become crooked cops
**(Claude's call: of the two rogue forms in the playback, crooked cops keep their uniforms and need no new art.)** Their names, nameplates and dialogue lines change so they read as crooked officers paying a criminal off the books to wipe out rival gangs; the quests, rewards and levels stay the same. Uniformed police who hunt you and uniformed crooked cops who pay you can both exist; the lines make the difference plain.

## 6. Constraints

- Target place `Crimelife city.rbxl`; other places read only; never publish; do not save without the developer's word (none given for this run).
- Server authority: heat, stars, seen, dispatch, all on the server; the client only shows the meter.
- The heist suite's failure set (the timing-sensitive `Zone` sweep only) and the city's 18 suites (193 / 193 / 0) hold.
- Phones: at most 24 police alive; police exist only for wanted players.
- Edits to existing scripts are recorded as deviations (`CityMergeDeviation`, `CityMerge/after-import.md`) and exported to `CityScripts/`.

## 7. Left to the builder

File layout under a new `ServerScriptService.Wanted` (service, dispatcher, pure heat model); the exact dispatch-point search; the star icons from existing slices or simple shapes; the guard post positions in NewsStation; the crooked-cop lines (in the game's tone, short); the test cases.

## 8. Answers to the builder check (all Claude's calls, 2026-11-17)

1. **Where "the robbed building" is:** each location already has a `StatusBillboardAnchor` part (in `HeistMarkers`, `SlowFoodsMarkers`, `Gas2GoMarkers`, `NewsStationMarkers`, now Persistent Models). The alarm dispatch searches a ring 60 to 120 studs (horizontal) around that anchor. No new markers.
2. **Targeting:** editing the shared `EnemyAI` is accepted, as a recorded deviation: `EnemyAI.new` takes an optional `config.targetFilter(player): boolean`, consulted in `_findVisibleTarget`; when absent (every gang) behaviour is unchanged. Police get `targetFilter = player has WantedStars >= 1`.
3. **Hearing hits and kills:** player weapons (guns and melee) all resolve through `ShotResolver`, which already fires `ServerScriptService.Blaster.Events.Eliminated` on a kill. Add one sibling `BindableEvent`, `Blaster.Events.Damaged(attacker: Player, humanoid: Humanoid, amount: number)`, fired by `ShotResolver` where it applies damage. The wanted service listens to both. Heist hazards and NPC weapons are not crimes.
4. **Deaths and squads:** squads are per player and never merge. When a wanted player dies or reaches 0 stars, their squad's officers may take any other wanted player they can see; otherwise they leave and despawn. Other participants of the same robbery keep their own heat. The 24 cap is shared, highest stars first.
5. **"Seen":** `EnemyAI` gains a public `EnemyAI:canSee(character): boolean` using its own line-of-sight check, and a registry of live police instances; guards use the same ray check from their head (a small shared helper). The wanted service evaluates "seen" for each wanted player twice a second, not every frame.
6. **Witnesses:** tag `Witness` on the heist civilian templates (`HeistShared.ModelTemplates.BankClerk`, `RestaurantShared.ModelTemplates.Cashier`, `NewsStationShared.ModelTemplates.NewsWorker`) and `ServerStorage.GuardTemplate`; spawned police get the tag at spawn. Witnesses are found with `CollectionService:GetTagged("Witness")`.
7. **Quest givers:** quest data, including the givers' lines, is in `ReplicatedStorage.Quests.QuestConfig`; the shown name is the `Head.gui` billboard's name label on each of the six models in `Workspace.Quests`. The model names (`Level 1 Quest` ... `Level 70 Quest`) and `npcName` stay, since code finds givers by them; only the shown names and the lines change.
