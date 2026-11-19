-- ReplicatedStorage.PlayerMovement.Config: every number of the player's movement animations and moves
-- (StarterCharacterScripts.Movement, ported from OBT Revamp on 2026-11-20). Clip ids live on the Animation objects in
-- ReplicatedStorage.PlayerMovement.Animations. Walk and sprint speed, landing recovery and stamina stay CrimeLife's
-- (Animate2, Movement.Constants, ServerScriptService.Movement.Scripts.SprintAuthority).
return {
	-- Speed (studs/s) at which each kind of clip plays at 1x; the game plays a clip at speed / (base x leg scale).
	-- The clips' planted feet move at Walk 3, Jog 9, Run 16, Sprint 30 (OBT walks at 16 and sprints at 30).
	-- CrimeLife (2026-11-20): retuned so each CrimeLife gait plays its own kind at 1x rather than at the feet's
	-- speed: a heavy carry 12 plays Jog, the walk 20 Run, the sprint 38 Sprint (crouched at 8, Crouching's own clips
	-- play instead). The feet slip by a fifth to a quarter of the speed for it. Climb and Swim use Roblox's own scale.
	BaseSpeed = { Walk = 3, Jog = 12, Run = 20, Sprint = 38, Climb = 5, Swim = 12 },
	-- the clips were measured on a rig whose hip joint sits 2.0 studs above the sole; base speeds scale by the avatar's
	-- own hip-to-sole height over this
	RigLegLength = 2.0,
	PlaySpeed = { Min = 0.4, Max = 2.2 }, -- clamp on the playback rate of a moving loop
	-- ground speed bands (studs/s): idle below IdleBelow, then crossfades Walk -> Jog -> Run -> Sprint between these
	IdleBelow = 0.6,
	WalkToJog = { 4, 7 }, -- 8 is all Jog
	JogToRun = { 13, 18 }, -- 12 is all Jog, 20 all Run
	RunToSprint = { 26, 34 }, -- 20 is all Run, 38 all Sprint (forward only)
	Fade = 10, -- crossfade rate (1/s): about 0.3 s from one state to the next
	-- landing: vertical speed (studs/s) at touchdown
	LandSoftAbove = 28, -- below this nothing plays (steps, small hops)
	LandHardAbove = 70, -- LandHard from here (a flat jump lands at about 53)
	LandMovingWeight = 0.45, -- landing while moving: the run keeps going under a lighter Land
	-- seconds a clip may take to load before the Roblox default of its kind replaces it (PlayerMovement.Fallback)
	FallbackWait = 3,

	Roll = {
		-- Q: C is crouch, Z the shoulder swap; B on a pad
		Key = Enum.KeyCode.Q,
		PadKey = Enum.KeyCode.ButtonB,
		Time = 0.62,
		StartSpeed = 30,
		EndSpeed = 12,
		-- seconds; the client counts from the roll's end, the server (RollAuthority) from the request on its own clock
		Cooldown = 0.9,
		-- rolling out of a sprint: Distance x as far, over Time x as long (the clip slowed to fit), same stamina
		Sprint = { Distance = 1.5, Time = 1.2 },
		-- x as far in the same time (OBT 2026-11-06: 13 -> 18.2 studs standing)
		Reach = 1.4,
		-- stamina a roll costs: 40 of OBT's 325 is the same share as 12.3 of CrimeLife's 100 (Movement.Constants.MAX_STAMINA)
		Stamina = 12.3,
		-- the touch button, inside Roblox's ContextButtonFrame (the right 30% x lower half of the screen), from its
		-- bottom-right corner: left of the shoot button and below it on a 844 x 390 phone, clear of the jump button
		TouchPosition = UDim2.new(1, -288, 1, -84),
		TouchSize = 56,
	},
	-- ledge: Space (or the jump button) facing a wall whose top is in reach
	Ledge = { Reach = 2.6, MinHeight = 3.8, MaxHeight = 8, Time = 1.0 },
}
