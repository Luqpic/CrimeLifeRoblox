-- Server side of the roll (2026-11-20). StarterCharacterScripts.Movement rolls at once, the character being the
-- client's, and fires ReplicatedStorage.PlayerMovement.Roll (wired in RunningState); this re-checks the roll on the
-- server's own clock and state and spends its stamina through SprintAuthority. A refused roll costs nothing.
-- ponytail: a refused roll is not undone (no server rollback of a client-owned move); add one if rolls get abused.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.PlayerMovement.Config)
local Constants = require(ReplicatedStorage.Movement.Constants)
local CarryState = require(ReplicatedStorage.SharedSystems.CarryState)
local SprintAuthority = require(script.Parent.SprintAuthority)

local RollAuthority = {}

local lastRoll: { [Player]: number } = {}

-- `now` is this server's os.clock(). Returns true once the stamina is spent, or false and why not.
function RollAuthority.request(player: Player, now: number): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root
		or (typeof(player) == "Instance" and player:IsA("Player") and player.Parent == nil) then -- a request after leaving
		return false, "dead"
	end
	if now - (lastRoll[player] or -math.huge) < Config.Roll.Cooldown then
		return false, "cooldown"
	end
	-- any carry: a heavy one (the cap attribute) or a light one (CarryState)
	if character:GetAttribute(Constants.CARRY_SPEED_CAP_ATTRIBUTE) ~= nil or CarryState:IsCarrying(player) then
		return false, "carrying"
	end
	local stunnedUntil = root:GetAttribute("StunnedUntil")
	if (type(stunnedUntil) == "number" and now < stunnedUntil) or character:GetAttribute("IsRagdolled") or root.Anchored
		or character:GetAttribute("AdminFrozen") or player:GetAttribute("AdminFrozen")
		or root:GetAttribute("IsCrouching") == true or humanoid.Sit or humanoid.PlatformStand then
		return false, "blocked"
	end
	if not SprintAuthority.spend(player, Config.Roll.Stamina) then
		return false, "stamina"
	end
	lastRoll[player] = now
	-- Combat balance (2026-11-20): NPC aim gives a rolling target its widest cone (Enemy.Scripts.NpcFire). The client's
	-- MoveAction attribute never reaches the server, so an accepted roll is stamped here, for the longest roll.
	root:SetAttribute("RollingUntil", now + Config.Roll.Time * Config.Roll.Sprint.Time)
	return true
end

function RollAuthority.cleanup(player: Player)
	lastRoll[player] = nil
end

return RollAuthority
