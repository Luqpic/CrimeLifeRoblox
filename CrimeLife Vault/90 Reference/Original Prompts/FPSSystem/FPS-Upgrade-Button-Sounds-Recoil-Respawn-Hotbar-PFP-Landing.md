# Prompt: Upgrade Button Style, Pickup/Equip/Cash Sound Tuning, Enemy Recoil, Respawn Timing, Hotbar Restyle, Player Card PFP Fix, Landing Slowdown

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode verification). It is self-contained.

## Context, confirmed live before writing this — read this first

**Player card photo, confirmed via direct reproduction, not guessed:** calling `Players:GetUserThumbnailAsync` with `Enum.ThumbnailSize.X180Y180` throws immediately — `X180Y180` is not a valid member of `Enum.ThumbnailSize` (confirmed live: the call errors with exactly that message). `PlayerCardController`'s `pcall` swallows the error silently, so `thumbnail.Image` is never set and stays at its template default of `""` — a blank image. Also confirmed live: `Enum.ThumbnailSize.Size180x180` (the actual, correctly-named member) works and returns a valid `rbxthumb://` URI immediately. This is a one-token typo, not an environment limitation.

**Equip sound volumes, measured live across all 16 weapons' `Sounds.Equip.Volume`:** rifle-family weapons (`AK47`, `M16A1`, and the other 9 sharing the same asset) are `0.2`; the shotgun (`Mossberg 590`) is also `0.2`; pistols/melee (`Deagle`, `Crowbar`) are `0.25`. Everything is quiet, rifles and the shotgun are the quietest — matching "especially the rifles."

**Armed Police / Armed Criminal recoil:** these templates have no recoil override today — they inherit `Scar L`'s (`recoilMin (-3, 9)` / `recoilMax (3, 14)`) and `AKM`'s (`recoilMin (-4, 10)` / `recoilMax (4, 16)`) recoil directly from the shared weapon Tool, the same values a player using that weapon gets. Reducing it for these two enemies specifically (without touching what a player feels using the same guns) needs a per-template override, mirroring the existing `AimMaxErrorDegrees` override pattern from the earlier enemy-balance pass — there is no such override for recoil yet.

**Respawn timing:** `StarterPlayer.StarterPlayerScripts.DeathScreen`'s `HOLD_TIME = 2` is what actually drives the visible "Respawning in N" countdown. `ServerScriptService.Ragdoll.Scripts.PlayerRagdoll`'s `PLAYER_RAGDOLL_DURATION = 3` (which raises `Players.RespawnTime` to match) has to stay **longer** than the full visible sequence (`HOLD_TIME + FADE_IN_TIME + BLACK_FADE_TIME`), or the automatic respawn can land before the black screen has even started covering it.

