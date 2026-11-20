--!strict
-- Smarter enemies (combat depth, developer picker 2026-11-20): the pure geometry EnemyAI uses. A gun enemy in Attack
-- backs away while it fires when badly hurt, may take cover after a burst, and flanks when another enemy already
-- engages its target; an enemy that spots a player alerts its faction nearby. Melee enemies keep rushing.
local Tactics = {}

Tactics.BACK_OFF_FRACTION = 0.3 -- below this share of max health
Tactics.BACK_OFF_STEP = 10
Tactics.BACK_OFF_UNTIL = 0.9 -- backs away while nearer than this share of its engage range
Tactics.COVER_CHANCE = 0.5 -- after each burst
Tactics.COVER_RADII = { 6, 12 }
Tactics.COVER_DIRECTIONS = 8
Tactics.COVER_SECONDS = 2
Tactics.COVER_HEIGHT = 1.5 -- above the root (chest): the target's view of this point must be blocked
Tactics.GROUND_DEPTH = 6 -- below the root: a cover point needs ground
Tactics.FLANK_MIN_DEGREES = 60
Tactics.FLANK_MAX_DEGREES = 90
Tactics.FLANK_MIN_DISTANCE = 10
Tactics.FLANK_REACHED = 6
Tactics.ALERT_RADIUS = 60

function Tactics.shouldBackOff(health: number, maxHealth: number): boolean
	return maxHealth > 0 and health > 0 and health < maxHealth * Tactics.BACK_OFF_FRACTION
end

-- BACK_OFF_STEP studs straight away from the target, flat.
function Tactics.backOffPoint(from: Vector3, target: Vector3): Vector3
	local away = Vector3.new(from.X - target.X, 0, from.Z - target.Z)
	if away.Magnitude < 1e-3 then
		away = Vector3.xAxis
	end
	return from + away.Unit * Tactics.BACK_OFF_STEP
end

-- A point `degrees` (signed) round the target from the direction to `ally` (the enemy already engaging), at
-- `distance` from the target.
function Tactics.flankPoint(target: Vector3, ally: Vector3, distance: number, degrees: number): Vector3
	local toAlly = Vector3.new(ally.X - target.X, 0, ally.Z - target.Z)
	if toAlly.Magnitude < 1e-3 then
		toAlly = Vector3.xAxis
	end
	return target + CFrame.Angles(0, math.rad(degrees), 0):VectorToWorldSpace(toAlly.Unit) * distance
end

-- A point round `from` (COVER_DIRECTIONS directions on each of COVER_RADII, the inner ring first) that the target
-- cannot see at chest height, that the enemy can walk to in a straight line, and that has ground under it.
-- blocked(a, b) is true when something solid lies between a and b. nil when there is none.
function Tactics.findCover(from: Vector3, target: Vector3, blocked: (Vector3, Vector3) -> boolean): Vector3?
	local chest = Vector3.yAxis * Tactics.COVER_HEIGHT
	for _, radius in Tactics.COVER_RADII do
		for i = 0, Tactics.COVER_DIRECTIONS - 1 do
			local angle = i * 2 * math.pi / Tactics.COVER_DIRECTIONS
			local point = from + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
			if
				blocked(target, point + chest)
				and not blocked(from + chest, point + chest)
				and blocked(point, point - Vector3.yAxis * Tactics.GROUND_DEPTH)
			then
				return point
			end
		end
	end
	return nil
end

function Tactics.inAlertRange(spotter: Vector3, ally: Vector3): boolean
	return (spotter - ally).Magnitude <= Tactics.ALERT_RADIUS
end

return Tactics
