# Prompt: Sniper Fire-Rate Fix, Weapon Sounds, Crowbar VFX Rework

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained. Each part is independent except Part 4, where the emitter-removal step and the defensive-guard step must land together (see the warning in Part 4).

---

## Part 1 — Sniper "won't fire after aiming" (root cause found, not a code bug)

**Investigation already done — don't re-derive this, verify and apply the fix.** `BlasterController:startShooting()`'s `Semi` branch sets `self.shooting = true`, fires once, and only clears the flag via `task.delay(60 / rateOfFire, function() self.shooting = false ... end)`. The Snipex Alligator's `rateOfFire = 35` makes that lock last **~1.71 seconds** — by far the longest of any weapon (the next-slowest, Mateba 2006M, locks for only ~0.27s; every auto/burst weapon's per-shot gap is well under 0.1s). Every click that lands inside that 1.71s window is silently dropped by the `if self.shooting then return end` guard at the top of `startShooting()` — this is working exactly as designed, but there is **zero player-facing feedback** (no sound, no HUD cue) when a click is denied this way, so a player aiming through the scope and clicking for a follow-up shot experiences total, unexplained unresponsiveness for nearly two seconds. That fully explains "sometimes" (depends on the player's own click timing relative to the fixed cooldown), "after aiming" (exactly when a follow-up shot is wanted), and "completely useless" (in a firefight, ~1.7s of silent nonresponse reads as broken).

Ruled out with evidence, not assumption, before landing on this: the muzzle/`FlashEmitter`/`CircleEmitter` setup (matches the AK47/Deagle world-model pattern exactly — only `FlashEmitter` on world models is the established convention, not a defect), the first/third-person muzzle-swap logic in `ViewModelController:update()` (self-consistent), and `CameraAuthority`/`PropertyAuthority` (no stuck-state possible there — `_resolve()` always re-applies correctly on `Clear`).

**Fix:** in `StarterPack."Snipex Alligator"`, change the `rateOfFire` attribute from `35` to `50` (cuts the lock to ~1.2s — still unmistakably the slowest, heaviest-feeling weapon in the game by a wide margin, but meaningfully less punishing).

**Not fixed here, flagged for awareness:** the underlying "no feedback on a denied click" issue still exists and will still be somewhat noticeable at 50 RPM, just less severe. A proper fix (a soft "dry click" sound or a HUD cooldown indicator on a denied `startShooting()` call) needs a new sound asset that hasn't been provided — treat this as a known follow-up, not something to build speculatively now.

**Verify:** equip the sniper, fire, and confirm the weapon becomes responsive again in about 1.2s rather than 1.7s. Confirm no other weapon's fire timing changed (this edit only touches the Snipex Alligator's own attribute).

---

## Part 2 — Kriss Vector / MP9 orientation: investigated, no bug found — verify before touching

A prior fix pass corrected AKM/Scar L/Kriss Vector's world-model orientation (a 180°-Y flip bug). This report says Kriss Vector and MP9 are facing backwards again. Before assuming the same fix applies, the following was checked and **all of it already matches the known-correct `AK47` template exactly** (compared via the raw `CFrame.Rotation` matrix, not just the rounded `Rotation` display, so this isn't a rounding coincidence):

- `StarterPack."Kriss Vector".Blaster.Body.Rotation` / `StarterPack.MP9.Blaster.Body.Rotation` — both `(90, 0, 180)`, matching `StarterPack.AK47.Blaster.Body`.
- Both weapons' `Magazine.Rotation` — both `(90, 0, 180)`, matching AK47's `Magazine`.
- Both weapons' `Tool.Grip` (Position and Rotation) — byte-identical to AK47's `Grip`.
- Both weapons' viewmodel `Body.Rotation` (`ReplicatedStorage.Blaster.ViewModels.*`) — both `(0, -90, 0)`, matching AK47's viewmodel `Body`.
- Both weapons' viewmodel `BodyJoint` Motor6D `C0.Rotation` (the value that actually governs the rendered first-person pose, independent of `Body`'s own stored CFrame) — both match AK47's `C0.Rotation` exactly; `C1` also matches (as expected, `C1` is shared rig geometry, not per-gun).

**Do not blindly re-apply the 180°-Y `PivotTo` fix from the earlier orientation-fix prompt** — every one of these guns is currently correct, and flipping already-correct geometry would break them.

