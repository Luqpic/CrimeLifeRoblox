# Prompt: Rifle Enemy Accuracy/Damage Rebalance, Death Camera Fix, Remove Old Templates

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

---

## Part 1 — Remove the old generic enemy templates

Delete `ServerStorage.EnemyTemplates.StandardEnemy` and `ServerStorage.EnemyTemplates.HeavyEnemy`. `EnemySpawner.getTemplates()` discovers templates generically by scanning the folder's children (no hardcoded name references anywhere), so this is safe on its own — verify nothing else in the codebase references either name before deleting, but none was found when this system was built.

This also resolves the flagged tension from the previous pass (repurposing all 6 spawn points left these two templates with no spawn point): since they're being removed outright, no extra untagged spawn point is needed after all.

### Verify
- Only the 6 templates (`Security`, `Police`, `Armed Police`, `Thug`, `Criminal`, `Armed Criminal`) remain under `ServerStorage.EnemyTemplates`.

---

## Part 2 — Rifle enemies (Armed Police, Armed Criminal): real misses, 60% less damage

Scoped to these two specifically — "the enemies with the rifles" — not `Police`/`Criminal` (pistols) or `Security`/`Thug` (melee), which aren't reported as a problem.

### Why this needs a small code change, not just attribute tuning

`ReplicatedStorage.Enemy.AimConfig.getErrorDegrees()` sums a base + distance + movement + acquisition-lag term, then does `return math.min(degrees, AimConfig.MAX_ERROR_DEGREES)` — `MAX_ERROR_DEGREES` is a **flat 12°, and it is not one of the fields `templateConfig.lua` currently allows a template to override**. The per-template `AimBaseErrorDegrees`/`AimDistanceErrorDegrees`/`AimMovementErrorDegrees` attributes all feed into the sum *before* this clamp, so no matter how high they're set, the effective cone can never exceed 12° for any enemy today. Per this file's own documented accuracy table, a 12° cone still lands roughly 62–83% of shots at 20 studs — that ceiling itself is why full-auto rifle fire reads as unmissable. Making `maxErrorDegrees` a fourth overridable field is the actual fix; everything else is just picking numbers for these two templates.

**`ReplicatedStorage.Enemy.AimConfig`** — change the last line of `getErrorDegrees` from:
```lua
	return math.min(degrees, AimConfig.MAX_ERROR_DEGREES)
```
to read an override the same way the other three terms already do:
```lua
	local maxError = (overrides and overrides.maxErrorDegrees) or AimConfig.MAX_ERROR_DEGREES
	return math.min(degrees, maxError)
```

**`ReplicatedStorage.Enemy.templateConfig`** — add `maxErrorDegrees: number` to the `AimOverrides` type, and add to the `aim = { ... }` table in `templateConfig.read`:
```lua
maxErrorDegrees = numberAttribute(template, "AimMaxErrorDegrees", AimConfig.MAX_ERROR_DEGREES),
```
Every template that doesn't set `AimMaxErrorDegrees` keeps the shared 12° ceiling exactly as before — zero behavior change for `Police`, `Criminal`, `Security`, `Thug`, or anything else.

### Set these attributes on `Armed Police` and `Armed Criminal`

| Attribute | Current shared default | New value (these 2 templates only) |
|---|---|---|
| `AimBaseErrorDegrees` | 2.0 | 6.0 |
| `AimDistanceErrorDegrees` | 4.5 | 9.0 |
| `AimMovementErrorDegrees` | 5.5 | 8.0 |
| `AimMaxErrorDegrees` (new) | 12.0 | 22.0 |

