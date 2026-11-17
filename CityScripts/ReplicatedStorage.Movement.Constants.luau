-- Shared tuning + attribute names for the movement/stamina system. Mirrors the role
-- ReplicatedStorage.Blaster.Constants plays for the combat system: every balance number lives here
-- so tuning stamina never means hunting through the server tick, Animate2 and the HUD separately.
--
-- Stamina is expressed on a 0-100 scale, matching how Humanoid.Health and the blaster's ammo are
-- already represented in this game (whole-number gameplay resources rather than normalized 0-1).
local Constants = {
	-- Attributes on the character's HumanoidRootPart. IsSprinting is the pre-existing shared sprint
	-- state (set by the server, read by Lean); the other two are added by the stamina system and
	-- follow the same IsCrouching/CrouchEnabled attribute convention used elsewhere.
	SPRINTING_ATTRIBUTE = "IsSprinting",
	STAMINA_ATTRIBUTE = "Stamina",
	CAN_SPRINT_ATTRIBUTE = "CanSprint",

	-- Animate2's ground walk pace, and the speed the server clamps a locked-out player back to.
	-- Note this is intentionally NOT StarterPlayer.CharacterWalkSpeed (25): Animate2 drives WalkSpeed
	-- itself and walks at 20, so clamping to the StarterPlayer value would never bite.
	WALK_SPEED_BASELINE = 20,

	-- Heavy-loot carry (heist layers 2026-11-17). While the character carries this attribute (a
	-- number, set by SharedSystems.CarryState from the carried object's speedCap) Animate2 caps its
	-- walk target at it and drops the sprint boost, SprintAuthority caps WalkSpeed and grants no
	-- sprint, and Crouching never exceeds it. Absent = no cap.
	CARRY_SPEED_CAP_ATTRIBUTE = "CarrySpeedCap",
	CARRY_SPEED_CAP = 12,

	-- Landing recovery. EVERY landing costs the player all of their momentum -- a sprint landing and
	-- a step off a low ledge are treated the same.
	--
	-- The shape is: hold at the floor for LANDING_RECOVERY_HOLD, then accelerate back to
	-- WALK_SPEED_BASELINE at LANDING_RECOVERY_ACCELERATION. DURATION is sized to outlast that curve
	-- (0.12 + 20/50 = 0.52s) so the window's own release is a no-op rather than a step change.
	LANDING_RECOVERY_DURATION = 0.55,
	-- A dead stop on touchdown.
	LANDING_RECOVERY_WALK_SPEED = 0,
	-- Seconds pinned at the floor before momentum starts returning.
	LANDING_RECOVERY_HOLD = 0.12,
	-- Studs/s^2 back up to the baseline. Matches Animate2's runAcceleration, so the client's ramp
	-- and the server's clamp describe the same curve instead of fighting each other.
	LANDING_RECOVERY_ACCELERATION = 50,

	MAX_STAMINA = 100,

	-- Full-to-empty in exactly this many seconds of continuous sprinting.
	SPRINT_DURATION_SECONDS = 10,
	-- Empty-to-full regen is deliberately slower than the drain.
	REGEN_DURATION_SECONDS = 16,
	-- Regen does not start the instant sprinting stops, so tapping sprint isn't free stamina.
	REGEN_DELAY_SECONDS = 0.9,

	-- Anti-flicker: once stamina bottoms out, sprint stays locked until stamina climbs back to this
	-- value. Re-enabling at anything above 0 makes sprint toggle every tick while the key is held.
	SPRINT_REENABLE_STAMINA = 18,

	-- Stamina only drains while the character is actually moving at sprint pace. This is a gate on
	-- the existing sprint state, NOT a second way of detecting sprint: the server still takes
	-- "is this player sprinting" from the IsSprinting flag that UpdateRunningState maintains, and
	-- only additionally requires real movement so holding the key while standing still, crouching
	-- or walking backwards doesn't burn stamina. Sits above Animate2's walk speed (20) and well
	-- below its sprint speed (38).
	MIN_DRAIN_SPEED = 22,

	-- How often the server publishes the stamina attribute. The stamina maths itself runs every
	-- Heartbeat (so the 10s drain is exact), but the replicated value is only written at this
	-- interval -- state changes such as lockout are always written immediately.
	SERVER_PUBLISH_INTERVAL = 0.1,

	-- The client predicts stamina between server updates; it snaps to the server value when they
	-- disagree by more than this, and eases toward it otherwise.
	CLIENT_RECONCILE_TOLERANCE = 6,
	CLIENT_RECONCILE_SPEED = 6,

	-- HUD
	HUD_WIDTH = 240,
	HUD_HEIGHT = 10,
	HUD_TOP_OFFSET = 20,
	HUD_FILL_TWEEN_TIME = 0.12,
	HUD_FADE_TWEEN_TIME = 0.25,
	-- The bar hides itself when stamina is full and sprint isn't locked out. Flip this to false for
	-- an always-visible bar -- nothing else in the HUD depends on it.
	HUD_HIDE_WHEN_FULL = true,
	HUD_FILL_COLOR = Color3.fromRGB(255, 255, 255),
	HUD_LOCKED_COLOR = Color3.fromRGB(255, 74, 74),
	HUD_BACKGROUND_COLOR = Color3.fromRGB(0, 0, 0),
	HUD_BACKGROUND_TRANSPARENCY = 0.5,
	HUD_CORNER_RADIUS = 4,
}

Constants.STAMINA_DRAIN_PER_SECOND = Constants.MAX_STAMINA / Constants.SPRINT_DURATION_SECONDS
Constants.STAMINA_REGEN_PER_SECOND = Constants.MAX_STAMINA / Constants.REGEN_DURATION_SECONDS

return Constants
