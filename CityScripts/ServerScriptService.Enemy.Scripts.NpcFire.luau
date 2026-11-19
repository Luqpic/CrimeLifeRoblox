-- What every NPC shooter shares (readable gunfights, combat balance 2026-11-20): the shooter tokens of each player
-- (at most Combat.MAX_SHOOTERS_PER_TARGET firing at one player at a time), the red aim line shown during a wind-up,
-- and the aim cone with the focus ramp. Used by EnemyAI (gangs, police, heist police) and by
-- Heist.Components.GuardPost (guards). Numbers: ReplicatedStorage.Enemy.Combat.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AimConfig = require(ReplicatedStorage.Enemy.AimConfig)
local Combat = require(ReplicatedStorage.Enemy.Combat)
local getRayDirections = require(ReplicatedStorage.Blaster.Utility.getRayDirections)

local NpcFire = {}

-- One registry for the whole server, keyed by target player; a player's tokens go when they die or leave.
NpcFire.tokens = Combat.newTokens(Combat.MAX_SHOOTERS_PER_TARGET)

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		(humanoid :: Humanoid).Died:Connect(function()
			NpcFire.tokens:clear(player)
		end)
	end
end
local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerRemoving:Connect(function(player)
	NpcFire.tokens:clear(player)
end)

local function noop() end

-- The weapon's muzzle in the world, else its Handle, else the holder's root.
function NpcFire.muzzlePosition(weapon: Tool, holder: Model): Vector3
	local muzzle = weapon:FindFirstChild("MuzzleAttachment", true)
	if muzzle and muzzle:IsA("Attachment") then
		return muzzle.WorldPosition
	end
	local handle = weapon:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle.Position
	end
	return (holder.PrimaryPart :: BasePart).Position
end

-- The red aim line from `weapon`'s muzzle to the target's root, replicated to everyone. Returns the function that
-- removes it (safe to call more than once); it also goes by itself after Combat.TELL_MAX_SECONDS.
function NpcFire.showTell(weapon: Tool?, targetHumanoid: Humanoid?): () -> ()
	local muzzle = weapon and weapon:FindFirstChild("MuzzleAttachment", true)
	local root = targetHumanoid and targetHumanoid.RootPart
	if not (muzzle and muzzle:IsA("Attachment") and root) then
		return noop
	end
	local endpoint = Instance.new("Attachment")
	endpoint.Name = "NpcAimLine"
	endpoint.Parent = root
	local beam = Instance.new("Beam")
	beam.Name = "NpcAimLine"
	beam.Attachment0 = muzzle
	beam.Attachment1 = endpoint
	beam.Color = ColorSequence.new(Combat.TELL_COLOR)
	beam.Transparency = NumberSequence.new(Combat.TELL_TRANSPARENCY)
	beam.Width0 = Combat.TELL_WIDTH
	beam.Width1 = Combat.TELL_WIDTH
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = muzzle.Parent
	Debris:AddItem(beam, Combat.TELL_MAX_SECONDS)
	Debris:AddItem(endpoint, Combat.TELL_MAX_SECONDS)
	return function()
		beam:Destroy()
		endpoint:Destroy()
	end
end

-- Whether the target is mid-roll: RollAuthority stamps RollingUntil (server os.clock) on the root of an accepted roll
-- (the client's own MoveAction attribute never reaches the server).
function NpcFire.isRolling(root: BasePart): boolean
	local untilTime = root:GetAttribute("RollingUntil")
	return typeof(untilTime) == "number" and os.clock() < untilTime
end

-- The aim cone in degrees at `targetRoot`: AimConfig's cone for the distance, the target's ground speed and the
-- template's `aim` overrides, widened by the focus ramp (`focusSeconds` of continuous sight), or the widest cone
-- against a rolling target.
function NpcFire.errorDegrees(aim, distance: number, targetRoot: BasePart, secondsSinceAcquired: number, focusSeconds: number): number
	local velocity = targetRoot.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local base = AimConfig.getErrorDegrees(distance, speed, secondsSinceAcquired, aim)
	local ceiling = (aim and aim.maxErrorDegrees) or AimConfig.MAX_ERROR_DEGREES
	return Combat.aimError(base, ceiling, focusSeconds, NpcFire.isRolling(targetRoot))
end

-- A shot's origin from `from` toward `aimPosition`, turned by a random angle inside `errorDegrees` (the same seeded
-- helper the weapon's own spread uses, offset so the two cones draw different numbers).
function NpcFire.aimOrigin(from: Vector3, aimPosition: Vector3, errorDegrees: number, seed: number): CFrame
	local origin = CFrame.lookAt(from, aimPosition)
	if errorDegrees <= 0 then
		return origin
	end
	local deviated = getRayDirections(origin, 1, math.rad(errorDegrees), seed + AimConfig.SEED_DECORRELATION_OFFSET)[1]
	return if deviated then CFrame.lookAt(from, from + deviated) else origin
end

return NpcFire
