# Prompt: Enemy Roster Rework — Retire Enforcement From Quests, 3 New Recruits, Per-Type Spawn Cap

Paste this whole document to Claude Code (with Roblox Studio MCP access, targeting the `FPS System.rbxl` place). It is self-contained.

**Context:** Security, Police and Armed Police are being spun off into a separate robbery system built in another workspace — they stay in this place purely as designed-and-ready enemy templates, but lose their quest ties and their spawners here. That leaves the Level 10/35/70 quests with no enemy to target, so three new criminal-side recruits (Smuggler, Bandits, Saboteur) take their place. Criminal and Armed Criminal are also being renamed to Offender and Disrupters. End state: **9 total templates** (Security, Police, Armed Police, Thug, Offender, Disrupters, Smuggler, Bandits, Saboteur) — only the **6 criminal-side ones** (Thug, Offender, Disrupters, Smuggler, Bandits, Saboteur) get a spawner.

**Interpretation calls made before writing this, flagged so they're easy to correct:**
- Quest dictionary **keys** are renamed to match their new target (`Level10Security` → `Level10Smugglers`, etc.) — pure internal bookkeeping (session-only state, no persistence), but this file's own convention already embeds the enemy name in the key (`Level1Thugs`, `Level20Criminal`, …), so keeping that consistent seemed right even though you didn't explicitly ask for it.
- Quest **flavor titles** (the `name` field, e.g. `"No Badge, No Mercy"`, `"Heavy Hitters"`) are deliberately left unchanged even though a couple no longer thematically match their new target — only the enemy/objective assignment was requested, not a copy rewrite. Say the word if you want these refreshed too.
- Enforcement-side spawn points are **deleted outright**, not just detagged — "the only one that has a spawner are the criminal side" reads as enforcement getting no spawner at all, and these Parts have no future use in this workspace (the robbery system is a separate place). Their **enemy templates are untouched**, only their `Workspace` spawn points go.
- Weapons picked on your behalf ("you choose"): **PB** for Smuggler — the lowest-damage Semi-fire pistol in the armory (19 stock damage, shortest pistol range at 650 studs), fits "weak" best. **Mossberg 590** for Bandits — the baseline pump shotgun, sits between the faster Benelli M4 and the harder-hitting Itacha Mag-10.
- New templates' `MaxHealth`/`WalkSpeed`/`ChaseSpeed`/`DetectionRadius` are placeholder numbers interpolated onto the existing difficulty curve between their level-neighbors — not balance, tune freely, exactly like every other number in `ReplicatedStorage.Enemy.Constants` already is documented as being.
- Exact map placement of the 3 new spawn points is left to you (duplicate an existing spawner Part so its properties are correct, then place it in open ground away from other spawners and the player spawn) — this needs eyes on the actual map layout, which a text prompt can't dictate.

---

## Part 1 — Rename two existing templates: Criminal → Offender, Armed Criminal → Disrupters

Do this first — later parts reference the new names.

1. `ServerStorage.EnemyTemplates.Criminal` → rename Model to **`Offender`**. Do not touch its `M1911` Tool or any of its attributes (`DamageOverride=8`, aim tier, `MaxHealth=90`, etc.) — only the Model's `Name` changes.
2. `ServerStorage.EnemyTemplates.Armed Criminal` → rename Model to **`Disrupters`**. Same rule: only the `Name` changes, nothing else on it.
3. `Workspace.EnemySpawns.CriminalSpawner` → rename Part to **`OffenderSpawner`**; its `EnemyType` StringValue child's `.Value` changes from `"Criminal"` to `"Offender"`.
4. `Workspace.EnemySpawns."Armed CriminalSpawner"` → rename Part to **`DisruptersSpawner`**; its `EnemyType` StringValue child's `.Value` changes from `"Armed Criminal"` to `"Disrupters"`.

**Do not** rename `Workspace.Quests."Level 20 Quest"` or `Workspace.Quests."Level 50 Quest"` (the physical quest-giver NPC Models) — those names are unrelated to the enemy identifier and QuestService looks them up by their own `npcName` field in QuestConfig (Part 4), which stays `"Level 20 Quest"` / `"Level 50 Quest"`.

