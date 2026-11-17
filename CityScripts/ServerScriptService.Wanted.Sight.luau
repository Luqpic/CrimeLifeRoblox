-- Sight: the one line-of-sight probe of the police and wanted feature (moved out of PoliceDispatcher in
-- Task 3, 2026-11-17, so police spawns, witnesses and guards share it).
--
-- inSight(eye, position, ignore?): is a character standing at `position` in view from `eye`? Probed at its
-- legs, root and head (SIGHT_PROBE_HEIGHTS) and left and right of its root across the line of view
-- (SIGHT_PROBE_SIDE), so a pole or a lamp post hides none of it. Characters (players, police, gang enemies)
-- and non-colliding parts never block; parts at least SEE_THROUGH_TRANSPARENCY transparent (glass) do not
-- either. `ignore` (the witness's own model) is left out of the rays too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Wanted.Constants)

local Sight = {}

-- Rays that ignore characters (players, police, gang enemies) and anything that does not collide.
function Sight.params(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local exclude = {}
	for _, name in { "Police", "Enemies" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

-- Does anything that hides a character lie between `from` and `to`? See-through parts (glass) do not: the
-- ray is cast again with them filtered out.
local function blocked(from: Vector3, to: Vector3, params: RaycastParams): boolean
	for _ = 1, Constants.SIGHT_RECASTS do
		local hit = Workspace:Raycast(from, to - from, params)
		if not hit then
			return false
		end
		if hit.Instance.Transparency < Constants.SEE_THROUGH_TRANSPARENCY then
			return true
		end
		params:AddToFilter(hit.Instance)
	end
	return true -- ponytail: more panes than SIGHT_RECASTS counts as cover
end

function Sight.inSight(eye: Vector3, position: Vector3, ignore: Instance?): boolean
	local params = Sight.params()
	if ignore then
		params:AddToFilter(ignore)
	end
	local flat = Vector3.new(position.X - eye.X, 0, position.Z - eye.Z)
	local side = if flat.Magnitude > 1e-3 then flat.Unit:Cross(Vector3.yAxis) * Constants.SIGHT_PROBE_SIDE else Vector3.zero
	local points = { position + side, position - side }
	for _, height in Constants.SIGHT_PROBE_HEIGHTS do
		table.insert(points, position + Vector3.new(0, height, 0))
	end
	for _, point in points do
		if not blocked(eye, point, params) then
			return true
		end
	end
	return false
end

return Sight
