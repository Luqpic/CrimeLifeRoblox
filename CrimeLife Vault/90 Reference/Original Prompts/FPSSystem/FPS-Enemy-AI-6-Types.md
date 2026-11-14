# Prompt: Six Enemy Types with Dedicated Debug Spawners

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## What's being built

Six enemy templates, each with a distinct weapon and stat tier, each spawning only at its own dedicated point far from the others:

| Type | Weapon | Role tier |
|---|---|---|
| Security | Baton (new — reskinned Crowbar) | Law enforcement, melee, weakest |
| Police | Mateba 2006M (cloned) | Law enforcement, pistol |
| Armed Police | Scar L (cloned) | Law enforcement, auto-rifle, strongest |
| Thug | Crowbar (cloned as-is) | Criminal, melee, weakest |
| Criminal | M1911 (cloned) | Criminal, pistol |
| Armed Criminal | AKM (cloned) | Criminal, auto-rifle, strongest |

## Prerequisite finding — read before doing anything

`EnemyAI:_engageRange()` computes `weapon.range * config.engageRangeFraction`, and `config.engageRangeFraction` defaults to `Constants.ENGAGE_RANGE_FRACTION = 0.1`. For a melee weapon (`range = 6`), that's a 0.6-stud engagement distance — Security and Thug would essentially never register as "in range" to attack under the default. This is **not a code bug** — `EngageRangeFraction` is already a per-template attribute override (`ReplicatedStorage.Enemy.templateConfig`), so the fix is configuration, not a code change: set `EngageRangeFraction ≈ 0.9` on the two melee templates only (`6 * 0.9 = 5.4` studs, close to the weapon's real reach). Every ranged template keeps the default.

Second prerequisite finding: `ReplicatedStorage.Enemy.templateConfig` force-overrides every enemy's weapon damage to `Constants.ENEMY_DAMAGE_OVERRIDE` (currently `3`, explicitly commented `"TEMP: lowered for debugging, restore/rebalance before shipping"`) **unless the template sets its own `DamageOverride` attribute**. Without setting this per template, all 6 new types would deal an identical, near-harmless 3 damage regardless of which weapon they carry — completely flattening the point of giving them different guns. Each template below gets an explicit `DamageOverride` matching its weapon's own stock `damage` attribute.

---

## Part 1 — `EnemySpawner`: pair a spawn point to a specific enemy type

Currently `pickSpawnPosition()` and the template pick in `trySpawn()` are two **independent** random choices — any enemy type can currently spawn at any tagged point. That has to change for "separate spawners, test one by one" to mean anything: a point needs to be pinned to exactly one type.

**`ServerScriptService.Enemy.Scripts.EnemySpawner`** — replace `pickSpawnPosition()`:
```lua
local function pickSpawnPoint(): (Instance?, Vector3?)
	local candidates = {}
	for _, point in CollectionService:GetTagged(Constants.SPAWN_POINT_TAG) do
		local position
		if point:IsA("BasePart") then
			position = point.Position
		elseif point:IsA("Attachment") then
			position = point.WorldPosition
		end
		if position and isSpawnPointClear(position) then
			table.insert(candidates, { point = point, position = position })
		end
	end

	if #candidates == 0 then
		return nil, nil
	end
	local candidate = candidates[math.random(1, #candidates)]
	return candidate.point, candidate.position
end
```
In `trySpawn()`, change:
```lua
	local spawnPosition = pickSpawnPosition()
	if not spawnPosition then
		return false
	end

	local templates = getTemplates()
	if #templates == 0 then
		warn(...)
		return false
	end
```
to:
```lua
	local spawnPoint, spawnPosition = pickSpawnPoint()
	if not spawnPoint or not spawnPosition then
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

	-- A spawn point tagged with an EnemyType attribute only spawns the matching-named template, so
	-- each debug zone only ever produces its own enemy type. A point with no EnemyType attribute
	-- keeps the old behaviour: any template can spawn there (this is what StandardEnemy/HeavyEnemy
	-- relied on -- see the note in Part 4 about what happens to them here).
	local enemyType = spawnPoint:GetAttribute("EnemyType")
	local eligibleTemplates = templates
	if enemyType then
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
```
And change the existing `local template = templates[math.random(1, #templates)]` line to read from `eligibleTemplates` instead of `templates`.

**`ReplicatedStorage.Enemy.Constants`** — raise the population cap. It's currently `MAX_CONCURRENT_ENEMIES = 4`, shared across every zone; with 6 dedicated zones now competing for that same tiny pool, most zones would rarely have anything alive to test against. Raise it to `10` (still a real cap, not unlimited — tune further if needed).

