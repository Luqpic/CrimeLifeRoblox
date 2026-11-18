--!strict
-- Open items pass 2026-11-18: the getaway distance, one copy for both sides. Heist.Services.Getaway (the
-- server, which banks) and HeistClient (the getaway widget) both call it, so the studs shown are the studs
-- that bank. Before this the formula was written twice with nothing checking they agreed.
--
-- HORIZONTAL: every StatusBillboardAnchor floats 40-120 studs above its building so its badge reads from
-- the ground; a 3D distance would count that height as escape progress.
local GetawayMath = {}

function GetawayMath.horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

-- Studs still to cover before escapeDistance is reached (0 once reached).
function GetawayMath.remaining(position: Vector3, anchorPosition: Vector3, escapeDistance: number): number
	return math.max(0, escapeDistance - GetawayMath.horizontalDistance(position, anchorPosition))
end

return GetawayMath
