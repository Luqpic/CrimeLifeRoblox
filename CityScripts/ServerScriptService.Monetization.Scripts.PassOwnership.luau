-- Gamepass ownership for every pass in Monetization.Constants.Gamepasses: the city's passes and the
-- heist duffel passes (one system since 2026-11-18). Ownership is published as the player attribute
-- GamepassOwned_<key>, and that attribute is the only record: WeaponShopService, CosmeticsService, the
-- heist's GamepassManager and the client shops all read it, so a read never calls the network, and the
-- record leaves with the Player (nothing to clear on leave).
--
-- - A pass with id 0 is "not configured": never owned, never prompted, never asked about, and a
--   purchase event carrying 0 matches nothing (the heist's three passes used to share the key 0).
-- - A failed check reads not owned and is asked again after FAILED_CHECK_RETRY_SECONDS, never on a read.
-- - PromptGamePassPurchaseFinished is reported through the client, so "purchased" is confirmed with
--   UserOwnsGamePassAsync before anything is published: up to CONFIRM_ATTEMPTS tries,
--   CONFIRM_RETRY_SECONDS apart, off the event thread, stopping once the player has left.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Monetization.Constants)

local PassOwnership = {}

-- Seams for PassOwnership_Test, which swaps them on a cloned copy (never on this live one).
PassOwnership._passes = Constants.Gamepasses
PassOwnership._ownershipCheck = function(userId: number, gamepassId: number): boolean
	return MarketplaceService:UserOwnsGamePassAsync(userId, gamepassId)
end
PassOwnership._inGame = function(player): boolean
	return player.Parent == Players
end
PassOwnership._confirmRetryDelay = Constants.CONFIRM_RETRY_SECONDS
PassOwnership._failedCheckRetryDelay = Constants.FAILED_CHECK_RETRY_SECONDS

function PassOwnership.owns(player, key: string): boolean
	return player:GetAttribute(Constants.ownedAttributeFor(key)) == true
end

-- A check that started before a confirmed purchase landed may answer a stale false: it never
-- overwrites the true.
local function publishAnswer(player, pass: Constants.Gamepass, owns: boolean)
	if owns or not PassOwnership.owns(player, pass.key) then
		player:SetAttribute(Constants.ownedAttributeFor(pass.key), owns)
	end
end

-- (answered, owns)
local function ask(player, pass: Constants.Gamepass): (boolean, boolean)
	local ok, owns = pcall(PassOwnership._ownershipCheck, player.UserId, pass.gamepassId)
	return ok, ok and owns == true
end

local function check(player, pass: Constants.Gamepass)
	if not PassOwnership._inGame(player) then
		return
	end
	local answered, owns = ask(player, pass)
	if not PassOwnership._inGame(player) then
		return -- left while the web call yielded
	end
	publishAnswer(player, pass, owns)
	if not answered then
		warn(`PassOwnership: ownership check failed for gamepass "{pass.key}"; asking again in {PassOwnership._failedCheckRetryDelay} s`)
		task.delay(PassOwnership._failedCheckRetryDelay, check, player, pass)
	end
end

-- At join: every pass, in order. A failing pass does not stop the ones after it.
function PassOwnership.publish(player)
	for _, pass in PassOwnership._passes do
		if Constants.isConfigured(pass.gamepassId) then
			check(player, pass)
		else
			player:SetAttribute(Constants.ownedAttributeFor(pass.key), false)
		end
	end
end

local function passForId(gamepassId: any): Constants.Gamepass?
	if not Constants.isConfigured(gamepassId) then
		return nil
	end
	for _, pass in PassOwnership._passes do
		if pass.gamepassId == gamepassId then
			return pass
		end
	end
	return nil
end

function PassOwnership.onPurchaseFinished(player, gamepassId: any, wasPurchased: any)
	if wasPurchased ~= true then
		return
	end
	local pass = passForId(gamepassId)
	if not pass then
		return
	end
	task.spawn(function()
		local answered = false
		for attempt = 1, Constants.CONFIRM_ATTEMPTS do
			if attempt > 1 then
				task.wait(PassOwnership._confirmRetryDelay)
			end
			if not PassOwnership._inGame(player) then
				return
			end
			local owns
			answered, owns = ask(player, pass)
			if not PassOwnership._inGame(player) then
				return
			end
			if owns then
				publishAnswer(player, pass, true)
				return
			end
		end
		-- "Not owned" three times is an answer: nothing more. A last try that could not answer at all is
		-- a failed check, asked again later like one at join.
		if not answered then
			task.delay(PassOwnership._failedCheckRetryDelay, check, player, pass)
		end
	end)
end

return PassOwnership
