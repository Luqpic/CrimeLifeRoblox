# Prompt: Spawner Directory Rework, Deeper Enemy Nerf + Recoil, Lock Inventory on Death

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

**Interpretation calls made before writing this, flagged so they're easy to correct:**
- "The damage is 80% reduced" is read as the new *total* target measured from each weapon's stock `damage` attribute (i.e. enemies now deal 20% of what a player deals with the same gun), **replacing** last round's 60%-of-stock figure on Armed Police/Armed Criminal rather than stacking with it. Applied to all 6 templates, since this request says "the enemies" generally rather than singling out the rifles like last time.
- "Shoot accuracy" and "recoil" are only applied to the 4 ranged templates (Police, Armed Police, Criminal, Armed Criminal) — Security and Thug don't shoot, and their existing swing-fan hit detection isn't an aiming mechanic recoil or an accuracy cone would apply to.

---

## Part 1 — Spawner directory rework: name + StringValue instead of Attribute

Replaces the `EnemyType` Attribute mechanism (added two passes ago) with a StringValue child, and renames each spawn point to match its enemy type — both purely for Explorer-level discoverability/scalability, no behavior change in what actually spawns where.

### Rename each spawn point

| Current name | New name | `EnemyType` StringValue's `.Value` |
|---|---|---|
| `EnemySpawnPoint1` | `SecuritySpawner` | `Security` |
| `EnemySpawnPoint2` | `PoliceSpawner` | `Police` |
| `EnemySpawnPoint3` | `Armed PoliceSpawner` | `Armed Police` |
| `EnemySpawnPoint4` | `ThugSpawner` | `Thug` |
| `EnemySpawnPoint5` | `CriminalSpawner` | `Criminal` |
| `EnemySpawnPoint6` | `Armed CriminalSpawner` | `Armed Criminal` |

