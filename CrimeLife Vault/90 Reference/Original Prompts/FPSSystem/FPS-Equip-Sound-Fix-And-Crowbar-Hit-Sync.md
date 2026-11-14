# Prompt: Fix Missing Equip Sounds, Sync Crowbar Animation/Sound/Damage

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Root cause, confirmed before writing this — read this first

Equip (and Shoot) sounds play through `ReplicatedStorage.Blaster.Utility.bindSoundsToAnimationEvents`, which is **entirely animation-marker-driven**: it does nothing unless the animation asset itself has an authored `"Sound"` marker whose parameter string matches a child name in the weapon's `Sounds` folder (`animation:GetMarkerReachedSignal("Sound"):Connect(function(param) ... sounds:FindFirstChild(param) ...)`). There is no fallback.

Already verified directly, not assumed:
- `ServerStorage.Weapons.AK47.Sounds.Equip.SoundId` is a valid, non-empty asset (`rbxassetid://9114725075`) — same situation as `Deagle` (`rbxassetid://17682721729`). **The SoundId was never the problem.**
- Both AK47 and Deagle have a real `Equip` Animation instance under their viewmodel's `Animations` folder (different underlying `AnimationId`s, as expected for different weapons).
- A red herring ruled out: the Tool's own top-level `Animations` folder (as opposed to the viewmodel's) is missing an `Equip` entry on *both* AK47 and Deagle equally — that folder only feeds `CharacterAnimationController`, which never plays or binds sounds to an "Equip" track at all, so this gap is pre-existing, universal, and unrelated to the reported bug.

