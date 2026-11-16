local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local CashClaimVFX = TestRunner.freshRequire(game.ReplicatedStorage.SharedSystems.CashClaimVFX)
	local suite = TestRunner.new("CashClaimVFX")

	-- Real Tweens run on real engine time, not an injectable clock (same
	-- tradeoff as UITransitionsSpec) -- deliberately tiny durations, and
	-- flyStaggerMax = 0, so a full burst->fly->land sequence finishes fast
	-- and deterministically enough for a unit test.
	local FAST_TWEEN = TweenInfo.new(0.02, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local function tempGui()
		local folder = Instance.new("Folder")
		folder.Parent = nil
		return folder
	end

	-- Returns the VFX instance plus a setter that changes what getCash()
	-- reports next, simulating the server having credited more Cash.
	local function makeVFX(overrides)
		overrides = overrides or {}
		local cash = overrides.cash or 0
		local getCash = overrides.getCash or function() return cash end
		local vfx = CashClaimVFX.new({
			playerGui = overrides.playerGui or tempGui(),
			getCash = getCash,
			burstCount = overrides.burstCount or 5,
			scatterTweenInfo = FAST_TWEEN,
			flyTweenInfo = FAST_TWEEN,
			flyStaggerMax = 0,
		})
		return vfx, function(v) cash = v end
	end

	-- City (phase 3 G5, spec updated in Task 5): one cash display. The module no longer builds its
	-- own CashDisplay; the city's CashHud owns the readout and the coins fly to
	-- PlayerGui["Custom Inventory"].cashDisplay. The two cases below replace the Robbery
	-- "persistent Cash display" case.
	suite:test("construction reads the initial value and builds no cash display of its own", function(expect)
		local gui = tempGui()
		local vfx = makeVFX({ cash = 1234, playerGui = gui })
		local childCount = #gui:GetChildren()
		local displayed = vfx._displayedValue
		vfx:Destroy()
		expect.equal(displayed, 1234, "initial value read")
		expect.equal(childCount, 0, "no own ScreenGui")
	end)

	suite:test("coins target the city's Custom Inventory.cashDisplay once it exists", function(expect)
		local gui = tempGui()
		local inventory = Instance.new("ScreenGui")
		inventory.Name = "Custom Inventory"
		local frame = Instance.new("Frame")
		frame.Name = "cashDisplay"
		frame.Parent = inventory
		inventory.Parent = gui
		local vfx = makeVFX({ cash = 0, playerGui = gui })
		task.wait(0.05) -- the lookup runs in its own thread
		local target = vfx._cashTarget
		local position = vfx:_targetPosition(nil)
		vfx:Destroy()
		expect.equal(target, frame, "found the city frame")
		expect.truthy(typeof(position) == "UDim2", "a fly-to position")
	end)

	suite:test("PlaySequence animates the display up to the exact new value, no drift", function(expect)
		local vfx, setCash = makeVFX({ cash = 100 })
		setCash(2100) -- e.g. a 2000 register rob on top of an existing 100
		vfx:PlaySequence()
		task.wait(0.6)
		expect.equal(vfx._displayedValue, 2100, "settled at exactly the true new value")
		vfx:Destroy()
	end)

	suite:test("the displayed value never exceeds the true new value mid-animation", function(expect)
		local vfx, setCash = makeVFX({ cash = 0, burstCount = 10 })
		setCash(1000)
		vfx:PlaySequence()
		local sawOverage = false
		for _ = 1, 20 do
			task.wait(0.03)
			if vfx._displayedValue > 1000 then sawOverage = true end
		end
		expect.falsy(sawOverage, "display value never overshot the true total")
		vfx:Destroy()
	end)

	suite:test("burst count is fixed regardless of the claimed amount -- not scaled to the amount", function(expect)
		local vfx = makeVFX({ cash = 0, burstCount = 7 })
		expect.equal(vfx.burstCount, 7, "uses the configured fixed count")
		vfx:Destroy()
	end)

	-- Corrected, 2026-09-10: real cash decal (rbxassetid://18885492728)
	-- replacing the earlier procedural gold-chip placeholder.
	suite:test("burst icons are ImageLabels using the real cash decal, not procedural shapes", function(expect)
		local gui = tempGui()
		local vfx, setCash = makeVFX({ cash = 0, playerGui = gui, burstCount = 3 })
		setCash(500)
		vfx:PlaySequence()
		task.wait(0.02) -- just long enough for the burst ScreenGui/icons to exist, before they land

		local burstGui = gui:FindFirstChild("CashBurst")
		expect.truthy(burstGui ~= nil, "burst ScreenGui exists")
		if burstGui then
			local children = burstGui:GetChildren()
			expect.truthy(#children > 0, "has icons")
			for _, icon in ipairs(children) do
				expect.truthy(icon:IsA("ImageLabel"), "icon is an ImageLabel, not a procedural Frame")
				-- City (phase 3 Task 5): the coin comes from UITheme.Assets.Coin, which moved to a new
				-- slice after this spec pinned 18885492705; read the theme instead of a literal.
				expect.equal(icon.Image, require(game.ReplicatedStorage.SharedSystems.UITheme).Assets.Coin, "uses the theme's cash decal")
			end
		end
		task.wait(0.6)
		vfx:Destroy()
	end)

	-- Corrected, 2026-09-10: burst originates from the claim-confirmation
	-- GUI's position, not an arbitrary screen-center point.
	suite:test("burst icons spawn at the configured burstOrigin, not screen center, when one is supplied", function(expect)
		local gui = tempGui()
		local confirmationOrigin = UDim2.new(0.5, 0, 0, 127) -- e.g. the real toast's own resting center
		local cash = 0
		local vfx = CashClaimVFX.new({
			playerGui = gui,
			getCash = function() return cash end,
			burstCount = 3,
			scatterTweenInfo = FAST_TWEEN,
			flyTweenInfo = FAST_TWEEN,
			flyStaggerMax = 0,
			burstOrigin = confirmationOrigin,
		})
		expect.equal(vfx.burstOrigin, confirmationOrigin, "stored the supplied origin")

		cash = 500
		vfx:PlaySequence()
		local burstGui = gui:FindFirstChild("CashBurst")
		expect.truthy(burstGui ~= nil, "burst ScreenGui exists")
		if burstGui then
			local icon = burstGui:GetChildren()[1]
			-- Checked at the very instant of spawn, before the scatter tween has
			-- had any real time to move it -- still sitting at its origin.
			expect.equal(icon.Position, confirmationOrigin, "spawned exactly at the confirmation GUI's position")
		end
		task.wait(0.6)
		vfx:Destroy()
	end)

	suite:test("burstOrigin defaults to screen center when none is supplied (e.g. in tests)", function(expect)
		local vfx = makeVFX({ cash = 0 })
		expect.equal(vfx.burstOrigin, UDim2.new(0.5, 0, 0.5, 0), "default origin")
		vfx:Destroy()
	end)

	suite:test("cleans up every burst icon and the burst ScreenGui once the sequence completes", function(expect)
		local gui = tempGui()
		local vfx, setCash = makeVFX({ cash = 0, playerGui = gui })
		setCash(500)
		vfx:PlaySequence()
		task.wait(0.6)
		expect.falsy(gui:FindFirstChild("CashBurst"), "the burst ScreenGui was destroyed after completion")
		vfx:Destroy()
	end)

	suite:test("calling PlaySequence when the value hasn't changed is a no-op", function(expect)
		local vfx, setCash = makeVFX({ cash = 500 })
		vfx:PlaySequence() -- getCash still returns 500, nothing changed
		task.wait(0.1)
		expect.equal(vfx._displayedValue, 500, "unchanged")
		vfx:Destroy()
	end)

	suite:test("a second claim animates from the previous displayed value, not from zero", function(expect)
		local vfx, setCash = makeVFX({ cash = 0 })
		setCash(1000)
		vfx:PlaySequence()
		task.wait(0.6)
		expect.equal(vfx._displayedValue, 1000, "first claim settled")

		setCash(1500)
		vfx:PlaySequence()
		task.wait(0.6)
		expect.equal(vfx._displayedValue, 1500, "second claim settled at the new total, continuing from the first")
		vfx:Destroy()
	end)

	-- The passive listener (initial DataStore load, or any future non-claim
	-- change) updates the display after a short grace window (not instantly
	-- any more -- see below) as long as no claim animation has claimed
	-- ownership in the meantime.
	suite:test("the passive leaderstats listener updates the display when no claim animation is in progress", function(expect)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cashValue = Instance.new("IntValue")
		cashValue.Name = "Cash"
		cashValue.Value = 50
		cashValue.Parent = stats

		-- A plain table with method-shaped fields, matching how :FindFirstChild
		-- is actually called (obj:FindFirstChild(x) == obj.FindFirstChild(obj, x))
		-- -- good enough to stand in for a real Player here without needing an
		-- actual Players.LocalPlayer, which doesn't exist in this test context.
		local fakePlayer = {}
		fakePlayer.FindFirstChild = function(_, name)
			return name == "leaderstats" and stats or nil
		end

		local vfx = CashClaimVFX.new({
			player = fakePlayer,
			playerGui = tempGui(),
			passiveListenerGrace = 0.02, -- fast, deterministic for this test
		})
		expect.equal(vfx._displayedValue, 50, "initial read from the real leaderstat")

		cashValue.Value = 75 -- e.g. DataStore load completing late, not a claim
		task.wait(0.15) -- comfortably past the 0.02s grace window
		expect.equal(vfx._displayedValue, 75, "passive listener updated it, no animation needed")

		vfx:Destroy()
		stats:Destroy()
	end)

	-- Root-caused live, 2026-09-10: leaderstats.Cash's property replication
	-- was observed consistently arriving and being processed BEFORE the
	-- RobberySuccess RemoteEvent for the SAME claim, even though the server
	-- fires the property write first and the remote second -- property
	-- replication and RemoteEvents are independent channels with no relative
	-- ordering guarantee. Without the grace window + _animating guard, the
	-- passive listener would win, instantly jump the display to the target,
	-- and PlaySequence would see oldValue == newValue and silently no-op --
	-- exactly "the cash total updates correctly, but no burst ever appears".
	suite:test("a same-claim passive Value-change racing a PlaySequence call does not swallow the animation", function(expect)
		local stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cashValue = Instance.new("IntValue")
		cashValue.Name = "Cash"
		cashValue.Value = 0
		cashValue.Parent = stats

		local fakePlayer = {}
		fakePlayer.FindFirstChild = function(_, name)
			return name == "leaderstats" and stats or nil
		end

		local gui = tempGui()
		local burstsSeen = 0
		gui.ChildAdded:Connect(function(child)
			if child.Name == "CashBurst" then burstsSeen += 1 end
		end)

		local vfx = CashClaimVFX.new({
			player = fakePlayer,
			playerGui = gui,
			getCash = function() return cashValue.Value end,
			burstCount = 3,
			scatterTweenInfo = FAST_TWEEN,
			flyTweenInfo = FAST_TWEEN,
			flyStaggerMax = 0,
			-- Generous relative to the fast tweens above, so PlaySequence (fired
			-- right after, exactly like the real RobberySuccess handler) has
			-- every chance to win and claim _animating before this grace elapses.
			passiveListenerGrace = 0.2,
		})

		-- Simulates the real race: the leaderstat changes (starting the
		-- passive listener's grace wait), and PlaySequence is invoked right
		-- after, exactly as HeistClient's RobberySuccess handler does live.
		cashValue.Value = 2000
		vfx:PlaySequence()

		task.wait(0.6)
		expect.equal(vfx._displayedValue, 2000, "settled at exactly the true value, no drift from either path")
		expect.falsy(vfx._animating, "not stuck mid-animation")
		expect.equal(burstsSeen, 1, "exactly one burst sequence ran -- the animation was not swallowed, and did not double-fire either")

		vfx:Destroy()
		stats:Destroy()
	end)

	return suite:run()
end
