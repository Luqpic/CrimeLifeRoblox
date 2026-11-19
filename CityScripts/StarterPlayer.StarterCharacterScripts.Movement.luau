--[[ StarterCharacterScripts.Movement: the player's movement animations and moves (ported from OBT Revamp, 2026-11-20).

	Plays the movement clips in ReplicatedStorage.PlayerMovement.Animations:
	  ground   Idle, Walk / Jog / Run in four directions (_F/B/L/R), Sprint. Speed picks the kind, the move direction
	           (relative to where the body faces) blends the four directions, so diagonals and strafes come out of two
	           clips. Tracks of one kind share a phase, and a kind fading in takes over the phase of the one fading out.
	  air      Jump, Fall, then Land / LandHard by the speed of the touchdown
	  other    Climb, Swim / SwimIdle
	  moves    Roll (Q, B on a pad, a touch button), LedgeClimb (Space or the jump button facing a ledge in reach)
	Holding a tool: the full-body loops drop to Core priority (the tool's hold animation wins the upper body) and a
	legs-only copy of each plays at Action4 on top, so the legs keep moving under any hold. During a move the legs
	layer steps aside.
	CrimeLife: Animate2 keeps WalkSpeed, sprint input, landing recovery, sitting and the sprint FOV, and plays no
	locomotion clip while character attribute MovementAnimations is set (here). While crouched (root attribute
	IsCrouching) this script steps aside for Crouching's clips. No roll or ledge climb while dead, seated, ragdolled
	(the baton stun), frozen, crouched, carrying anything, or with a panel open. A clip that does not load plays the
	Roblox default of its kind (PlayerMovement.Fallback). The roll's stamina is the server's: this checks the
	replicated Stamina, fires PlayerMovement.Roll, and ServerScriptService.Movement.Scripts.RollAuthority re-checks
	and spends it. Character attribute MoveAction is "Roll" / "Ledge" while a move runs. Numbers: PlayerMovement.Config.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CAS = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PM = ReplicatedStorage:WaitForChild("PlayerMovement")
local C = require(PM:WaitForChild("Config"))
local fallbackFor = require(PM:WaitForChild("Fallback"))
local anims = PM:WaitForChild("Animations")
local rollRemote = PM:WaitForChild("Roll")
local MovementConstants = require(ReplicatedStorage:WaitForChild("Movement"):WaitForChild("Constants"))
local Panels = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Panels"))

local owner = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local root = character:WaitForChild("HumanoidRootPart")
local animator = humanoid:WaitForChild("Animator")
local S = Enum.HumanoidStateType

-- priorities and looping are set here, not trusted from the asset (a track reads Action until its asset has loaded)
local P = Enum.AnimationPriority
local MOVES = { Land = true, LandHard = true, Roll = true, LedgeClimb = true }
local ONCE = { Jump = true, Land = true, LandHard = true, Roll = true, LedgeClimb = true }
local function priorityOf(name)
	if name:find("Legs$") then return P.Action4 end
	if MOVES[name] then return P.Action2 end
	return name == "Idle" and P.Idle or P.Movement
end
local tracks, basePriority = {}, {}
local function load(name, animation)
	local t = animator:LoadAnimation(animation)
	t.Priority = priorityOf(name)
	t.Looped = not ONCE[(name:gsub("Legs$", ""))]
	tracks[name], basePriority[name] = t, t.Priority
end
local clips = {}
for _, a in anims:GetChildren() do
	if a:IsA("Animation") and a.AnimationId ~= "" and a.Name ~= "Empty" then
		load(a.Name, a)
		table.insert(clips, a)
	end
end
character:SetAttribute("MovementAnimations", true) -- Animate2 stops its locomotion clips

-- a clip that did not load (a failed fetch, or Length still 0 after Config.FallbackWait) plays the Roblox default of
-- its kind; one with no default (a legs copy, Land, LandHard, Roll, LedgeClimb) is dropped: the move still runs
task.spawn(function()
	local failed = {}
	pcall(ContentProvider.PreloadAsync, ContentProvider, clips, function(id, status)
		if status == Enum.AssetFetchStatus.Failure then failed[id] = true end
	end)
	local deadline = os.clock() + C.FallbackWait
	repeat
		local waiting = false
		for _, a in clips do
			local t = tracks[a.Name]
			if t and t.Length == 0 and not failed[a.AnimationId] then waiting = true break end
		end
		if waiting then task.wait(0.2) end
	until not waiting or os.clock() > deadline
	if not character.Parent then return end
	local swapped = {}
	for _, a in clips do
		local t = tracks[a.Name]
		if t and (t.Length == 0 or failed[a.AnimationId]) then
			t:Stop(0)
			tracks[a.Name], basePriority[a.Name] = nil, nil
			local id = fallbackFor(a.Name)
			if id then
				local stand = Instance.new("Animation")
				stand.Name, stand.AnimationId = a.Name, id
				load(a.Name, stand)
			end
			table.insert(swapped, a.Name .. (id and " -> default" or " skipped"))
		end
	end
	if #swapped > 0 then warn("Movement: clips that did not load: " .. table.concat(swapped, ", ")) end
end)

-- stride scale of this avatar: hip joint to the bottom of the foot, at rest, against the rig's (Config.RigLegLength)
local function legScale()
	local hip = character:FindFirstChild("LeftHip", true)
	local foot = character:FindFirstChild("LeftFoot")
	local upper = character:FindFirstChild("LeftUpperLeg")
	local knee = character:FindFirstChild("LeftKnee", true)
	local ankle = character:FindFirstChild("LeftAnkle", true)
	if not (hip and foot and upper and knee and ankle) then return 1 end
	-- rest chain lengths from the joints' own offsets (independent of the pose being played)
	local thigh = (hip.C1.Position - knee.C0.Position).Magnitude
	local shin = (knee.C1.Position - ankle.C0.Position).Magnitude
	local sole = foot.Size.Y / 2 + ankle.C1.Position.Y -- ankle above the foot centre, down to the sole
	return math.clamp((thigh + shin + sole) / C.RigLegLength, 0.5, 2)
end
local legs = legScale()

local function ramp(x, band) return math.clamp((x - band[1]) / (band[2] - band[1]), 0, 1) end
local function ease(t) return t * t * (3 - 2 * t) end

-- ======================= loop weights =======================
local weight, target, rate = {}, {}, {}
local function want(name, w, speed)
	if tracks[name] and w > 0 then
		target[name] = (target[name] or 0) + w
		if speed then rate[name] = speed end
	end
end

local KINDS = {
	Walk = { "Walk_F", "Walk_B", "Walk_L", "Walk_R" },
	Jog = { "Jog_F", "Jog_B", "Jog_L", "Jog_R" },
	Run = { "Run_F", "Run_B", "Run_L", "Run_R" },
	Sprint = { "Sprint" },
}
local function kindWeight(kind)
	local w = 0
	for _, n in KINDS[kind] do w += weight[n] or 0 end
	return w
end
local function phase(kind) -- normalised phase of the strongest track of a kind
	local best, bw = nil, 0
	for _, n in KINDS[kind] do
		local t = tracks[n]
		if t and t.IsPlaying and (weight[n] or 0) > bw and t.Length > 0 then best, bw = t, weight[n] end
	end
	return best and best.TimePosition / best.Length
end

local function applyWeights(dt, toolHeld, inMove)
	local a = 1 - math.exp(-C.Fade * dt)
	-- the legs layer copies the full-body weights while a tool is held (not during a move)
	if toolHeld and not inMove then
		for name, w in pairs(table.clone(target)) do
			if tracks[name .. "Legs"] then
				target[name .. "Legs"], rate[name .. "Legs"] = w, rate[name]
			end
		end
	end
	-- a kind fading in starts on the phase of the strongest moving kind
	local lead
	for kind in KINDS do
		local p = kindWeight(kind) > 0.05 and phase(kind)
		if p then lead = p break end
	end
	for name, t in tracks do
		if not t.Looped then continue end
		local cur = weight[name] or 0
		local goal = target[name] or 0
		cur += (goal - cur) * a
		if math.abs(goal - cur) < 0.002 then cur = goal end
		if cur > 0.001 then
			if not t.IsPlaying then
				t:Play(0, cur, rate[name] or 1)
				if lead and t.Length > 0 then t.TimePosition = lead * t.Length end
			else
				t:AdjustWeight(cur, 0)
				t:AdjustSpeed(rate[name] or 1)
			end
		elseif t.IsPlaying then
			t:Stop(0)
			cur = 0
		end
		weight[name] = cur
	end
	-- keep each kind (and each legs copy) on one clock, by fraction of the clip (a default stand-in differs in length)
	for _, list in KINDS do
		local master
		for _, n in list do
			local t = tracks[n]
			if t and t.IsPlaying and (not master or (weight[n] or 0) > (weight[master.Name] or 0)) then master = t end
		end
		if master then
			for _, n in list do
				for _, m in { n, n .. "Legs" } do
					local t = tracks[m]
					local at = master.Length > 0 and t and t.Length > 0 and master.TimePosition / master.Length * t.Length or master.TimePosition
					if t and t ~= master and t.IsPlaying and math.abs(t.TimePosition - at) > 0.03 then
						t.TimePosition = at
					end
				end
			end
		end
	end
	for name, t in tracks do -- priorities: full-body loops step under a held tool
		if t.Looped and not name:find("Legs$") and basePriority[name] then
			local p = toolHeld and P.Core or basePriority[name]
			if t.Priority ~= p then t.Priority = p end
		end
	end
end

-- ======================= one-shots =======================
local function play(name, fade, w, speed)
	local t = tracks[name]
	if not t then return end
	t:Play(fade or 0.1, w or 1, speed or 1)
	return t
end
local jumpTrack, landTrack -- the one playing now (full or legs copy)

-- ======================= moves =======================
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { character }
-- (CrimeLife) only what a body can stand on or bump into: the city's night-light slabs (invisible, not colliding,
-- 13.5 studs up over every road) failed every ledge's head room and could pass for a ledge top themselves
params.RespectCanCollide = true
local function cast(from, dir) return workspace:Raycast(from, dir, params) end
local function hrpHeight() return humanoid.HipHeight + root.Size.Y / 2 end
local function flatLook()
	local l = root.CFrame.LookVector
	return Vector3.new(l.X, 0, l.Z).Unit
end

local move -- the running move: {name, t0, T, ...}
local ready = { Roll = 0 }
local att = Instance.new("Attachment")
att.Name = "MovementAttachment"
att.Parent = root
local turnedOff = false -- AutoRotate switched off by a move

local function newVelocity(planar)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.MaxForce = root.AssemblyMass * workspace.Gravity * 25 -- wins over the Humanoid's own braking (OBT: mass x 600 rolled 0.5 studs)
	if planar then
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis, lv.SecondaryTangentAxis = Vector3.xAxis, Vector3.zAxis
	end
	lv.Parent = root
	return lv
end

local function endMove(exitVelocity)
	if not move then return end
	for _, i in move.instances do i:Destroy() end
	for part, was in move.limbs or {} do part.CanCollide = was end
	if move.track then move.track:Stop(0.2) end
	if move.physics then
		humanoid:ChangeState(S.Freefall)
		if exitVelocity then root.AssemblyLinearVelocity = exitVelocity end
	end
	-- back on: the only client writer that wants it off (CustomShiftLock) sets it again every frame
	if turnedOff then humanoid.AutoRotate = true end
	turnedOff = false
	if ready[move.name] then ready[move.name] = os.clock() + C[move.name].Cooldown end
	character:SetAttribute("MoveAction", nil)
	move = nil
end

local function begin(name, T, trackName, extra)
	move = extra or {}
	move.name, move.t0, move.T, move.instances = name, os.clock(), T, move.instances or {}
	local t = tracks[trackName]
	if t then
		move.track = play(trackName, 0.08, 1, t.Looped and 1 or (t.Length > 0 and t.Length / T or 1))
	end
	character:SetAttribute("MoveAction", name == "LedgeClimb" and "Ledge" or name)
end

local function grounded()
	local s = humanoid:GetState()
	return s == S.Running or s == S.RunningNoPhysics or s == S.Landed
end
local function carrying()
	if character:GetAttribute(MovementConstants.CARRY_SPEED_CAP_ATTRIBUTE) ~= nil then return true end
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("IsSupplyCarryTool") == true
end
-- (CrimeLife stand-in for OBT's Locomotion.blocked) a move may not start; the baton stun's StunnedUntil runs on the
-- server's clock, but the stun staggers the body (IsRagdolled) for exactly that window, so that is what is read here
local function blocked()
	return humanoid.Health <= 0 or humanoid.Sit or humanoid.PlatformStand or root.Anchored
		or character:GetAttribute("IsRagdolled") == true
		or character:GetAttribute("AdminFrozen") == true or owner:GetAttribute("AdminFrozen") == true
		or root:GetAttribute("IsCrouching") == true or carrying()
		or Panels.current() ~= nil
end

local function startRoll()
	if move or blocked() or not grounded() or os.clock() < ready.Roll then return end
	if (root:GetAttribute(MovementConstants.STAMINA_ATTRIBUTE) or 0) < C.Roll.Stamina then return end
	local md = humanoid.MoveDirection
	local dir = md.Magnitude > 0.1 and Vector3.new(md.X, 0, md.Z).Unit or flatLook()
	local onward = dir:Dot(flatLook()) > 0.5 -- (the way the body faces: a sprint backwards behind a gun isn't run-up)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	turnedOff = humanoid.AutoRotate
	humanoid.AutoRotate = false
	-- from a sprint (the server's IsSprinting) it goes further: longer and faster, Config.Roll.Sprint
	local sp = root:GetAttribute(MovementConstants.SPRINTING_ATTRIBUTE) and onward and C.Roll.Sprint
	begin("Roll", C.Roll.Time * (sp and sp.Time or 1), "Roll",
		{ dir = dir, speed = (sp and sp.Distance / sp.Time or 1) * C.Roll.Reach, instances = { newVelocity(true) } })
	rollRemote:FireServer()
end

-- path moves (LedgeClimb): Physics state, steered through waypoints {position, time 0..1}, held upright.
-- (CrimeLife) in the Physics state the Humanoid lets the limbs collide again: a foot caught under the lip held the
-- body below the top (measured 2026-11-20). The limbs stay out of collisions for the move and get their own values back.
local KEEP_COLLIDING = { HumanoidRootPart = true, UpperTorso = true, LowerTorso = true }
local function drive(name, T, pts, exitVelocity)
	local limbs = {}
	for _, part in character:GetChildren() do
		if part:IsA("BasePart") and not KEEP_COLLIDING[part.Name] then limbs[part] = part.CanCollide end
	end
	local lv = newVelocity(false)
	local ao = Instance.new("AlignOrientation")
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.RigidityEnabled = true
	ao.CFrame = CFrame.lookAt(Vector3.zero, flatLook())
	ao.Parent = root
	humanoid:ChangeState(S.Physics)
	table.insert(pts, 1, { root.Position, 0 })
	begin(name, T, name, { pts = pts, physics = true, exit = exitVelocity, instances = { lv, ao }, limbs = limbs })
end

local function tryLedge()
	local Lg = C.Ledge
	if move or blocked() then return end
	local fwd = flatLook()
	local h = hrpHeight()
	local feet = root.Position.Y - h
	local wall = cast(root.Position + Vector3.new(0, 0.5, 0), fwd * Lg.Reach)
	if not wall or math.abs(wall.Normal.Y) > 0.3 then return end
	local edge = wall.Position + fwd * 0.4
	local top = cast(Vector3.new(edge.X, feet + Lg.MaxHeight + 1, edge.Z), Vector3.new(0, -(Lg.MaxHeight + 1 - Lg.MinHeight + 0.5), 0))
	if not top or top.Normal.Y < 0.7 then return end
	local height = top.Position.Y - feet
	if height < Lg.MinHeight or height > Lg.MaxHeight then return end
	local y = top.Position.Y
	local stand = wall.Position + fwd * 1.2
	if cast(Vector3.new(stand.X, y + 0.2, stand.Z), Vector3.new(0, 2 * h, 0)) then return end -- no head room up there
	local face = Vector3.new(wall.Position.X, 0, wall.Position.Z) - fwd * 0.7
	drive("LedgeClimb", Lg.Time, { -- matched to the clip: pull up to 30%, chest over and knee up by 62%, step up to the end
		{ face + Vector3.new(0, y - 0.5, 0), 0.3 },
		{ face + fwd * 0.5 + Vector3.new(0, y + h - 0.7, 0), 0.62 },
		{ Vector3.new(stand.X, y + h + 0.1, stand.Z), 1.0 },
	}, Vector3.zero)
end

-- Catmull-Rom through {position, time 0..1} points, eased so the move starts and ends gently
local function curve(pts, a)
	a = a * a * (3 - 2 * a)
	for i = 1, #pts - 1 do
		local p1, p2 = pts[i], pts[i + 1]
		if a <= p2[2] or i == #pts - 1 then
			local p0 = pts[i - 1] or { p1[1] * 2 - p2[1] }
			local p3 = pts[i + 2] or { p2[1] * 2 - p1[1] }
			local x = math.clamp((a - p1[2]) / (p2[2] - p1[2]), 0, 1)
			local A, B, Cc, D = p0[1], p1[1], p2[1], p3[1]
			return 0.5 * (2 * B + (Cc - A) * x + (2 * A - 5 * B + 4 * Cc - D) * x * x + (3 * B - A - 3 * Cc + D) * x * x * x)
		end
	end
	return pts[#pts][1]
end

local function stepMove()
	local a = (os.clock() - move.t0) / move.T
	if move.name == "Roll" then
		local M = C.Roll
		local v = (M.StartSpeed + (M.EndSpeed - M.StartSpeed) * ease(math.min(a, 1))) * (move.speed or 1)
		move.instances[1].PlaneVelocity = Vector2.new(move.dir.X, move.dir.Z) * v
		local real = root.AssemblyLinearVelocity
		local stuck = a > 0.3 and Vector3.new(real.X, 0, real.Z).Magnitude < v * 0.35 -- ran into something
		if a >= 1 or stuck or humanoid.PlatformStand then endMove() end
		return
	end
	for part in move.limbs do part.CanCollide = false end
	if a >= 1 then
		-- the body follows the curve a little behind it: settle onto the end point (at most 0.3 s) before letting go,
		-- or a ledge climb that ends a few tenths short drops back off the edge
		local goal = move.pts[#move.pts][1]
		local miss = goal - root.Position
		if miss.Magnitude > 0.2 and a < 1 + 0.3 / move.T then
			move.instances[1].VectorVelocity = miss * 12
			return
		end
		return endMove(move.exit)
	end
	-- one smooth curve through the waypoints (straight segments started and stopped at each one: a jerky climb)
	local here, ahead = curve(move.pts, a), curve(move.pts, math.min(a + 0.03, 1))
	local v = (ahead - here) / (0.03 * move.T) + (here - root.Position) * 12
	move.instances[1].VectorVelocity = v.Magnitude > 80 and v.Unit * 80 or v
end

-- which character holds the roll binding: a newer character's Movement takes it, and only the holder unbinds
local bindId = (owner:GetAttribute("MovementBind") or 0) + 1
owner:SetAttribute("MovementBind", bindId)
CAS:BindAction("MovementRoll", function(_, state, input)
	-- B is also "back" on a pad: while the GUI cursor is on a menu it belongs to the menu, not the roll
	if input and input.KeyCode == C.Roll.PadKey and GuiService.SelectedObject ~= nil then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then startRoll() end
	return Enum.ContextActionResult.Pass
end, true, C.Roll.Key, C.Roll.PadKey)
CAS:SetTitle("MovementRoll", "Roll")
CAS:SetPosition("MovementRoll", C.Roll.TouchPosition)
local rollButton = CAS:GetButton("MovementRoll") -- nil without a touch screen
if rollButton then rollButton.Size = UDim2.fromOffset(C.Roll.TouchSize, C.Roll.TouchSize) end
-- other scripts can ask for a move: script.Do:Fire("Roll" | "Ledge") (the same checks as the keys apply)
local doEvent = Instance.new("BindableEvent")
doEvent.Name = "Do"
doEvent.Parent = script
doEvent.Event:Connect(function(name)
	if name == "Roll" then startRoll() elseif name == "Ledge" then tryLedge() end
end)
local jumpConn = UIS.JumpRequest:Connect(function()
	if not move and humanoid:GetState() ~= S.Climbing then tryLedge() end
end)

-- ======================= state =======================
local airVy, climbVy = 0, 0
humanoid.StateChanged:Connect(function(_, new)
	if move and move.physics then return end
	local toolHeld = character:FindFirstChildOfClass("Tool") ~= nil
	if new == S.Jumping then
		jumpTrack = play(toolHeld and "JumpLegs" or "Jump", 0.05)
	elseif new == S.Landed then
		local v = root.AssemblyLinearVelocity
		local moving = Vector3.new(v.X, 0, v.Z).Magnitude > 4
		local name = -airVy > C.LandHardAbove and "LandHard" or -airVy > C.LandSoftAbove and "Land" or nil
		if name and not move then
			landTrack = play(toolHeld and name .. "Legs" or name, 0.05, moving and C.LandMovingWeight or 1)
		end
		airVy = 0
	end
end)

local stepConn = RunService.Heartbeat:Connect(function(dt)
	if humanoid.Health <= 0 then return end
	target, rate = {}, {}
	local state = humanoid:GetState()
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	local toolHeld = character:FindFirstChildOfClass("Tool") ~= nil
	if state == S.Freefall or state == S.Jumping then airVy = math.min(airVy, v.Y) end
	if move then stepMove() end

	local mul = 1 -- a landing on the legs layer takes its share from the loops
	if landTrack and landTrack.IsPlaying and landTrack.Animation.Name:find("Legs$") then mul = 1 - landTrack.WeightCurrent end
	if root:GetAttribute("IsCrouching") == true then
		-- Crouching plays its own clips: nothing of ours under them
	elseif state == S.Climbing then
		-- trusses climb rung by rung (vertical speed jumps 11 -> 0.2 -> 11): smooth it, or the hands stutter
		climbVy += (v.Y - climbVy) * (1 - math.exp(-5 * dt))
		local cv = climbVy
		want("Climb", 1, math.abs(cv) < 0.5 and 0 or math.clamp(math.abs(cv) / (C.BaseSpeed.Climb * legs), 0.3, 2) * math.sign(cv))
	elseif state == S.Swimming then
		local k = ramp(speed, { 1, 4 })
		want("SwimIdle", 1 - k)
		want("Swim", k, math.clamp(speed / C.BaseSpeed.Swim, 0.5, 1.6))
	elseif state == S.Freefall or state == S.Jumping then
		local jumping = jumpTrack and jumpTrack.IsPlaying and jumpTrack.TimePosition < jumpTrack.Length * 0.75
		want("Fall", jumping and 0 or 1)
	elseif grounded() or (move and move.physics) then
		local moving = speed > C.IdleBelow -- by real velocity: MoveDirection reads 0 under Humanoid:MoveTo
		if not moving then
			want("Idle", mul)
		else
			local look, right = root.CFrame.LookVector, root.CFrame.RightVector
			local fx, rx = flat:Dot(look), flat:Dot(right)
			local d = { F = math.max(fx, 0), B = math.max(-fx, 0), R = math.max(rx, 0), L = math.max(-rx, 0) }
			local sum = d.F + d.B + d.R + d.L
			for k, x in d do d[k] = x / sum end
			local jog = ramp(speed, C.WalkToJog)
			local run = jog * ramp(speed, C.JogToRun)
			local sprint = run * ramp(speed, C.RunToSprint) * d.F -- only forward; a sprint-speed strafe stays a run
			local walk = 1 - jog
			jog -= run
			run -= sprint
			local PS = C.PlaySpeed
			local function kind(name, w)
				if w <= 0 then return end
				local r = math.clamp(speed / (C.BaseSpeed[name] * legs), PS.Min, PS.Max)
				for k, x in d do want(name .. "_" .. k, w * x * mul, r) end
			end
			kind("Walk", walk)
			kind("Jog", jog)
			kind("Run", run)
			want("Sprint", sprint * mul, math.clamp(speed / (C.BaseSpeed.Sprint * legs), PS.Min, PS.Max))
		end
	end
	applyWeights(dt, toolHeld, move ~= nil)
end)

local stopped = false
local function stop()
	if stopped then return end
	stopped = true
	endMove()
	stepConn:Disconnect()
	jumpConn:Disconnect()
	if owner:GetAttribute("MovementBind") == bindId then CAS:UnbindAction("MovementRoll") end
	for _, t in tracks do t:Stop(0.3) end
	character:SetAttribute("MovementAnimations", nil)
end
humanoid.Died:Connect(stop)
-- a character replaced without a death (LoadCharacter): this one's roll binding must go
owner.CharacterAdded:Connect(function(c) if c ~= character then stop() end end)