Conclusion: the rifle/shotgun `Equip` animation *assets* very likely lack the `"Sound"` marker the pistols' happen to have — a content-authoring gap in external animation data this document's author cannot inspect or edit (no access to the Animation Editor's marker/event data). Rather than patch markers on assets that can't be inspected, remove the dependency on markers for Equip entirely, for every weapon uniformly — this fixes the currently-broken weapons and makes every future weapon's Equip sound reliable regardless of whether its animation happens to have a marker authored on it.

---

## Part 1 — Make Equip sound marker-independent (all weapons)

**`ReplicatedStorage.Blaster.Scripts.ViewModelController`**

In the animation-loading loop inside `ViewModelController.new()`, change the unconditional `bindSoundsToAnimationEvents(animationTrack, sounds, SoundService)` call to skip `"Equip"` (and, for melee weapons only, skip `"Shoot"` too — see Part 2 for why):
```lua
local isMeleeWeapon = blaster:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE)

-- ... inside the existing loop, replace the unconditional bind call with:
local skipMarkerBinding = animation.Name == "Equip" or (isMeleeWeapon and animation.Name:match("^Shoot"))
if not skipMarkerBinding then
	bindSoundsToAnimationEvents(animationTrack, sounds, SoundService)
end
```

Add near the top of the file (alongside the existing `bindSoundsToAnimationEvents` require):
```lua
local playSoundFromSource = require(script.Parent.Parent.Utility.playSoundFromSource)
local playRandomSoundFromSource = require(script.Parent.Parent.Utility.playRandomSoundFromSource)
```

In `ViewModelController:enable()`, right after `self.animations.Equip:Play(0)`, add:
```lua
-- Explicit, marker-independent equip sound -- see the loading-loop comment for why this doesn't
-- rely on the animation having a "Sound" marker.
local sounds = self.blaster:FindFirstChild("Sounds")
local equipSound = sounds and sounds:FindFirstChild("Equip")
if equipSound then
	playSoundFromSource(equipSound, self.handle)
end
```

### Verify
- Equip every one of the 16 weapons individually and confirm an audible equip sound plays for **all** of them, not just pistols.
- Equip a pistol that was already reportedly working: confirm it does **not** now play the equip sound twice (this is the reason marker-binding is skipped for Equip rather than left active alongside the explicit call — verify this holds, don't just assume the skip prevents it).

---

## Part 2 — Crowbar: same marker risk for the swing sound

The crowbar's swing animations were added recently as fresh assets with no confirmation a `"Sound"` marker was authored on them either — treat this as the same class of risk as Equip, not confirmed broken, but worth the same robust treatment rather than hoping.

In `ViewModelController:playShootAnimation()`, right after `pick.track:Play(0)`, add:
```lua
-- Explicit, marker-independent swing sound for melee weapons only -- guns keep using the
-- marker-based path (self.blaster:GetAttribute(...) is false/unset for them, so this is a no-op).
if self.blaster:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE) then
	local sounds = self.blaster:FindFirstChild("Sounds")
	local shootSounds = sounds and sounds:FindFirstChild("Shoot")
	if shootSounds then
		playRandomSoundFromSource(shootSounds, self.handle)
	end
end
```
This plays immediately when the swing animation starts (unchanged timing from before) — it's the *reliability* of the sound that's being fixed here, not its timing. The timing fix for damage/hit is Part 4, and is deliberately independent of this.

### Verify
- Swing the crowbar and confirm the swing/whoosh sound is audible, not just the separate on-hit "Hit" sound from earlier work.

---

## Part 3 — Assign the new sound IDs

Two of the three IDs given for rifles/shotgun were identical (`134455464145882` listed twice) — flagging this rather than silently treating it as intentional. Proceeding with the 2 actually-distinct sounds: one for the 11 rifle-family weapons as a group (thematically similar, all originally built from the AK47 template), the other for the shotgun specifically, since it's already a mechanically distinct weapon class (shell-by-shell reload, knockback) and deserves its own identity rather than sharing with the rifles. If a genuine third sound was intended, send the correct ID and it's a one-line swap.

**Rifle-family `Sounds.Equip.SoundId` = `rbxassetid://136748385357155`**, applied to: `AK47`, `AKM`, `HCAR`, `Kriss Vector`, `Scar L`, `AUG A-3`, `AMB-17`, `MP9`, `Sig MPX`, `M16A1`, `FN P-90` (11 weapons, under `ServerStorage.Weapons`).

**Shotgun `Sounds.Equip.SoundId` = `rbxassetid://134455464145882`**, applied to: `Mossberg 590`.

**Crowbar (`ServerStorage.Weapons.Crowbar`):**
- `Sounds.Equip.SoundId` = `rbxassetid://9113453540` (replaces the previous `127835667593323`)
- `Sounds.Shoot.Shoot1.SoundId`, `Shoot2.SoundId`, `Shoot3.SoundId` = `rbxassetid://6241709963` (these were left silent in an earlier pass since no swing sound existed yet — this fills them in)

### Verify
- Each of the 12 rifle/shotgun weapons plays its newly-assigned equip sound (not silence, not the old sound if one happened to already be set).
- Crowbar equip and swing sounds are the new assets, not the previous ones.

---

## Part 4 — Sync crowbar damage/hitmarker with the swing's visual contact point

**Reported bug:** damage (and the hitmarker/Hit VFX/sound it triggers) currently lands the instant the swing is clicked, before the swing animation has visually moved the crowbar anywhere near the target — reads as the target getting hurt before the weapon has swung. This is specific to melee: for guns, instant hit resolution is correct (a bullet reads as instantaneous), so nothing about gun timing should change.

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
-- Delay, in seconds, between initiating an attack and the hit actually resolving. 0/unset for
-- every weapon except melee, which needs the hit to land when the swing animation visually shows
-- contact rather than at the instant the swing starts.
SWING_DELAY_ATTRIBUTE = "swingDelay",
```

**`ReplicatedStorage.Blaster.Scripts.BlasterController`** — in `shoot()`, wrap the raycast/damage-resolution portion (everything from computing `origin` through `drawRayResults`) in a local function, and delay calling it when `swingDelay > 0`. Animation start, recoil, and ammo decrement stay immediate (unchanged) — only the actual hit resolution moves:
```lua
function BlasterController:shoot()
	local spread = self.blaster:GetAttribute(Constants.SPREAD_ATTRIBUTE)
	local raysPerShot = self.blaster:GetAttribute(Constants.RAYS_PER_SHOT_ATTRIBUTE)
	local range = self.blaster:GetAttribute(Constants.RANGE_ATTRIBUTE)
	local rayRadius = self.blaster:GetAttribute(Constants.RAY_RADIUS_ATTRIBUTE)
	local swingDelay = self.blaster:GetAttribute(Constants.SWING_DELAY_ATTRIBUTE) or 0

	local pickedAnimation = self.viewModelController:playShootAnimation()
	self.characterAnimationController:playShootAnimation(pickedAnimation)
	self:recoil()

	if not self.infiniteAmmo then
		self.ammo -= 1
		self.guiController:setAmmo(self.ammo)
	end

	local function resolveHit()
		local now = Workspace:GetServerTimeNow()
		local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.viewModelController.thirdPerson

		local origin
		if isFirstPerson then
			origin = camera.CFrame
		else
			local muzzlePosition = self.viewModelController:getMuzzlePosition()
			origin = CFrame.new(muzzlePosition, muzzlePosition + camera.CFrame.LookVector)
		end

		local rayDirections = getRayDirections(origin, raysPerShot, math.rad(spread), now)
		for index, direction in rayDirections do
			rayDirections[index] = direction * range
		end

		local rayResults = castRays(player, origin.Position, rayDirections, rayRadius)

		local tagged = {}
		local didTag = false
		for index, rayResult in rayResults do
			if rayResult.taggedHumanoid then
				tagged[tostring(index)] = rayResult.taggedHumanoid
				didTag = true
			end
		end

		if didTag then
			self.guiController:showHitmarker()
		end

		shootRemote:FireServer(now, self.blaster, origin, tagged)

		local muzzlePosition = self.viewModelController:getMuzzlePosition()
		drawRayResults(self.blaster, muzzlePosition, rayResults)
	end

	if swingDelay > 0 then
		task.delay(swingDelay, resolveHit)
	else
		resolveHit()
	end
end
```
Note the aim direction (`origin`) is deliberately read live *inside* `resolveHit`, not captured before the delay — this means the crowbar tracks wherever the camera is actually facing at the moment of impact, matching how a real swing would connect wherever you're currently looking, not frozen to your aim at the instant you clicked.

**`StarterPack.Crowbar` / `ServerStorage.Weapons.Crowbar`** — set `swingDelay = 0.2`. This is a starting estimate, not measured against the actual animation's timing (no way to inspect keyframe timing here) — watch the swing animation play in Play mode and tune this value up or down until the hitmarker/damage/Hit-VFX visibly lands right as the crowbar model reaches the target, not before the swing has moved or noticeably after it's already retracting.

### Verify
- Swing at a target: the swing animation visibly begins, travels toward the target, and the hitmarker/damage/Hit VFX land at the moment of visual contact — not instantly on click.
- Fire every gun afterward and confirm their hit timing is completely unchanged (instant, as before) — `swingDelay` is unset/0 for all of them, so this must not regress.
- Miss a swing (aim away from a target): no hit registers, same as always — the delay changes *when* the hit resolves, not whether the existing hit-detection logic still works correctly.

## Verification checklist

- [ ] All 16 weapons play an audible equip sound; no weapon double-plays it.
- [ ] Crowbar swing sound is audible (not just the separate on-hit sound).
- [ ] Rifle-family, shotgun, and crowbar sounds all updated to the specified new asset IDs.
- [ ] Crowbar damage/hitmarker/Hit-VFX now land synced with the swing animation's visual contact, tuned via `swingDelay` against the actual animation.
- [ ] Every gun's hit timing is unchanged (still instant).