### Verify
- Confirm `trySpawn()` now reads `spawnPoint:GetAttribute("EnemyType")` and only spawns a name-matching template when it's set.

---

## Part 2 — Build the Baton (Security's weapon)

Per the instruction, this reuses the Crowbar's entire mechanism (`infiniteAmmo`, `meleeHitEffect`, `knockbackForce`, spread-fan hit detection, damage-per-ray division — everything built in earlier passes) and only reskins the mesh and sounds. This is enemy-only content — it does not need a viewmodel (`ViewModelController` is never touched by `EnemyAI`, only `CharacterAnimationController` is), and its `Scripts` LocalScript folder is irrelevant since `EnemySpawner.prepareWeapon()` strips all `BaseScript`s from any weapon it hands to an enemy anyway.

1. Duplicate `StarterPack.Crowbar` in full, rename to `Baton`. This carries over every attribute (`damage`, `infiniteAmmo`, `meleeHitEffect`, `knockbackForce`, `range`, `spread`, `raysPerShot`, `rayRadius`, `recoilMin`/`recoilMax`, `fireMode`, `rateOfFire`) unchanged — leave all of them exactly as Crowbar's.
2. Replace the visible geometry: delete the cloned `Blaster` model's mesh contents, and in their place weld `Workspace."Police Baton".Part` (the `SpecialMesh`-based baton rod) to the Tool, positioned relative to the Crowbar's existing `Handle`/`Grip` setup (keep Crowbar's own `Grip` CFrame as the starting point — it's already tuned for a swung one-handed weapon — and adjust the baton mesh's local position/rotation to sit naturally in the hand; verify visually).
3. Sounds — replace the cloned Crowbar's Sounds:
   - `Sounds.Equip.SoundId` = `Workspace."Police Baton".Handle.UnsheathSound`'s `SoundId`
   - `Sounds.Shoot.Shoot1/2/3.SoundId` = `Workspace."Police Baton".Handle.SlashSound`'s `SoundId` (only one slash sound exists; apply it to all three variation slots)
   - Add a new `Hit` Sound instance under `Sounds` (this weapon has `meleeHitEffect = true`, so `impactEffect` looks for `Sounds.Hit` on a confirmed swing connect — see the earlier crowbar VFX work) with `SoundId` = `Workspace."Police Baton".Handle.HitSound`'s `SoundId`.
   - `LungeSound` and `OverheadSound` don't map to anything in the current Sounds schema — leave them unused, don't force-fit them anywhere.
4. Animations — see Part 3 below (same 3 IDs as the Crowbar).
5. Parent the finished `Baton` Tool into the `Security` enemy template (Part 4) — not into `StarterPack`; this is an enemy-only weapon unless asked otherwise later.
6. Delete `Workspace."Police Baton"` once its mesh and sounds have been extracted.

### Verify
- `Baton`'s attributes match `Crowbar`'s exactly except `viewModel` (irrelevant here) and cosmetics.
- The baton mesh sits naturally in a held pose, not floating or clipping through the hand.

---

## Part 3 — Real swing animations (replaces the earlier placeholder)

Both melee weapons' `Shoot`/`Shoot2`/`Shoot3` animation slots currently hold a placeholder (a cloned Deagle firing animation, flagged as temporary when the multi-swing system was built). Replace with the actual provided IDs on **both** weapons, same three IDs on each:

- `Shoot` → `rbxassetid://6783943440`
- `Shoot2` → `rbxassetid://6783954162`
- `Shoot3` → `rbxassetid://6783965485`

Apply to:
- `StarterPack.Crowbar.Animations` (third-person, player-equipped)
- `ReplicatedStorage.Blaster.ViewModels.Crowbar.Animations` (first-person, player-equipped)
- `Baton.Animations` (third-person; this is the only copy the Baton needs, since it has no viewmodel and no player-facing use)

Since which specific animation lands in which of the three slots doesn't matter (the random-pick-without-immediate-repeat logic treats all "Shoot"-named animations as equally valid options), the mapping above is arbitrary — just be consistent across all three locations so a given slot name means the same clip everywhere.

### Verify
- Swing the crowbar as a player (first- and third-person) and confirm real swing motions play, varying across swings, no back-to-back repeats.

---

## Part 4 — Build the 6 enemy templates

`ServerStorage.EnemyTemplates` already has two working rigs, `StandardEnemy` and `HeavyEnemy` (full R15 rig + Humanoid + Animator, each carrying a `Blaster` Tool). Duplicate `StandardEnemy` six times as the base rig for all six new types (don't rebuild rigging from scratch) — visual differentiation between the 6 (clothing, body color, etc.) wasn't asked for and isn't done here; that's an easy separate follow-up if wanted later.

**Important consequence, flagged rather than silently caused:** Part 5 assigns all 6 existing spawn points an `EnemyType`, which means no untagged point remains for `StandardEnemy`/`HeavyEnemy` to use — they will stop spawning entirely once this is applied. If you want them to keep spawning, add at least one fresh point tagged `EnemySpawnPoint` with no `EnemyType` attribute before finishing this prompt; otherwise this is expected and intentional per "separate their spawners."

For each of the 6, after duplicating `StandardEnemy` and renaming:
1. Delete the template's existing `Blaster` Tool child.
2. Add the weapon: for Security, the finished `Baton` from Part 2; for Thug, a clone of `StarterPack.Crowbar` as-is (no changes); for the other four, a clone of the corresponding `StarterPack` Tool (`Mateba 2006M`, `Scar L`, `M1911`, `AKM`).
3. Set the template's own Attributes (read by `ReplicatedStorage.Enemy.templateConfig`):

| Template name | MaxHealth | WalkSpeed | ChaseSpeed | DetectionRadius | EngageRangeFraction | DamageOverride |
|---|---|---|---|---|---|---|
| `Security` | 80 | 10 | 16 | 90 | **0.9** | 45 |
| `Police` | 100 | 12 | 20 | 120 | (default) | 60 |
| `Armed Police` | 120 | 12 | 20 | 140 | (default) | 16 |
| `Thug` | 90 | 11 | 18 | 80 | **0.9** | 45 |
| `Criminal` | 90 | 12 | 19 | 100 | (default) | 38 |
| `Armed Criminal` | 110 | 12 | 20 | 120 | (default) | 18 |

`DamageOverride` values match each weapon's own current `damage` attribute (i.e. "deal what a player would deal with the same gun") — verify the actual current `damage` attribute on each `StarterPack` weapon before setting these, in case it's drifted from these numbers since they were last tuned, and use the live value instead if it differs. `(default)` means don't set the attribute at all — the shared `Constants.ENGAGE_RANGE_FRACTION` (0.1) already gives sensible engagement distances for these weapons' much longer `range`.

The health/speed/detection progression deliberately keeps the three tiers roughly parallel across both factions (melee weakest, pistol middle, auto-rifle strongest/most alert) — adjust freely, this is a starting balance, not a final one.

### Verify
- All 6 templates exist under `ServerStorage.EnemyTemplates`, each with exactly one Tool child carrying the correct weapon.
- Spawn one of each manually (or via testing, see Part 5) and confirm it equips the right weapon and doesn't error.

---

## Part 5 — Wire spawn points to types

The 6 existing points under `Workspace.EnemySpawns` are already well-separated (roughly a 90-160 stud ring around the map's origin: `(-90,-40)`, `(90,-40)`, `(0,-120)`, `(-70,45)`, `(70,45)`, `(0,90)` in X/Z) — no repositioning needed. Just tag each with which type it spawns:

| Spawn point | `EnemyType` attribute |
|---|---|
| `EnemySpawnPoint1` | `Security` |
| `EnemySpawnPoint2` | `Police` |
| `EnemySpawnPoint3` | `Armed Police` |
| `EnemySpawnPoint4` | `Thug` |
| `EnemySpawnPoint5` | `Criminal` |
| `EnemySpawnPoint6` | `Armed Criminal` |

(Confirm all 6 are still tagged `EnemySpawnPoint` via CollectionService before assuming — that tag is what `EnemySpawner` actually reads, not the instance name.)

### Verify
- Stand near each zone individually and confirm only the assigned enemy type ever spawns there.
- Confirm zones are far enough apart that one zone's enemies don't wander (via Patrol, `PATROL_RADIUS = 70`) into a neighboring zone and cause cross-contamination during testing — the current spacing should already be enough, but check the two closest pairs (`EnemySpawnPoint4`/`5` are 140 studs apart, `EnemySpawnPoint1`/`2` are 180 studs apart) if anything looks off.

## Verification checklist

- [ ] `EnemySpawner` pairs a spawn point's `EnemyType` to a matching-named template; a point with no `EnemyType` still works the old way.
- [ ] `MAX_CONCURRENT_ENEMIES` raised to 10.
- [ ] Baton built, mechanically identical to Crowbar, reskinned mesh + sounds, real swing animations.
- [ ] Crowbar (player-equipped) also has the real swing animations now, both viewmodel and third-person.
- [ ] All 6 templates exist with correct weapon + stats, including the melee `EngageRangeFraction` fix and non-default `DamageOverride`.
- [ ] All 6 spawn points tagged with their `EnemyType`; each zone only produces its assigned type.
- [ ] `StandardEnemy`/`HeavyEnemy` status (still spawning via a new untagged point, or intentionally retired) matches what you actually want — flagged, not assumed.
