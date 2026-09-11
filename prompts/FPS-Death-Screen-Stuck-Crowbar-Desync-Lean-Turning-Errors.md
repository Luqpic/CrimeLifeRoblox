# Prompt: Death Screen Stuck / Button Z-Order, Stale Enemy Crowbar, Enemy Melee Timing, Lean+Turning Error Spam

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/console/screenshot verification). It is self-contained.

## Context, investigated live before writing this — read this first

**The death screen and the inventory button bug are the same bug.** `StarterPlayer.StarterPlayerScripts.DeathScreen` renders `DeathScreenGui` at `DisplayOrder = 10`, above every other HUD element, full screen (`IgnoreGuiInset = true`). If `BlackOverlay` ever fails to fade back to `BackgroundTransparency = 1`, it sits over the *entire* screen — including `StarterGui."Custom Inventory".openButton` — which reads exactly as "the backpack emoji appears behind a black semi-transparent box." Live-inspecting `openButton` and its `icon` child in Edit mode found nothing structurally wrong there (correct parenting, `ZIndex = 1`, `BackgroundTransparency = 1` on the icon) — so this is not a separate inventory bug, it's the death screen's overlay leaking through.

Live Play-mode testing (repeated `Humanoid:TakeDamage(9999)` calls, polling `TextContainer.GroupTransparency` / `BlackOverlay.BackgroundTransparency` / `DepthOfField.Enabled` continuously through the full sequence) confirmed the *symptom* is real but did not cleanly isolate one single trigger — repeated test-deaths in the same session introduced their own timing noise. Rather than guess at the exact trigger, the fix below closes the actual gap that would explain it either way: **nothing currently guarantees the overlay/blur/text get reset if anything in the sequence doesn't complete cleanly.** Part 1 makes that reset unconditional.

**A separate, serious bug found while testing, not part of the original report:** the console was flooded, every single frame, with:
```
Unable to assign property C0. Property is read only
Stack Begin
Script 'Workspace.<Player>.Lean', Line 142
Stack End
...
Script 'Workspace.<Player>.Turning', Line 101 - function Calculate
```
Root cause, confirmed against `ReplicatedStorage.Modules.RagdollController`'s own documented rig notes: this character rig's R15 joints (`Root`, `Waist`, `Neck`, `RightHip`, `LeftHip`) are `AnimationConstraint`s, not `Motor6D`s — a deliberate choice that makes the ragdoll system work. `AnimationConstraint.C0` can be **read** but not **assigned**. `StarterCharacterScripts.Lean` and `.Turning` both predate that rig change and both try to assign `.C0` every frame, unconditionally, for every single player. Part 4 stops this — by disabling the (currently completely non-functional, silently-failing) lean/turn effect for this rig rather than attempting a from-scratch `AnimationConstraint`-compatible reimplementation, which is a separate task if the visual effect is wanted back.

**Crowbar staleness, confirmed live:** `ServerStorage.EnemyTemplates.Thug.Crowbar` (an embedded, static copy cloned wholesale by `EnemySpawner` — not a live reference to `ServerStorage.Weapons.Crowbar`) has `knockbackForce = 15` (the pre-tune value) and **no `swingDelay` attribute at all**, while the current player Crowbar has `knockbackForce = 90` and `swingDelay = 0.2`. Thug's copy also has its own `Grip` position (`(0.000007, 0.43, -3.008)`), different from the player Tool's grip convention — this is rig-specific hand positioning, not something that should be overwritten by a wholesale swap. Part 2 syncs the attributes and sound ids that actually drift, not the whole Tool.

