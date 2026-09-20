-- Exports the authored viewmodel joint motion as editable KeyframeSequences.
-- Viewmodel rigs only (ReplicatedStorage.Blaster.ViewModels): Root -> Body -> Magazine/RightArm/
-- ChargingHandle, LeftArm under Magazine or Body depending on the weapon. The character rig is
-- never touched.
--
-- Every Pose is Enum.PoseEasingStyle.Linear. WeaponViewmodelMotion already interpolates linearly,
-- so emitting the authored key times verbatim reproduces the runtime pose exactly; only the
-- recoil spring, which is an ODE rather than a keyed track, is resampled at 30 Hz.
--
-- Run in Edit mode. Output: ServerStorage.ViewmodelKeyframeSequences.<class|weapon>.<clip>

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion)
local ViewModels = ReplicatedStorage.Blaster.ViewModels

-- Generic class clips use representatives that are NOT in the module's `showcase` table, so the
-- exported track is the class track. The three showcase weapons are exported separately, by name,
-- because their carry pose and reload phrasing are authored per weapon and would otherwise be lost.
local TARGETS = {
	{out = "rifle",    vm = "AR-18"},
	{out = "rock",     vm = "AKM"},
	{out = "pistol",   vm = "M1911"},
	{out = "revolver", vm = "Mateba 2006M"},
	{out = "shell",    vm = "Benelli M4"},
	{out = "pump",     vm = "Spas 12"},
	{out = "bullpup",  vm = "AUG A-3"},
	{out = "top",      vm = "FN P90"},
	{out = "melee",    vm = "Crowbar"},
	{out = "AK47",         vm = "AK47"},
	{out = "Glock 17",     vm = "Glock 17"},
	{out = "Mossberg 590", vm = "Mossberg 590"},
}

local PRIORITY = {
	Idle = Enum.AnimationPriority.Idle,
	Equip = Enum.AnimationPriority.Action,
}

local function findTool(vmName)
	for _, d in ServerStorage.Weapons:GetDescendants() do
		if d:IsA("Tool") and d:GetAttribute("viewModel") == vmName then return d end
	end
	return nil
end

-- Sorted unique times, deduped at 1e-4 so float noise cannot emit two keyframes on one frame.
local function union(...)
	local seen, list = {}, {}
	for _, set in {...} do
		for _, t in set do
			local key = math.floor(t * 10000 + 0.5)
			if not seen[key] then seen[key] = true; table.insert(list, key / 10000) end
		end
	end
	table.sort(list)
	return list
end

local function trackTimes(tracks)
	local times = {}
	for _, keys in tracks do
		for _, key in keys do table.insert(times, key[1]) end
	end
	return times
end

