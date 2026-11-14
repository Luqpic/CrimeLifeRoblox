# Prompt: Melee Combo Animation System + Shell-by-Shell Shotgun Reload

Paste this whole document to Claude Code (with Roblox Studio MCP access). It is self-contained.

## Where this comes from

`Workspace.MeleeSystemV2` and `Workspace.ShotgunFPS` are reference packages the user prepared, each containing a bundled demo weapon ("Knife" / "Shotgun") plus a `README` Script holding the actual Luau code fragments showing how the reference mechanism extends this project's own shared controller scripts. **Decision made: keep the existing Crowbar and Mossberg 590 models/viewmodels/Tools exactly as they are — only adopt the underlying mechanism from these packages, not their bundled models.** Everything below has already been extracted, cross-referenced against this project's actual current code, and adapted to fit — the two Workspace models are reference-only from here on and should be deleted once this prompt is fully applied and verified.

Neither package changes hit detection — both still fire through the existing shared hitscan pipeline (`Shoot` remote → `ShotResolver`). This is a presentation/reload-mechanics upgrade, not a new detection system, so it slots into the existing architecture rather than replacing it.

---

## Part 1 — Melee combo animation system

Applies to `ReplicatedStorage.Blaster.Scripts.ViewModelController` and `ReplicatedStorage.Blaster.Scripts.CharacterAnimationController`, which are **shared by every weapon in the game**, not just the crowbar. Every change here is written to be a no-op for a weapon that only has a single `Shoot` animation (the random-pick logic on a 1-item list always returns that item), so this must not change behavior for the other 19 weapons — verify that explicitly, not just assume it.

### `ViewModelController.new()` — animation loading

Current code loads every animation unconditionally with no priority or error handling. Replace the loading loop with:
```lua
local trail = viewModel:FindFirstChild("Trail", true)

local animations = {}
for _, animation in animationsFolder:GetChildren() do
	if animation:IsA("Animation") and animation.AnimationId ~= "" then
		local ok, animationTrack = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and animationTrack then
			animationTrack.Priority = Enum.AnimationPriority.Action4
			animations[animation.Name] = animationTrack
			bindSoundsToAnimationEvents(animationTrack, sounds, SoundService)
		else
			warn("Failed to load animation:", animation.Name, animation.AnimationId)
		end
	else
		warn("Skipping invalid animation:", animation.Name)
	end
end

-- Idle/Equip must not compete with combat animations at the same top priority.
if animations.Idle then
	animations.Idle.Priority = Enum.AnimationPriority.Idle
end
if animations.Equip then
	animations.Equip.Priority = Enum.AnimationPriority.Action
end
```
Then add `trail` and `lastShootAnimation` to the `self` table constructed right after (alongside the existing fields):
```lua
trail = trail, -- nil for every weapon except the crowbar
lastShootAnimation = nil,
```
This is purely additive/defensive (pcall + priority tuning) — every existing weapon's single `Shoot`/`Idle`/`Reload`/`Equip` animations still load and play exactly as before, just now isolated so a bad/empty AnimationId on one weapon can't error the whole loop, and combat animations reliably render on top of idle.

### `ViewModelController:playShootAnimation()` — random pick + trail

