--!strict
local Players = game:GetService("Players")

local Zone = {}
Zone.__index = Zone

-- The default sweep: which players' characters overlap this volume. Injected in
-- tests so occupancy logic can be exercised without characters.
--
-- The filter is an Include list of live character models, NOT an Exclude list of
-- the zone part. Excluding only the zone made the engine return every wall, floor
-- and prop inside a building-sized volume -- up to 4,007 parts for NewsroomZone --
-- which this loop then walked in Luau on every sweep. At the 10Hz service cadence
-- that cost ~835ms of work per second across the 12 zones and pinned the server
-- at ~29 FPS with a 3:1 stutter. Scoping the query to character parts is the same
-- volume-overlap test against the same candidates, ~21x cheaper.
-- Open items pass 2026-11-18: `overlap` is workspace:GetPartsInPart unless a spec passes deps.overlap,
-- which ZoneSpec uses to count the parts this loop walks (its old wall-clock limit flaked).
local function defaultQuery(part: BasePart, overlap: (BasePart, OverlapParams) -> { BasePart })
	local characters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	if #characters == 0 then
		return {}
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = characters
	local found, seen = {}, {}
	for _, hit in ipairs(overlap(part, params)) do
		local character = hit:FindFirstAncestorOfClass("Model")
		if character then
			local player = Players:GetPlayerFromCharacter(character)
			if player and not seen[player] then
				seen[player] = true
				table.insert(found, player)
			end
		end
	end
	return found
end

function Zone.new(part: BasePart, deps)
	assert(part and part:IsA("BasePart"), "Zone requires a BasePart")
	local role = part:GetAttribute("ZoneRole")
	assert(type(role) == "string", "Zone " .. part:GetFullName() .. " is missing a ZoneRole attribute")
	local overlap = deps.overlap or function(p: BasePart, params: OverlapParams) return workspace:GetPartsInPart(p, params) end
	return setmetatable({
		part = part,
		role = role,
		config = deps.config,
		queryOccupants = deps.queryOccupants or function(p: BasePart) return defaultQuery(p, overlap) end,
	}, Zone)
end

function Zone:GetOccupants()
	return self.queryOccupants(self.part)
end

function Zone:Contains(player): boolean
	return table.find(self:GetOccupants(), player) ~= nil
end

-- Zones are pure sensors: nothing to seal or rearm.
function Zone:Seal() end
function Zone:Rearm() end
function Zone:Destroy() end

return Zone