**Before doing anything else here:** enter Play mode, equip Kriss Vector and MP9, and take a fresh `screen_capture` from both first-person and third-person (someone else's view, or a spectator angle) for each. If they render correctly now, this was very likely a stale report from before the earlier fix/careful-construction took effect, or from testing an older running instance of the game — no changes needed, report back that it's confirmed fixed. If either is still visibly backwards despite every check above passing, that means the bug is somewhere not yet identified (possibly a rendering/streaming issue rather than a geometry issue) — stop and report exactly what's still wrong with a screenshot, rather than guessing at another geometry fix.

---

## Part 3 — Mossberg 590 sounds

Current `StarterPack."Mossberg 590".Sounds` structure: `Shoot` (folder containing `Shoot1`/`Shoot2`/`Shoot3` — `ShotReplication.lua` picks one at random per shot), `Equip`, `Charger` (plays on the pump/reload cycle), `MagIn`, `MagOut`.

Set:
- `Sounds.Equip.SoundId` = `rbxassetid://135021341713034`
- `Sounds.Shoot.Shoot1.SoundId`, `Shoot2.SoundId`, `Shoot3.SoundId` = `rbxassetid://132711300701696` (only one shot sound was provided; apply it to all three variation slots rather than leaving two of them as the inherited AK47 gunshot)
- `Sounds.Charger.SoundId` = `rbxassetid://113837896417526` (this is the pump-action sound)
- `Sounds.MagIn.SoundId` and `Sounds.MagOut.SoundId` = `rbxassetid://139827026287805` (only one reload sound was provided for two slots that both fire during the same reload animation; applying it to both is the reasonable default — flag this choice back to the user rather than silently picking one arbitrarily)

**Verify:** equip the Mossberg, fire (hear the new shot sound), reload (hear the pump/charger sound and the reload sound), equip it fresh (hear the new equip sound).

---

## Part 4 — Crowbar: sounds + on-hit VFX rework

### The bug this must not reintroduce

`ViewModelController:playShootAnimation()` currently does, unconditionally, on every attack:
```lua
self.muzzle.FlashEmitter:Emit(1)
if isFirstPerson then
	self.muzzle.CircleEmitter:Emit(1)
end
```
`ShotReplication.lua` (what plays for *other* clients watching the swing) does the same unconditionally: `muzzle.FlashEmitter:Emit(1)`. If `FlashEmitter`/`CircleEmitter` are simply deleted from the crowbar as asked, both of these will throw the moment anyone swings it — and per the root-cause chain established in Part 1, an error thrown inside `shoot()`'s call chain means `self.shooting` never gets reset, permanently soft-locking that weapon for the shooter (and erroring for every observer). **Fix `ViewModelController` and `ShotReplication` to check for the emitters before using them, then remove the emitters from the crowbar** — do both together, not the removal alone.

**`ReplicatedStorage.Blaster.Scripts.ViewModelController`** — change `playShootAnimation()` to:
```lua
function ViewModelController:playShootAnimation()
	local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.thirdPerson
	self.animations.Shoot:Play(0)

	local flashEmitter = self.muzzle:FindFirstChild("FlashEmitter")
	if flashEmitter then
		flashEmitter:Emit(1)
	end

	if isFirstPerson then
		local circleEmitter = self.muzzle:FindFirstChild("CircleEmitter")
		if circleEmitter then
			circleEmitter:Emit(1)
		end
	end
end
```

**`ReplicatedStorage.Blaster.Scripts.ShotReplication`** — change the unconditional `muzzle.FlashEmitter:Emit(1)` (inside the `if muzzle then` block) to check existence first, same pattern as above.

### Sounds
`StarterPack.Crowbar.Sounds.Equip.SoundId` = `rbxassetid://127835667593323`.

There is no "Hit" sound slot yet — add a new `Sound` instance named `Hit` under `StarterPack.Crowbar.Sounds` with `SoundId = rbxassetid://111155812664366`. This is played programmatically on a confirmed hit (see below), not via the animation-marker mechanism the other sounds use, since it must only play when the swing actually connects.

No swing/whoosh sound was provided. `Sounds.Shoot.Shoot1/2/3` currently still hold the inherited Deagle gunshot sound, which is wrong for a melee swing and would play on every attempt whether it hits or not. Clear their `SoundId` to `""` (silent) rather than leave a gunshot bang on a crowbar swing — flag to the user that a proper whoosh sound would be a good follow-up addition.

### Remove the muzzle-flash particles
Delete `CircleEmitter` and `FlashEmitter` from both `StarterPack.Crowbar.Blaster.Body.MuzzleAttachment` and `ReplicatedStorage.Blaster.ViewModels.Crowbar.Blaster.Body.MuzzleAttachment`. Leave the `MuzzleAttachment` itself in place (other code locates it by name; removing the attachment entirely is a bigger, unnecessary risk than emptying it).

### New on-hit VFX ("mini white vfx")

The existing hit-effect pipeline (`ShotResolver` → `drawRayResults` → `impactEffect`) is shared by every weapon and has no concept of a per-weapon custom effect — extend it minimally rather than bypassing it, so the crowbar's hit effect keeps working identically for the shooter's own local prediction *and* for other clients watching via `ReplicateShot` (the same reason the existing "reuse the same effect" design works at all).

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
MELEE_HIT_EFFECT_ATTRIBUTE = "meleeHitEffect",
```

**New template `ReplicatedStorage.Blaster.Objects.MeleeImpact`** — clone the structure of `ReplicatedStorage.Blaster.Objects.CharacterImpact` (an invisible anchored `Part`, `Transparency = 1`, holding `ParticleEmitter`s) but built for a small, punchy white flash rather than the guns' spark/circle look: a single `ParticleEmitter` named `HitEmitter`, white `Color`, short `Lifetime` (roughly 0.15–0.3s), small `Size`, no drift/gravity (`Speed` near 0 or a small burst outward) — a quick white pop, not a lingering effect. Exact numeric tuning is a judgment call; keep it visually distinct from the spark/circle look guns use.

**`ReplicatedStorage.Blaster.Effects.impactEffect`** — add a `weapon: Tool` parameter and branch on the new attribute, ahead of the existing `isCharacter` check:
```lua
local meleeImpactTemplate = ReplicatedStorage.Blaster.Objects.MeleeImpact

local function impactEffect(weapon: Tool, position: Vector3, normal: Vector3, isCharacter: boolean)
	local impact

	if isCharacter and weapon:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE) then
		impact = meleeImpactTemplate:Clone()
		impact.CFrame = CFrame.lookAlong(position, normal)
		impact.Parent = Workspace
		impact.HitEmitter:Emit(15)

		local sounds = weapon:FindFirstChild("Sounds")
		local hitSound = sounds and sounds:FindFirstChild("Hit")
		if hitSound then
			local sound = hitSound:Clone()
			sound.Parent = impact
			sound:Play()
			Debris:AddItem(sound, sound.TimeLength + 0.1)
		end
	elseif isCharacter then
		impact = characterImpactTemplate:Clone()
		impact.CFrame = CFrame.lookAlong(position, normal)
		impact.Parent = Workspace
		impact.SparkEmitter:Emit(10)
		impact.CircleEmitter:Emit(2)
	else
		impact = environmentImpactTemplate:Clone()
		impact.CFrame = CFrame.lookAlong(position, normal)
		impact.Parent = Workspace
		impact.SparkEmitter:Emit(10)
		impact.CircleEmitter:Emit(2)
	end

	task.delay(0.5, function()
		impact:Destroy()
	end)
