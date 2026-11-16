local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Pins the externally-observable behavior of the shared per-location
-- orchestration skeleton BEFORE the location scripts were refactored onto it
-- (Part 1). The per-location scripts themselves have never had direct test
-- coverage -- the suite only ever covered the shared Heist.* modules -- so
-- this exists specifically so the migration cannot silently change what a
-- client actually observes: the remote payloads, the message literals, and
-- the order things happen in.
--
-- Deliberately uses a neutral name/role rather than SlowFoods' own, so it
-- tests the skeleton's parameterization instead of re-asserting one
-- location's literals.
--
-- Every test tears its fixtures down BEFORE asserting: a failed assertion
-- throws, and cleanup placed after it would leak Parts into the saved place
-- (the existing specs do exactly that -- see the 65+ instances a full Edit-mode
-- suite run leaves behind).
return function()
	local LocationServer = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.LocationServer)
	local Getaway = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Getaway)
	local Zone = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.Zone)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("LocationServer")

	local NAME = "TestLoc"
	local INTERIOR = "Interior"

	local function makeRig(cfgOverrides)
		cfgOverrides = cfgOverrides or {}

		local t = 1000
		local function now() return t end
		local function advance(dt) t += dt end

		-- Recorded observable output.
		local calls = {
			BroadcastState = {}, BroadcastZoneOccupancy = {}, SendDuffel = {},
			Toast = {}, NotifyRobberySuccess = {}, CurrencyAdd = {},
			NotifyLocationOpened = {}, NotifyRobberyTriggered = {},
			AlarmStart = 0, AlarmStop = 0, AlarmUpdate = 0,
			ForceDetachAll = 0, Sync = {}, Forget = {},
		}

		local net = {
			BroadcastState = function(_, loc, state, endsAt, cdEndsAt)
				table.insert(calls.BroadcastState, { loc, state, endsAt, cdEndsAt })
			end,
			BroadcastZoneOccupancy = function(_, loc, player, inside)
				table.insert(calls.BroadcastZoneOccupancy, { loc, player, inside })
			end,
			SendDuffel = function(_, loc, player, base, rate, since, cap)
				table.insert(calls.SendDuffel, { loc, player, base, rate, since, cap })
			end,
			Toast = function(_, player, message)
				table.insert(calls.Toast, { player, message })
			end,
			NotifyRobberySuccess = function(_, player)
				table.insert(calls.NotifyRobberySuccess, player)
			end,
			-- Global notification popups: both are FireAllClients broadcasts, so
			-- unlike the per-player calls above they carry no player object --
			-- only a location name, plus the triggering player's name.
			NotifyLocationOpened = function(_, loc)
				table.insert(calls.NotifyLocationOpened, loc)
			end,
			NotifyRobberyTriggered = function(_, loc, playerName)
				table.insert(calls.NotifyRobberyTriggered, { loc, playerName })
			end,
		}

		-- role -> list of players, mutated directly by each test.
		local occupancy = {}
		local parts, zones, byRole = {}, {}, {}
		for _, role in ipairs({ INTERIOR }) do
			local part = Instance.new("Part")
			part.Anchored = true
			part.CanCollide = false
			part.Transparency = 1
			part.Size = Vector3.new(20, 20, 20)
			part.Position = Vector3.new(0, 6000, 0)
			part:SetAttribute("ZoneRole", role)
			part.Parent = workspace
			occupancy[part] = {}
			byRole[role] = part
			table.insert(parts, part)
			table.insert(zones, Zone.new(part, {
				config = Config,
				queryOccupants = function(p) return occupancy[p] or {} end,
			}))
		end

		local connectedPlayers = {}

		-- Forward-declared: the getaway callbacks below only RUN after new()
		-- returns, so closing over this is safe.
		local location
		local positions = {}
		local ANCHOR = Vector3.new(0, 6136, 0) -- above the fixture zones' own Y=6000

		local cfg = {
			name = NAME,
			config = Config,
			interiorRole = INTERIOR,
			zones = zones,
			now = now,
			net = net,
			exitCFrame = function() return CFrame.new() end,
			startHeartbeat = false,
			currency = {
				Add = function(_, userId, amount)
					table.insert(calls.CurrencyAdd, { userId, amount })
				end,
			},
			carryState = { IsCarrying = function() return false end },
			getPlayers = function() return connectedPlayers end,
			forfeit = {
				Eject = function() end,
				Die = function() end,
				Forget = function(_, player) table.insert(calls.Forget, player) end,
			},
			alarm = {
				Start = function() calls.AlarmStart += 1 end,
				Stop = function() calls.AlarmStop += 1 end,
				Update = function() calls.AlarmUpdate += 1 end,
			},
			duffelBagAttachment = {
				Sync = function(_, player, hasBag) table.insert(calls.Sync, { player, hasBag }) end,
				ForceDetachAll = function() calls.ForceDetachAll += 1 end,
				Forget = function() end,
			},
			duffelCapMultiplier = function() return 1 end,
			accrualRateMultiplier = function() return 1 end,
		}

		cfg.getaway = Getaway.new({
			escapeDistance = 200,
			getAnchorPosition = function() return ANCHOR end,
			isInsideBuilding = function(player)
				return location.zoneService:IsInside(INTERIOR, player)
			end,
			getDuffel = function(player) return location.bank:GetDuffel(player) end,
			getPosition = function(player) return positions[player] end,
			getPlayers = function() return connectedPlayers end,
			onEscaped = function(player) location:_bankBag(player) end,
		})
		for k, v in pairs(cfgOverrides) do cfg[k] = v end

		location = LocationServer.new(cfg)
		location:Start()

		local rig = {
			location = location,
			bank = location.bank,
			calls = calls,
			advance = advance,
			now = now,
			connected = connectedPlayers,
			setOccupants = function(role, list) occupancy[byRole[role]] = list end,
			setPosition = function(player, position) positions[player] = position end,
		}
		function rig.teardown()
			location:Destroy()
			for _, p in ipairs(parts) do p:Destroy() end
		end
		return rig
	end

	suite:test("broadcasts every state transition under this location's own name", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("p1")
		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step()

		local broadcasts = rig.calls.BroadcastState
		local first = broadcasts[1]
		local second = broadcasts[2]
		rig.teardown()

		expect.equal(#broadcasts, 2, "one broadcast per transition")
		expect.equal(first[1], NAME, "carries the location name, not a hardcoded literal")
		expect.equal(first[2], "Active", "first transition is Active")
		expect.equal(second[2], "Cooldown", "second is Cooldown")
	end)

	suite:test("broadcasts zone occupancy only when it actually changes", function(expect)
		local rig = makeRig()
		rig.connected[1] = "p1"
		rig.setOccupants(INTERIOR, { "p1" })

		rig.location:Tick()
		rig.location:Tick()
		rig.location:Tick()
		local afterEnter = #rig.calls.BroadcastZoneOccupancy

		rig.setOccupants(INTERIOR, {})
		rig.location:Tick()
		rig.location:Tick()

		local all = rig.calls.BroadcastZoneOccupancy
		local entered, exited = all[1], all[2]
		local total = #all
		rig.teardown()

		expect.equal(afterEnter, 1, "one broadcast for entering, not one per sweep")
		expect.equal(total, 2, "one more for leaving, still not one per sweep")
		expect.equal(entered[1], NAME, "location name")
		expect.equal(entered[3], true, "entered reports inside = true")
		expect.equal(exited[3], false, "exited reports inside = false")
	end)

	suite:test("pushes duffel state on DuffelChanged, always at rate 0", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("p1")
		rig.bank:AddParticipant("p1")
		rig.bank:TryAddDuffel("p1", 250)

		local sends = rig.calls.SendDuffel
		local last = sends[#sends]
		local syncs = rig.calls.Sync
		local lastSync = syncs[#syncs]
		rig.teardown()

		expect.truthy(last ~= nil, "a duffel push happened")
		expect.equal(last[1], NAME, "location name")
		expect.equal(last[2], "p1", "player")
		expect.equal(last[3], 250, "the banked-so-far amount")
		expect.equal(last[4], 0, "rate is always 0 at a lump-sum location")
		expect.equal(lastSync[2], true, "the bag accessory is attached once carrying")
	end)

	suite:test("getting clear banks the floored amount, toasts, then notifies success", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 1234.7)

		rig.setPosition(player, Vector3.new(250, 6000, 0))
		rig.location:Tick()

		local added = rig.calls.CurrencyAdd[1]
		local toasts = rig.calls.Toast
		local lastToast = toasts[#toasts]
		local notified = rig.calls.NotifyRobberySuccess[1]
		local remaining = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(added[1], 42, "credited that player's UserId")
		expect.equal(added[2], 1234, "floored, not rounded")
		expect.equal(lastToast[1], player, "toasted the banking player")
		expect.equal(lastToast[2], string.format("Banked %d %s.", 1234, Config.CurrencyName),
			"exact banked-toast wording")
		expect.equal(notified, player, "RobberySuccess fired for them")
		expect.equal(remaining, 0, "bag emptied")
	end)

	-- The Bank's VaultZone is 314 studs from its own anchor, so this gate is
	-- what stops a bag banking the moment it fills. Asserted here too because
	-- LocationServer builds its own getaway wiring independently of HeistServer.
	suite:test("staying inside the building banks nothing, however far from the anchor", function(expect)
		local rig = makeRig()
		local player = { UserId = 42 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 500)

		rig.setOccupants(INTERIOR, { player })
		rig.setPosition(player, Vector3.new(400, 6000, 0))
		rig.location:Tick()

		local notifications = #rig.calls.NotifyRobberySuccess
		local remaining = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(notifications, 0, "no payout from inside")
		expect.equal(remaining, 500, "bag intact")
	end)

	-- _bankBag's `amount <= 0` bail, which is reachable in production with a
	-- bag still in hand: bank:Claim pays out only for a current participant of
	-- an Active session, so a player whose session has sealed -- or who has
	-- been dropped from the roster -- gets 0 back while still carrying. Nothing
	-- may be credited, toasted or notified on that path, and the bag must be
	-- left exactly as it was: a bag that survives the refusal is what holds
	-- Getaway's fired-once latch set, instead of re-arming and re-firing this
	-- same no-op every tick for the rest of the session.
	--
	-- AddParticipant -> TryAddDuffel -> RemoveParticipant is the same trick the
	-- ForgetPlayer test below uses to reach this state.
	suite:test("getting clear with a bag Claim refuses credits nothing and leaves the bag alone", function(expect)
		local rig = makeRig()
		local player = { UserId = 77 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 500)
		-- Off the roster, bag still in hand -- exactly what Claim refuses.
		rig.bank:RemoveParticipant(player)

		local creditsBefore = #rig.calls.CurrencyAdd
		local toastsBefore = #rig.calls.Toast
		local notifiedBefore = #rig.calls.NotifyRobberySuccess

		rig.setPosition(player, Vector3.new(250, 6000, 0))
		rig.location:Tick()

		local creditsAfter = #rig.calls.CurrencyAdd
		local toastsAfter = #rig.calls.Toast
		local notifiedAfter = #rig.calls.NotifyRobberySuccess
		local remainingBag = rig.bank:GetDuffel(player)
		rig.teardown()

		expect.equal(creditsAfter, creditsBefore, "nothing credited")
		expect.equal(toastsAfter, toastsBefore, "no banked toast")
		expect.equal(notifiedAfter, notifiedBefore, "no RobberySuccess")
		expect.equal(remainingBag, 500, "bag untouched")
	end)

	-- The personal "Alarm triggered" Toast was removed 2026-09-13: the global
	-- RobberyTriggered notification fires to ALL clients including this one, so
	-- the personal copy was duplicate information for the very player already
	-- being told. Pinned as an explicit no-Toast assertion rather than deleted,
	-- so re-adding one is a test failure and not a silent regression.
	suite:test("a successful trigger starts the session and enrolls the player, with no personal toast", function(expect)
		local rig = makeRig()
		local toastsBefore = #rig.calls.Toast
		rig.location:TryTriggerRobbery("p1")

		local state = rig.bank:GetState()
		local isParticipant = rig.bank:IsParticipant("p1")
		local toastsAfter = #rig.calls.Toast
		rig.teardown()

		expect.equal(state, "Active", "session started")
		expect.truthy(isParticipant, "triggering player is enrolled")
		expect.equal(toastsAfter, toastsBefore, "a successful trigger sends NO personal toast")
	end)

	-- Global notification popups: now the ONLY feedback a successful trigger
	-- produces, so a refused trigger must still stay silent for everyone.
	suite:test("a successful trigger broadcasts a robbery notification, a refused one does not", function(expect)
		local rig = makeRig()
		rig.location:TryTriggerRobbery("p1")
		local afterSuccess = #rig.calls.NotifyRobberyTriggered
		local firstLoc = afterSuccess > 0 and rig.calls.NotifyRobberyTriggered[1][1] or nil

		-- Already Active, so this one is refused. A different player, since the
		-- 1s trigger debounce is per-player.
		rig.location:TryTriggerRobbery("p2")
		local afterRefusal = #rig.calls.NotifyRobberyTriggered
		rig.teardown()

		expect.equal(afterSuccess, 1, "exactly one broadcast for the successful trigger")
		expect.equal(firstLoc, NAME, "broadcast under this location's own name")
		expect.equal(afterRefusal, 1, "a refused trigger notifies nobody")
	end)

	-- Idle only ever reaches StateChanged via _rearm: BankInstance seeds its
	-- initial Idle as a plain field, never through _setState, so this can never
	-- fire at server boot. Pinned here because that is the whole reason the
	-- feature needs no boot-time special-casing.
	suite:test("the reopen notification fires on rearm only, never on the boot Idle", function(expect)
		local rig = makeRig()
		local atBoot = #rig.calls.NotifyLocationOpened

		rig.bank:TryStart("starter")
		local afterActive = #rig.calls.NotifyLocationOpened

		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step() -- -> Cooldown
		local afterCooldown = #rig.calls.NotifyLocationOpened

		rig.advance(Config.CooldownDuration + 1)
		rig.bank:Step() -- -> Idle (rearm)
		local afterRearm = #rig.calls.NotifyLocationOpened
		local loc = afterRearm > 0 and rig.calls.NotifyLocationOpened[1] or nil
		rig.teardown()

		expect.equal(atBoot, 0, "the initial Idle never fires StateChanged, so nothing is broadcast")
		expect.equal(afterActive, 0, "nothing on Active")
		expect.equal(afterCooldown, 0, "nothing on Cooldown")
		expect.equal(afterRearm, 1, "exactly one broadcast on the genuine reopen")
		expect.equal(loc, NAME, "named under this location")
	end)

	suite:test("a trigger during cooldown refuses with the exact remaining-time format", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("starter")
		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step() -- -> Cooldown

		-- A different player: the 1s trigger debounce is per-player.
		rig.location:TryTriggerRobbery("p2")

		local toasts = rig.calls.Toast
		local lastToast = toasts[#toasts]
		local remaining = math.max(0, (rig.bank:GetCooldownEndsAt() or 0) - rig.now())
		local expected = string.format("%s sealed -- %d:%02d remaining.",
			NAME, remaining // 60, math.floor(remaining % 60))
		rig.teardown()

		expect.equal(lastToast[2], expected, "exact sealed-refusal wording, with the location's own name")
	end)

	suite:test("a trigger while carrying supplies is refused before the session is touched", function(expect)
		local rig = makeRig({ carryState = { IsCarrying = function() return true end } })
		rig.location:TryTriggerRobbery("p1")

		local state = rig.bank:GetState()
		local toasts = rig.calls.Toast
		local lastToast = toasts[#toasts]
		rig.teardown()

		expect.equal(state, "Idle", "no session started")
		expect.equal(lastToast[2], Config.SupplyCarryingRefusalMessage, "the shared carrying refusal message")
	end)

	suite:test("the alarm starts on Active and stops on any non-Active state", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("p1")
		local startedAfterActive = rig.calls.AlarmStart
		local stoppedAfterActive = rig.calls.AlarmStop

		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step() -- -> Cooldown
		local stoppedAfterCooldown = rig.calls.AlarmStop
		rig.teardown()

		expect.equal(startedAfterActive, 1, "started exactly once on Active")
		expect.equal(stoppedAfterActive, 0, "not stopped while Active")
		expect.equal(stoppedAfterCooldown, 1, "stopped on leaving Active")
	end)

	suite:test("the duffel-detach safety net runs on Cooldown only", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("p1")
		local onActive = rig.calls.ForceDetachAll

		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step() -- -> Cooldown
		local onCooldown = rig.calls.ForceDetachAll

		rig.advance(Config.CooldownDuration + 1)
		rig.bank:Step() -- -> Idle
		local onIdle = rig.calls.ForceDetachAll
		rig.teardown()

		expect.equal(onActive, 0, "not on Active")
		expect.equal(onCooldown, 1, "exactly once on Cooldown")
		expect.equal(onIdle, 1, "not again on the return to Idle")
	end)

	suite:test("a late joiner entering the interior during an Active session is enrolled", function(expect)
		local rig = makeRig()
		rig.bank:TryStart("starter")
		expect.truthy(true, "")

		rig.setOccupants(INTERIOR, { "latecomer" })
		rig.location:Tick()

		local enrolled = rig.bank:IsParticipant("latecomer")
		rig.teardown()

		expect.truthy(enrolled, "walked in mid-session and joined the roster")
	end)

	suite:test("anyone already standing inside when the session goes Active is enrolled", function(expect)
		local rig = makeRig()
		rig.setOccupants(INTERIOR, { "bystander" })
		rig.location:Tick() -- establishes occupancy while still Idle

		rig.bank:TryStart("starter")

		local enrolled = rig.bank:IsParticipant("bystander")
		rig.teardown()

		expect.truthy(enrolled, "bystander swept into the roster on Active")
	end)

	suite:test("ForgetPlayer clears every piece of per-player skeleton state", function(expect)
		local rig = makeRig()
		rig.connected[1] = "p1"
		rig.bank:TryStart("p1")
		rig.setOccupants(INTERIOR, { "p1" })
		rig.location:Tick()

		local wasParticipant = rig.bank:IsParticipant("p1")
		local wasInside = rig.location.zoneService:IsInside(INTERIOR, "p1")

		-- Also drive the getaway latch non-empty, for a second player, so
		-- that ForgetPlayer clearing it below is a meaningful assertion --
		-- otherwise this is asserting nil equals nil and passes whether or
		-- not Forget is called. A second player (rather than reusing "p1")
		-- so this setup cannot taint the roster/zone/cache assertions above:
		-- "p2" is never added as a bank participant when the escape fires,
		-- so bank:Claim refuses to pay out (Claim requires IsParticipant)
		-- and the bag stays nonzero -- exactly the case Getaway:Step's own
		-- re-arm comment describes as needing Forget, since the "bag gone,
		-- re-arm" branch is never reached for a departed, unlisted player.
		rig.connected[2] = "p2"
		rig.bank:AddParticipant("p2")
		rig.bank:TryAddDuffel("p2", 50)
		rig.bank:RemoveParticipant("p2")
		rig.setPosition("p2", Vector3.new(250, 6136, 0))
		rig.location:Tick()
		local latchSetAfterEscape = rig.location.getaway._fired["p2"] == true

		rig.setOccupants(INTERIOR, {})
		rig.location:ForgetPlayer("p1")
		rig.location:ForgetPlayer("p2")

		local stillParticipant = rig.bank:IsParticipant("p1")
		local stillInside = rig.location.zoneService:IsInside(INTERIOR, "p1")
		local insideCache = rig.location._insideBuilding["p1"]
		local triggerCache = rig.location._recentTriggerAttempt["p1"]
		local latchAfterForget = rig.location.getaway._fired["p2"]
		rig.teardown()

		expect.truthy(wasParticipant, "was a participant beforehand")
		expect.truthy(wasInside, "was tracked inside beforehand")
		expect.truthy(latchSetAfterEscape, "getaway latch set once a player got clear with an unclaimed bag")
		expect.falsy(stillParticipant, "roster cleared")
		expect.falsy(stillInside, "zone occupancy cleared")
		expect.falsy(insideCache, "occupancy cache cleared")
		expect.falsy(triggerCache, "trigger debounce cleared")
		expect.falsy(latchAfterForget, "getaway latch cleared")
	end)

	suite:test("one Tick drives the session clock, the zone sweep, the alarm and occupancy", function(expect)
		local rig = makeRig()
		rig.connected[1] = "p1"
		rig.setOccupants(INTERIOR, { "p1" })

		local alarmBefore = rig.calls.AlarmUpdate
		rig.location:Tick()
		local alarmAfter = rig.calls.AlarmUpdate
		local sweptOccupancy = rig.location.zoneService:IsInside(INTERIOR, "p1")
		local broadcast = #rig.calls.BroadcastZoneOccupancy
		rig.teardown()

		expect.equal(alarmBefore, 0, "alarm idle before the tick")
		expect.equal(alarmAfter, 1, "alarm updated exactly once per tick")
		expect.truthy(sweptOccupancy, "the zone sweep ran")
		expect.equal(broadcast, 1, "occupancy pushed after the sweep, in the same tick")
	end)

	suite:test("the location hooks fire at their documented points", function(expect)
		local fired = {}
		local rig = makeRig({
			onActive = function() table.insert(fired, "active") end,
			onSealed = function(state) table.insert(fired, "sealed:" .. state) end,
			heartbeatExtras = function() table.insert(fired, "extras") end,
			onPlayerRemoving = function(player) table.insert(fired, "removing:" .. tostring(player)) end,
		})

		rig.bank:TryStart("p1")
		rig.location:Tick()
		rig.advance(Config.SessionDuration + 1)
		rig.bank:Step()
		rig.location:ForgetPlayer("p1")

		local seq = table.concat(fired, ",")
		rig.teardown()

		expect.truthy(seq:find("active"), "onActive fired on session start")
		expect.truthy(seq:find("extras"), "heartbeatExtras fired during the tick")
		expect.truthy(seq:find("sealed:Cooldown"), "onSealed fired with the new state")
		expect.truthy(seq:find("removing:p1"), "onPlayerRemoving fired with the player")
	end)

	-- City (phase 3 Task 5): the bag is keyed by Player, not by character, and the city spawn is
	-- past EscapeDistance from every location, so a character removed without dying used to
	-- respawn holding the bag and bank it. Removal now forfeits exactly like a death.
	suite:test("a character removed mid-heist forfeits the bag, so the respawn banks nothing", function(expect)
		local Forfeit = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.Forfeit)
		local rig = makeRig({ forfeit = Forfeit.new({
			teleport = function() end,
			exitCFrame = function() return CFrame.new() end,
			log = function() end,
		}) })
		local player = { UserId = 55 }
		rig.connected[1] = player
		rig.bank:TryStart(player)
		rig.bank:AddParticipant(player)
		rig.bank:TryAddDuffel(player, 900)

		rig.location:_onCharacterRemoving(player)
		local bagAfterRemoval = rig.bank:GetDuffel(player)
		local stillParticipant = rig.bank:IsParticipant(player)

		rig.setPosition(player, Vector3.new(250, 6000, 0)) -- the respawn, past 200 studs
		rig.location:Tick()
		local credits = #rig.calls.CurrencyAdd
		rig.teardown()

		expect.equal(bagAfterRemoval, 0, "bag voided on removal")
		expect.falsy(stillParticipant, "off the roster")
		expect.equal(credits, 0, "nothing banked after the respawn")
	end)

	suite:test("a removal outside an Active session, or by a non-participant, forfeits nothing", function(expect)
		local dies = 0
		local rig = makeRig({ forfeit = {
			Eject = function() end,
			Die = function() dies += 1 end,
			Forget = function() end,
		} })
		rig.location:_onCharacterRemoving("idleRemoval") -- Idle
		rig.bank:TryStart("starter")
		rig.location:_onCharacterRemoving("bystander") -- Active, not a participant
		rig.teardown()

		expect.equal(dies, 0, "no forfeit")
	end)

	return suite:run()
end