**Hotbar "black outline":** `StarterGui."Custom Inventory".InventoryController.toolButton` has a `UIStroke` (`Color (0,0,0)`, `Thickness 5`, fully opaque) — that's the outline. Its plate's own `BackgroundColor3 (0,0,0)` / `BackgroundTransparency 0.5` already numerically match `Movement.Constants.HUD_BACKGROUND_COLOR`/`HUD_BACKGROUND_TRANSPARENCY` (the leveling bar's own look) — so the only actual mismatch is the stroke; removing it is the whole fix, not a full restyle.

**Upgrade button:** part of `ReplicatedStorage.GuiTemplates.WeaponStatPanel`, confirmed live to still match what was originally built. Making the button ~1.6x taller while keeping every other row/header/gap/padding at its **current** absolute size (not shrinking to compensate, not growing along with it) requires recomputing every fraction against a new total panel height — shown worked out below, not just guessed at.

---

## Part 1 — Upgrade button: red, and noticeably taller

Run once (Command Bar or a temporary `Script`, deleted after):
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local panel = ReplicatedStorage.GuiTemplates.WeaponStatPanel

-- Recomputed so the button grows to ~1.6x its old absolute height while the header, three stat
-- rows, gaps and padding all keep their CURRENT absolute size -- only the button gets bigger.
-- (Old panel height 2.375 studs; new total 2.592 studs; every fraction below is that row's old
-- absolute stud size divided by the new total, except the button which is old x1.6.)
panel.UIPadding.PaddingTop = UDim.new(0.046, 0)
panel.UIPadding.PaddingBottom = UDim.new(0.046, 0)
panel.UIListLayout.Padding = UDim.new(0.0275, 0)
panel.Header.Size = UDim2.new(1, 0, 0.2136, 0)
panel.Damage.Size = UDim2.new(1, 0, 0.1201, 0)
panel.Ammo.Size = UDim2.new(1, 0, 0.1201, 0)
panel.FireRate.Size = UDim2.new(1, 0, 0.1201, 0)
panel.UpgradeButton.Size = UDim2.new(1, 0, 0.2229, 0)

panel.UpgradeButton.BackgroundColor3 = Color3.fromRGB(200, 45, 45)

print("WeaponStatPanel: upgrade button is now red and ~1.6x taller")
```

**`StarterPlayer.StarterPlayerScripts.WeaponStatBillboard`** — the panel fills whatever `BillboardGui` it's placed in, and that billboard's own absolute size is a separate constant in this script (not part of the template). Update it to match the new proportions:
```lua
local BILLBOARD_SIZE = UDim2.new(5.625, 0, 2.592, 0)
```
(was `UDim2.new(5.625, 0, 2.375, 0)` — width unchanged, height up from 2.375 to 2.592 studs, exactly the amount the button grew by.)

### Verify
- Approach any weapon pickup: the upgrade button is clearly red and visibly taller/more prominent than the stat rows above it; the stat rows themselves are the same size as before, not shrunk.
- Panel doesn't clip or overflow its own background at the new height.
- Clicking the button still fires the upgrade request and updates damage the same as before (only its look changed).

---

## Part 2 — Pickup sound reuses the weapon's own Equip sound

**`ServerScriptService.Weapons.Scripts.WeaponPickup`** — add near the top:
```lua
local Debris = game:GetService("Debris")

local PICKUP_SOUND_LINGER = 3

-- Plays independently of anything else in the world, at the pickup's own position, so it survives
-- regardless of what happens to the pickup station or the weapon afterward.
local function playPickupSound(equipSound: Sound, position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "WeaponPickupSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace

	local sound = equipSound:Clone()
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, PICKUP_SOUND_LINGER)
end
```
In `onTriggered`, right after `weapon.Parent = backpack` (i.e. only on an actual successful grant, not a no-op re-trigger):
```lua
	weapon.Parent = backpack

	local sounds = template:FindFirstChild("Sounds")
	local equipSound = sounds and sounds:FindFirstChild("Equip")
	if equipSound and equipSound:IsA("Sound") and pickup.PrimaryPart then
		playPickupSound(equipSound, pickup.PrimaryPart.Position)
	end
end
```
Reuses whatever that specific weapon's Equip sound is (e.g. picking up a Deagle plays the Deagle's own Equip sound) — no new sound IDs, matching the request exactly.

### Verify
- Pick up each of the 16 weapon types individually: each plays **its own** Equip sound at the moment of pickup, not a shared generic one.
- Re-trigger a pickup you already own: no sound plays (the existing `playerHasWeapon` early-return still applies, now also gating the sound).
- The sound is positional (audible near the station, not everywhere) — confirm by walking away before it finishes.

---

## Part 3 — Boost Equip volume across all weapons

Run once:
```lua
local ServerStorage = game:GetService("ServerStorage")

local EQUIP_VOLUME = 0.7 -- was 0.2-0.25 across the board; rifles/shotgun (0.2) get the biggest relative boost

local updated = 0
for _, weapon in ServerStorage.Weapons:GetChildren() do
	if weapon:IsA("Tool") then
		local sounds = weapon:FindFirstChild("Sounds")
		local equip = sounds and sounds:FindFirstChild("Equip")
		if equip and equip:IsA("Sound") then
			equip.Volume = EQUIP_VOLUME
			updated += 1
		end
	end
end

print(`Equip volume set to {EQUIP_VOLUME} on {updated} weapons`)
```

### Verify
- `updated` prints `16`.
- Equip a rifle and a pistol back to back: both are clearly louder than before; rifles no longer sound noticeably quieter than pistols.

---

## Part 4 — Boost cash pickup sound volume

**`ServerScriptService.Weapons.Scripts.CashService`** — in `playPickupSound` (added in the earlier cash-sound-fix prompt), add a `Volume` line:
```lua
	local sound = Instance.new("Sound")
	sound.SoundId = COLLECT_SOUND_ID
	sound.Volume = 0.8
	sound.Parent = anchor
	sound:Play()
```

### Verify
- Collect a cash drop: the pickup sound is clearly louder than before.

---

## Part 5 — Reduce Armed Police / Armed Criminal recoil (without touching player recoil)

**`ReplicatedStorage.Enemy.templateConfig`** — add a `Vector2` reader alongside `numberAttribute`, and two new optional fields:
```lua
local function vector2Attribute(model: Instance, name: string): Vector2?
	local value = model:GetAttribute(name)
	if typeof(value) == "Vector2" then
		return value
	end
	return nil
end
```
Add to `EnemyConfig`:
```lua
export type EnemyConfig = {
	maxHealth: number,
	walkSpeed: number,
	chaseSpeed: number,
	detectionRadius: number,
	engageRangeFraction: number,
	preferredRangeFraction: number,
	damageOverride: number?,
	recoilMinOverride: Vector2?,
	recoilMaxOverride: Vector2?,
	aim: AimOverrides,
}
```
Add to the returned table in `templateConfig.read`:
```lua
		recoilMinOverride = vector2Attribute(template, "RecoilMinOverride"),
		recoilMaxOverride = vector2Attribute(template, "RecoilMaxOverride"),
```
A template that leaves these unset keeps using the weapon's own shared recoil exactly as today — zero behavior change for every enemy except the two this is scoped to.

**`ServerScriptService.Enemy.Scripts.EnemyAI`** — in `_accumulateRecoil`, prefer the config override:
```lua
function EnemyAI:_accumulateRecoil()
	local recoilMin = self.config.recoilMinOverride or self.weapon:GetAttribute(BlasterConstants.RECOIL_MIN_ATTRIBUTE)
	local recoilMax = self.config.recoilMaxOverride or self.weapon:GetAttribute(BlasterConstants.RECOIL_MAX_ATTRIBUTE)
	if not recoilMin or not recoilMax then
		return
	end
	...
```
(Everything after this in the function is unchanged.)

**Set these attributes** (placeholders, roughly half of the current shared values — tune freely):
- `ServerStorage.EnemyTemplates."Armed Police"`: `RecoilMinOverride = Vector2.new(-1.5, 4.5)`, `RecoilMaxOverride = Vector2.new(1.5, 7)`
- `ServerStorage.EnemyTemplates."Armed Criminal"`: `RecoilMinOverride = Vector2.new(-2, 5)`, `RecoilMaxOverride = Vector2.new(2, 8)`

### Verify
- Get shot at by an Armed Police/Armed Criminal enemy in full auto: their aim visibly walks off-target more slowly than before (less recoil accumulating per shot).
- Equip a Scar L or AKM yourself as the player: recoil feels completely unchanged — the override only ever applies inside `EnemyAI`, never to a player-held Tool.
- Every other enemy type's recoil (reading straight from their weapon, no override set) is unchanged.

---

## Part 6 — Respawn: 2 seconds → 5 seconds

**`StarterPlayer.StarterPlayerScripts.DeathScreen`**:
```lua
local HOLD_TIME = 5
```
(was `2`.)

**`ServerScriptService.Ragdoll.Scripts.PlayerRagdoll`**:
```lua
local PLAYER_RAGDOLL_DURATION = 6
```
(was `3` — must stay above `HOLD_TIME + FADE_IN_TIME + BLACK_FADE_TIME` = `5 + 0.5 + 0.4 = 5.9`, so the automatic respawn never lands before the black screen has finished covering it.)

### Verify
- Die: the countdown now reads "Respawning in 5" and counts down over 5 seconds before the black screen appears, matching the new pacing.
- The respawn still lands cleanly under the black cover, not visibly early or with an awkward extra wait — confirms the two numbers are still coherent with each other.

---

## Part 7 — Hotbar: remove the black outline

Run once:
```lua
local StarterGui = game:GetService("StarterGui")
local toolButton = StarterGui["Custom Inventory"].InventoryController.toolButton

local stroke = toolButton:FindFirstChild("UIStroke")
if stroke then
	stroke:Destroy()
end

local corner = toolButton:FindFirstChild("UICorner")
if corner then
	corner.CornerRadius = UDim.new(0, 4) -- matches Movement.Constants.HUD_CORNER_RADIUS -- same language as the leveling bar
end

print("toolButton: outline removed")
```
Nothing else on `toolButton` needs to change — its background color/transparency already numerically match the leveling bar's own `HUD_BACKGROUND_COLOR`/`HUD_BACKGROUND_TRANSPARENCY`; the stroke was the only actual mismatch.

### Verify
- Hotbar slots (and the overflow Inventory panel, which shares the same `toolButton` template) no longer have a visible black border — clean dark rounded plate, matching the leveling bar's look.
- Slot contents (icon, name, ammo count, number) are all still legible and unaffected.

---

## Part 8 — Player card photo: fix the invalid enum

**`StarterPlayer.StarterPlayerScripts.PlayerCardController`** — one-line fix:
```lua
		local ok, image = pcall(
			Players.GetUserThumbnailAsync,
			Players,
			target.UserId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size180x180  -- was X180Y180, which is not a real enum member
		)
```

### Verify
- Open your own player card: your actual Roblox avatar headshot now loads, not a blank square.
- `/view` another player's card: their photo loads too.

---

## Part 9 — Slow down after landing a jump, even without sprinting

**`ReplicatedStorage.Movement.Constants`** — add:
```lua
	-- How long a landing recovery lasts, and how slow WalkSpeed is clamped to during it. Applies to
	-- every landing (jumping or just falling off a ledge), regardless of whether sprint is involved
	-- -- it is a movement-recovery window, not a sprint mechanic.
	LANDING_RECOVERY_DURATION = 0.5,
	LANDING_RECOVERY_WALK_SPEED = 12,
```
(`WALK_SPEED_BASELINE` is `20`; `12` is a clear, noticeable slowdown below normal walk pace, not just a sprint block.)

**`ServerScriptService.Movement.Scripts.SprintAuthority`** — add `landingRecoveryUntil` to the per-player state:
```lua
type PlayerState = {
	intent: boolean,
	stamina: staminaStep.StaminaState,
	secondsSincePublish: number,
	landingRecoveryUntil: number,
}
```
In `getState`'s default table:
```lua
		state = {
			intent = false,
			stamina = staminaStep.newState(),
			secondsSincePublish = 0,
			landingRecoveryUntil = 0,
		}
```
In `onCharacterAdded`, reset it and hook the landing event:
```lua
local function onCharacterAdded(player: Player, character: Model)
	local state = getState(player)
	state.intent = false
	state.stamina = staminaStep.newState()
	state.secondsSincePublish = 0
	state.landingRecoveryUntil = 0

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	rootPart:SetAttribute(Constants.STAMINA_ATTRIBUTE, state.stamina.stamina)
	rootPart:SetAttribute(Constants.CAN_SPRINT_ATTRIBUTE, true)
	rootPart:SetAttribute(Constants.SPRINTING_ATTRIBUTE, false)

	-- Landing recovery: reuses the engine's own Landed state rather than hand-rolling a fall-speed
	-- threshold. Scoped to this character's own lifetime; a fresh humanoid on respawn gets its own
	-- connection, so nothing needs manual disconnection here.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Landed then
				state.landingRecoveryUntil = os.clock() + Constants.LANDING_RECOVERY_DURATION
			end
		end)
	end