(`Armed PoliceSpawner`/`Armed CriminalSpawner` keep the space that's already part of the enemy type's own name, with "Spawner" appended directly — following the literal pattern from the example ("Police" → "PoliceSpawner") rather than inventing a different convention for the two-word names. If a no-space `ArmedPoliceSpawner` reads better to you, that's a one-word rename away — say so.)

**Do not change** the CollectionService tag on these Parts — it stays `EnemySpawnPoint` (that's what `EnemySpawner.lua`'s `CollectionService:GetTagged(Constants.SPAWN_POINT_TAG)` actually looks up; it's independent of the instance's Name).

### On each spawn point

1. Remove the existing `EnemyType` **Attribute** (the old mechanism — don't leave it sitting alongside the new one as a stale, confusing second source of truth).
2. Add a `StringValue` child named `EnemyType`, with `.Value` set per the table above (e.g. `PoliceSpawner.EnemyType.Value = "Police"`, referencing the template of the same name under `ServerStorage.EnemyTemplates`).

### `ServerScriptService.Enemy.Scripts.EnemySpawner`

In `trySpawn()`, change:
```lua
	local enemyType = spawnPoint:GetAttribute("EnemyType")
```
to:
```lua
	local enemyTypeValue = spawnPoint:FindFirstChild("EnemyType")
	local enemyType = if enemyTypeValue and enemyTypeValue:IsA("StringValue") then enemyTypeValue.Value else nil
```
Everything after this line (the eligible-templates filtering, the warn-and-return-false on no match) is unchanged — only how `enemyType` is read changes.

### Verify
- Each of the 6 spawners still only produces its own assigned enemy type after the rename.
- No script anywhere still reads the old `EnemyType` Attribute (grep for it) — the StringValue is now the single source of truth.

---

## Part 2 — Deeper nerf: 80%-of-stock damage (all 6), lower accuracy + recoil (ranged 4)

### Damage — all 6 templates, verify current stock damage before computing

For each template, read the **current** `damage` attribute on the weapon it actually carries (don't assume these are still accurate — verify live), then set `DamageOverride` to 20% of that (rounded):

| Template | Weapon | Expected stock `damage` | New `DamageOverride` (20%) |
|---|---|---|---|
| `Security` | Baton | 45 | 9 |
| `Police` | Mateba 2006M | 60 | 12 |
| `Armed Police` | Scar L | 16 | 3 |
| `Thug` | Crowbar | 45 | 9 |
| `Criminal` | M1911 | 38 | 8 |
| `Armed Criminal` | AKM | 18 | 4 |

This **replaces** the `6`/`7` set on `Armed Police`/`Armed Criminal` in the previous pass — those numbers are superseded, not compounded.

### Accuracy — the 4 ranged templates

Building on the `AimMaxErrorDegrees`-as-override mechanism added last pass (`ReplicatedStorage.Enemy.AimConfig` / `ReplicatedStorage.Enemy.templateConfig` — no further code change needed here, just attribute values):

| Attribute | Shared default | `Police` / `Criminal` (new) | `Armed Police` / `Armed Criminal` (was → now) |
|---|---|---|---|
| `AimBaseErrorDegrees` | 2.0 | 4.0 | 6.0 → 8.0 |
| `AimDistanceErrorDegrees` | 4.5 | 6.5 | 9.0 → 11.0 |
| `AimMovementErrorDegrees` | 5.5 | 6.5 | 8.0 → 10.0 |
| `AimMaxErrorDegrees` | 12.0 | 16.0 | 22.0 → 28.0 |

`Police`/`Criminal` didn't get an override in the previous pass (only the rifles did) — this adds a moderate one now, smaller than the rifle enemies' since pistols weren't the original complaint but "the enemies" here reads broader than last time.

### Recoil — new mechanic, doesn't exist for enemies today

The player's recoil (`BlasterController:recoil()` / `CameraRecoiler`) is a **camera** effect — it works because a human player's own view persists and drifts, and their next shot's origin comes from wherever their camera ends up. An enemy has no camera and recomputes its aim origin fresh from the target's live position every shot (`EnemyAI:_fireOnce()`), so there's nothing today for recoil to act on — this needs its own small mechanism, built from the same `recoilMin`/`recoilMax` weapon attributes so it stays weapon-consistent rather than inventing separate enemy-only tuning.

**Design:** each enemy accumulates a `recoilOffset` (Vector2, radians) that grows by a random kick (drawn from the weapon's own `recoilMin`/`recoilMax`, same math as the player's `recoil()`) on every shot fired, decays continuously back toward zero over time, and gets folded into the aim origin right before each shot resolves. A slow semi-auto pistol's recoil decays faster than it can build (barely visible, since shots are seconds apart), while a fast automatic rifle's recoil visibly climbs over a sustained burst — this falls out naturally from the fixed decay rate against each weapon's own firing cadence, no per-weapon-type special-casing needed.

**`ReplicatedStorage.Enemy.Constants`** — add:
```lua
-- === Recoil ===
-- Radians/second the accumulated recoil offset decays by. Tuned against automatic weapons: a shot
-- lands roughly every 60/rateOfFire seconds, and this is deliberately set lower than the typical
-- kick-per-second an automatic weapon adds, so recoil visibly climbs over a sustained burst. A
-- slow semi-auto weapon's kick-per-second is naturally below this decay rate, so its recoil stays
-- negligible without needing separate tuning.
RECOIL_DECAY_RATE = 1.2,
-- Sanity ceiling so recoil cannot run away indefinitely during an unusually long burst.
RECOIL_MAX_OFFSET_DEGREES = 45,
```

**`ServerScriptService.Enemy.Scripts.EnemyAI`** — add to the `self` table in `EnemyAI.new()`:
```lua
recoilOffset = Vector2.new(0, 0),
lastRecoilTime = nil :: number?,
```
Add two new methods (near `_applyAimError`, same section):
```lua
-- Decays the accumulated recoil toward zero based on real elapsed time since it was last touched.
-- Called lazily right before each shot rather than on a separate timer -- a long gap since the last
-- shot (e.g. the enemy stopped firing entirely) naturally decays it back to ~0 in one lump, which is
-- correct and needs no separate "stopped firing" handling.
function EnemyAI:_decayRecoil(now: number)
	local elapsed = now - (self.lastRecoilTime or now)
	self.lastRecoilTime = now

	local magnitude = self.recoilOffset.Magnitude
	if magnitude <= 1e-4 then
		self.recoilOffset = Vector2.new(0, 0)
		return
	end
	local decay = math.min(Constants.RECOIL_DECAY_RATE * elapsed, magnitude)
	self.recoilOffset -= self.recoilOffset.Unit * decay
end

-- Adds one shot's worth of kick, same random-in-range math as BlasterController:recoil() for the
-- player, so an enemy's recoil feel matches the player's for the same weapon.
function EnemyAI:_accumulateRecoil()
	local recoilMin = self.weapon:GetAttribute(BlasterConstants.RECOIL_MIN_ATTRIBUTE)
	local recoilMax = self.weapon:GetAttribute(BlasterConstants.RECOIL_MAX_ATTRIBUTE)
	if not recoilMin or not recoilMax then
		return
	end

	local xDif = recoilMax.X - recoilMin.X
	local yDif = recoilMax.Y - recoilMin.Y
	local kick = Vector2.new(
		math.rad(-(recoilMin.X + math.random() * xDif)),
		math.rad(recoilMin.Y + math.random() * yDif)
	)

	self.recoilOffset += kick
	local maxRadians = math.rad(Constants.RECOIL_MAX_OFFSET_DEGREES)
	if self.recoilOffset.Magnitude > maxRadians then
		self.recoilOffset = self.recoilOffset.Unit * maxRadians
	end
end
```
In `_fireOnce()`, right after computing `origin` via `_applyAimError` and before the `ShotResolver.resolveShot` call, fold the recoil in and then accumulate this shot's kick for the *next* one:
```lua
	local seed = Workspace:GetServerTimeNow()
	local origin = self:_applyAimError(CFrame.lookAt(muzzlePosition, aimPosition), targetHumanoid, seed)

	local now = os.clock()
	self:_decayRecoil(now)
	origin = origin * CFrame.Angles(self.recoilOffset.Y, self.recoilOffset.X, 0)

	ShotResolver.resolveShot({
		shooter = self.character,
		weapon = weapon,
		origin = origin,
		seed = seed,
	})

	self:_accumulateRecoil()
```
(Recoil is applied *before* accumulating this shot's own kick, and accumulated *after* — so a given shot is affected by every *previous* shot's recoil, not its own, matching how a real weapon's recoil affects the follow-up shot rather than the one that caused it.)

This lives in the shared `EnemyAI` module, so it automatically applies to every ranged enemy — no per-template code, only the existing `recoilMin`/`recoilMax` each weapon already has.

### Verify
- All 6 templates' `damage` output matches the new `DamageOverride` table.
- `Police`/`Criminal` now visibly miss sometimes (previously untouched); `Armed Police`/`Armed Criminal` miss noticeably more than after the previous pass.
- Stand still and take sustained fire from an Armed Police/Armed Criminal enemy: confirm their shots visibly climb/spread out the longer they hold the trigger, then tighten back up after a pause — not a fixed, unchanging spread from shot to shot.
- Confirm a Police/Criminal (semi-auto) enemy's recoil is barely noticeable shot-to-shot (their slower cadence should mean it decays before compounding much).

---

## Part 3 — Lock the inventory while dead

**Root cause:** the death-camera fix from the previous pass (`Humanoid.Died` → `BlasterController:unequip()`) only handles the weapon that was equipped *at the moment of death*. It does nothing to stop the player from then clicking a *different* weapon in the Backpack/hotbar while still dead — equipping that new Tool fires its own `Equipped` event, which re-enters `BlasterController:equip()` and force-sets `player.CameraMode = LockFirstPerson` again, right back into first person on a dead character. Tying a fix to `BlasterController` again would only cover the "was holding a weapon at death" case, and does nothing if the player died empty-handed and then opens the backpack — this needs a character-level hook, independent of weapon state entirely.

**Fix — new script**, `StarterPlayer.StarterPlayerScripts.InventoryDeathLock` (LocalScript):
```lua
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local function onCharacterAdded(character: Model)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end
```
This disables Roblox's native Backpack/hotbar UI entirely on death (so there's nothing left to click), and re-enables it the moment a fresh character spawns. It's independent of and complementary to the `BlasterController` death fix from last pass — that one resets the camera for whatever was equipped at the moment of death, this one prevents equipping anything new afterward.

### Verify
- Die while holding a weapon: confirm the backpack/hotbar disappears and can't be reopened while dead.
- Die with no weapon equipped (empty-handed): confirm the backpack still disappears (this is the case the previous pass's fix alone did not cover).
- Respawn: confirm the backpack is usable again immediately.

## Verification checklist

- [ ] All 6 spawners renamed; each has an `EnemyType` StringValue child (old Attribute removed) and still only spawns its own type.
- [ ] All 6 templates deal 20% of their weapon's stock damage.
- [ ] All 4 ranged templates visibly miss more than before; `Armed Police`/`Armed Criminal` more than `Police`/`Criminal`.
- [ ] Ranged enemies show visible recoil climb during sustained automatic fire, settling after pauses; semi-auto enemies' recoil stays subtle.
- [ ] Backpack/hotbar is unusable for the entire duration a player is dead, regardless of whether they were holding a weapon at the moment of death, and returns immediately on respawn.