end
```
(Add `local Debris = game:GetService("Debris")` and `local Constants = require(ReplicatedStorage.Blaster.Constants)` to the top of the file alongside the existing requires.) This only changes behavior for a weapon with `meleeHitEffect` set — every existing gun's `isCharacter`/environment branches are untouched.

**`ReplicatedStorage.Blaster.Utility.drawRayResults`** — add a `weapon: Tool` parameter and pass it through:
```lua
local function drawRayResults(weapon: Tool, position: Vector3, rayResults: { castRays.RayResult })
	for _, rayResult in rayResults do
		laserBeamEffect(position, rayResult.position)
		if rayResult.instance then
			impactEffect(weapon, rayResult.position, rayResult.normal, rayResult.taggedHumanoid ~= nil)
		end
	end
end
```

**Update both call sites** (the only two places `drawRayResults` is called):
- `ReplicatedStorage.Blaster.Scripts.BlasterController:shoot()` — change `drawRayResults(muzzlePosition, rayResults)` to `drawRayResults(self.blaster, muzzlePosition, rayResults)`.
- `ReplicatedStorage.Blaster.Scripts.ShotReplication.onReplicateShotEvent` — change `drawRayResults(position, rayResults)` to `drawRayResults(blaster, position, rayResults)` (`blaster` is already the function's first parameter).

**`StarterPack.Crowbar`** — set the new `meleeHitEffect` attribute to `true`.

### Knockback — already implemented, no action needed
`StarterPack.Crowbar.knockbackForce = 15` is already set from the earlier prompt and works through the existing shared `ShotResolver` knockback code (Part 1b of the previous prompt) — the "short knockback" behavior requested here is already live. Just confirm it still feels right after this VFX rework; don't reimplement it.

### Verify
- Swing the crowbar at an enemy/player: no muzzle flash, a small white pop plays at the point of impact (not at the crowbar), the new hit sound plays only on a connecting swing (not on a whiffed swing), the target is knocked back slightly.
- Swing and miss: no hit sound, no white VFX, no gunshot sound either (Shoot1/2/3 now silent).
- Watch another player swing the crowbar (or have a second client observe): confirm the same hit VFX/sound replicate correctly and nothing errors in that client's output.
- Fire any gun afterward and confirm its impact effect (spark/circle) and hit registration are unchanged — the `impactEffect`/`drawRayResults` signature change must not alter behavior for non-melee weapons.

## Verification checklist

- [ ] Sniper: `rateOfFire` = 50, follow-up shots usable in ~1.2s instead of ~1.7s.
- [ ] Kriss Vector / MP9: re-verified via fresh screenshot before any change was made; only touched if actually still wrong.
- [ ] Mossberg 590: all four sound slots (Equip, Shoot×3, Charger, MagIn+MagOut) updated.
- [ ] Crowbar: Equip + Hit sounds set, Shoot1-3 silenced, muzzle emitters removed from both models, `ViewModelController`/`ShotReplication` guarded defensively before the emitters were removed (not after), new white on-hit VFX plays only on a confirmed hit, knockback confirmed still working.
- [ ] Every other existing weapon's fire/hit/impact behavior unchanged.
