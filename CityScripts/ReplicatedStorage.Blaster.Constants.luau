local Constants = {
	RAY_EXCLUDE_TAG = "RayExclude",
	NON_STATIC_TAG = "NonStatic",
	FIRE_MODE = {
		SEMI = "Semi",
		AUTO = "Auto",
		BURST = "Burst",
	},
	-- Rounds fired per trigger pull in BURST mode, at the weapon's own rateOfFire cyclic rate.
	BURST_ROUND_COUNT = 3,
	AMMO_ATTRIBUTE = "_ammo",
	RELOADING_ATTRIBUTE = "_reloading",
	DAMAGE_ATTRIBUTE = "damage",
	FIRE_MODE_ATTRIBUTE = "fireMode",
	MAGAZINE_SIZE_ATTRIBUTE = "magazineSize",
	RANGE_ATTRIBUTE = "range",
	RATE_OF_FIRE_ATTRIBUTE = "rateOfFire",
	RELOAD_TIME_ATTRIBUTE = "reloadTime",
	RAYS_PER_SHOT_ATTRIBUTE = "raysPerShot",
	RAY_RADIUS_ATTRIBUTE = "rayRadius",
	SPREAD_ATTRIBUTE = "spread",
	VIEW_MODEL_ATTRIBUTE = "viewModel",
	RECOIL_MIN_ATTRIBUTE = "recoilMin",
	RECOIL_MAX_ATTRIBUTE = "recoilMax",
	UNANCHORED_IMPULSE_FORCE_ATTRIBUTE = "unanchoredImpulseForce",

	-- Opt-in per-weapon attributes. Every one of these is absent on the existing weapons, and the
	-- code that reads them falls back to the previous hardcoded behaviour when they are unset, so
	-- adding them changes nothing for a weapon that does not declare them.

	-- true = the weapon never consumes ammo and never reloads (melee).
	INFINITE_AMMO_ATTRIBUTE = "infiniteAmmo",
	-- studs/s of push applied to a hit character. 0/unset = no knockback.
	-- Deliberately NOT scaled by range, unlike the unanchored-prop impulse.
	KNOCKBACK_FORCE_ATTRIBUTE = "knockbackForce",
	-- Opt-in: spend the whole knockbackForce on the shot that KILLS, and none on a shot the target
	-- survives. Set on the shotguns. Melee leaves it unset and keeps pushing on every swing.
	KNOCKBACK_ON_KILL_ATTRIBUTE = "knockbackOnKill",
	-- Opt-in bleed: a weapon declaring both keeps damaging what it cut after the swing lands.
	-- Set on the Knife. Every other weapon leaves them unset and behaves exactly as before.
	BLEED_DURATION_ATTRIBUTE = "bleedDuration",
	BLEED_DAMAGE_ATTRIBUTE = "bleedDamagePerSecond",
	-- true = a hit on a character plays the white melee pop instead of the guns' spark/circle impact.
	MELEE_HIT_EFFECT_ATTRIBUTE = "meleeHitEffect",
	-- Delay, in seconds, between initiating an attack and the hit actually resolving. 0/unset for
	-- every weapon except melee, which needs the hit to land when the swing animation visually shows
	-- contact rather than at the instant the swing starts. A bullet reads as instantaneous, so guns
	-- must leave this unset.
	SWING_DELAY_ATTRIBUTE = "swingDelay",

	-- Seconds a hit from this weapon locks the target's movement for, read by ShotResolver.
	-- Unset/0 for every weapon except ones that declare it (e.g. the Baton).
	STUN_DURATION_ATTRIBUTE = "stunDuration",
	-- Damage multiplier for a hit on the back of the upper torso from behind, read by ShotResolver.
	-- A weapon that declares it (the Knife) trades the headshot bonus for this one; unset everywhere else.
	BACKSTAB_MULTIPLIER_ATTRIBUTE = "backstabMultiplier",

	-- Explosive rounds (the RPG). Setting explosionRadius makes each ray an explosion where it lands,
	-- INSTEAD of a direct hit: everyone damageable within the radius takes `damage` at the centre falling
	-- linearly to explosionEdgeDamage x damage at the rim, survivors are shoved by explosionKnockback
	-- (studs/s), and the killed are flung at explosionFlingSpeed. Unset on every other weapon.
	EXPLOSION_RADIUS_ATTRIBUTE = "explosionRadius",
	EXPLOSION_EDGE_DAMAGE_ATTRIBUTE = "explosionEdgeDamage",
	EXPLOSION_KNOCKBACK_ATTRIBUTE = "explosionKnockback",
	EXPLOSION_FLING_SPEED_ATTRIBUTE = "explosionFlingSpeed",
	-- Name of a model in Blaster.Objects drawn flying to the impact instead of a laser tracer.
	PROJECTILE_ATTRIBUTE = "projectile",
	-- Studs/s for a projectile weapon's round. One value for BOTH the client's flying model and the
	-- server's explosion delay, so the blast lands the moment the rocket arrives.
	PROJECTILE_SPEED = 250,
	-- The explosive round's flash (ShotResolver.explode): Blaster.Objects.RPGBlast's emitter is switched on
	-- at RPG_BLAST_RATE particles/s for RPG_BLAST_EMIT_SECONDS, and the blast is removed after RPG_BLAST_LIFETIME s.
	RPG_BLAST_RATE = 60,
	RPG_BLAST_EMIT_SECONDS = 0.25,
	RPG_BLAST_LIFETIME = 2,
	-- On a weapon's mesh part: hidden while the weapon is empty (the RPG's loaded rocket).
	HIDE_WHEN_EMPTY_ATTRIBUTE = "HideWhenEmpty",
	-- true = shell-by-shell, interruptible reload. NOTE: this also changes what reloadTime means for
	-- that weapon, from "seconds for the whole magazine" to "seconds per shell".
	ISSHOTGUN_ATTRIBUTE = "isShotgun",

	KEYBOARD_RELOAD_KEY_CODE = Enum.KeyCode.R,
	GAMEPAD_RELOAD_KEY_CODE = Enum.KeyCode.ButtonX,
	KEYBOARD_TOGGLE_VIEW_KEY_CODE = Enum.KeyCode.V,

	-- Pixel size under which a screen is considered 'small'. This is the same threshold used by the default touch UI.
	UI_SMALL_SCREEN_THRESHOLD = 500,
	-- Amount to scale the UI when on a small screen
	UI_SMALL_SCREEN_SCALE = 0.6,

	HITMARKER_SOUND_DELAY = 0.1,

	-- View model
	VIEW_MODEL_BIND_NAME = "BlasterViewModel",
	VIEW_MODEL_OFFSET = CFrame.new(0.9, -1.3, -1.3),
	VIEW_MODEL_BOBBING_SPEED = 0.4,
	VIEW_MODEL_BOBBING_AMOUNT = 0.05,
	VIEW_MODEL_BOBBING_TRANSITION_SPEED = 10,
	VIEW_MODEL_RELOAD_FADE_TIME = 0.1,
	-- Recoil
	RECOIL_BIND_NAME = "Recoiler",
	RECOIL_STOP_SPEED = 10,
	RECOIL_ZOOM_RETURN_SPEED = 20,
	-- VFX
	LASER_BEAM_VISUAL_SPEED = 200,
}

return Constants
