--!strict
-- Melee combos, heavy swings, block and parry (combat depth, developer picker 2026-11-20): the numbers and the pure rules
-- both sides use. Server: ServerScriptService.Blaster.Scripts.MeleeMoves; client: ReplicatedStorage.Blaster.Scripts
-- .MeleeController.
local MeleeRules = {}

MeleeRules.COMBO = { 1, 1.2, 1.5 } -- damage of each step
MeleeRules.COMBO_WINDOW = 0.6 -- the next press within the weapon's cooldown plus this continues the combo
MeleeRules.HEAVY_HOLD = 0.8 -- held this long after a swing, the release is a heavy
MeleeRules.HEAVY_MULTIPLIER = 2
MeleeRules.HEAVY_STAGGER = 0.8
MeleeRules.BLOCK_FACTOR = 0.3 -- a blocked melee hit deals this share (-70 %)
MeleeRules.BLOCK_FRONT_DOT = 0 -- blocks an attacker in the front half
MeleeRules.PARRY_WINDOW = 0.25 -- a hit this soon after the block started is parried
MeleeRules.PARRY_STUN = 1
MeleeRules.PARRY_REARM = 1 -- a block started sooner than this after the last one cannot parry

MeleeRules.BLOCK_KEY = Enum.KeyCode.F
MeleeRules.BLOCK_PAD = Enum.KeyCode.ButtonL1

-- OBT's PLAYER_SWORD clips (group-owned; they load in the city). Hold is the guard while blocking.
MeleeRules.CLIPS = {
	Slash1 = "rbxassetid://127462674626273",
	Slash2 = "rbxassetid://134523728388679",
	Slash3 = "rbxassetid://132607297852668",
	Charge = "rbxassetid://103447955916892",
	Heavy = "rbxassetid://74911061348171",
	Hold = "rbxassetid://108243579707637",
}

-- The step (1 to #COMBO) of a swing at `now` after one at `lastSwing` that was step `step` (0: none or a heavy).
function MeleeRules.nextStep(step: number, lastSwing: number?, now: number, cooldown: number): number
	if lastSwing and now - lastSwing <= cooldown + MeleeRules.COMBO_WINDOW then
		return step % #MeleeRules.COMBO + 1
	end
	return 1
end

-- A swing at `now` is a heavy when the player reported holding on after the last swing (chargeFrom is that swing's
-- timestamp) and HEAVY_HOLD has passed since it.
function MeleeRules.isHeavy(lastSwing: number?, chargeFrom: number?, now: number): boolean
	return lastSwing ~= nil and chargeFrom == lastSwing and now - lastSwing >= MeleeRules.HEAVY_HOLD
end

-- A melee hit on a blocking defender: the damage factor and whether it was parried. blockAge: seconds since the block
-- started; parryable: this block may still parry; look: the defender's look; toAttacker: defender to attacker.
function MeleeRules.defend(blockAge: number, parryable: boolean, look: Vector3, toAttacker: Vector3): (number, boolean)
	local flat = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 1e-3 and flatLook.Magnitude > 1e-3 and flatLook.Unit:Dot(flat.Unit) < MeleeRules.BLOCK_FRONT_DOT then
		return 1, false -- from behind
	end
	if parryable and blockAge <= MeleeRules.PARRY_WINDOW then
		return 0, true
	end
	return MeleeRules.BLOCK_FACTOR, false
end

return MeleeRules