end
```
In `tick`, add the landing clamp alongside the existing lockout clamp, and fold it into the sprint-grant check:
```lua
			-- Server-side speed correction. Animate2 drives WalkSpeed on the client, and a client's
			-- own writes to WalkSpeed are local -- they never reach the server -- so this clamp is
			-- stable rather than a tug-of-war: while a player is locked out, the server's Humanoid
			-- reads at most the walk baseline, and it replicates that correction down to the client.
			if lockedOut then
				local humanoid = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.WalkSpeed > Constants.WALK_SPEED_BASELINE then
					humanoid.WalkSpeed = Constants.WALK_SPEED_BASELINE
				end
			end

			-- Same idea, for the brief window right after landing -- clamped BELOW the normal walk
			-- baseline (not just capped at it), so this slows ordinary walking too, not only sprint.
			if os.clock() < state.landingRecoveryUntil then
				local humanoid = rootPart.Parent and rootPart.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.WalkSpeed > Constants.LANDING_RECOVERY_WALK_SPEED then
					humanoid.WalkSpeed = Constants.LANDING_RECOVERY_WALK_SPEED
				end
			end
```
And change the sprint-grant line so landing recovery also blocks a fresh sprint the instant you land:
```lua
			local granted = state.intent and not lockedOut and os.clock() >= state.landingRecoveryUntil
