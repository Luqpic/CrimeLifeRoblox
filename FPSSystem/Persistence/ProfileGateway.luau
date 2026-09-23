-- The only module in this place that knows ProfileStore exists.
--
-- Services call get and receive a plain table. That keeps ProfileStore swappable and keeps its
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
-- `apply` receives the PROFILE, so a write is `profile.Data.field = value`. Writing `field` directly on
-- the argument silently lands on the ProfileStore profile object, which is never serialised -- the
-- write appears to succeed and is simply lost. That bug shipped once already; hence the spelt-out
-- parameter name in every call site.
--
-- Guarded because a persistence failure must cost a save and never the gameplay path it sits in --
-- the same rule every cosmetics call site in Phases 1 and 2 follows. A player with no profile is not
-- an error here: they are mid-load, or their load failed and they are about to be removed, and either
-- way the correct behaviour is to change nothing.
function ProfileGateway.mirror(player: any, apply: (profile: any) -> ())
	local profile = profiles[player]
	if not profile then
		return
	end
	local ok, err = pcall(apply, profile)
	if not ok then
		warn("[Persistence] mirror failed for " .. tostring(player) .. ": " .. tostring(err))
	end
end

-- Services register at require time; the gateway runs them all after a successful load and BEFORE
-- binding the profile.
--
-- Ordering is the whole point. While hydrators run, get() still returns nil, so mirror is a no-op and
-- a change earned in that window is LOST rather than written from un-hydrated state. Losing a kill's
-- reward is recoverable; overwriting a real balance with a partial one is not.
local hydrators: { (player: any, profile: any) -> () } = {}

-- Runs a just-registered hydrator for every player whose profile is ALREADY bound.
--
-- _runHydrators runs whatever is registered at that instant and then binds unconditionally, so a
-- service that registers AFTER a bind never hydrates that player at all. Its own guarded PlayerAdded
-- default then wins, and the next ordinary action mirrors that default over real saved data: level 1
-- over a saved level 12 on the first kill, {Crowbar} over real ownership on the first purchase, a fresh
-- kills table over a real count. Closing the window here -- at the class -- rather than in each service
-- is what stops the next adoption reopening it; the alternative is seven services each remembering.
--
-- Guarded exactly like the loops below, so a throwing late hydrator cannot take registration with it.
local function runForBound(label: string, fn: (player: any, profile: any) -> ())
	for player, profile in profiles do
		local ok, err = pcall(fn, player, profile)
		if not ok then
			warn("[Persistence] late " .. label .. " failed for " .. tostring(player) .. ": " .. tostring(err))
		end
	end
end

function ProfileGateway.registerHydrator(hydrator: (player: any, profile: any) -> ())
	table.insert(hydrators, hydrator)
	runForBound("hydrator", hydrator)
end

-- Test seam only: runs every registered hydrator directly, without a real Player or onPlayerAdded --
-- which needs one. Production reuses this same function below, so there is exactly one hydrate-then-
-- bind sequence, not a copy a test exercises and a separate copy the live server actually runs.
function ProfileGateway._runHydrators(player: any, profile: any)
	for _, hydrator in hydrators do
		local ok, err = pcall(hydrator, player, profile)
		if not ok then
			warn("[Persistence] hydrator failed for " .. tostring(player) .. ": " .. tostring(err))
		end
	end
end

-- Runs after every hydrator, still before the bind.
--
-- Some restoration depends on the whole profile being restored, not just one service's slice:
-- re-dressing a Tool needs both the equipped skin AND the ownership attributes that decide whether
-- that skin is allowed. Ordering hydrators by hand would work until someone adds a require and
-- silently changes the order, so the dependency gets its own phase instead of a convention.
local postHydrators: { (player: any, profile: any) -> () } = {}

function ProfileGateway.registerPostHydrator(postHydrator: (player: any, profile: any) -> ())
	table.insert(postHydrators, postHydrator)
	runForBound("post-hydrator", postHydrator)
end

-- Test seam only: same rationale as _runHydrators -- production reuses this below.
function ProfileGateway._runPostHydrators(player: any, profile: any)
	for _, postHydrator in postHydrators do
		local ok, err = pcall(postHydrator, player, profile)
		if not ok then
			warn("[Persistence] post-hydrator failed for " .. tostring(player) .. ": " .. tostring(err))
		end
	end
end

function ProfileGateway.keyFor(userId: number): string
	return "player_" .. userId
end

