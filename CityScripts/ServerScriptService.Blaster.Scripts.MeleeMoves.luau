--!strict
-- Melee combos, heavy swings, block and parry (combat depth, developer picker 2026-11-20), the server side. Numbers and
-- rules: ReplicatedStorage.Combat.MeleeRules; the client: ReplicatedStorage.Blaster.Scripts.MeleeController.
-- Combo: a validated melee swing (Blaster.onShootEvent) pressed within the weapon's cooldown + COMBO_WINDOW of the last
-- one is the next of three steps (x1, x1.2, x1.5). Heavy: the client reports it kept holding after a swing
-- (Combat.Remotes.MeleeCharge with that swing's own timestamp); a swing HEAVY_HOLD or more after it is a heavy (x2,
-- staggers what it hits) and the combo starts over. Timing uses the shots' validated timestamps, so latency neither
-- adds nor drops a step. Block: Combat.Remotes.Block(true / false) while holding a melee weapon; ShotResolver asks
-- `defend` for every melee hit on a player's character.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local MeleeRules = require(ReplicatedStorage.Combat.MeleeRules)
local RagdollController = require(ReplicatedStorage.Modules.RagdollController)

local MeleeMoves = {}

type State = {
	step: number,
	lastSwing: number?,
	chargeFrom: number?,
	blockingSince: number?,
	lastBlockStart: number?,
	parryable: boolean,
}

local states: { [Instance]: State } = setmetatable({}, { __mode = "k" }) :: any

local function stateOf(player: Instance): State
	local state = states[player]
	if not state then
		state = { step = 0, parryable = false }
		states[player] = state
	end
	return state
end

local function heldMelee(player: Player): Tool?
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute(Constants.MELEE_HIT_EFFECT_ATTRIBUTE) ~= nil then
		return tool
	end
	return nil
end

-- A validated melee swing: its damage multiplier and whether it is a heavy.
function MeleeMoves.onSwing(player: Instance, weapon: Tool, timestamp: number): (number, boolean)
	local state = stateOf(player)
	local heavy = MeleeRules.isHeavy(state.lastSwing, state.chargeFrom, timestamp)
	state.chargeFrom = nil
	if heavy then
		state.step = 0
		state.lastSwing = timestamp
		return MeleeRules.HEAVY_MULTIPLIER, true
	end
	local rateOfFire = weapon:GetAttribute(Constants.RATE_OF_FIRE_ATTRIBUTE)
	local cooldown = 60 / (if typeof(rateOfFire) == "number" and rateOfFire > 0 then rateOfFire else 60)
	state.step = MeleeRules.nextStep(state.step, state.lastSwing, timestamp, cooldown)
	state.lastSwing = timestamp
	return MeleeRules.COMBO[state.step], false
end

-- MeleeCharge: `from` is the timestamp of the swing the player is still holding after (only the last swing counts), or
-- false when they let go early.
function MeleeMoves.charge(player: Instance, from: unknown)
	local state = stateOf(player)
	if typeof(from) == "number" and from == state.lastSwing then
		state.chargeFrom = from
	else
		state.chargeFrom = nil
	end
end

function MeleeMoves.block(player: Player, on: unknown)
	if typeof(on) ~= "boolean" then
		return
	end
	local state = stateOf(player)
	local character = player.Character
	if on and heldMelee(player) and character then
		if state.blockingSince == nil then
			local now = os.clock()
			state.parryable = state.lastBlockStart == nil or now - state.lastBlockStart >= MeleeRules.PARRY_REARM
			state.blockingSince = now
			state.lastBlockStart = now
			character:SetAttribute("Blocking", true)
		end
	elseif not on and state.blockingSince ~= nil then
		state.blockingSince = nil
		if character then
			character:SetAttribute("Blocking", nil)
		end
	end
end

-- A melee hit on `victim` from `attackerPosition` (ShotResolver.applyDamage, once per swing per victim): the damage
-- factor and whether it was parried. A player blocks only while still holding a melee weapon.
function MeleeMoves.defend(victim: Humanoid, attackerPosition: Vector3): (number, boolean)
	local character = victim.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	local state = player and states[player]
	local root = victim.RootPart
	if not (player and state and state.blockingSince and root and heldMelee(player)) then
		return 1, false
	end
	local factor, parried = MeleeRules.defend(os.clock() - state.blockingSince, state.parryable, root.CFrame.LookVector,
		attackerPosition - root.Position)
	if parried then
		state.parryable = false
	end
	return factor, parried
end

local function stun(model: Model?, seconds: number)
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) :: BasePart?
	if not (model and root) then
		return
	end
	root:SetAttribute("StunnedUntil", math.max(root:GetAttribute("StunnedUntil") or 0, os.clock() + seconds))
	RagdollController.stagger(model, seconds)
end

-- A parry stuns the attacker (a player's character or an NPC model) for PARRY_STUN.
function MeleeMoves.stunAttacker(attacker: Player | Model)
	stun(if attacker:IsA("Player") then attacker.Character else attacker, MeleeRules.PARRY_STUN)
end

-- A heavy swing staggers what it hits for HEAVY_STAGGER.
function MeleeMoves.stagger(victim: Humanoid)
	local model = victim.Parent
	stun(if model and model:IsA("Model") then model else nil, MeleeRules.HEAVY_STAGGER)
end

local started = false
function MeleeMoves.start()
	if started then
		return
	end
	started = true
	local remotes = ReplicatedStorage.Combat.Remotes
	remotes.MeleeCharge.OnServerEvent:Connect(MeleeMoves.charge)
	remotes.Block.OnServerEvent:Connect(MeleeMoves.block)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local state = states[player]
			if state then
				state.blockingSince = nil
				state.chargeFrom = nil
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return MeleeMoves
