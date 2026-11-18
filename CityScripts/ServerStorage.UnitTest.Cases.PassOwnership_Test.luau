-- PassOwnership: the one gamepass ownership path (city passes and the heist duffel passes, 2026-11-18).
-- Each test requires a CLONE of the module, so the seams it swaps never reach the live copy that
-- MonetizationService uses in the same server. Stand-in players are tables: a unit test cannot mint a
-- Player, and the module only uses UserId, GetAttribute and SetAttribute (plus the `_inGame` seam).
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Constants = require(ReplicatedStorage.Monetization.Constants)
	local expect = t.expect

	local PASSES = {
		{ key = "Configured", gamepassId = 501 },
		{ key = "Second", gamepassId = 502 },
		{ key = "PlaceholderA", gamepassId = 0 },
		{ key = "PlaceholderB", gamepassId = 0 },
	}
	local function attr(key) return Constants.ownedAttributeFor(key) end

	local nextUserId = 0
	local function fakePlayer()
		nextUserId += 1
		local attributes = {}
		return {
			UserId = nextUserId,
			inGame = true,
			GetAttribute = function(_, name) return attributes[name] end,
			SetAttribute = function(_, name, value) attributes[name] = value end,
		}
	end

	-- A fresh copy with stand-in passes, no delays, and an ownership stub. `answers` is either a map
	-- gamepassId -> boolean, or a list answered one per call (the last repeats; "error" throws).
	local function fresh(answers)
		local PassOwnership = require(ServerScriptService.Monetization.Scripts.PassOwnership:Clone())
		PassOwnership._passes = PASSES
		PassOwnership._inGame = function(player) return player.inGame end
		PassOwnership._confirmRetryDelay = 0
		PassOwnership._failedCheckRetryDelay = 0.05
		local calls = {}
		PassOwnership._ownershipCheck = function(userId, gamepassId)
			table.insert(calls, { userId = userId, gamepassId = gamepassId })
			local answer
			if #answers > 0 then
				answer = answers[math.min(#calls, #answers)]
			else
				answer = answers[gamepassId] == true
			end
			if answer == "error" then error("network error") end
			return answer
		end
		return PassOwnership, calls
	end
	local function settle() task.wait(0.1) end -- the confirm runs in its own thread

	t.test("join: an owned pass reads owned, a pass not owned reads not owned", function()
		local PassOwnership = fresh({ [501] = true })
		local player = fakePlayer()
		PassOwnership.publish(player)
		expect.equal(player:GetAttribute(attr("Configured")), true)
		expect.equal(player:GetAttribute(attr("Second")), false)
		expect.truthy(PassOwnership.owns(player, "Configured"))
		expect.falsy(PassOwnership.owns(player, "Second"))
	end)

	t.test("join: a placeholder id 0 is never owned and never asked about", function()
		local PassOwnership, calls = fresh({ [0] = true })
		local player = fakePlayer()
		PassOwnership.publish(player)
		expect.equal(player:GetAttribute(attr("PlaceholderA")), false)
		for _, call in calls do
			expect.falsy(call.gamepassId == 0)
		end
		expect.equal(#calls, 2) -- the two configured passes only
	end)

	t.test("two id-0 passes keep their own entries: owning one pass marks neither", function()
		local PassOwnership = fresh({ [501] = true })
		local player = fakePlayer()
		PassOwnership.publish(player)
		expect.falsy(PassOwnership.owns(player, "PlaceholderA"))
		expect.falsy(PassOwnership.owns(player, "PlaceholderB"))
		expect.truthy(attr("PlaceholderA") ~= attr("PlaceholderB"))
	end)

	t.test("reads never call the network: the published attribute is the only record", function()
		local PassOwnership, calls = fresh({ [501] = true })
		local player = fakePlayer()
		PassOwnership.publish(player)
		local afterJoin = #calls
		for _ = 1, 3 do
			PassOwnership.owns(player, "Configured")
			PassOwnership.owns(player, "Second")
		end
		expect.equal(#calls, afterJoin)
	end)

	t.test("ownership is per player", function()
		local PassOwnership = fresh({ [501] = true })
		local a, b = fakePlayer(), fakePlayer()
		PassOwnership.publish(a)
		expect.truthy(PassOwnership.owns(a, "Configured"))
		expect.falsy(PassOwnership.owns(b, "Configured")) -- b never joined: nothing published for b
	end)

	t.test("a failed check reads not owned, does not throw, and is asked again once after the retry delay", function()
		local PassOwnership, calls = fresh({ "error", true })
		PassOwnership._passes = { PASSES[1] }
		local player = fakePlayer()
		local ok = pcall(PassOwnership.publish, player)
		expect.truthy(ok)
		expect.equal(player:GetAttribute(attr("Configured")), false)
		for _ = 1, 5 do PassOwnership.owns(player, "Configured") end
		expect.equal(#calls, 1) -- no read asked during the window
		task.wait(0.15)
		expect.equal(#calls, 2)
		expect.truthy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("a purchase confirmed by the ownership check reads owned", function()
		local PassOwnership, calls = fresh({ true })
		local player = fakePlayer()
		PassOwnership.onPurchaseFinished(player, 501, true)
		settle()
		expect.equal(#calls, 1)
		expect.truthy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("not owned at join, then a purchase confirmed on the 2nd attempt reads owned", function()
		local PassOwnership, calls = fresh({ false, false, true }) -- join, stale, confirmed
		PassOwnership._passes = { PASSES[1] }
		local player = fakePlayer()
		PassOwnership.publish(player)
		expect.falsy(PassOwnership.owns(player, "Configured"))
		PassOwnership.onPurchaseFinished(player, 501, true)
		settle()
		expect.equal(#calls, 3)
		expect.truthy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("the event says purchased but the web check says no: not owned after 3 tries, nothing more", function()
		local PassOwnership, calls = fresh({ false })
		local player = fakePlayer()
		PassOwnership.onPurchaseFinished(player, 501, true)
		task.wait(0.2) -- past the failed-check retry delay: no further ask
		expect.equal(#calls, 3)
		expect.falsy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("a purchase whose check errors 3 times does not throw, reads not owned, and is asked again later", function()
		local PassOwnership, calls = fresh({ "error", "error", "error", true })
		PassOwnership._failedCheckRetryDelay = 0.3
		local player = fakePlayer()
		local ok = pcall(PassOwnership.onPurchaseFinished, player, 501, true)
		settle()
		expect.truthy(ok)
		expect.equal(#calls, 3)
		expect.falsy(PassOwnership.owns(player, "Configured"))
		task.wait(0.35)
		expect.equal(#calls, 4)
		expect.truthy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("a closed prompt without a purchase asks nothing and changes nothing", function()
		local PassOwnership, calls = fresh({ true })
		local player = fakePlayer()
		PassOwnership.onPurchaseFinished(player, 501, false)
		settle()
		expect.equal(#calls, 0)
		expect.equal(player:GetAttribute(attr("Configured")), nil)
	end)

	t.test("a stale false arriving after a confirmed true does not overwrite it", function()
		local PassOwnership = fresh({})
		PassOwnership._passes = { PASSES[1] }
		local player = fakePlayer()
		PassOwnership._ownershipCheck = function()
			player:SetAttribute(attr("Configured"), true) -- the confirm lands while this check yields
			return false
		end
		PassOwnership.publish(player)
		expect.truthy(PassOwnership.owns(player, "Configured"))
	end)

	t.test("an event carrying id 0 matches no pass and makes no call", function()
		local PassOwnership, calls = fresh({ true })
		local player = fakePlayer()
		PassOwnership.onPurchaseFinished(player, 0, true)
		settle()
		expect.equal(#calls, 0)
		expect.equal(player:GetAttribute(attr("PlaceholderA")), nil)
		expect.equal(player:GetAttribute(attr("PlaceholderB")), nil)
	end)

	t.test("an event for an id outside the pass list changes nothing", function()
		local PassOwnership, calls = fresh({ true })
		local player = fakePlayer()
		PassOwnership.onPurchaseFinished(player, 999, true)
		settle()
		expect.equal(#calls, 0)
	end)

	t.test("a player who leaves mid-confirm gets no entry and no further tries", function()
		local PassOwnership, calls = fresh({ false, false, true })
		local player = fakePlayer()
		PassOwnership._confirmRetryDelay = 0.1
		PassOwnership.onPurchaseFinished(player, 501, true)
		task.wait(0.05) -- the first try answered no; the second waits
		player.inGame = false
		task.wait(0.3)
		expect.equal(#calls, 1)
		expect.equal(player:GetAttribute(attr("Configured")), nil)
	end)

	t.test("config: the duffel passes are hidden placeholders; the panel's 7 passes are unchanged", function()
		local shown, hidden = {}, {}
		for _, pass in Constants.Gamepasses do
			if pass.shop == false then
				hidden[pass.key] = pass.gamepassId
			else
				table.insert(shown, pass.key)
			end
		end
		expect.equal(table.concat(shown, ","), "DoubleCash,DoubleXp,Vip,ExtraSlot,FastReload,InfiniteSprint,RPG")
		expect.equal(hidden.DuffelCapacityX2, 0)
		expect.equal(hidden.DuffelCapacityX4, 0)
		expect.equal(hidden.DuffelSpeedBoost, 0)
		expect.falsy(Constants.isConfigured(0))
	end)
end
