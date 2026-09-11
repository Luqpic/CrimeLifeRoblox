# Prompt: Damage Directional Indicator, Match Weapon Prompt Range to Billboard

Paste this whole document to Claude Code (with Roblox Studio MCP access, including Play-mode/screenshot verification). It is self-contained.

---

## Part 1 — Damage Directional Indicator

Shows a screen-edge arrow toward wherever damage came from (enemy AI or another player), fading out after a moment — tells the player when they're being hit from outside their current view, not just when they can already see the shooter.

### Integration point — reuse the existing `Tagged` event, don't touch `ShotResolver`

`ServerScriptService.Blaster.Scripts.ShotResolver` already fires a server-internal `Tagged` BindableEvent (`ServerScriptService.Blaster.Events.Tagged`) on every hit, `(shooter, victimHumanoid, damage)`, where `shooter` is either a `Player` or an enemy character `Model` — this is the exact same event `EnemyAI:onDamagedBy` already listens to for retaliation detection. Add a second, independent listener rather than modifying the resolver itself.

### New RemoteEvent: `ReplicatedStorage.Blaster.Remotes.DamageDirection`

### New script: `ServerScriptService.Blaster.Scripts.DamageDirectionService`
```lua
-- Tells a player's client where the damage that just hit them came from, so it can render a
-- directional indicator. Reuses the Tagged event ShotResolver already fires on every hit rather
-- than adding a second "something got hurt" signal.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local damageDirectionRemote = ReplicatedStorage.Blaster.Remotes.DamageDirection
local taggedEvent = ServerScriptService.Blaster.Events.Tagged

local function getAttackerPosition(shooter: Player | Model): Vector3?
	if shooter:IsA("Player") then
		local character = shooter.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		return rootPart and rootPart.Position
	elseif shooter:IsA("Model") then
		return shooter:GetPivot().Position
	end
	return nil
end

taggedEvent.Event:Connect(function(shooter: Player | Model, victimHumanoid: Humanoid)
	local victimCharacter = victimHumanoid.Parent
	local victimPlayer = victimCharacter and Players:GetPlayerFromCharacter(victimCharacter)
	if not victimPlayer then
		return -- enemies have no screen to show this on
	end

	local attackerPosition = getAttackerPosition(shooter)
	if attackerPosition then
		damageDirectionRemote:FireClient(victimPlayer, attackerPosition)
	end
end)
```
Fires for damage from an AI enemy or another player identically — both are covered by the same `shooter` handling, matching "enemy/PVP player" in the request. Shows on every hit regardless of whether the attacker happens to already be visible on screen — that matches how this pattern works in every mainstream FPS (Call of Duty, Fortnite, etc.); it isn't specially suppressed when the attacker is in view, just most useful when they aren't.

### New script: `StarterPlayer.StarterPlayerScripts.DamageDirectionIndicator` (LocalScript)

No icon asset needed — uses a Unicode triangle glyph (▲), same placeholder-without-a-risky-asset-guess approach used for the inventory button earlier, and it's simple to rotate.

**Bearing math, worked out explicitly (not from memory) since a sign error here would make the indicator point the wrong way:** flatten both the camera's look direction and the direction to the attacker onto the horizontal plane, then use `atan2` of the cross and dot products to get a signed angle where `0` = directly ahead, positive = clockwise (right), negative = counter-clockwise (left), `±180°` = directly behind. The cross product must be taken as `toAttacker:Cross(lookVector)` (attacker cross look, that specific order) for positive angle to mean "attacker is to the right" — verified by hand-computing the right-of-camera case; get it backwards and every indicator points the mirrored direction.

```lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local damageDirectionRemote = ReplicatedStorage.Blaster.Remotes.DamageDirection

local RADIUS = 150 -- pixels from screen center
local HOLD_TIME = 0.15
local FADE_TIME = 1.2

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DamageDirectionIndicator"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local function showIndicator(attackerPosition: Vector3)
	local cameraPosition = camera.CFrame.Position
	local toAttacker = attackerPosition - cameraPosition
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 1e-3 then
		return
	end
	toAttacker = toAttacker.Unit

	local lookVector = camera.CFrame.LookVector
	lookVector = Vector3.new(lookVector.X, 0, lookVector.Z).Unit

	local dot = math.clamp(lookVector:Dot(toAttacker), -1, 1)
	local cross = toAttacker:Cross(lookVector) -- order matters, see note above
	local angle = math.atan2(cross.Y, dot) -- 0 = ahead, +90deg = right, -90deg = left, 180deg = behind

	local indicator = Instance.new("TextLabel")
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.BackgroundTransparency = 1
	indicator.Size = UDim2.fromOffset(40, 40)
	indicator.Font = Enum.Font.GothamBold
	indicator.TextScaled = true
	indicator.TextColor3 = Color3.fromRGB(255, 60, 60)
	indicator.Text = "▲"
	indicator.Rotation = math.deg(angle)
	indicator.Position = UDim2.new(
		0.5, math.sin(angle) * RADIUS,
		0.5, -math.cos(angle) * RADIUS
	)
	indicator.Parent = screenGui

	task.wait(HOLD_TIME)
	local tween = TweenService:Create(
		indicator,
		TweenInfo.new(FADE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ TextTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Wait()
	indicator:Destroy()
end

damageDirectionRemote.OnClientEvent:Connect(function(attackerPosition: Vector3)
	task.spawn(showIndicator, attackerPosition)
end)
```
Each hit spawns its own independent indicator on its own thread (`task.spawn`), so taking hits from multiple directions in quick succession correctly shows multiple arrows at once rather than one replacing another.

### Verify — sign conventions specifically, not just "something appears"
- Stand still, have (or simulate) damage land from directly **in front**: arrow appears at the top of the screen, pointing further up/away from center.
- From directly **behind**: arrow appears at the bottom, pointing down.
- From the **right**: arrow appears on the right side, pointing further right.
- From the **left**: arrow appears on the left side, pointing further left.
- If any of these are mirrored (e.g. right hits show the arrow on the left), the fix is flipping the cross product argument order noted above, not the position/rotation formulas.
- Take several hits from different directions within ~1 second: multiple arrows visible simultaneously, each fading independently, not overwriting each other.
- Arrow fully fades and is destroyed after ~1.35s total; no leftover invisible labels accumulating in `DamageDirectionIndicator` over time.

---

## Part 2 — Match weapon pickup prompt range to the stat billboard

Currently `ProximityPrompt.MaxActivationDistance = 10` on all 16 weapon pickups, while the stat billboard's `MaxDistance = 20` — the mismatch is exactly the reported bug: the billboard becomes visible at 20 studs but the "Equip" prompt doesn't activate until 10, so there's a 10-stud gap where the stats are visible with no way to interact yet.

For every `Model` tagged `WeaponPickup` (all 16 weapon pickups — **not** the `Cash` drops, which have their own unrelated `MaxActivationDistance = 8` for a different reason and aren't part of this mismatch), set `ProximityPrompt.MaxActivationDistance = 20`.

### Verify
- Approach any weapon pickup: the stat billboard and the "Equip" prompt become available at the same distance, not one before the other.
- Cash drop pickups are unaffected (still activate at 8 studs).

## Verification checklist

- [ ] Taking damage from any source (enemy or player) shows a correctly-directioned, fading screen-edge arrow toward the attacker.
- [ ] All four cardinal directions (front/behind/left/right) verified against the actual on-screen position, not assumed correct from the math alone.
- [ ] Multiple simultaneous hits from different directions show multiple independent arrows.
- [ ] All 16 weapon pickups now activate their prompt at 20 studs, matching the billboard's visibility range.
- [ ] Cash drop pickup range untouched.
