--!strict
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

-- Universal, location-agnostic gamepass logic (spec addendum, 2026-09-03).
-- Lives under ReplicatedStorage.SharedSystems -- a sibling of HeistShared,
-- not nested inside it -- so any future robbery system references this
-- directly instead of reimplementing ownership checks/tier logic per
-- location. A robbery-specific module (e.g. this Bank's BankInstance) should
-- only ever see the RESULT of these functions via an injected dependency; it
-- must never require this module directly, so it stays testable without a
-- real MarketplaceService round-trip. See BankInstance.new's
-- duffelCapMultiplier/accrualRateMultiplier deps for that seam.
local GamepassManager = {}

-- TODO(project owner): every Id below is a placeholder. DuffelSpeedBoost's
-- Multiplier is also TBD -- a real balance decision, not a technical one.
GamepassManager.GamepassConfig = {
	DuffelCapacityX2 = { Id = 0, Multiplier = 2 },
	DuffelCapacityX4 = { Id = 0, Multiplier = 4 },
	DuffelSpeedBoost = { Id = 0, Multiplier = 1.5 },
}

-- player.UserId -> gamepassId -> boolean
local _cache = {}

-- The actual network call, factored out so tests can swap it for a stub
-- instead of hitting a real MarketplaceService (which has no real gamepass
-- to check against in a test/offline context anyway). Production code must
-- never call MarketplaceService directly anywhere else in this module --
-- always through here, so the cache stays the only path to it.
GamepassManager._ownershipCheck = function(userId: number, gamepassId: number): boolean
	return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
end

local function cacheFor(userId: number)
	_cache[userId] = _cache[userId] or {}
	return _cache[userId]
end

-- Records a KNOWN ownership fact directly, bypassing _ownershipCheck --
-- used by _onPurchaseFinished once the ownership check has confirmed a
-- purchase (city, phase 3 Task 5: the client-reported event alone is not
-- trusted), and by tests simulating that same fact.
function GamepassManager:_setCached(userId: number, gamepassId: number, owns: boolean)
	cacheFor(userId)[gamepassId] = owns
end

function GamepassManager:PlayerOwnsGamepass(player, gamepassId: number): boolean
	local cache = cacheFor(player.UserId)
	local cached = cache[gamepassId]
	if cached ~= nil then return cached end

	local ok, owns = pcall(GamepassManager._ownershipCheck, player.UserId, gamepassId)
	if not ok then
		warn("[GamepassManager] UserOwnsGamePassAsync failed: " .. tostring(owns))
		return false
	end

	cache[gamepassId] = owns
	return owns
end

-- Checks x4 first and returns immediately if owned, so an x4 owner never
-- pays for a second (unnecessary) x2 lookup -- pure efficiency, both checks
-- go through the same cached wrapper either way. No stacking between tiers:
-- owning both resolves to x4 only, never x6 or any additive combination.
-- Also cleanly handles the x2 -> x4 upgrade path with no invalidation logic,
-- since both ownership records stay simultaneously valid; this just always
-- resolves to the higher one.
function GamepassManager:GetDuffelCapMultiplier(player): number
	local config = GamepassManager.GamepassConfig
	if GamepassManager:PlayerOwnsGamepass(player, config.DuffelCapacityX4.Id) then
		return config.DuffelCapacityX4.Multiplier
	end
	if GamepassManager:PlayerOwnsGamepass(player, config.DuffelCapacityX2.Id) then
		return config.DuffelCapacityX2.Multiplier
	end
	return 1
end

-- Independent of the capacity tiers -- stacks alongside whichever (if any)
-- capacity gamepass a player owns.
function GamepassManager:GetAccrualRateMultiplier(player): number
	local config = GamepassManager.GamepassConfig
	if GamepassManager:PlayerOwnsGamepass(player, config.DuffelSpeedBoost.Id) then
		return config.DuffelSpeedBoost.Multiplier
	end
	return 1
end

-- City (phase 3 Task 5, fix round 1): PromptGamePassPurchaseFinished is reported by the client,
-- so a "purchased" event is never taken as ownership on its own; it is confirmed through the same
-- ownership check (UserOwnsGamePassAsync, pcall'd). That call caches on Roblox's side and may still
-- answer false right after an in-game purchase, and a heist has usually cached false here already
-- (TryAddDuffel and accrual read PlayerOwnsGamepass). So the event first clears this user's entry
-- for the pass, then confirms off the event thread: up to CONFIRM_ATTEMPTS tries,
-- _confirmRetryDelay seconds apart, caching true on the first confirmed true. If none confirms the
-- entry stays empty and the next PlayerOwnsGamepass asks again. With the placeholder Id 0 nothing
-- is ever owned. A closed prompt without a purchase changes nothing.
local CONFIRM_ATTEMPTS = 3
GamepassManager._confirmRetryDelay = 2 -- seconds; a spec sets 0

function GamepassManager:_onPurchaseFinished(player, gamepassId: number, wasPurchased: boolean)
	if not wasPurchased then return end
	local userId = player.UserId
	cacheFor(userId)[gamepassId] = nil
	task.spawn(function()
		for attempt = 1, CONFIRM_ATTEMPTS do
			if attempt > 1 then task.wait(GamepassManager._confirmRetryDelay) end
			local ok, owns = pcall(GamepassManager._ownershipCheck, userId, gamepassId)
			if ok and owns == true then
				GamepassManager:_setCached(userId, gamepassId, true)
				return
			end
		end
	end)
end

-- Wires the real Players/MarketplaceService listeners exactly once, no
-- matter how many robbery-system scripts each call Init() defensively on
-- their own boot (every future location is expected to). Never called by
-- tests, so a freshRequire'd module in a spec never leaks a real listener.
local _initialized = false
function GamepassManager:Init()
	if _initialized then return end
	_initialized = true

	Players.PlayerAdded:Connect(function(player)
		-- Fresh slate, not a pre-fetch: a stale cache from an earlier session on
		-- this same server (rejoin) must not linger. The first real query after
		-- this naturally re-fetches from the API.
		_cache[player.UserId] = {}
	end)

	Players.PlayerRemoving:Connect(function(player)
		_cache[player.UserId] = nil
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamepassId, wasPurchased)
		GamepassManager:_onPurchaseFinished(player, gamepassId, wasPurchased)
	end)
end

return GamepassManager
