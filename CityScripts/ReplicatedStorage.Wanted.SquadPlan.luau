--!strict
-- Pure squad arithmetic for the police dispatcher (police and wanted, Task 2, 2026-11-17).
local Constants = require(script.Parent.Constants)

local SquadPlan = {}

-- The squad a wanted player should have at `stars`: plain police and armed police (spec table).
function SquadPlan.target(stars: number): (number, number)
	local row = Constants.SQUAD_BY_STARS[math.clamp(math.floor(stars), 0, Constants.MAX_HEAT)]
	if not row then
		return 0, 0
	end
	return row.police, row.armed
end

-- How many officers of each kind are above the target at `stars` (final review 2026-11-17: the squad shrinks
-- when stars fall; the dispatcher sends these away).
function SquadPlan.surplus(stars: number, police: number, armed: number): (number, number)
	local targetPolice, targetArmed = SquadPlan.target(stars)
	return math.max(0, police - targetPolice), math.max(0, armed - targetArmed)
end

-- How many officers each player may get now. `alive` = officers already in that player's squad; `cap` =
-- police that may be alive in total for these squads. Highest stars first; nobody above their target, the
-- total never above the cap, nothing for 0 stars.
function SquadPlan.allocate(requests: { { player: any, stars: number, alive: number } }, cap: number): { [any]: number }
	local sorted = table.clone(requests)
	table.sort(sorted, function(a, b)
		return a.stars > b.stars
	end)
	local budget = cap
	for _, request in sorted do
		budget -= request.alive
	end
	local out = {}
	for _, request in sorted do
		local police, armed = SquadPlan.target(request.stars)
		local n = math.max(0, math.min(police + armed - request.alive, budget))
		out[request.player] = n
		budget -= n
	end
	return out
end

return SquadPlan
