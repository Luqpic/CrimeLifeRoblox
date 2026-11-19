-- Tests for ServerScriptService.Admin.Actions (2026-11-20): the dispatcher's order (role, action role, target
-- rules, validation, cooldown, run, log) and each action's argument checks. Players are tables and every service
-- is a fake in ctx, so nothing here touches a real player, the economy or the world. Also BankInstance's cooldown
-- reset, the heist seam the admin calls.
return function(t)
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local Config = require(ServerScriptService.Admin.Config)
	local Actions = require(ServerScriptService.Admin.Actions)
	local BankInstance = require(ServerScriptService.Heist.BankInstance)
	local LEVEL_CAP = require(ReplicatedStorage.Leveling.Constants).LEVEL_CAP
	local expect = t.expect
	local R = Actions.REFUSE

	local OWNER, HELPER, HELPER2, PLAYER, STRANGER = 1, 2, 3, 4, 5
	local NAN, INF = 0 / 0, math.huge

	-- A fresh dispatcher over fake players and services. calls counts every service the runs touched.
	local function setup()
		local roles = {}
		local byId = {}
		local function fakePlayer(id, name, role)
			local p = { Name = name, DisplayName = name, UserId = id }
			byId[id] = p
			roles[p] = role
			return p
		end
		local s = {
			owner = fakePlayer(OWNER, "Owner", "owner"),
			helper = fakePlayer(HELPER, "Helper", "helper"),
			helper2 = fakePlayer(HELPER2, "Helper2", "helper"),
			player = fakePlayer(PLAYER, "Player", nil),
			stranger = fakePlayer(STRANGER, "Stranger", nil),
			clock = 100,
			calls = {},
		}
		local function count(name)
			s.calls[name] = (s.calls[name] or 0) + 1
		end
		s.ctx = {
			now = function() return s.clock end,
			roleOf = function(p) return roles[p] end,
			playerByUserId = function(id) return byId[id] end,
			players = function() return {} end,
			stats = function() return {} end,
			filterBroadcast = function(text) count("filter") return text end,
			broadcast = function(_text) count("broadcast") end,
			hooks = {
				setLevel = function(_p, _level) count("setLevel") end,
				giveWeapon = function(_p, _name) count("giveWeapon") return true, "given" end,
				heists = {},
			},
		}
		s.d = Actions.newDispatcher(s.ctx)
		function s.call(p, action, args)
			s.clock += Config.COOLDOWN -- keeps the cooldown out of every test but its own
			return s.d.call(p, action, args)
		end
		return s
	end

	local function refused(reply, message)
		expect.equal(reply.ok, false)
		if message then
			expect.equal(reply.message, message)
		end
	end

	t.test("a known action from the owner runs and is logged", function()
		local s = setup()
		local reply = s.call(s.owner, "setLevel", { target = PLAYER, level = 12 })
		expect.equal(reply.ok, true)
		expect.equal(s.calls.setLevel, 1)
		expect.equal(#s.d.log, 1)
		expect.equal(s.d.log[1].action, "setLevel")
		expect.equal(s.d.log[1].admin, "Owner")
		expect.equal(s.d.log[1].target, "Player")
	end)

	t.test("every owner-only action is refused for a helper before anything runs", function()
		local s = setup()
		local ownerOnly = 0
		for name, action in Actions.list do
			if action.role == "owner" then
				ownerOnly += 1
				refused(s.call(s.helper, name, { target = PLAYER }), R.ownerOnly)
			end
		end
		expect.equal(ownerOnly, 17)
		expect.equal(next(s.calls), nil)
		expect.equal(#s.d.log, 0)
	end)

	t.test("helper actions run for a helper", function()
		local s = setup()
		expect.equal(s.call(s.helper, "announce", { text = "hello" }).ok, true)
		expect.equal(s.calls.broadcast, 1)
		expect.equal(s.call(s.helper, "log", {}).ok, true)
	end)

	t.test("a helper never acts on an owner or another helper, teleport-to is allowed", function()
		local s = setup()
		for _, action in { "kick", "ban", "freeze", "unfreeze", "bring" } do
			refused(s.call(s.helper, action, { target = OWNER, reason = "x", duration = "1h" }), R.staff)
			refused(s.call(s.helper, action, { target = HELPER2, reason = "x", duration = "1h" }), R.staff)
		end
		-- goto passes the staff rule (fails later: a fake player has no character)
		local reply = s.call(s.helper, "goto", { target = OWNER })
		expect.truthy(reply.message ~= R.staff)
		-- the owner may act on a helper
		reply = s.call(s.owner, "freeze", { target = HELPER })
		expect.truthy(reply.message ~= R.staff)
	end)

	t.test("nobody is refused everything, logged once a minute", function()
		local s = setup()
		for name in Actions.list do
			refused(s.call(s.stranger, name, { target = PLAYER, text = "x" }), R.role)
		end
		refused(s.call(s.stranger, "nope", {}), R.role)
		expect.equal(next(s.calls), nil)
		expect.equal(#s.d.log, 1)
		expect.equal(s.d.log[1].admin, "Stranger")
		s.clock += Config.REFUSAL_LOG_SECONDS
		s.call(s.stranger, "lookup", {})
		expect.equal(#s.d.log, 2)
	end)

	t.test("unknown actions and arguments that are not a table are refused", function()
		local s = setup()
		refused(s.call(s.owner, "nope", {}), R.unknown)
		refused(s.call(s.owner, 42, {}), R.unknown)
		refused(s.call(s.owner, "__index", {}), R.unknown)
		refused(s.call(s.owner, "setLevel", "12"), R.badArgs)
		refused(s.call(s.owner, "setLevel", Instance.new("Folder")), R.badArgs)
	end)

	t.test("a target must be the UserId of a player in this server", function()
		local s = setup()
		for _, target in { 999, NAN, INF, -INF, "4", 4.5, true, Instance.new("Part"), { 4 } } do
			refused(s.call(s.owner, "setLevel", { target = target, level = 5 }), R.notFound)
		end
		refused(s.call(s.owner, "setLevel", { level = 5 }), R.notFound)
		expect.equal(s.calls.setLevel, nil)
	end)

	t.test("numbers must be finite, whole and in range", function()
		local s = setup()
		for _, level in { NAN, INF, -INF, "5", 0, LEVEL_CAP + 1, 5.5, Instance.new("Part"), nil } do
			refused(s.call(s.owner, "setLevel", { target = PLAYER, level = level }))
		end
		for _, amount in { NAN, INF, -INF, "100", 0, Config.CASH_LIMIT + 1, -Config.CASH_LIMIT - 1, 0.5 } do
			refused(s.call(s.owner, "addCash", { target = PLAYER, amount = amount }))
		end
		for _, stars in { -1, Config.STARS_MAX + 1, NAN, "3" } do
			refused(s.call(s.owner, "setStars", { target = PLAYER, stars = stars }))
		end
		for _, count in { 0, Config.SPAWN_COUNT_MAX + 1, NAN, INF } do
			refused(s.call(s.owner, "spawnPolice", { count = count }))
		end
		for _, value in { Config.WALK_SPEED_MIN - 1, Config.WALK_SPEED_MAX + 1, NAN, "50" } do
			refused(s.call(s.owner, "walkSpeed", { value = value }))
		end
		expect.equal(s.calls.setLevel, nil)
		-- the same calls with a good value pass their check
		expect.truthy(Actions.list.setLevel.validate({ level = LEVEL_CAP }, "owner"))
		expect.truthy(Actions.list.addCash.validate({ amount = -Config.CASH_LIMIT }, "owner"))
		expect.truthy(Actions.list.setStars.validate({ stars = 0 }, "owner"))
		expect.truthy(Actions.list.spawnPolice.validate({ count = Config.SPAWN_COUNT_MAX }, "owner"))
		expect.truthy(Actions.list.walkSpeed.validate({ value = Config.WALK_SPEED_MAX }, "owner"))
		expect.truthy(Actions.list.walkSpeed.validate({}, "owner")) -- no value: back to normal
	end)

	t.test("names must be a known weapon, enemy type, heist or place", function()
		local s = setup()
		for _, name in { "NoSuchGun", "", 7, NAN, Instance.new("Tool") } do
			refused(s.call(s.owner, "giveWeapon", { target = PLAYER, weapon = name }))
		end
		expect.equal(s.calls.giveWeapon, nil)
		expect.equal(s.call(s.owner, "giveWeapon", { target = PLAYER, weapon = "AK47" }).ok, true)
		expect.equal(s.calls.giveWeapon, 1)

		for _, name in { "Dragon", "Police", "Armed Police", 5 } do
			expect.falsy(Actions.list.spawnEnemy.validate({ enemyType = name, count = 1 }, "owner"))
		end
		expect.truthy(Actions.list.spawnEnemy.validate({ enemyType = "Thug", count = 1 }, "owner"))
		for _, name in { "Casino", "all", 1 } do
			expect.falsy(Actions.list.resetCooldown.validate({ heist = name }, "owner"))
		end
		expect.truthy(Actions.list.resetCooldown.validate({ heist = "All" }, "owner"))
		expect.truthy(Actions.list.resetCooldown.validate({ heist = "Gas2Go" }, "owner"))
		for _, name in { "Moon", "", false } do
			expect.falsy(Actions.list.teleportTo.validate({ place = name }, "helper"))
		end
		expect.truthy(Actions.list.teleportTo.validate({ place = "Illegal Supplier" }, "helper"))
		for _, scope in { "everything", 1 } do
			expect.falsy(Actions.list.clearEnemies.validate({ scope = scope }, "owner"))
		end
	end)

	t.test("text is a string, not empty and not too long", function()
		local s = setup()
		for _, text in { "", "   ", string.rep("a", Config.ANNOUNCE_MAX + 1), 5, Instance.new("Part") } do
			refused(s.call(s.owner, "announce", { text = text }))
		end
		expect.equal(s.calls.broadcast, nil)
		expect.falsy(Actions.list.kick.validate({ reason = string.rep("a", Config.KICK_REASON_MAX + 1) }, "owner"))
		expect.truthy(Actions.list.kick.validate({ reason = string.rep("a", Config.KICK_REASON_MAX) }, "owner"))
	end)

	t.test("ban lengths: a helper up to a day, the owner any of the four", function()
		expect.truthy(Actions.list.ban.validate({ duration = "1h" }, "helper"))
		expect.truthy(Actions.list.ban.validate({ duration = "1d" }, "helper"))
		expect.falsy(Actions.list.ban.validate({ duration = "7d" }, "helper"))
		expect.falsy(Actions.list.ban.validate({ duration = "forever" }, "helper"))
		for key in Config.BAN_DURATIONS do
			expect.truthy(Actions.list.ban.validate({ duration = key }, "owner"))
		end
		expect.falsy(Actions.list.ban.validate({ duration = "2y" }, "owner"))
	end)

	t.test("kick and ban refuse yourself", function()
		local s = setup()
		refused(s.call(s.owner, "kick", { target = OWNER, reason = "x" }), R.self)
		refused(s.call(s.owner, "ban", { target = OWNER, duration = "1h" }), R.self)
	end)

	t.test("a burst inside the cooldown is refused, the next call after it runs", function()
		local s = setup()
		expect.equal(s.d.call(s.owner, "announce", { text = "one" }).ok, true)
		refused(s.d.call(s.owner, "announce", { text = "two" }), R.tooFast)
		s.clock += Config.COOLDOWN * 0.9
		refused(s.d.call(s.owner, "announce", { text = "three" }), R.tooFast)
		s.clock += Config.COOLDOWN
		expect.equal(s.d.call(s.owner, "announce", { text = "four" }).ok, true)
		expect.equal(s.calls.broadcast, 2)
		-- per admin: the helper is not slowed by the owner
		expect.equal(s.d.call(s.helper, "announce", { text = "five" }).ok, true)
	end)

	t.test("the log keeps the newest LOG_SIZE rows, newest first, and reads are not logged", function()
		local s = setup()
		for i = 1, Config.LOG_SIZE + 10 do
			s.call(s.owner, "announce", { text = "n" .. i })
		end
		s.call(s.owner, "lookup", {})
		s.call(s.owner, "stats", nil)
		expect.equal(#s.d.log, Config.LOG_SIZE)
		expect.equal(s.d.log[1].detail, "n" .. (Config.LOG_SIZE + 10))
		local reply = s.call(s.owner, "log", {})
		expect.equal(#reply.data, Config.LOG_SIZE)
		expect.equal(reply.data[1].detail, "n" .. (Config.LOG_SIZE + 10))
	end)

	t.test("an action that throws is refused, logged and leaves the dispatcher working", function()
		local s = setup()
		s.ctx.hooks.setLevel = function()
			error("boom")
		end
		refused(s.call(s.owner, "setLevel", { target = PLAYER, level = 3 }), R.failed)
		expect.equal(s.d.log[1].detail, "failed")
		expect.equal(s.call(s.owner, "announce", { text = "still here" }).ok, true)
	end)

	t.test("text is bounded before the trim, announcements are spaced, a target still loading is refused", function()
		local s = setup()
		-- trimmed it would be "hi" (accepted); the byte bound refuses it before the pattern runs
		refused(s.call(s.helper, "announce", { text = string.rep(" ", 4 * Config.ANNOUNCE_MAX) .. "hi" }))
		expect.equal(s.calls.filter, nil)
		expect.equal(s.call(s.helper, "announce", { text = "hello" }).ok, true)
		refused(s.call(s.helper, "announce", { text = "again" }), R.announceGap)
		s.clock += Config.ANNOUNCE_GAP
		expect.equal(s.call(s.helper, "announce", { text = "again" }).ok, true)
		s.ctx.roleLoaded = function(p) return p ~= s.player end
		refused(s.call(s.helper, "freeze", { target = PLAYER }), R.loading)
		expect.equal(s.call(s.owner, "freeze", { target = PLAYER }).message == R.loading, false) -- owners are not held
	end)

	t.test("a heist cooldown resets through the normal rearm; refused while robbing or open", function()
		local clock = 1000
		local bank = BankInstance.new({
			config = { effective = function(key) return if key == "SessionDuration" then 60 else 600 end },
			now = function() return clock end,
		})
		local states = {}
		bank.StateChanged:Connect(function(state) table.insert(states, state) end)
		expect.equal(select(2, bank:ResetCooldown()), "Idle")
		bank:TryStart(nil)
		expect.equal(select(2, bank:ResetCooldown()), "Active")
		clock += 61
		bank:Step()
		expect.equal(bank:GetState(), "Cooldown")
		expect.truthy(bank:ResetCooldown())
		expect.equal(bank:GetState(), "Idle")
		expect.equal(bank:GetCooldownEndsAt(), nil)
		expect.equal(states[#states], "Idle")
	end)
end
