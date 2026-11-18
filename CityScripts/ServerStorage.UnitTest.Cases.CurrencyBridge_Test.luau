-- CurrencyBridge_Test: ServerScriptService.PlayerData.CurrencyService (phase 3 bridge onto leaderstats.Cash).
-- API and return values from CityMerge/phase3/currency-api.md (the Robbery CurrencyAdapter).
-- Stand-ins are Folders never parented to Players; the bridge's _playerFor seam is swapped per case.
return function(t)
	local expect = t.expect
	local USER = -424242

	local function standIn(withStats: boolean)
		local p = Instance.new("Folder")
		p.Name = "StandInPlayer"
		if withStats then
			local ls = Instance.new("Folder")
			ls.Name = "leaderstats"
			ls.Parent = p
			local cash = Instance.new("IntValue")
			cash.Name = "Cash"
			cash.Value = 500
			cash.Parent = ls
		end
		return p
	end

	-- requires inside each case, so a missing module fails every case
	local function with(withStats: boolean, fn)
		local currency = require(game:GetService("ServerScriptService").PlayerData.CurrencyService)
		local p = standIn(withStats)
		local original = currency._playerFor
		currency._playerFor = function(userId)
			if userId == USER then return p end
			return nil
		end
		local ok, err = pcall(fn, currency, p)
		currency._playerFor = original
		p:Destroy()
		if not ok then error(err, 0) end
	end
	local function cashOf(p) return p.leaderstats.Cash.Value end

	t.test("Add 100 makes Cash 600 and returns the new balance", function()
		with(true, function(c, p)
			expect.equal(c:Add(USER, 100), 600)
			expect.equal(cashOf(p), 600)
		end)
	end)
	-- Open items pass 2026-11-18: -math.huge, and amounts above HeistShared.Config.MaxCashCredit.
	local MAX_CREDIT = require(game:GetService("ReplicatedStorage").HeistShared.Config).MaxCashCredit
	for _, case in ipairs({ { "NaN", 0 / 0 }, { "-5", -5 }, { "math.huge", math.huge }, { "-math.huge", -math.huge },
		{ "string 100", "100" }, { "nil", nil }, { "0", 0 }, { "MaxCashCredit + 1", MAX_CREDIT + 1 }, { "1e300", 1e300 } }) do
		t.test("Add " .. case[1] .. " leaves Cash 500 and returns the unchanged balance", function()
			with(true, function(c, p)
				expect.equal(c:Add(USER, case[2]), 500)
				expect.equal(cashOf(p), 500)
			end)
		end)
	end
	t.test("Add accepts exactly MaxCashCredit", function()
		with(true, function(c, p)
			expect.equal(c:Add(USER, MAX_CREDIT), 500 + MAX_CREDIT)
			expect.equal(cashOf(p), 500 + MAX_CREDIT)
		end)
	end)
	t.test("Add floors a fraction: 100.9 adds 100, 0.5 adds nothing", function()
		with(true, function(c, p)
			expect.equal(c:Add(USER, 100.9), 600)
			expect.equal(c:Add(USER, 0.5), 600)
			expect.equal(cashOf(p), 600)
		end)
	end)
	t.test("Add with no leaderstats returns 0, does not error, creates nothing", function()
		with(false, function(c, p)
			expect.equal(c:Add(USER, 100), 0)
			expect.equal(p:FindFirstChild("leaderstats"), nil)
		end)
	end)
	t.test("Add for a userId with no player returns 0", function()
		with(true, function(c, p)
			expect.equal(c:Add(USER + 1, 100), 0)
			expect.equal(cashOf(p), 500)
		end)
	end)
	t.test("Add does not yield", function()
		with(true, function(c)
			local co = coroutine.create(function() return c:Add(USER, 1) end)
			local ok, v = coroutine.resume(co)
			expect.truthy(ok)
			expect.equal(coroutine.status(co), "dead")
			expect.equal(v, 501)
		end)
	end)

	-- Open items pass 2026-11-18: the unswapped _playerFor resolves through Players:GetPlayerByUserId. Read only:
	-- a real player in the session is looked up, never credited.
	t.test("the default _playerFor finds a real player by UserId and nobody for an unknown id", function()
		local currency = require(game:GetService("ServerScriptService").PlayerData.CurrencyService)
		local Players = game:GetService("Players")
		expect.equal(currency._playerFor(USER), nil)
		expect.equal(currency:Get(USER), 0)
		local real = Players:GetPlayers()[1]
		if real then
			expect.equal(currency._playerFor(real.UserId), real)
			local cash = real:FindFirstChild("leaderstats") and real.leaderstats:FindFirstChild("Cash")
			if cash then expect.equal(currency:Get(real.UserId), cash.Value) end
		end
	end)

	t.test("Get returns Cash", function()
		with(true, function(c) expect.equal(c:Get(USER), 500) end)
	end)
	t.test("Get with no leaderstats returns 0 and creates nothing", function()
		with(false, function(c, p)
			expect.equal(c:Get(USER), 0)
			expect.equal(p:FindFirstChild("leaderstats"), nil)
		end)
	end)
	t.test("Load returns Cash and leaves it at 500", function()
		with(true, function(c, p)
			expect.equal(c:Load(USER), 500)
			expect.equal(cashOf(p), 500)
		end)
	end)
	t.test("Load with no leaderstats returns 0 and creates nothing", function()
		with(false, function(c, p)
			expect.equal(c:Load(USER), 0)
			expect.equal(p:FindFirstChild("leaderstats"), nil)
		end)
	end)
	t.test("PendingCount is 0 after an Add (CashService persists)", function()
		with(true, function(c)
			c:Add(USER, 100)
			expect.equal(c:PendingCount(), 0)
		end)
	end)
	t.test("PendingCount is 0 after a refused Add", function()
		with(false, function(c)
			c:Add(USER, 100)
			expect.equal(c:PendingCount(), 0)
		end)
	end)
	t.test("Save returns true and leaves Cash at 500", function()
		with(true, function(c, p)
			expect.equal(c:Save(USER), true)
			expect.equal(cashOf(p), 500)
		end)
	end)
	t.test("Save with no leaderstats returns true and creates nothing", function()
		with(false, function(c, p)
			expect.equal(c:Save(USER), true)
			expect.equal(p:FindFirstChild("leaderstats"), nil)
		end)
	end)
	t.test("FlushAll and Release leave Cash at 500", function()
		with(true, function(c, p)
			c:FlushAll()
			c:Release(USER)
			expect.equal(cashOf(p), 500)
		end)
	end)
	t.test("FlushAll and Release with no leaderstats do not error or create", function()
		with(false, function(c, p)
			c:FlushAll()
			c:Release(USER)
			expect.equal(p:FindFirstChild("leaderstats"), nil)
		end)
	end)
end
