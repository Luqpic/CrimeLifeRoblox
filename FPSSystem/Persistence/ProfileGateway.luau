-- The only module in this place that knows ProfileStore exists.
--
-- Services call waitFor/get and receive a plain table. That keeps ProfileStore swappable and keeps its
-- API out of the seven services that hold progression state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileStore = require(ServerStorage.ProfileStore)
local Schema = require(ReplicatedStorage.Persistence.Schema)

local STORE_NAME = "PlayerProfiles"
local LOAD_ATTEMPTS = 3
local RETRY_DELAY = 2
local LOAD_DEADLINE = 30 -- seconds; after this a load is abandoned and the player is kicked

local KICK_MESSAGE =
	"Your saved data could not be loaded, so nothing has been changed. Please rejoin in a moment."

local ProfileGateway = {}

local store = ProfileStore.New(STORE_NAME, Schema.template)
local profiles: { [any]: any } = {}
local forcedFailure = false

-- Both of these exist for tests and would be catastrophic in a live server: pointing at the mock store
-- silently discards everything written afterwards, and there is deliberately no way to undo it. The
-- guard is what stops a stray call in one of the seven services doing that by accident.
function ProfileGateway.useMockStore()
	if not RunService:IsStudio() then
		warn("[Persistence] useMockStore ignored outside Studio")
		return
	end
	store = ProfileStore.New(STORE_NAME, Schema.template).Mock
end

-- Test seam only: makes the next load behave as a contended session would.
function ProfileGateway._forceNextLoadFailure(active: boolean)
	if not RunService:IsStudio() then
		return
	end
	forcedFailure = active
end

-- Test seams only. Production binding happens in onPlayerAdded; these let a test attach a stand-in
-- player to a profile without a real Player instance, which cannot be constructed.
function ProfileGateway._bind(player: any, profile: any)
	profiles[player] = profile
end

function ProfileGateway._unbind(player: any)
	profiles[player] = nil
end

-- Applies a change to a player's profile, if they have one.
--
-- Guarded because a persistence failure must cost a save and never the gameplay path it sits in --
-- the same rule every cosmetics call site in Phases 1 and 2 follows. A player with no profile is not
-- an error here: they are mid-load, or their load failed and they are about to be removed, and either
-- way the correct behaviour is to change nothing.
function ProfileGateway.mirror(player: any, apply: (any) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	local ok, err = pcall(apply, profile)
	if not ok then
		warn("[Persistence] mirror failed for " .. tostring(player) .. ": " .. tostring(err))
	end
end

function ProfileGateway.keyFor(userId: number): string
	return "player_" .. userId
end

-- Loads one key, retrying a contended session a few times. Returns nil when it cannot be had.
--
-- `cancel` lets a load abandon itself when the player it was for has already left, so a departing
-- player does not hold a session open while the server retries on their behalf.
function ProfileGateway.loadForKey(key: string, cancel: (() -> boolean)?): any?
	for attempt = 1, LOAD_ATTEMPTS do
		if cancel and cancel() then
			return nil
		end
		local profile = if forcedFailure then nil else store:StartSessionAsync(key, { Cancel = cancel })
		if profile then
			profile:Reconcile()
			if profile.Data.version == nil then
				profile.Data.version = Schema.VERSION
			end
			return profile
		end
		if attempt < LOAD_ATTEMPTS then
			if cancel and cancel() then
				return nil
			end
			task.wait(RETRY_DELAY)
		end
	end
	return nil
end

function ProfileGateway.get(player: any): any?
	return profiles[player]
end

function ProfileGateway.isLoaded(player: any): boolean
	return profiles[player] ~= nil
end

-- Yields until the player's profile is available. Returns nil if they left or the load failed, and
-- callers must treat nil as "do not persist anything for this player" rather than as "start fresh".
function ProfileGateway.waitFor(player: Player): any?
	while player.Parent == Players and profiles[player] == nil do
		task.wait(0.1)
	end
	return profiles[player]
end

local function onPlayerAdded(player: Player)
	-- Cancel serves two purposes: abandon a load whose player has already left, and put an upper bound
	-- on one that will never complete. Supplying Cancel at all disables ProfileStore's own session
	-- timeout, so without the deadline a sustained DataStore outage would leave a connected player
	-- waiting forever with no load, no kick and no explanation.
	local deadline = os.clock() + LOAD_DEADLINE
	local profile = ProfileGateway.loadForKey(
		ProfileGateway.keyFor(player.UserId),
		function()
			return player.Parent ~= Players or os.clock() > deadline
		end
	)

	if profile == nil then
		-- Nothing was written and nothing will be. Kicking is the honest outcome: a session that
		-- cannot save looks identical to one that can until the moment the player logs off.
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
		return
	end

	profile:AddUserId(player.UserId)

	profile.OnSessionEnd:Connect(function()
		profiles[player] = nil
		-- The session can end without the player leaving -- another server stealing it, or a
		-- shutdown. Continuing to play against a profile that no longer saves is the same silent
		-- data loss this phase exists to prevent.
		if player.Parent == Players then
			player:Kick(KICK_MESSAGE)
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	profiles[player] = profile
end

function ProfileGateway.start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		local profile = profiles[player]
		profiles[player] = nil
		if profile then
			profile:EndSession()
		end
	end)
end

return ProfileGateway