---

## Part 2 — Enforcement side exits the quest loop

`Security`, `Police`, and `Armed Police` under `ServerStorage.EnemyTemplates` are **not modified in any way** — keep every attribute and their weapons (`Baton`, `Mateba 2006M`, `Scar L`) exactly as they are. They simply stop having anywhere to spawn from in this workspace:

Delete these 3 Parts entirely from `Workspace.EnemySpawns`:
- `SecuritySpawner`
- `PoliceSpawner`
- `Armed PoliceSpawner`

After this, `Workspace.EnemySpawns` should contain exactly 6 children: `ThugSpawner`, `OffenderSpawner`, `DisruptersSpawner`, plus the 3 new ones added in Part 3.

Their quest ties are removed as part of the QuestConfig rewrite in Part 4 (there is no separate step here — Level 10/35/70 simply no longer reference Security/Police/Armed Police once Part 4 is applied).

---

## Part 3 — Three new recruits: Smuggler (Lv10), Bandits (Lv35), Saboteur (Lv70)

### How to build each template

For each new enemy: duplicate an existing template as your starting rig (any of them — the rig itself doesn't need to match the weapon; `EnemySpawner.prepareWeapon` + `Humanoid:EquipTool` builds the grip fresh at spawn time regardless of which rig you started from), then:

1. Rename the duplicated Model to the new template's name.
2. Delete its existing `Tool` child.
3. Clone the correct weapon **from `ServerStorage.Weapons`** (by name, below) and parent the clone directly under the new template Model — same pattern every existing template already uses (e.g. `Offender` carries a cloned `M1911` directly as a child). Keep the weapon's own name unchanged (`"PB"`, `"Mossberg 590"`, `"FN P-90"`).
4. **Delete every attribute the base template you duplicated already had** (`DamageOverride`, `RecoilMinOverride`, `RecoilMaxOverride`, `AimBaseErrorDegrees`, `AimDistanceErrorDegrees`, `AimMovementErrorDegrees`, `AimAcquisitionErrorDegrees`, `AimMaxErrorDegrees`, `MaxHealth`, `WalkSpeed`, `ChaseSpeed`, `DetectionRadius`, `EngageRangeFraction`, `PreferredRangeFraction`) before setting the new ones below. This matters most if you duplicate `Disrupters` (AKM) as a base for `Saboteur` (FN P-90) — its old recoil/aim overrides are tuned for a completely different weapon and must not survive the copy.
5. Character appearance/clothing/accessories are not specified — reuse or restyle whatever came with the base template you duplicated; purely cosmetic, no effect on correctness.

You do **not** need to edit the cloned weapon's own `damage` attribute — `EnemySpawner.prepareWeapon` overwrites it from `DamageOverride` at spawn time, exactly as it already does for all 6 existing templates.

### Attributes to set on each new template

**`Smuggler`** — weapon: clone of `ServerStorage.Weapons.PB` (stock damage 19)

| Attribute | Value |
|---|---|
| `MaxHealth` | `85` |
| `WalkSpeed` | `11` |
| `ChaseSpeed` | `17` |
| `DetectionRadius` | `95` |
| `PreferredRangeFraction` | `0.6` |
| `DamageOverride` | `4` (19 × 0.2, rounded) |
| `AimBaseErrorDegrees` | `4` |
| `AimDistanceErrorDegrees` | `6.5` |
| `AimMovementErrorDegrees` | `6.5` |
| `AimAcquisitionErrorDegrees` | `3` |
| `AimMaxErrorDegrees` | `16` |

No `EngageRangeFraction` override (leave unset → default `0.1`, matching every other non-melee enemy). No `RecoilMinOverride`/`RecoilMaxOverride` (leave unset → PB's own stock recoil is used directly, matching every other Semi-fire enemy).

**`Bandits`** — weapon: clone of `ServerStorage.Weapons."Mossberg 590"` (stock damage 15, `raysPerShot=8`)

| Attribute | Value |
|---|---|
| `MaxHealth` | `100` |
| `WalkSpeed` | `12` |
| `ChaseSpeed` | `19` |
| `DetectionRadius` | `110` |
| `PreferredRangeFraction` | `0.6` |
| `DamageOverride` | `3` (15 × 0.2, rounded — this is per-pellet, same as the stock weapon already works) |
| `AimBaseErrorDegrees` | `4` |
| `AimDistanceErrorDegrees` | `6.5` |
| `AimMovementErrorDegrees` | `6.5` |
| `AimAcquisitionErrorDegrees` | `3` |
| `AimMaxErrorDegrees` | `16` |

No `EngageRangeFraction` override — the default `0.1` fraction already yields a short ~55-stud engage distance off the Mossberg's 550-stud range, which is correct for a shotgun. No recoil override, same reasoning as Smuggler (Semi fire mode).

**`Saboteur`** — weapon: clone of `ServerStorage.Weapons."FN P-90"` (stock damage 12, Auto, stock `recoilMin=(-2,5)` / `recoilMax=(2,9)`)

| Attribute | Value |
|---|---|
| `MaxHealth` | `130` |
| `WalkSpeed` | `12` |
| `ChaseSpeed` | `21` |
| `DetectionRadius` | `150` |
| `PreferredRangeFraction` | `0.6` |
| `DamageOverride` | `2` (12 × 0.2, rounded) |
| `RecoilMinOverride` | `Vector2.new(-1, 2.5)` (50% of the P-90's own `recoilMin`) |
| `RecoilMaxOverride` | `Vector2.new(1, 4.5)` (50% of the P-90's own `recoilMax`) |
| `AimBaseErrorDegrees` | `8` |
| `AimDistanceErrorDegrees` | `11` |
| `AimMovementErrorDegrees` | `10` |
| `AimAcquisitionErrorDegrees` | `3` |
| `AimMaxErrorDegrees` | `28` |

No `EngageRangeFraction` override (default `0.1`), same as `Disrupters`/`Armed Police` (the other two auto-weapon enemies).

`RecoilMinOverride`/`RecoilMaxOverride` must be set as **Vector2** attributes in the Attributes panel (type dropdown → Vector2), matching how `Disrupters`/`Armed Police` already store theirs.

### New spawn points

Duplicate any existing spawn point Part (e.g. `ThugSpawner`) three times — this copies its correct Size/Anchored/CanCollide/Transparency for free — then for each:
1. Rename to `SmugglerSpawner` / `BanditsSpawner` / `SaboteurSpawner`.
2. Reposition to open ground, away from the other spawners and the player spawn location.
3. Change its `EnemyType` StringValue child's `.Value` to `"Smuggler"` / `"Bandits"` / `"Saboteur"` respectively.

Leave the `EnemySpawnPoint` CollectionService tag exactly as duplicated (it's independent of the Part's name).

---

## Part 4 — QuestConfig: full updated table

Replace only the `QuestConfig.Quests` table in `ReplicatedStorage.Quests.QuestConfig` with this. Everything else in the file (`QuestDefinition` type, `sanitize`, the three `*AttributeFor` functions, the `STATE_*` constants) stays exactly as-is — do not touch it.

```lua
QuestConfig.Quests = {
	Level1Thugs = {
		name = "A Warning to Thugs",
		description = "Defeat 10 Thugs.",
		npcName = "Level 1 Quest",
		requiredLevel = 1,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Thug",
		objectiveEnemyNamePlural = "Thugs",
		objectiveTarget = 10,
		rewardCash = 500,
		rewardXp = 100,
		repeatable = true,
	},
	Level10Smugglers = {
		name = "Lockdown",
		description = "Defeat 10 Smugglers.",
		npcName = "Level 10 Quest",
		requiredLevel = 10,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Smuggler",
		objectiveEnemyNamePlural = "Smugglers",
		objectiveTarget = 10,
		rewardCash = 900,
		rewardXp = 300,
		repeatable = true,
	},
	Level20Offender = {
		name = "Clean Sweep",
		description = "Defeat 10 Offenders.",
		npcName = "Level 20 Quest",
		requiredLevel = 20,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Offender",
		objectiveEnemyNamePlural = "Offenders",
		objectiveTarget = 10,
		rewardCash = 1600,
		rewardXp = 600,
		repeatable = true,
	},
	Level35Bandits = {
		name = "No Badge, No Mercy",
		description = "Defeat 10 Bandits.",
		npcName = "Level 35 Quest",
		requiredLevel = 35,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Bandits",
		objectiveEnemyNamePlural = "Bandits",
		objectiveTarget = 10,
		rewardCash = 2800,
		rewardXp = 1200,
		repeatable = true,
	},
	Level50Disrupters = {
		name = "Heavy Hitters",
		description = "Defeat 10 Disrupters.",
		npcName = "Level 50 Quest",
		requiredLevel = 50,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Disrupters",
		objectiveEnemyNamePlural = "Disrupters",
		objectiveTarget = 10,
		rewardCash = 4500,
		rewardXp = 2000,
		repeatable = true,
	},
	Level70Saboteurs = {
		name = "Last Stand",
		description = "Defeat 10 Saboteurs.",
		npcName = "Level 70 Quest",
		requiredLevel = 70,
		objectiveType = "KillCount",
		objectiveEnemyTemplate = "Saboteur",
		objectiveEnemyNamePlural = "Saboteurs",
		objectiveTarget = 10,
		rewardCash = 8000,
		-- Level 70 is the cap, so XP granted here would simply be dropped by LevelingService.
		-- This quest's whole value is in its cash reward instead.
		rewardXp = 0,
		repeatable = true,
	},
} :: { [string]: QuestDefinition }
```

**What is deliberately NOT changing:** `CashService.getEnemyTier` and `LevelingService.getCharacterTier` derive an enemy's cash/XP tier purely from its weapon's attributes (`infiniteAmmo` → Melee, `fireMode == Auto` → AutoRifle, else → Pistol) — never from the template name. Do not touch either file. One known, deliberate consequence: Smuggler (pistol) and Bandits (shotgun) both drop "Pistol"-tier cash ($35) and XP (15) on death, since there's no separate "Shotgun" tier in either table today — this is expected, not a bug to fix as part of this change.

---

## Part 5 — Spawner rework: independent per-type cap (up to 10 each)

Today `Constants.MAX_CONCURRENT_ENEMIES = 10` is a single number shared across **every** spawn point combined. This changes it to a cap applied **independently per enemy type** — each of the 6 criminal-side spawners may have up to 10 of its own type alive+pending at once, so the practical ceiling across all criminal-side enemies combined becomes up to 60.

### `ReplicatedStorage.Enemy.Constants`

Rename `MAX_CONCURRENT_ENEMIES` to `MAX_CONCURRENT_ENEMIES_PER_TYPE` (value stays `10`) and update its comment:

```lua
-- === Spawner ===
-- Applied INDEPENDENTLY per enemy type -- not a shared total. Each spawn point's own type may
-- have up to this many alive+pending at once, so the practical ceiling across every criminal-side
-- enemy combined is (number of spawn points) * this value, not this value alone.
MAX_CONCURRENT_ENEMIES_PER_TYPE = 10,
```

### `ServerScriptService.Enemy.Scripts.EnemySpawner`

Replace the scalar counters:
```lua
local aliveCount = 0
-- Spawns that have been committed to but not yet finished, so a burst of top-up ticks cannot
-- overshoot MAX_CONCURRENT_ENEMIES part-way through building one.
local pendingCount = 0
```
with per-type tables and small accessors:
```lua
-- Keyed by enemy type name (matches a spawn point's EnemyType value, and the template's own Name).
-- A spawn point with no EnemyType child buckets under UNASSIGNED_TYPE -- unused today (every
-- current spawn point has one), kept only as a safe fallback.
local UNASSIGNED_TYPE = "Unassigned"
local aliveCounts: { [string]: number } = {}
-- Spawns that have been committed to but not yet finished, so a burst of top-up ticks cannot
-- overshoot MAX_CONCURRENT_ENEMIES_PER_TYPE part-way through building one.
local pendingCounts: { [string]: number } = {}

local function getAliveCount(enemyType: string): number
	return aliveCounts[enemyType] or 0
end

local function getPendingCount(enemyType: string): number
	return pendingCounts[enemyType] or 0
end
```

Replace `pickSpawnPoint` entirely — it now filters out any spawn point whose own type is already at cap, and returns the resolved type alongside the point/position:
```lua
local function getSpawnPointType(point: Instance): string
	local enemyTypeValue = point:FindFirstChild("EnemyType")
	if enemyTypeValue and enemyTypeValue:IsA("StringValue") and enemyTypeValue.Value ~= "" then
		return enemyTypeValue.Value
	end
	return UNASSIGNED_TYPE
end

-- Returns the chosen point, its position, and its resolved enemy type -- callers no longer need
-- to re-read the EnemyType child themselves. A spawn point is only offered as a candidate if its
-- own type has not already reached MAX_CONCURRENT_ENEMIES_PER_TYPE; this is the one place the cap
-- is enforced.
local function pickSpawnPoint(): (Instance?, Vector3?, string?)
	local candidates = {}
	for _, point in CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) do
		local position
		if point:IsA("BasePart") then
			position = point.Position
		elseif point:IsA("Attachment") then
			position = point.WorldPosition
		end
		if not position or not isSpawnPointClear(position) then
			continue
		end

		local enemyType = getSpawnPointType(point)
		if getAliveCount(enemyType) + getPendingCount(enemyType) >= Constants.MAX_CONCURRENT_ENEMIES_PER_TYPE then
			continue -- this type is already at its own cap
		end

		table.insert(candidates, { point = point, position = position, enemyType = enemyType })
	end

	if #candidates == 0 then
		return nil, nil, nil
	end
	local candidate = candidates[math.random(1, #candidates)]
	return candidate.point, candidate.position, candidate.enemyType
end
```

Replace `trySpawn`. The global cap check at the top is gone (the cap is now enforced inside `pickSpawnPoint`, per candidate); the redundant re-read of the spawn point's `EnemyType` child is gone (use the `enemyType` `pickSpawnPoint` already resolved); the scalar increment/decrement lines become per-type table operations:
```lua
function trySpawn(): boolean
	local spawnPoint, spawnPosition, enemyType = pickSpawnPoint()
	if not spawnPoint or not spawnPosition or not enemyType then
		return false
	end

	local templates = getTemplates()
	if #templates == 0 then
		warn(
			`EnemySpawner: no rig templates found. Put a Model containing a Humanoid under `
				.. `ServerStorage.{TEMPLATES_FOLDER_NAME}.`
		)
		return false
	end

	-- A spawn point carrying an EnemyType only ever produces the template of that name. Only an
	-- UNASSIGNED_TYPE point (none exist today) draws from the whole pool.
	local eligibleTemplates = templates
	if enemyType ~= UNASSIGNED_TYPE then
		eligibleTemplates = {}
		for _, template in templates do
			if template.Name == enemyType then
				table.insert(eligibleTemplates, template)
			end
		end
		if #eligibleTemplates == 0 then
			warn(`EnemySpawner: no template named "{enemyType}" for spawn point {spawnPoint:GetFullName()}`)
			return false
		end
	end

	pendingCounts[enemyType] = getPendingCount(enemyType) + 1

	local template = eligibleTemplates[math.random(1, #eligibleTemplates)]
	local character = template:Clone()
	character.Name = "Enemy"
	stripClientScripts(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not character.PrimaryPart then
		pendingCounts[enemyType] -= 1
		character:Destroy()
		warn(`EnemySpawner: template {template.Name} has no Humanoid or no PrimaryPart`)
		return false
	end

	local config = templateConfig.read(character)

	local weapon = prepareWeapon(character, config)
	if not weapon then
		pendingCounts[enemyType] -= 1
		character:Destroy()
		return false
	end

	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.WalkSpeed = config.walkSpeed

	local head = character:FindFirstChild("Head")
	if head then
		enemyGuiTemplate:Clone().Parent = head
	end

	CollectionService:AddTag(character, Constants.ENEMY_TAG)
	character:SetAttribute("EnemyTemplate", template.Name)

	character:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, SPAWN_HEIGHT_OFFSET, 0)))
	character.Parent = getEnemiesFolder()

	pcall(function()
		humanoid:EquipTool(weapon)
	end)

	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end

	RagdollController.prepare(character)

	EnemyAI.new(character, weapon, spawnPosition, onEnemyDied, config)

	pendingCounts[enemyType] -= 1
	aliveCounts[enemyType] = getAliveCount(enemyType) + 1
	return true
end
```

Update `onEnemyDied` to decrement the right bucket, using the `EnemyTemplate` attribute the dying character already carries (the same attribute quests already key kills off):
```lua
local function onEnemyDied(enemy)
	local enemyType = (enemy.character:GetAttribute("EnemyTemplate") :: string?) or UNASSIGNED_TYPE
	aliveCounts[enemyType] = math.max(getAliveCount(enemyType) - 1, 0)

	task.delay(Constants.RESPAWN_DELAY, function()
		trySpawn()
	end)
end
```

Update `initialize`'s top-up loop — the old pre-check (`if aliveCount + pendingCount < Constants.MAX_CONCURRENT_ENEMIES then trySpawn() end`) doesn't translate to a single boolean anymore (different types can be at different fill levels simultaneously), so simplify to an unconditional call; `trySpawn` → `pickSpawnPoint` already returns nothing when every type is full, so this stays just as cheap when the roster is full:
```lua
local function initialize()
	if #getTemplates() == 0 then
		warn(
			`EnemySpawner: no rig templates. Put a Model containing a Humanoid under `
				.. `ServerStorage.{TEMPLATES_FOLDER_NAME} -- duplicate one to add an enemy variant.`
		)
	end

	if #CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) == 0 then
		warn(
			`EnemySpawner: no spawn points found. Tag Parts or Attachments in Workspace with `
				.. `"{Constants.SPAWN_POINT_TAG}" to place enemies.`
		)
	end

	while true do
		trySpawn()
		task.wait(TOP_UP_INTERVAL)
	end
end
```

Nothing else in `EnemySpawner.lua` changes (`getEnemiesFolder`, `isSpawnPointClear`, `stripClientScripts`, `getTemplates`, `prepareWeapon` are all untouched).

---

## Verification checklist

- [ ] `Offender` (ex-Criminal) and `Disrupters` (ex-Armed Criminal) spawn correctly from `OffenderSpawner`/`DisruptersSpawner`, keep their original weapon/damage/aim/recoil unchanged.
- [ ] `Security`, `Police`, `Armed Police` still exist under `ServerStorage.EnemyTemplates`, unmodified, and **never spawn** in this workspace (their 3 spawn points are gone).
- [ ] `Smuggler`, `Bandits`, `Saboteur` each spawn only from their own new spawn point, each deals damage matching its `DamageOverride`, and each visibly misses/has spread consistent with its assigned aim tier.
- [ ] `Saboteur`'s automatic fire visibly climbs during a sustained burst and settles after a pause (recoil override working); `Smuggler`/`Bandits` show no such climb (no recoil override, Semi fire mode).
- [ ] Accepting/turning in Level 10, 35, 70 quests now requires killing Smugglers/Bandits/Saboteurs respectively (not Security/Police/Armed Police), and Level 1/20/50 (Thug/Offender/Disrupters) are unaffected.
- [ ] Let one enemy type's spawner run uninterrupted (e.g. stand near only the `ThugSpawner` area) and confirm it fills up to 10 Thugs alive without being blocked by other types being at their own cap, and without exceeding 10 of that one type.
- [ ] With multiple types spawning simultaneously, confirm each stays independently capped at 10 (one type reaching 10 does not stop another type from continuing to spawn).
- [ ] No leftover reference to the old quest ids (`Level10Security`, `Level20Criminal`, `Level35Police`, `Level50ArmedCriminal`, `Level70ArmedPolice`) or old template names (`"Criminal"`, `"Armed Criminal"`) remains anywhere (grep the whole place).
