-- Admin roles (2026-11-20, admin-design.md "Access"). No UserId literal anywhere: a role comes from Studio, the
-- place's creator or a group rank.
--
-- roleOf is pure (the environment is passed in; AdminRoles_Test drives it). The live part reads the rank once per
-- join (pcall; a failure leaves no role and retries a few times), caches it per player, publishes the player
-- attribute AdminRole ("owner" / "helper") for the HUD, tells onChanged listeners (AdminService delivers the
-- panel) and forgets the player on leave.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.Config)

local Roles = {}

local function fromRank(rank: number): string?
	if rank >= Config.OWNER_RANK then
		return "owner"
	elseif rank >= Config.HELPER_RANK then
		return "helper"
	end
	return nil
end

-- env = { isStudio, creatorType: Enum.CreatorType, creatorId, rankIn: (groupId) -> number (may throw) }.
-- Returns the role (or nil) and true when a rank lookup failed (then the role is nil).
function Roles.roleOf(userId: number, env): (string?, boolean)
	if env.isStudio then
		return "owner", false
	end
	if env.creatorType == Enum.CreatorType.User and userId == env.creatorId then
		return "owner", false
	end
	local groups = { Config.GROUP_ID }
	if env.creatorType == Enum.CreatorType.Group and env.creatorId ~= Config.GROUP_ID then
		table.insert(groups, env.creatorId)
	end
	local best = nil
	for _, groupId in groups do
		local ok, rank = pcall(env.rankIn, groupId)
		if not ok or type(rank) ~= "number" then
			return nil, true
		end
		local role = fromRank(rank)
		if role == "owner" then
			return role, false
		end
		best = best or role
	end
	return best, false
end

local cache: { [Player]: string | false } = {} -- false: looked up, no role
local listeners = {}

-- The cached role, or nil (no role, or not looked up yet).
function Roles.get(player): string?
	return cache[player] or nil
end

-- Sets the role (false = none), publishes AdminRole and tells the listeners. Also the test seam for a role-less
-- caller in Play: Roles.set(player, false), then Roles.set(player, "owner") to restore.
function Roles.set(player: Player, role: string | false)
	cache[player] = role
	player:SetAttribute("AdminRole", role or nil)
	for _, fn in listeners do
		task.spawn(fn, player, role or nil)
	end
end

function Roles.onChanged(fn: (Player, string?) -> ())
	table.insert(listeners, fn)
end

-- Once per join. Yields on the rank lookup; a failure retries RANK_RETRIES times, RANK_RETRY_SECONDS apart.
function Roles.load(player: Player)
	for _ = 0, Config.RANK_RETRIES do
		if player.Parent ~= Players then
			return
		end
		local role, failed = Roles.roleOf(player.UserId, {
			isStudio = RunService:IsStudio(),
			creatorType = game.CreatorType,
			creatorId = game.CreatorId,
			rankIn = function(groupId)
				return player:GetRankInGroup(groupId)
			end,
		})
		if not failed then
			if player.Parent == Players then
				Roles.set(player, role or false)
			end
			return
		end
		task.wait(Config.RANK_RETRY_SECONDS)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cache[player] = nil
end)

return Roles