**The real cause of the enemy "damage before hit animation" problem:** confirmed directly in `ServerScriptService.Enemy.Scripts.EnemyAI:_fireOnce()` — it calls `ShotResolver.resolveShot(...)` **before** `self.animationController:playShootAnimation()`, and `Constants.SWING_DELAY_ATTRIBUTE` is never read anywhere in `EnemyAI` at all (confirmed by grep — the only reader is `BlasterController`, the player's own script). Syncing the Crowbar's attributes (Part 2) puts `swingDelay = 0.2` onto Thug's weapon, but that alone changes nothing for enemies, because the deferral logic that *uses* `swingDelay` was only ever built for players. Part 3 ports it to `EnemyAI`, mirroring `BlasterController:shoot()`'s existing pattern exactly.

---

## Part 1 — Death screen: guaranteed cleanup, not best-effort

**`StarterPlayer.StarterPlayerScripts.DeathScreen`** — rename the existing `playDeathSequence` function to `runDeathSequence`, and replace it with this plus a new wrapper:
```lua
local function runDeathSequence()
	local respawnCountAtDeath = respawnCount

	depthOfField.Enabled = true

	phraseLabel.Text = PHRASES[math.random(1, #PHRASES)]
	countdownLabel.Text = `Respawning in {math.ceil(HOLD_TIME)}`

	local fadeInTweenInfo = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(textContainer, fadeInTweenInfo, { GroupTransparency = 0 }):Play()
	TweenService:Create(depthOfField, fadeInTweenInfo, {
		FarIntensity = DEATH_FAR_INTENSITY,
		InFocusRadius = DEATH_IN_FOCUS_RADIUS,
	}):Play()

	local holdDeadline = os.clock() + HOLD_TIME
	while os.clock() < holdDeadline do
		local remaining = math.max(0, math.ceil(holdDeadline - os.clock()))
		countdownLabel.Text = `Respawning in {remaining}`
		task.wait(0.2)
	end

	TweenService:Create(
		blackOverlay,
		TweenInfo.new(BLACK_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	):Play()
	task.wait(BLACK_FADE_TIME)

	-- The actual respawn: waited for, not guessed.
	while respawnCount <= respawnCountAtDeath do
		respawnedSignal.Event:Wait()
	end
end

-- Wraps the sequence so cleanup is UNCONDITIONAL: whether it completes normally or errors or stalls
-- partway through for any reason, the overlay/blur/text are always reset afterward. A stuck black
-- screen covering the whole HUD (which is exactly what an unhandled failure here looks like -- see
-- the Context section on why this also explains the inventory button symptom) is worse than an
-- early, un-animated reset.
local function playDeathSequence()
	local ok, err = pcall(runDeathSequence)
	if not ok then
		warn("DeathScreen: sequence failed, forcing reset:", err)
	end

	textContainer.GroupTransparency = 1
	depthOfField.FarIntensity = originalFarIntensity
	depthOfField.InFocusRadius = originalInFocusRadius
	depthOfField.Enabled = originalDoFEnabled

	TweenService:Create(
		blackOverlay,
		TweenInfo.new(BLACK_FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	):Play()
end
```
Everything else in the file (the `onCharacterAdded`/`respawnCount`/`respawnedSignal` setup) is unchanged.

### Verify
- Die repeatedly, several times in a row, in the same session (not just once): every single time, the phrase/countdown fade out and the black screen fully clears — no run leaves anything stuck.
- While the death screen is showing, confirm the inventory button is *not* visible underneath a black layer (expected, since it's covered by design during the sequence) — then confirm it's back to normal, fully visible, immediately once the black screen finishes fading out.
- Force an error inside `runDeathSequence` temporarily (e.g. `error("test")` right after `depthOfField.Enabled = true`) and confirm the outer wrapper still resets everything and the game is left in a normal, playable state, not stuck — then remove the test line.

---

## Part 2 — Sync the Thug's Crowbar (attributes + sounds, not a wholesale swap)

Run this once (Command Bar, or a temporary `Script` you delete afterward):
```lua
local ServerStorage = game:GetService("ServerStorage")

local currentCrowbar = ServerStorage.Weapons.Crowbar
local thugCrowbar = ServerStorage.EnemyTemplates.Thug.Crowbar

-- Every attribute is exactly what drifts out of date over time (knockbackForce, swingDelay,
-- damage, etc.) -- Grip/Handle/Blaster/Animations are NOT touched, since those are positioned
-- specifically for the Thug rig, not shared with the player Tool.
local currentAttributeNames = {}
for name, value in currentCrowbar:GetAttributes() do
	currentAttributeNames[name] = true
	thugCrowbar:SetAttribute(name, value)
end
-- Clear anything Thug's copy still has that the current Crowbar no longer declares, so a removed
-- or renamed attribute doesn't linger as stale dead data.
for name in thugCrowbar:GetAttributes() do
	if not currentAttributeNames[name] then
		thugCrowbar:SetAttribute(name, nil)
	end
end

-- Sound ids are the other thing that drifts; Sound instance identity/parenting is left alone.
local currentSounds = currentCrowbar:FindFirstChild("Sounds")
local thugSounds = thugCrowbar:FindFirstChild("Sounds")
if currentSounds and thugSounds then
	for _, currentSound in currentSounds:GetDescendants() do
		if currentSound:IsA("Sound") then
			local thugSound = thugSounds:FindFirstChild(currentSound.Name, true)
			if thugSound and thugSound:IsA("Sound") then
				thugSound.SoundId = currentSound.SoundId
			end
		end
	end
end

print("Thug Crowbar synced. knockbackForce=" .. tostring(thugCrowbar:GetAttribute("knockbackForce")) .. " swingDelay=" .. tostring(thugCrowbar:GetAttribute("swingDelay")))
```

### Verify
- `ServerStorage.EnemyTemplates.Thug.Crowbar.knockbackForce` reads `90`; `swingDelay` reads `0.2`.
- Thug's Crowbar still visually sits correctly in its hand in Play mode (confirms `Grip` wasn't touched) — screenshot a Thug holding it.
- Thug's Crowbar sound ids match the player Crowbar's current ones.

---

## Part 3 — Give `EnemyAI` the same swing-delay deferral `BlasterController` already has

**`ServerScriptService.Enemy.Scripts.EnemyAI`** — in `_fireOnce`, replace everything from the `ShotResolver.resolveShot({...})` call through the end of the function with:
```lua
	if self.animationController then
		pcall(function()
			self.animationController:playShootAnimation()
		end)
	end

	-- Melee weapons declare a swingDelay so the hit lands when the swing visually reaches the
	-- target -- the same problem BlasterController's own player-facing fix already solved. Without
	-- this, a melee enemy's damage resolves the instant the swing starts, before the animation has
	-- moved the weapon anywhere near the target. Guns leave this unset/0, so their behaviour
	-- (instant hit) is completely unchanged.
	local swingDelay = weapon:GetAttribute(BlasterConstants.SWING_DELAY_ATTRIBUTE) or 0
	local character = self.character
	local function resolveHit()
		if self.destroyed or not character.Parent then
			return -- the enemy died or was cleaned up during the delay
		end
		ShotResolver.resolveShot({
			shooter = character,
			weapon = weapon,
			origin = origin,
			seed = seed,
		})
	end

	if swingDelay > 0 then
		task.delay(swingDelay, resolveHit)
	else
		resolveHit()
	end

	self:_accumulateRecoil()

	return true
end
```
The animation now plays immediately (matching how it already looks for guns, since `swingDelay` is 0 for them) and the hit resolution — damage, the `Tagged`/`Eliminated` events, the knockback, the replicated tracer — is what gets deferred. `self:_accumulateRecoil()` still runs synchronously right after, same as before; moving it after the (possibly-deferred) resolve call doesn't change its effect, since `origin` already has *previous* recoil baked in before this line, exactly as the original code's own comment describes — this shot's own kick has always only ever affected the *next* shot.

### Verify
- A Thug swings the crowbar at you: the swing animation visibly starts and travels toward you, and the hit/damage lands at the moment of visual contact, not instantly when the swing begins — the same fix already verified for the player's own crowbar.
- Every gun-carrying enemy type (`Police`, `Armed Police`, `Criminal`, `Armed Criminal`) fires with completely unchanged, instant hit timing — `swingDelay` is unset/0 for all of them.
- `Security`'s Baton is unaffected (different Tool, not touched by Part 2, and Part 3's change is generic — it will pick up a `swingDelay` automatically the moment one is ever set on the Baton, but does nothing differently today since it's currently unset).
- Kill a Thug mid-swing (before its deferred hit resolves): confirm no error — `resolveHit`'s guard checks `self.destroyed`/`character.Parent` and safely no-ops.

---

## Part 4 — Stop the Lean/Turning per-frame error spam

**`StarterPlayer.StarterCharacterScripts.Lean`** — right after `m6d` is resolved (before `originalM6dC0 = m6d.C0`), add:
```lua
-- This rig's R15 joints are AnimationConstraints, not Motor6Ds (see RagdollController's own notes
-- on why) -- their C0 can be read but not assigned, which is exactly what was spamming "Unable to
-- assign property C0. Property is read only" on every single frame. Disabling the lean effect here
-- rather than reimplementing it for AnimationConstraints, which is a separate task.
if not m6d:IsA("Motor6D") then
	return
end
```

**`StarterPlayer.StarterCharacterScripts.Turning`** — in `getCharacterData`, change the top of the function and add the same guard before building `data`:
```lua
local function getCharacterData(char)
	local cached = characterData[char]
	if cached ~= nil then
		return cached or nil -- false is a cached "checked, disabled" result, not "not checked yet"
	end

	local lt = char:FindFirstChild('LowerTorso')
	local ut = char:FindFirstChild('UpperTorso')
	local hd = char:FindFirstChild('Head')
	local rul = char:FindFirstChild('RightUpperLeg')
	local lul = char:FindFirstChild('LeftUpperLeg')

	if not (lt and ut and hd and rul and lul) then return nil end

	local root = lt:FindFirstChild('Root')
	local waist = ut:FindFirstChild('Waist')
	local neck = hd:FindFirstChild('Neck')
	local rh = rul:FindFirstChild('RightHip')
	local lh = lul:FindFirstChild('LeftHip')

	if not (root and waist and neck and rh and lh) then return nil end

	-- Same AnimationConstraint-vs-Motor6D issue as Lean.lua. Cached per-character (via the false
	-- sentinel above) so this is checked once, not every frame.
	if not root:IsA("Motor6D") then
		characterData[char] = false
		return nil
	end

	local data = {
		rootC0 = root.C0,
		waistC0 = waist.C0,
		neckC0 = neck.C0,
		rightHipC0 = rh.C0,
		leftHipC0 = lh.C0,
	}
	characterData[char] = data
	return data
end
```
`Calculate` already does `local data = getCharacterData(char); if not data then return end` immediately after, so no further change is needed there.

### Verify
- Play mode: move around (walk, strafe, sprint) for at least 10 seconds and check `get_console_output` — zero "Unable to assign property C0" errors, where previously it was continuous, every frame.
- Confirm this doesn't newly break anything else that depended on these scripts running (nothing else in this codebase reads anything from `Lean`/`Turning` — confirmed by grep before writing this).
- Understood and expected, not a bug: the character no longer visually leans/turns its upper body when strafing — that visual effect is now off rather than erroring. A proper reimplementation using `AnimationConstraint`-compatible offsets (not `.C0`) is a separate follow-up if the effect is wanted back.

## Verification checklist

- [ ] Dying repeatedly in the same session never leaves the phrase/countdown/black-overlay stuck, even under a forced-error test.
- [ ] The inventory button is never covered by a stuck black layer after a death screen finishes.
- [ ] `Thug`'s Crowbar attributes and sound ids match the current player Crowbar; its `Grip`/hand positioning is unchanged.
- [ ] Thug's (and any future melee enemy's) crowbar hit now lands synced to the swing animation, not instantly; every gun-carrying enemy's timing is unchanged.
- [ ] Zero "Unable to assign property C0" errors during normal play; lean/turn effect is understood to be off, not broken.