This method was already modified in a previous pass to defensively check for `FlashEmitter`/`CircleEmitter` before emitting (don't lose that). Merge that with the new animation-variant logic and return the picked animation name so the caller can keep the third-person character in sync:
```lua
function ViewModelController:playShootAnimation(): string?
	local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.thirdPerson

	-- Pick a random animation whose name contains "shoot", avoiding an immediate repeat when
	-- there's more than one (e.g. a melee weapon's Shoot/Shoot2/Shoot3 swing variants). Every
	-- other weapon has exactly one such animation, so this always just plays that one.
	local shootList = {}
	for name, track in pairs(self.animations) do
		if name:lower():find("shoot") then
			table.insert(shootList, { name = name, track = track })
		end
	end
	if #shootList == 0 then
		return nil
	end
	local options = shootList
	if #shootList > 1 and self.lastShootAnimation then
		options = {}
		for _, data in ipairs(shootList) do
			if data.name ~= self.lastShootAnimation then
				table.insert(options, data)
			end
		end
	end
	local pick = options[math.random(1, #options)]
	self.lastShootAnimation = pick.name
	pick.track:Play(0)

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

	if self.trail then
		self.trail.Enabled = true
		task.delay(1, function()
			if self.trail then
				self.trail.Enabled = false
			end
		end)
	end

	return pick.name
end
```

### `CharacterAnimationController` — sync with the viewmodel's pick

Add `lastShootAnimation = nil` to the `self` table in `CharacterAnimationController.new()`. Replace `playShootAnimation()`:
```lua
function CharacterAnimationController:playShootAnimation(animationName: string?)
	if animationName then
		local track = self.animationTracks[animationName]
		if track then
			track:Play(0)
		else
			warn("[CharacterAnimationController] No animation named", animationName)
		end
		return
	end

	-- Fallback: auto-pick, same rule as ViewModelController. Only used if no name was passed in.
	local shootList = {}
	for name, track in pairs(self.animationTracks) do
		if name:lower():find("shoot") then
			table.insert(shootList, { name = name, track = track })
		end
	end
	if #shootList == 0 then
		return
	end
	local options = shootList
	if #shootList > 1 and self.lastShootAnimation then
		options = {}
		for _, data in ipairs(shootList) do
			if data.name ~= self.lastShootAnimation then
				table.insert(options, data)
			end
		end
	end
	local pick = options[math.random(1, #options)]
	self.lastShootAnimation = pick.name
	pick.track:Play(0)
end
```
(`CharacterAnimationController.lua`'s own `loadAnimations()` already sets a sensible shared priority via `AnimationPriorities.CombatAction` — leave that untouched, it doesn't need the `Action4` treatment.)

### `BlasterController:shoot()` — wire the sync through

Change:
```lua
self.viewModelController:playShootAnimation()
self.characterAnimationController:playShootAnimation()
```
to:
```lua
local pickedAnimation = self.viewModelController:playShootAnimation()
self.characterAnimationController:playShootAnimation(pickedAnimation)
```
So the first-person viewmodel's random pick and the third-person character's animation always match, instead of each independently (and possibly inconsistently) randomizing.

### Crowbar-specific content

- Add `Trail` to the part representing the crowbar's striking end (inspect the model visually to identify which part that is — likely the far end from the grip) on **both** `StarterPack.Crowbar.Blaster` and `ReplicatedStorage.Blaster.ViewModels.Crowbar.Blaster`, with two `Attachment`s spanning that part's length. Tune for a short, punchy metallic streak (`Lifetime` ~0.15–0.2s), `Enabled = false` by default (the code above turns it on/off during a swing).
- Add `Shoot2` and `Shoot3` Animation instances (in both `StarterPack.Crowbar.Animations` and `ReplicatedStorage.Blaster.ViewModels.Crowbar.Animations`), cloned from the existing `Shoot` slot's `AnimationId`. **This is still the placeholder motion flagged in the original crowbar prompt** — all three "variants" will look identical until real swing animations are authored, but this wires up and exercises the random-pick infrastructure now rather than leaving it dark until assets exist.

### Verify
- Swing the crowbar repeatedly: no back-to-back-identical variant twice in a row once real animations exist (right now, since all three are the same placeholder clip, this won't be visually distinguishable — just confirm no errors and that the trail flashes on each swing).
- Fire every other weapon once each and confirm animations/sounds/muzzle flash are unchanged from before this change.

---

## Part 2 — Shotgun: shell-by-shell, interruptible reload

Applies to `ReplicatedStorage.Blaster.Constants` and `ReplicatedStorage.Blaster.Scripts.BlasterController`, gated entirely behind a new opt-in attribute — every other weapon's `reload()`/`startShooting()` behavior is preserved verbatim in an `else` branch, so this must not change behavior for any gun except the Mossberg.

**`ReplicatedStorage.Blaster.Constants`** — add:
```lua
ISSHOTGUN_ATTRIBUTE = "isShotgun",
```

**`BlasterController`** — cache the flag wherever `self.infiniteAmmo` is cached (constructor and `equip()`'s resync):
```lua
self.isShotgun = self.blaster:GetAttribute(Constants.ISSHOTGUN_ATTRIBUTE) or false
```

Add a new method:
```lua
function BlasterController:cancelReload()
	self.reloadCancelRequested = true

	if self.reloadTask then
		task.cancel(self.reloadTask)
		self.reloadTask = nil
	end

	self.reloading = false
	self.guiController:setReloading(false)
end
```

At the very top of `startShooting()`, before the existing ammo-empty check, add the reload-interrupt: firing while a shotgun is mid-reload cancels the reload and fires with whatever's already chambered, instead of just being blocked (the current behavior for every other weapon, unchanged):
```lua
function BlasterController:startShooting()
	if self.isShotgun and self.reloading then
		self:cancelReload()
		while self.reloading do
			task.wait()
		end
		if self.ammo <= 0 then
			return
		end
	end

	if not self.infiniteAmmo and self.ammo == 0 then
		self:reload()
		return
	end
	...
```

In the `Semi` branch of `startShooting()`, add the pump-cycle delay right after firing, before the existing `task.delay(60 / rateOfFire, ...)` scheduling:
```lua
if fireMode == Constants.FIRE_MODE.SEMI then
	self.shooting = true
	self:shoot()
	if self.isShotgun then
		task.wait(0.5) -- pump cycle; adjust for feel
	end
	task.delay(60 / rateOfFire, function()
		...
```
(The reference package showed this as an isolated fragment without full surrounding context — this is the most sensible integration point given the rest of `startShooting()`'s shape, but confirm the pump-then-cooldown feel in playtesting and adjust the `0.5` if it feels off alongside the Mossberg's existing `rateOfFire`.)

Replace `reload()` entirely:
```lua
function BlasterController:reload()
	if not self:canReload() then
		return
	end

	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	local reloadTime = self.blaster:GetAttribute(Constants.RELOAD_TIME_ATTRIBUTE)

	self.reloading = true
	self.reloadCancelRequested = false
	self.guiController:setReloading(true)
	reloadRemote:FireServer(self.blaster)

	if self.isShotgun then
		while self.ammo < magazineSize and self.equipped and not self.reloadCancelRequested do
			local isLastShell = (self.ammo + 1) == magazineSize
			local animationSpeed = isLastShell and 1 or 4 / 3
			self.viewModelController:playReloadAnimation(animationSpeed)
			self.characterAnimationController:playReloadAnimation(animationSpeed)

			local playTime = isLastShell and reloadTime or (reloadTime * 0.85)
			local elapsed = 0
			while elapsed < playTime do
				if self.reloadCancelRequested then
					self.reloading = false
					self.guiController:setReloading(false)
					return
				end
				elapsed += task.wait()
			end
			if self.reloadCancelRequested then
				break
			end

			self.ammo += 1
			self.guiController:setAmmo(self.ammo)
		end
		self.reloading = false
		self.guiController:setReloading(false)
	else
		-- Unchanged monolithic reload for every non-shotgun weapon.
		self.viewModelController:playReloadAnimation(reloadTime)
		self.characterAnimationController:playReloadAnimation(reloadTime)
		self.reloadTask = task.delay(reloadTime, function()
			self.ammo = magazineSize
			self.reloading = false
			self.reloadTask = nil
			self.guiController:setAmmo(self.ammo)
			self.guiController:setReloading(false)
		end)
	end
end
```

### Critical: `reloadTime` means something different now — recalibrate the Mossberg's attribute

Every other weapon's `reloadTime` is the total time for the whole magazine to refill. Under the shell-by-shell loop, it's the time **per shell**. The Mossberg's current `reloadTime = 3.2` was set under the old (monolithic) meaning — left as-is, an 8-shell reload from empty would take roughly `7 × (3.2 × 0.85) + 3.2 ≈ 22s`. Change `StarterPack."Mossberg 590".reloadTime` to `0.5`, which gives `7 × (0.5 × 0.85) + 0.5 ≈ 3.48s` total for a full empty-to-full reload — close to the original intended feel. Also set `StarterPack."Mossberg 590".isShotgun = true`.

### Sounds — do not import the reference package's audio wholesale

`Workspace.ShotgunFPS`'s `Sounds` folder uses Roblox's `AudioPlayer`/`AudioEmitter` classes. Every sound utility already used across this project (`playRandomSoundFromSource`, `bindSoundsToAnimationEvents`, the hitmarker sound, etc.) is built around the classic `Sound` class — importing the package's audio folder as-is would not work with the existing pipeline. The Mossberg's `Sounds` folder already has the correct classic `Sound` instances with the right asset IDs set from the previous pass (Equip/Shoot1-3/Charger/MagIn/MagOut) — leave that folder as it is; nothing here needs new sound wiring, the shell-by-shell loop replays the existing `Reload` animation track each iteration, which re-triggers whatever animation-marker-bound sounds (`MagIn`/`MagOut`) are already attached to it.

### Known follow-up, not fixed here
- `GuiController:updateAmmoText()` shows dashes for the entire duration `self.reloading` is true, regardless of the `setAmmo()` calls the shell-by-shell loop makes each iteration — so the HUD will show a static dashed ammo count through the whole reload rather than visibly ticking up shell by shell. This matches what the reference package's own snippets show (they don't touch `GuiController`), so it's not a regression — but if a live-ticking count during reload is wanted, that's a small separate `GuiController` change, not included here.
- The Mossberg's existing `Reload` animation was authored for a single monolithic reload motion. Under the new loop it will now play repeatedly, once per shell — it will very likely need to be re-cut/re-authored as a single shell-insertion motion to look natural when looped. Flag this to the user rather than guessing at animation content.

### Verify
- Fire the Mossberg until empty, confirm it reloads shell-by-shell (ammo count updates internally each iteration even if the HUD doesn't visibly reflect it per the note above) and stops correctly at `magazineSize`.
- Mid-reload, fire again: confirm the reload cancels and the shot fires immediately with the currently-loaded ammo (and correctly refuses to fire if `ammo` is still 0 at that point).
- Confirm every other weapon's reload (monolithic, `task.delay`-based) is completely unchanged.

---

## Cleanup

Once both parts are verified working, delete `Workspace.MeleeSystemV2` and `Workspace.ShotgunFPS` — they were reference-only and are not used by any live script after this point.

## Verification checklist

- [ ] Every existing weapon's shoot animation, reload behavior, and muzzle VFX are unchanged.
- [ ] Crowbar has a working (if placeholder) 3-variant swing system with a trail effect on hit.
- [ ] Mossberg 590 reloads shell-by-shell, is interruptible by firing, and a full reload takes ~3.5s not ~22s.
- [ ] `Workspace.MeleeSystemV2` and `Workspace.ShotgunFPS` removed after verification.
