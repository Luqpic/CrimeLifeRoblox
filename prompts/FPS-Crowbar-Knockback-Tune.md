# Prompt: Crowbar Knockback Is Undertuned, Not Missing

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

## Root cause, confirmed before writing this — read this first

This is **not a missing feature**. `ServerScriptService.Blaster.Scripts.ShotResolver.resolveShot` already applies knockback generically to any weapon whose `knockbackForce` attribute (`Constants.KNOCKBACK_FORCE_ATTRIBUTE`) is nonzero — the same code path used for every weapon, guns and melee alike:
```lua
local knockbackForce = weapon:GetAttribute(Constants.KNOCKBACK_FORCE_ATTRIBUTE) or 0
local knockbackPerRay = knockbackForce / math.max(raysPerShot, 1)
...
if knockbackPerRay > 0 then
	local rootPart = taggedHumanoid.RootPart
	if rootPart then
		local offset = rayResult.position - origin.Position
		local direction = if offset.Magnitude > 1e-3 then offset.Unit else origin.LookVector
		rootPart.AssemblyLinearVelocity += direction * knockbackPerRay + Vector3.new(0, knockbackPerRay * 0.25, 0)
	end
end
```
Already live-inspected: `ServerStorage.Weapons.Crowbar.knockbackForce = 15`, `raysPerShot = 6` — that is `2.5` studs/s per connecting ray, up to `15` studs/s total on a fully-centred swing where all 6 rays land. For comparison, `ServerStorage.Weapons."Mossberg 590".knockbackForce = 55` across `raysPerShot = 8` (~6.9/ray, up to 55 total), and a default `Humanoid.WalkSpeed` is ~16 studs/s. A push smaller than or comparable to normal walk speed barely reads as a hit, especially against `EnemyAI`, which moves enemies via `Humanoid:MoveTo` (the engine's own gentle walk-to-target controller) rather than a per-frame velocity override — confirmed this is not fighting or cancelling the impulse, it just isn't strong enough to look like anything.

**The fix is a single attribute value, not new code.** Raising `knockbackForce` reuses the exact same, already-correct mechanism the shotgun uses.

---

## Part 1 — Raise the crowbar's knockback

**`ServerStorage.Weapons.Crowbar`** — change the `knockbackForce` attribute from `15` to `90`.

This is a placeholder, not final balance — tune freely. At `90` across `raysPerShot = 6`, a solidly-centred swing pushes at up to `90` studs/s (a clear, noticeable shove — well above walk speed, in the same spirit as a heavy blunt weapon), while even a single connecting ray (`15` studs/s) now matches what the *entire* swing used to do at the old value, so a glancing hit still reads as something happened rather than nothing.

### Verify
- Enter Play mode, hit an AI enemy with the crowbar: the enemy is visibly shoved backward/off-balance on hit, not just damaged silently as before.
- Hit an enemy that's actively pathing toward you (`Humanoid:MoveTo` engaged): confirm the knockback still visibly displaces it before it resumes walking back toward its target — this is the scenario most likely to hide a weak knockback.
- Hit another player in PvP: same visible shove.
- Fire every gun afterward and confirm their knockback (if any) is unchanged — only `Crowbar.knockbackForce` was touched.
- A glancing swing (only 1-2 of the 6 rays connect) still produces a noticeably smaller push than a solidly-centred one — the per-ray division should still scale with how much of the swing actually landed, same as before, just scaled up.

## Verification checklist

- [ ] `Crowbar.knockbackForce` raised from `15` to `90`; no other weapon's `knockbackForce` touched.
- [ ] Crowbar hits on AI enemies produce a clearly visible shove, confirmed in Play mode, not just inferred from the number.
- [ ] Crowbar hits on players (PvP) produce the same visible shove.
- [ ] No changes to `ShotResolver` or any other script — the existing generic mechanism is reused as-is.