Worked example at their typical holding distance (~55 studs, per `PreferredRangeFraction` against their `range`-derived engage distance): a stationary target now draws roughly `6.0 + 9.0×0.55 ≈ 10.95°` (was `~9.98°`, both under the old 12° cap so barely different) — the real change is against a *moving* target, where the old formula also capped at 12° (`2.0+2.475+5.5=9.975`, still under 12, so movement barely helped before), while the new one reaches `10.95+8.0 ≈ 18.95°`, close to the new 22° ceiling — roughly 18–25% per-shot hit rate at that range per the documented table, down from ~34–56%. Stationary targets close up will still get hit fairly often (this is intentional — an AI that can never hit a stationary point-blank target isn't a threat at all); the miss rate shows up specifically against movement and at range, which is exactly where "hit and miss" should live. Playtest and adjust these four numbers further if it still feels too accurate or now too weak — they're a first pass, not final balance.

### Damage: cut by 60%

Read each template's **current** `DamageOverride` attribute first rather than assuming a stale number, then set it to 40% of that value (rounded to a whole number):
- `Armed Police.DamageOverride`: expected to currently be `16` (Scar L's stock damage) → set to `6`.
- `Armed Criminal.DamageOverride`: expected to currently be `18` (AKM's stock damage) → set to `7`.

If either template's current value differs from the expected 16/18 above, use the actual current value × 0.4 instead, and note the discrepancy back to the user rather than silently using the expected number.

### Verify
- Get shot at by an Armed Police/Armed Criminal enemy from a distance while moving: confirm visible misses (tracer/impact not landing on you), not a constant hit stream.
- Confirm each hit that does land deals roughly 40% of what it did before (6 and 7 damage respectively, not 16/18).
- Confirm `Police`, `Criminal`, `Security`, `Thug` are completely unaffected (no `AimMaxErrorDegrees` set on them, so they keep the 12° ceiling; their `DamageOverride` values untouched).

---

## Part 3 — Stay stuck in first person after death

**Root cause:** `BlasterController:equip()`/`unequip()` — which is what resets `player.CameraMode` back to `Classic` and clears the ADS zoom via `removeZoom()` — is only ever triggered by the Tool's own `Equipped`/`Unequipped` events. Nothing in the system currently listens for the *character's* death. This game deliberately sets `BreakJointsOnDeath = false` (via `RagdollController.prepare()`) so its custom ragdoll can take over instead of the engine tearing the rig apart — which means the usual assumption that dying automatically drops/unequips a Tool isn't something to rely on here. A player who dies while zoomed into first person has no Tool-side event left to trigger the camera reset, so they stay locked into a first-person view of their own ragdoll.

**Fix:** in `BlasterController:equip()`, alongside the existing `zoomIn`/`zoomOut` connections, add a listener on the character's `Humanoid.Died` that runs the exact same cleanup a normal unequip does:
```lua
	-- Keep track of the humanoid in the character currently equipping the blaster.
	self.humanoid = self.blaster.Parent:FindFirstChildOfClass("Humanoid")

	-- BreakJointsOnDeath is off (RagdollController owns death presentation instead), so nothing
	-- else guarantees Tool.Unequipped fires when the character dies. Without this, a player who
	-- dies while zoomed into first person stays locked into a first-person view of their own
	-- ragdoll with no Tool-side event left to reset the camera.
	if self.humanoid then
		self.connections.died = self.humanoid.Died:Connect(function()
			self:unequip()
		end)
	end
```
And in `unequip()`, clean it up alongside the existing `zoomIn`/`zoomOut` disconnects:
```lua
	if self.connections.died then
		self.connections.died:Disconnect()
		self.connections.died = nil
	end
```
`unequip()` already guards on `if not self.equipped then return end`, so this is safe to trigger from `Died` even if the native `Tool.Unequipped` also ends up firing around the same time — whichever runs first does the cleanup, the second is a no-op. Reusing `unequip()` wholesale (not a partial camera-only version) is deliberate — it's the exact same reset a normal unequip already does correctly (viewmodel, GUI, touch input, animations, and the camera/zoom), so this doesn't introduce a second, parallel cleanup path to keep in sync with the first.

This lives in the shared `BlasterController`, so it applies to every weapon automatically — no per-weapon changes needed.

### Verify
- Die while a weapon is equipped and in first person: confirm the camera pulls back to third person immediately, matching what unequipping that weapon looks like.
- Die while a weapon is equipped and zoomed in (ADS): confirm the FOV/camera offset resets too, not just the first/third-person toggle.
- Respawn and confirm the new life's weapons work normally (equip/fire/zoom), unaffected by the previous life's death cleanup.

## Verification checklist

- [ ] `StandardEnemy`/`HeavyEnemy` removed; only the 6 new templates remain.
- [ ] `AimMaxErrorDegrees` is a working per-template override; `Armed Police`/`Armed Criminal` visibly miss more, especially against movement and at range.
- [ ] `Armed Police`/`Armed Criminal` damage per hit is ~40% of its previous value.
- [ ] Every other enemy type's accuracy and damage unchanged.
- [ ] Dying while zoomed/first-person resets the camera exactly like unequipping does, for every weapon.
