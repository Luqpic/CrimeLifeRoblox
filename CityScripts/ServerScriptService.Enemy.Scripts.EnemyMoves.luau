--!strict
-- Enemies climb, vault and roll (developer picker 2026-11-20: "Climb ledges when chasing, Vault low walls, Roll to
-- dodge, Roll to reach cover"). EnemyAI calls in; the clips are the player's own group clips
-- (ReplicatedStorage.PlayerMovement.Animations: Roll, LedgeClimb), which play on any R15 rig, at Action4.
-- Climb and vault: an enemy that has been stuck (a MoveTo goal more than 3 studs away, under STUCK_SPEED for
-- STUCK_SECONDS) looks for an obstacle right in front; a top VAULT_MIN to CLIMB_MAX above its feet with room to stand
-- is gone over: the root is anchored and tweened up, then forward. Roll: 12 studs along the ground with the Roll
-- clip, only where the line is clear and there is ground at the end. While a move runs, EnemyAI.think waits
-- (ai.moveLockUntil).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local EnemyMoves = {}

EnemyMoves.STUCK_SPEED = 1.5
EnemyMoves.STUCK_SECONDS = 0.6
EnemyMoves.LOOK_AHEAD = 3 -- an obstacle this close in front, at knee height
EnemyMoves.TOP_PROBE = 0.7 -- its top is measured this far past the face the knee ray hit
EnemyMoves.CLIMB_MIN = 3.8 -- the player's own ledge limits (PlayerMovement.Config.Ledge)
EnemyMoves.CLIMB_MAX = 8
EnemyMoves.VAULT_MIN = 1.5
EnemyMoves.HEADROOM = 5
EnemyMoves.ROOT_HEIGHT = 3 -- root above the feet (R15)
EnemyMoves.CLIMB_SECONDS = 1.0
EnemyMoves.VAULT_SECONDS = 0.6
EnemyMoves.ROLL_DISTANCE = 12
EnemyMoves.ROLL_SECONDS = 0.62
EnemyMoves.ROLL_SPEED = 24
EnemyMoves.DODGE_CHANCE = 0.3
EnemyMoves.DODGE_COOLDOWN = 4
EnemyMoves.COVER_ROLL_MIN = 6

type Cast = (Vector3, Vector3) -> RaycastResult?

-- Pure: what an obstacle whose top is `height` studs above the feet calls for.
function EnemyMoves.ledgeKind(height: number): string?
	if height >= EnemyMoves.CLIMB_MIN and height <= EnemyMoves.CLIMB_MAX then
		return "climb"
	elseif height >= EnemyMoves.VAULT_MIN and height < EnemyMoves.CLIMB_MIN then
		return "vault"
	end
	return nil
end

-- An obstacle in front of feet at `feet` going `forward` (flat unit): its kind and where the root lands on top, or nil.
-- cast(origin, direction) is a raycast against solid world geometry.
function EnemyMoves.measureLedge(feet: Vector3, forward: Vector3, cast: Cast): (string?, Vector3?)
	local knee = feet + Vector3.yAxis
	local face = cast(knee, forward * EnemyMoves.LOOK_AHEAD)
	if not face then
		return nil, nil -- nothing in the way
	end
	local reach = Vector3.new(face.Position.X - knee.X, 0, face.Position.Z - knee.Z).Magnitude + EnemyMoves.TOP_PROBE
	local above = feet + forward * reach + Vector3.yAxis * (EnemyMoves.CLIMB_MAX + 0.5)
	local top = cast(above, -Vector3.yAxis * (EnemyMoves.CLIMB_MAX + 0.5))
	if not top then
		return nil, nil
	end
	local kind = EnemyMoves.ledgeKind(top.Position.Y - feet.Y)
	if not kind then
		return nil, nil
	end
	if cast(top.Position + Vector3.yAxis * 0.1, Vector3.yAxis * EnemyMoves.HEADROOM) then
		return nil, nil -- no room to stand on it
	end
	return kind, top.Position + forward * 1 + Vector3.yAxis * EnemyMoves.ROOT_HEIGHT
end

-- Solid world geometry: no characters (players, gangs, police), only parts that collide.
local function worldCast(origin: Vector3, direction: Vector3): RaycastResult?
	local ignore: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	for _, name in { "Enemies", "Police" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(ignore, folder)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	return Workspace:Raycast(origin, direction, params)
end
EnemyMoves.worldCast = worldCast

local function clipId(name: string): string?
	local folder = ReplicatedStorage:FindFirstChild("PlayerMovement")
	local animation = folder and folder:FindFirstChild("Animations") and folder.Animations:FindFirstChild(name, true)
	return if animation and animation:IsA("Animation") then animation.AnimationId else nil
end

local function play(ai: any, name: string, speed: number)
	ai.moveTracks = ai.moveTracks or {}
	local track: AnimationTrack? = ai.moveTracks[name]
	if not track then
		local animator = ai.humanoid:FindFirstChildOfClass("Animator")
		local id = clipId(name)
		if not (animator and id) then
			return
		end
		local ok, loaded = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = id
			return animator:LoadAnimation(animation)
		end)
		if not ok or not loaded then
			return
		end
		loaded.Priority = Enum.AnimationPriority.Action4
		ai.moveTracks[name] = loaded
		track = loaded
	end
	local t = track :: AnimationTrack
	t:Play(0.08)
	t:AdjustSpeed(speed)
end

local function busy(ai: any, now: number): boolean
	return ai.destroyed
		or ai.humanoid.Health <= 0
		or now < (ai.moveLockUntil or 0)
		or now < (ai.rootPart:GetAttribute("StunnedUntil") or 0)
		or ai.character:GetAttribute("Wounded") == true
end

-- Up and over to `landing` (the root's spot on top), anchored and tweened; the AI waits meanwhile.
local function goOver(ai: any, kind: string, landing: Vector3)
	local root: BasePart = ai.rootPart
	local seconds = if kind == "climb" then EnemyMoves.CLIMB_SECONDS else EnemyMoves.VAULT_SECONDS
	ai.moveLockUntil = os.clock() + seconds + 0.1
	ai:_clearPath()
	ai.humanoid:MoveTo(root.Position)
	play(ai, "LedgeClimb", if kind == "climb" then 1 else 1.6)
	local start = root.Position
	local forward = Vector3.new(landing.X - start.X, 0, landing.Z - start.Z)
	forward = if forward.Magnitude > 1e-3 then forward.Unit else Vector3.zAxis
	local risen = Vector3.new(start.X, landing.Y, start.Z)
	task.spawn(function()
		root.Anchored = true
		local up = TweenService:Create(root, TweenInfo.new(seconds * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ CFrame = CFrame.lookAt(risen, risen + forward) })
		up:Play()
		up.Completed:Wait()
		local over = TweenService:Create(root, TweenInfo.new(seconds * 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ CFrame = CFrame.lookAt(landing, landing + forward) })
		over:Play()
		over.Completed:Wait()
		if root.Parent then
			root.Anchored = false
		end
	end)
end

-- EnemyAI.think, each think in a moving state: true when a stuck enemy started a climb or vault (think stops there).
function EnemyMoves.checkStuck(ai: any, now: number): boolean
	local root: BasePart = ai.rootPart
	local goal = ai.humanoid.WalkToPoint
	local toGoal = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
	local velocity = root.AssemblyLinearVelocity
	if ai.humanoid.WalkSpeed <= 0 or toGoal.Magnitude <= 3 or Vector3.new(velocity.X, 0, velocity.Z).Magnitude >= EnemyMoves.STUCK_SPEED then
		ai.stuckSince = nil
		return false
	end
	ai.stuckSince = ai.stuckSince or now
	if now - ai.stuckSince < EnemyMoves.STUCK_SECONDS or busy(ai, now) then
		return false
	end
	ai.stuckSince = nil
	local feet = root.Position - Vector3.yAxis * EnemyMoves.ROOT_HEIGHT
	local kind, landing = EnemyMoves.measureLedge(feet, toGoal.Unit, worldCast)
	if kind and landing then
		goOver(ai, kind, landing)
		return true
	end
	return false
end

-- EnemyAI.think: a path's Jump waypoint is held (ai.jumpAt) until the enemy is near the obstacle. One it can climb
-- or vault is gone over with the clip instead of a hop (the pathfinder jumps humanoids up about 7 studs); anything
-- else (a gap, a step) still jumps once within 3 studs of the waypoint. True when a climb or vault started.
function EnemyMoves.checkJump(ai: any, now: number): boolean
	local at: Vector3? = ai.jumpAt
	if not at or busy(ai, now) then
		return false
	end
	local root: BasePart = ai.rootPart
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude > 1e-3 then
		local kind, landing = EnemyMoves.measureLedge(root.Position - Vector3.yAxis * EnemyMoves.ROOT_HEIGHT, look.Unit, worldCast)
		if kind and landing then
			ai.jumpAt = nil
			goOver(ai, kind, landing)
			return true
		end
	end
	if Vector3.new(at.X - root.Position.X, 0, at.Z - root.Position.Z).Magnitude <= 3 then
		ai.jumpAt = nil
		ai.humanoid.Jump = true
	end
	return false
end

-- A 12-stud (at most) roll toward `target`, where the line is clear and there is ground at the end. True if it rolls.
function EnemyMoves.rollTo(ai: any, target: Vector3): boolean
	local now = os.clock()
	if busy(ai, now) then
		return false
	end
	local root: BasePart = ai.rootPart
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	if flat.Magnitude < 1 then
		return false
	end
	local destination = root.Position + flat.Unit * math.min(flat.Magnitude, EnemyMoves.ROLL_DISTANCE)
	if worldCast(root.Position, destination - root.Position) then
		return false -- something in the way
	end
	if not worldCast(destination, -Vector3.yAxis * (EnemyMoves.ROOT_HEIGHT + 3)) then
		return false -- no ground there
	end
	ai.moveLockUntil = now + EnemyMoves.ROLL_SECONDS
	root:SetAttribute("RollingUntil", now + EnemyMoves.ROLL_SECONDS)
	ai:_clearPath()
	local humanoid: Humanoid = ai.humanoid
	humanoid.WalkSpeed = EnemyMoves.ROLL_SPEED
	humanoid:MoveTo(destination)
	play(ai, "Roll", 1)
	task.delay(EnemyMoves.ROLL_SECONDS, function()
		if not ai.destroyed and humanoid.Health > 0 and humanoid.WalkSpeed == EnemyMoves.ROLL_SPEED then
			humanoid.WalkSpeed = ai.config.walkSpeed
		end
	end)
	return true
end

-- EnemyAI.onDamagedBy for a gun enemy fighting: sometimes (DODGE_CHANCE, DODGE_COOLDOWN) roll sideways from the shooter.
function EnemyMoves.dodge(ai: any, from: Vector3): boolean
	local now = os.clock()
	if now - (ai.lastDodge or -math.huge) < EnemyMoves.DODGE_COOLDOWN or math.random() >= EnemyMoves.DODGE_CHANCE then
		return false
	end
	local root: BasePart = ai.rootPart
	local away = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)
	if away.Magnitude < 1e-3 then
		return false
	end
	local side = away.Unit:Cross(Vector3.yAxis)
	if math.random() < 0.5 then
		side = -side
	end
	for _ = 1, 2 do
		if EnemyMoves.rollTo(ai, root.Position + side * EnemyMoves.ROLL_DISTANCE) then
			ai.lastDodge = now
			return true
		end
		side = -side
	end
	return false
end

return EnemyMoves
