--!strict
-- Edit is the truth (developer rule, 2026-11-20): a marker that puts an NPC in the world at run time carries that NPC
-- as a rig in Edit (a Model child of the marker), so the developer sees who stands where and moves them by moving the
-- rig. On the server the marker follows its rig (the rig's pivot, less `lift` studs: a guard post sits at the guard's
-- feet, a police spawn at the officer's root) and the rig leaves the world. The rig is returned for a caller that
-- builds from it (GuardPost); nil when the marker has none (never placed, or already taken).
local EditRig = {}

function EditRig.take(marker: BasePart, lift: number?): Model?
	local rig = marker:FindFirstChildWhichIsA("Model")
	if not rig then
		return nil
	end
	marker.CFrame = rig:GetPivot() - Vector3.new(0, lift or 0, 0)
	rig.Parent = nil
	return rig
end

return EditRig