```

### Verify
- Jump and land while walking normally (not sprinting): WalkSpeed visibly drops below normal pace for about half a second, then returns to normal on its own.
- Jump and land while sprinting: the same slowdown applies, and sprint cannot be re-engaged (held key or not) until the recovery window ends.
- Fall off a ledge without jumping (still triggers `Landed`): same slowdown applies — confirms this isn't jump-specific, it's landing-specific.
- Stamina lockout and landing recovery overlapping (land while already stamina-locked): the more restrictive of the two speeds wins; neither cancels the other early.
- Walking on flat ground with no jump involved: completely unaffected — `Landed` never fires without an actual landing.

## Verification checklist

- [ ] Upgrade button is red and ~1.6x taller; other rows unchanged in size; panel doesn't clip.
- [ ] Every weapon's pickup plays its own Equip sound once, on first successful grant only.
- [ ] All 16 weapons' Equip volume raised; rifles/shotgun no longer noticeably quieter than pistols.
- [ ] Cash pickup sound is louder.
- [ ] Armed Police/Armed Criminal recoil reduced; player-held Scar L/AKM recoil unchanged; every other enemy unchanged.
- [ ] Death countdown now runs 5 seconds, respawn still lands cleanly under the black cover.
- [ ] Hotbar slots have no visible outline, matching the leveling bar's look; contents still legible.
- [ ] Player card photo loads for yourself and for `/view`ed players.
- [ ] Landing (jumping or falling) always triggers a brief, noticeable slowdown below normal walk speed, whether or not sprint is involved.
