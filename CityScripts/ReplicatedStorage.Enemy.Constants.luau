-- Every tunable for the AI enemy system, in one place. Mirrors the role ReplicatedStorage.Blaster.Constants
-- and ReplicatedStorage.Movement.Constants play for their systems.
--
-- This lives in ReplicatedStorage rather than ServerScriptService only because ENEMY_TAG is needed
-- by ReplicatedStorage.Blaster.Utility.canDamageHumanoid, which is shared with the client. The AI
-- itself is server-only.
local Constants = {
	-- CollectionService tags. Matches how this game already marks world instances ("Target",
	-- "RayExclude", "NonStatic") rather than introducing a folder-based convention.
	ENEMY_TAG = "Enemy",
	SPAWN_POINT_TAG = "EnemySpawnPoint",

	-- Fallback weapon for a rig template that ships without a Tool of its own. Cloned from
	-- ServerStorage.Weapons, so an enemy fires the exact weapon config a player would -- same damage,
	-- spread, range, rate of fire, magazine and reload time. None of the six configured templates
	-- reach this path; each carries its own pre-equipped weapon.
	ENEMY_WEAPON_NAME = "Deagle",

	ENEMY_MAX_HEALTH = 100,
	ENEMY_WALK_SPEED = 12,
	ENEMY_CHASE_SPEED = 20,

	-- === Spawner ===
	-- Applied INDEPENDENTLY per enemy type -- not a shared total. Each spawn point's own type may
	-- have up to this many alive+pending at once, so the practical ceiling across every criminal-side
	-- enemy combined is (number of spawn points) * this value, not this value alone.
	-- Per TYPE, and there are six spawn points, so this is the total divided by six. At 10 the map
	-- held up to 60 enemies and a player standing still was being shot at by all of them at once.
	MAX_CONCURRENT_ENEMIES_PER_TYPE = 5,
	RESPAWN_DELAY = 6,
	-- An enemy will not spawn at a point this close to any living player.
	MIN_SPAWN_DISTANCE_FROM_PLAYER = 60,
	-- How long a corpse stays before it is removed.
	CORPSE_LINGER_DURATION = 4,

	-- === Detection ===
	DETECTION_RADIUS = 120,
	-- Enemies notice a player who shoots them from outside DETECTION_RADIUS -- being hit is itself
	-- a detection event, otherwise they ignore a sniper indefinitely.
	RETALIATION_DETECTION = true,

	-- === Attack ===
	-- The engagement distance is derived from the equipped weapon's own `range` attribute rather
	-- than being a separate NPC-only number, so rebalancing the gun moves the AI with it.
	--
	-- The blaster's `range` is a hitscan ceiling (1000 studs), not an engagement distance, so a
	-- fraction of it is used. This fraction is the one judgement call in the AI's ranges: at 1.0 an
	-- enemy opens fire from across the entire map the instant it has line of sight.
	ENGAGE_RANGE_FRACTION = 0.1,
	-- Stop closing in at this fraction of the engagement range, so enemies hold a firing line
	-- instead of walking into the player's face.
	PREFERRED_RANGE_FRACTION = 0.6,
	-- A gun enemy with an ally first in its line of fire holds the shot and walks sideways, toward a point
	-- this far across the line, until the line clears (open items pass 2026-11-18).
	ALLY_SIDESTEP = 4,

	-- === Recoil ===
	-- Radians/second the accumulated recoil offset decays by. Tuned against automatic weapons: a shot
	-- lands roughly every 60/rateOfFire seconds, and this is deliberately set lower than the typical
	-- kick-per-second an automatic weapon adds, so recoil visibly climbs over a sustained burst. A
	-- slow semi-auto weapon's kick-per-second is naturally below this decay rate, so its recoil stays
	-- negligible without needing separate tuning.
	RECOIL_DECAY_RATE = 1.2,
	-- Sanity ceiling so recoil cannot run away indefinitely during an unusually long burst.
	RECOIL_MAX_OFFSET_DEGREES = 45,

	-- === Search ===
	-- How long an enemy hunts around the player's last known position before giving up.
	SEARCH_DURATION = 5,

	-- === Patrol ===
	-- Enemies wander to random reachable points around their spawn point rather than following
	-- authored waypoint chains -- see EnemyAI.md for why this was chosen for this map.
	PATROL_RADIUS = 70,
	-- Pause at a patrol destination before picking the next one.
	PATROL_DWELL_DURATION = 2,

	-- === Scheduling ===
	-- The AI "thinks" (detection raycasts, path recomputes, firing decisions) on this interval, not
	-- every frame, and enemies are staggered across the interval so their think ticks do not all
	-- land on the same frame. Per-frame work stays proportional to nothing at all: movement is
	-- handled by Humanoid:MoveTo, which the engine steps for us.
	THINK_INTERVAL = 0.25,
	-- A path is reused until it is this stale, or until the target has moved further than
	-- PATH_REPLAN_DISTANCE from where it was when the path was computed.
	PATH_REPLAN_INTERVAL = 0.6,
	PATH_REPLAN_DISTANCE = 12,

	-- === Damage ===
	-- TEMP: lowered for debugging, restore/rebalance before shipping.
	--
	-- Applied by the spawner to the enemy's own cloned Tool, so it cannot affect the player's
	-- weapon balance. Set to nil to make enemies use the weapon's stock damage (35) again, which is
	-- what a player firing the same gun deals.
	ENEMY_DAMAGE_OVERRIDE = 3,

	-- === Animation ===
	-- Shoot and reload animations come from the equipped Tool's own Animations folder via the shared
	-- CharacterAnimationController, exactly as they do for a player.
	--
	-- Locomotion (idle/walk/run) is driven by the AI, because the runtime-built rig ships with an
	-- `Animate` LocalScript that the spawner strips (an enemy must carry no client-side scripts) and
	-- that script is what would normally supply the cycle. The animations themselves are NOT
	-- configured here: they are read from the player's own movement animations via
	-- ReplicatedStorage.Movement.Scripts.locomotionAnimations, so enemies and players always play the
	-- same clips. There is deliberately no enemy animation id list to drift out of sync.
	-- Locomotion is selected from how far the character actually travelled between think ticks --
	-- deliberately neither Humanoid.MoveDirection nor instantaneous velocity, both of which read zero
	-- for a server-driven humanoid using MoveTo even while it is walking. See
	-- EnemyAI:_updateLocomotionAnimation.
	--
	-- Below this average speed (studs/s) an enemy is presented as standing still.
	IDLE_SPEED_THRESHOLD = 0.5,
	-- Above ENEMY_WALK_SPEED plus this margin, the run cycle is used instead of the walk cycle. Kept
	-- as a margin over the configured walk speed rather than an absolute number, so changing
	-- ENEMY_WALK_SPEED / ENEMY_CHASE_SPEED keeps working.
	RUN_SPEED_MARGIN = 2,
	-- Left empty by default: this place has no death animation asset, and two of its existing
	-- locomotion assets already fail to load. Set this to a valid animation id to enable one; the
	-- Humanoid's own death ragdoll plays either way.
	DEATH_ANIMATION_ID = "",
}

return Constants