-- Brings stored data up to the current shape. Returns whether anything changed, so a caller can tell
-- a migration from a no-op.
--
-- Adding a FIELD needs no migration -- Reconcile fills it from the template. This exists for the case
-- Reconcile cannot handle: a field whose MEANING changed, and stale derived values that should never
-- have been stored.
function ProfileGateway.migrate(data: { [string]: any }): boolean
	local changed = false

	if data.version == nil then
		data.version = Schema.VERSION
		changed = true
	end

	for _, derived in Schema.DERIVED do
		if data[derived] ~= nil then
			data[derived] = nil
			changed = true
		end
	end

	-- A stamped, non-nil version with no case above that resolves it means VERSION was bumped without
	-- a step for it. Failing loudly here beats silently reading (and saving back) v-old data under a
	-- vN meaning -- the exact case the comment above this function names as migrate's reason to exist.
	assert(
		data.version == Schema.VERSION,
		string.format("ProfileGateway.migrate: no migration step for stored version %s (current is %s)", tostring(data.version), tostring(Schema.VERSION))
	)

	return changed
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
		-- StartSessionAsync is the only call in this function that makes a network round trip, and it
		-- THROWS rather than returning nil in at least one reachable case: a key already loaded in this
		-- same server, which is what a rejoin lands on inside the window between PlayerRemoving calling
		-- EndSession and the session actually ending. Unguarded, that throw escaped loadForKey AND
		-- onPlayerAdded, so the profile == nil kick never ran and the player played a full session
		-- unbound -- mirror silently no-opping, nothing saved. Exactly the outcome the kick exists to
		-- prevent, arrived at by the one line nobody had wrapped.
		--
		-- Treated as a failed ATTEMPT rather than an immediate nil: a contended or transient failure is
		-- what LOAD_ATTEMPTS is for, and the rejoin window is short enough that the next attempt often
		-- succeeds. If every attempt throws, the nil return hands the player to the existing kick path.
		local profile
		if not forcedFailure then
			local ok, result = pcall(function()
				return store:StartSessionAsync(key, { Cancel = cancel })
			end)
			if ok then
				profile = result
			else
				warn("[Persistence] StartSessionAsync failed for " .. key .. " (attempt " .. attempt .. "): " .. tostring(result))
			end
		end
		if profile then
			profile:Reconcile()
			-- migrate can throw (its own version assert), so it is pcall'd like every other step that runs
			-- between a successful StartSessionAsync and the bind: an uncaught throw here would otherwise
			-- escape loadForKey uncaught, skip the kick at onPlayerAdded's profile==nil branch, and leave
			-- the session open -- a player playing fully unbound AND a leaked lock on their next join.
			local migrateOk, migrateResult = pcall(ProfileGateway.migrate, profile.Data)
			if not migrateOk then
				warn("[Persistence] migrate failed for " .. key .. ": " .. tostring(migrateResult))
				profile:EndSession()
				return nil
			end
			if migrateResult then
				print("[Persistence] migrated profile " .. key .. " to version " .. tostring(Schema.VERSION))
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

local function onPlayerAdded(player: Player)
	-- Cancel serves two purposes: abandon a load whose player has already left, and put an upper bound
	-- on one that will never complete. Supplying Cancel at all disables ProfileStore's own session
	-- timeout, so without the deadline a sustained DataStore outage would leave a connected player
	-- waiting forever with no load, no kick and no explanation.
	--
	-- NEVER EXERCISED. ProfileStore's Mock proxy calls `self:StartSessionAsync(profile_key)` and drops
	-- the params argument, so under useMockStore -- which is every test run and every measurement this
	-- place has ever taken -- `params.Cancel` is nil inside ProfileStore and its own START_SESSION_TIMEOUT
	-- is back in charge. Neither the deadline below nor the departing-player cancel has run even once.
	-- Deliberately not worked around: the vendored file is pinned to an upstream sha256 and that
	-- guarantee is worth more than reaching this branch. See FPS-Persistence-Phase-3.md, DEFERRED.
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

	-- Hydrators run here, strictly before the bind below, so nothing outside this function can ever
	-- observe a bound profile whose attributes are not yet restored. get() stays nil for the whole of
	-- this loop. Post-hydrators run after EVERY hydrator has finished, so anything
	-- that depends on another service's restored state -- not just its own -- sees it regardless of
	-- which service happened to register first.
	ProfileGateway._runHydrators(player, profile)
	ProfileGateway._runPostHydrators(player, profile)

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
