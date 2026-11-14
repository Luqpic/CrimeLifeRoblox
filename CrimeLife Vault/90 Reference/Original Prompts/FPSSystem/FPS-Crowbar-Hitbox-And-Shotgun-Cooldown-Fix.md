# Prompt: Fix Crowbar Hit Reliability, Speed Up Shotgun Fire Rate

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

---

## Part 1 — Crowbar: unreliable hits ("needs a certain angle")

**Root cause:** the crowbar reuses the gun hitscan pipeline with `raysPerShot = 1` — a single ray straight down the crosshair. That works for guns (precision aiming is the point) but is wrong for melee: it means a swing only registers if the crosshair is *exactly* on the target, which is exactly the "needs to be hit at a certain angle" symptom reported. The fix isn't a bigger single ray, it's a fan of several rays across a forgiving cone — but naively doing that creates a real bug: `ShotResolver.applyDamage` runs once per ray that connects, so if a wide swing lands 4 of 6 rays on the same enemy, it would deal 4x damage. This has to be fixed as a pair, not just "increase raysPerShot."

There's already a precedent for this exact problem in the file — `knockbackPerRay = knockbackForce / math.max(raysPerShot, 1)` was added earlier specifically so the shotgun's 8 pellets couldn't stack knockback past the configured value. Apply the same division to damage, but **only for melee weapons** (a shotgun's pellets are *supposed* to stack damage — that's its whole identity, dividing there would nerf it to a fraction of its damage). Gate it on `MELEE_HIT_EFFECT_ATTRIBUTE`, which is already exclusively `true` on the crowbar.

### `ServerScriptService.Blaster.Scripts.ShotResolver`

Right after the existing `local damage = weapon:GetAttribute(Constants.DAMAGE_ATTRIBUTE)` line, add:
```lua
local isMeleeHit = weapon:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE)
-- A melee weapon fans multiple rays across a swing arc for forgiving hit detection (see the
-- crowbar's raysPerShot below). A swing should still land as ONE hit, not one hit per ray that
-- happens to connect: dividing here means a solidly-centered swing (most/all rays connect) still
-- deals the weapon's full configured damage, a glancing swing (only one ray connects) deals
-- proportionally less instead of zero, and it's never possible to multiply damage past the
-- configured value just by widening the swing's ray count. Same idea as knockbackPerRay below.
local damagePerRay = if isMeleeHit then damage / math.max(raysPerShot, 1) else damage
```
Then in `applyDamage`, change:
```lua
local appliedDamage = isHeadshot and (damage * HEADSHOT_DAMAGE_MULTIPLIER) or damage
```
to:
```lua
local appliedDamage = isHeadshot and (damagePerRay * HEADSHOT_DAMAGE_MULTIPLIER) or damagePerRay
```
Every other weapon has `MELEE_HIT_EFFECT_ATTRIBUTE` unset, so `isMeleeHit` is falsy and `damagePerRay == damage` exactly as before — zero behavior change for guns and the shotgun.

### `ReplicatedStorage.Blaster.Utility.drawRayResults`

With more rays now connecting per swing, the on-hit white VFX and hit sound (`impactEffect`) would otherwise fire once per connecting ray on the *same* target — several overlapping VFX pops and stacked hit-sound instances on one swing. Damage is already bounded by the fix above, but this cosmetic stacking should be capped too, once per humanoid per swing, for melee weapons only:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Blaster.Constants)
local castRays = require(script.Parent.castRays)
local laserBeamEffect = require(script.Parent.Parent.Effects.laserBeamEffect)
local impactEffect = require(script.Parent.Parent.Effects.impactEffect)

local function drawRayResults(weapon: Tool?, position: Vector3, rayResults: { castRays.RayResult })
	local isMeleeHit = weapon and weapon:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE)
	local impactedHumanoids = {}

	for _, rayResult in rayResults do
		laserBeamEffect(position, rayResult.position)

		if rayResult.instance then
			local taggedHumanoid = rayResult.taggedHumanoid
			if isMeleeHit and taggedHumanoid then
				if impactedHumanoids[taggedHumanoid] then
					continue
				end
				impactedHumanoids[taggedHumanoid] = true
			end
			impactEffect(weapon, rayResult.position, rayResult.normal, taggedHumanoid ~= nil)
		end
	end
end

return drawRayResults
```
(The laser tracer still draws for every ray — it's cosmetic, not a hit confirmation, and harmless to draw multiple short streaks at melee range. Only the impact VFX/sound is deduped.)

### `StarterPack.Crowbar` — widen the swing into a forgiving cone

Change:
- `raysPerShot`: `1` → `6`
- `spread`: `0` → `20` (degrees — noticeably wider than the shotgun's own `9`, since melee should be the most forgiving weapon in the game and its 6-stud range keeps this from being abusable at distance)
- `rayRadius`: `1` → `1.5` (modest bump on top of the cone, for a bit more per-ray forgiveness)

Leave `damage` (45), `knockbackForce` (15), and `range` (6) unchanged — both now represent "total if the swing connects solidly," exactly as before, thanks to the per-ray division added above.

### Verify
- Swing at an enemy/dummy from multiple angles, including ones that would have missed the old single ray (target slightly off-crosshair-center) — confirm it now registers damage instead of nothing.
- Swing dead-center on a target and confirm total damage this swing deals is still ~45 (not multiplied), and only one hit sound / one white VFX pop plays, not several stacked.
- Fire a gun and the shotgun afterward and confirm their damage/impact-VFX behavior is completely unchanged (this is the part that must not regress — verify explicitly, don't just assume from the `isMeleeHit` guard).

---

## Part 2 — Shotgun: faster follow-up shots

Current total time between shots is `PUMP_CYCLE_SECONDS (0.5s) + 60/rateOfFire (60/55 ≈ 1.09s) ≈ 1.59s`. Both live in `ReplicatedStorage.Blaster.Scripts.BlasterController`; `PUMP_CYCLE_SECONDS` is currently a single module-level constant (only the Mossberg sets `isShotgun`, so it's effectively already shotgun-specific — no need to promote it to a per-weapon attribute for one consumer).

- `BlasterController`: change `local PUMP_CYCLE_SECONDS = 0.5` to `local PUMP_CYCLE_SECONDS = 0.25`.
- `StarterPack."Mossberg 590"`: change `rateOfFire` from `55` to `90`.

New total between shots: `0.25 + 60/90 ≈ 0.92s` — about 42% faster than before, noticeably spammable while still reading as a pump-action (not literally full-auto). If this still isn't fast enough, `rateOfFire` and `PUMP_CYCLE_SECONDS` are the two knobs — push `rateOfFire` higher and/or `PUMP_CYCLE_SECONDS` lower further.

### Verify
- Click-fire the shotgun repeatedly and confirm the follow-up shot is noticeably faster than before.
- Confirm the shell-by-shell reload and its interrupt-by-firing behavior are unaffected (neither constant changed here touches `reload()`).
- Confirm no other weapon's fire timing changed (`PUMP_CYCLE_SECONDS` is only ever read inside the `if self.isShotgun then` branch).

## Verification checklist

- [ ] Crowbar reliably registers a hit across a reasonable swing arc, not just dead-center aim.
- [ ] Crowbar total damage per swing is still bounded at ~45 even when multiple rays connect.
- [ ] Crowbar hit VFX/sound plays once per swing, not once per connecting ray.
- [ ] Guns and the shotgun's own damage/impact behavior unchanged.
- [ ] Shotgun fires noticeably faster back-to-back; shell-by-shell reload behavior unaffected.