local function rigTree(model)
	local children, joints = {}, {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			children[d.Part0.Name] = children[d.Part0.Name] or {}
			table.insert(children[d.Part0.Name], d.Part1.Name)
			joints[d.Part1.Name] = d
		end
	end
	return children, joints
end

-- Motor6D drives Part1 by Part0.CFrame * C0 * Transform * C1:Inverse(). The motion module bakes its
-- pose into C0 and holds Transform at identity; an animation does the reverse. So the Pose CFrame
-- that reproduces the current joint is original C0 inverse times the posed C0.
local function buildKeyframe(time, m, children, joints, rootName)
	local kf = Instance.new("Keyframe")
	kf.Name = "Keyframe"
	kf.Time = time
	local function addPose(partName, parent)
		local p = Instance.new("Pose")
		p.Name = partName
		p.Weight = 1
		p.EasingStyle = Enum.PoseEasingStyle.Linear
		p.EasingDirection = Enum.PoseEasingDirection.In
		local joint = joints[partName]
		local tracked = m.joints[partName]
		p.CFrame = if joint and tracked then tracked.original:Inverse() * joint.C0 else CFrame.identity
		p.Parent = parent
		for _, child in children[partName] or {} do addPose(child, p) end
	end
	addPose(rootName, kf)
	return kf
end

local function newSequence(name, loop)
	local seq = Instance.new("KeyframeSequence")
	seq.Name = name
	seq.Loop = loop or false
	seq.Priority = PRIORITY[name] or Enum.AnimationPriority.Action4
	return seq
end

local report = {}
local root = ServerStorage:FindFirstChild("ViewmodelKeyframeSequences")
if root then root:Destroy() end
root = Instance.new("Folder")
root.Name = "ViewmodelKeyframeSequences"
root.Parent = ServerStorage

local totalClips, totalKeys, totalMarkers = 0, 0, 0

for _, target in TARGETS do
	local template = ViewModels:FindFirstChild(target.vm)
	if not template then table.insert(report, target.out .. " :: VIEWMODEL MISSING") continue end
	local tool = findTool(target.vm)
	if not tool then table.insert(report, target.out .. " :: TOOL MISSING") continue end

	local reloadTime = tool:GetAttribute("reloadTime") or 0
	local swingDelay = tool:GetAttribute("swingDelay") or 0.2

	local vm = template:Clone()
	vm.Parent = workspace
	local children, joints = rigTree(vm)
	local rootName = vm.PrimaryPart.Name
	local m = Motion.new(vm, tool)
	local folder = Instance.new("Folder")
	folder.Name = target.out
	folder.Parent = root

	local made = {}
	local function emit(clipName, duration, times, setState, markers, loop)
		local seq = newSequence(clipName, loop)
		local pending = {}
		if markers then
			for _, entry in markers do table.insert(pending, {entry[1], entry[2]}) end
		end
		for _, t in times do
			m:reset()
			m.active = true
			setState(t)
			m:step(0, 0, false)
			local kf = buildKeyframe(t * duration, m, children, joints, rootName)
			for _, entry in pending do
				if math.abs(entry[1] - t) < 1e-4 then
					local marker = Instance.new("KeyframeMarker")
					marker.Name = entry[2]
					marker.Parent = kf
					totalMarkers += 1
				end
			end
			kf.Parent = seq
			totalKeys += 1
		end
		seq.Parent = folder
		totalClips += 1
		table.insert(made, ("%s(%dkf, %.2fs)"):format(clipName, #seq:GetChildren(), duration))
	end

	-- Idle. Joints sit at rest, except the three showcase weapons whose carry pose is a real joint
	-- offset. Breathing, walk bob, sprint lean and the ADS offset are pivot-level in the controller,
	-- not joint motion, so they are deliberately absent here.
	emit("Idle", 1, {0, 1}, function() end, nil, true)

	-- Equip. sample() keys are Body {0,.65,1} and LeftArm {0,.8,1}.
	emit("Equip", m.equipTime, union({0, 0.65, 0.8, 1}), function(t)
		m.equipAge = t * m.equipTime
	end)

	if m.kind == "melee" then
		local hit = math.max(swingDelay, 0.05)
		local duration = hit + 0.27
		local contact = hit / duration
		local times = union({0, contact * 0.55, contact, math.min(contact + 0.14, 1), 1})
		for _, variant in {"Shoot", "Shoot2", "Shoot3"} do
			emit(variant, duration, times, function(t)
				m.swing = {age = t * duration, hit = hit, duration = duration, variant = variant}
			end)
		end
	else
		-- Recoil is a critically damped spring, so it is integrated at 60 Hz and keyed at 30 Hz.
		local dt = 1 / 60
		local elapsed = 0
		m:reset(); m.active = true; m:shoot()
		local seq = newSequence("Shoot")
		local index = 0
		repeat
			local kf = buildKeyframe(elapsed, m, children, joints, rootName)
			if index % 2 == 0 then kf.Parent = seq; totalKeys += 1 else kf:Destroy() end
			m:step(dt, 0, false)
			elapsed += dt
			index += 1
		until math.abs(m.recoil) < 0.002 and math.abs(m.recoilVelocity) < 0.02 or elapsed > 0.9
		local last = buildKeyframe(elapsed, m, children, joints, rootName)
		last.Parent = seq
		totalKeys += 1
		seq.Parent = folder
		totalClips += 1
		table.insert(made, ("Shoot(%dkf, %.2fs)"):format(#seq:GetChildren(), elapsed))

		if reloadTime > 0 then
			emit("Reload", reloadTime, union(trackTimes(m.tracks), trackTimes({m.markers})),
				function(t)
					m.reloadState = {age = t * reloadTime, duration = reloadTime,
						nextMarker = #m.markers + 1}
				end, m.markers)
		end
	end

	m:destroy()
	vm:Destroy()
	table.insert(report, ("%-14s <- %-14s %s"):format(target.out, target.vm, table.concat(made, " ")))
end

return ("%d clips, %d keyframes, %d markers\n%s")
	:format(totalClips, totalKeys, totalMarkers, table.concat(report, "\n"))
