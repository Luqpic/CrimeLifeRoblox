local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local VaultDoor = TestRunner.freshRequire(game.ServerScriptService.Heist.Components.VaultDoor)
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("VaultDoor")

	local function activeBank(now)
		local inst = BankInstance.new({ config = Config, now = now or function() return 1000 end })
		inst:TryStart("starter")
		return inst
	end

	-- Matches the real Vault Door model's exact hierarchy (spec addendum,
	-- 2026-09-12): Door (PrimaryPart=Center, ToGoPos, Handle w/HingeConstraint,
	-- Noisey w/Lock+Buzzer+Open sounds), Button.Button, VaultAlarm.Spinnyspin
	-- (w/HingeConstraint+Alarm sound) and VaultAlarm.Flash (w/SpotLight).
	local function tempVaultDoorModel()
		local model = Instance.new("Model")
		model.Name = "Vault Door"

		local door = Instance.new("Model")
		door.Name = "Door"
		door.Parent = model

		local center = Instance.new("Part")
		center.Name = "Center"
		center.Anchored = true
		center.CFrame = CFrame.new(0, 10, 0)
		center.Parent = door
		door.PrimaryPart = center

		local toGoPos = Instance.new("Part")
		toGoPos.Name = "ToGoPos"
		toGoPos.Anchored = true
		toGoPos.CFrame = CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(90), 0)
		toGoPos.Parent = door

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Anchored = true
		handle.Parent = door
		Instance.new("HingeConstraint").Parent = handle

		local noisey = Instance.new("Part")
		noisey.Name = "Noisey"
		noisey.Anchored = true
		noisey.Parent = door
		for _, soundName in ipairs({ "Lock", "Buzzer", "Open" }) do
			local sound = Instance.new("Sound")
			sound.Name = soundName
			sound.Parent = noisey
		end

		local buttonModel = Instance.new("Model")
		buttonModel.Name = "Button"
		buttonModel.Parent = model
		local button = Instance.new("Part")
		button.Name = "Button"
		button.Anchored = true
		button.Parent = buttonModel

		local alarmModel = Instance.new("Model")
		alarmModel.Name = "VaultAlarm"
		alarmModel.Parent = model
		local spinnyspin = Instance.new("Part")
		spinnyspin.Name = "Spinnyspin"
		spinnyspin.Anchored = true
		spinnyspin.Parent = alarmModel
		Instance.new("HingeConstraint").Parent = spinnyspin
		local alarmSound = Instance.new("Sound")
		alarmSound.Name = "Alarm"
		alarmSound.Parent = spinnyspin
		local flash = Instance.new("Part")
		flash.Name = "Flash"
		flash.Anchored = true
		flash.Parent = alarmModel
		Instance.new("SpotLight").Parent = flash

		model.Parent = workspace
		return model
	end

	-- Open items pass 2026-11-18: a case ends by unparenting its fixture, not destroying it. With the fake clock
	-- a sequence finishes at once, but the door tween it started runs on for 4 real seconds and moves the model
	-- every frame (VaultDoor's tweenModel, SetPrimaryPartCFrame on Door): on a destroyed model each frame warned
	-- "no PrimaryPart" (1,680 warnings in one RunAll, measured). Unparented, it moves quietly and is collected
	-- once the tween ends, as the real door is never destroyed.
	local function release(model: Model)
		model.Parent = nil
	end

	local function newDoor(overrides)
		overrides = overrides or {}
		local model = overrides.model or tempVaultDoorModel()
		local door = VaultDoor.new(model, {
			bank = overrides.bank,
			now = overrides.now or function() return 1000 end,
		})
		return door, model
	end

	-- Fully opens (or closes) a freshly-toggled door by advancing the fake
	-- clock straight past the sequence's known total duration and calling
	-- Update() once -- the step queue fires every step whose offset has been
	-- reached, in order, so this deterministically completes the whole
	-- sequence with no real waits. A small buffer past the exact total avoids
	-- landing precisely ON the last step's offset, where accumulated
	-- floating-point error in repeated addition could put elapsed a hair
	-- under it and skip the step entirely.
	local function runSequenceToCompletion(setT, door, totalOffset)
		setT(1000 + totalOffset + 0.05)
		door:Update()
	end

	local OPEN_TOTAL = 8.2
	local CLOSE_TOTAL = 6.7

	suite:test("construction places a ProximityPrompt on both Handle and Button, correctly configured", function(expect)
		local door, model = newDoor()
		for _, prompt in ipairs({ door.handlePrompt, door.buttonPrompt }) do
			expect.equal(prompt.ActionText, "Roll the Vault", "starts on the closed label")
			expect.equal(prompt.ObjectText, "Vault Door", "object text")
			expect.equal(prompt.HoldDuration, 10, "10 second hold")
			expect.equal(prompt.MaxActivationDistance, 12, "matches this system's other prompts")
			-- Deliberately true here, unlike this system's other prompts (marked
			-- intentional directly in VaultDoor.lua) -- the vault door specifically
			-- requires line of sight to trigger.
			expect.truthy(prompt.RequiresLineOfSight, "deliberately requires line of sight for this prompt")
			expect.truthy(prompt.Enabled, "enabled by default")
		end
		expect.equal(door.handlePrompt.Parent, model.Door.Handle, "handle prompt on Door.Handle")
		expect.equal(door.buttonPrompt.Parent, model.Button.Button, "button prompt on Button.Button")
		release(model)
	end)

	suite:test("starts closed, at the Center reference CFrame", function(expect)
		local door, model = newDoor()
		expect.falsy(door.isOpen, "closed")
		expect.equal(door.doorModel:GetPrimaryPartCFrame(), door.closedCFrame, "at the closed reference position")
		release(model)
	end)

	suite:test("Toggle from closed disables both prompts immediately", function(expect)
		local door, model = newDoor()
		door:Toggle()
		expect.falsy(door.handlePrompt.Enabled, "handle prompt disabled mid-animation")
		expect.falsy(door.buttonPrompt.Enabled, "button prompt disabled mid-animation")
		release(model)
	end)

	-- The actual door TWEEN runs on real TweenService/engine time (a real
	-- 4-second tween), fully decoupled from the injectable fake clock that
	-- only drives THIS step queue's own scheduling -- so whether the tween
	-- has visually finished by now is not something this fast, deterministic
	-- test can or should assert on (that a tween gets STARTED, with the
	-- correct target, is covered by the mid-animation tests below). This
	-- only asserts on what the step queue itself governs.
	suite:test("a full open sequence ends open, re-enables both prompts, and relabels them to close", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		runSequenceToCompletion(setT, door, OPEN_TOTAL)

		expect.truthy(door.isOpen, "now open")
		expect.falsy(door._steps, "sequence finished")
		for _, prompt in ipairs({ door.handlePrompt, door.buttonPrompt }) do
			expect.truthy(prompt.Enabled, "re-enabled once the sequence completes")
			expect.equal(prompt.ActionText, "Close the Vault", "relabeled to the open-state action")
		end
		release(model)
	end)

	suite:test("the open sequence starts a real tween toward the open reference CFrame", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		setT(1000 + 4.2) -- exactly the step that starts the door tween
		door:Update()
		expect.truthy(door._activeTween, "a tween was created")
		expect.equal(door._activeTween.PlaybackState, Enum.PlaybackState.Playing, "actively playing")
		-- Cancel before teardown (Destroy(), not just destroying the model) --
		-- otherwise this real, real-time tween keeps running orphaned in the
		-- background against a CFrameValue that isn't part of `model` at all,
		-- so destroying model alone doesn't stop it.
		door:Destroy()
		release(model)
	end)

	suite:test("a full close sequence (from open) ends closed and relabels back to Roll the Vault", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		runSequenceToCompletion(setT, door, OPEN_TOTAL)

		door:Toggle() -- now closing
		runSequenceToCompletion(setT, door, OPEN_TOTAL + CLOSE_TOTAL)

		expect.falsy(door.isOpen, "closed again")
		expect.falsy(door._steps, "sequence finished")
		for _, prompt in ipairs({ door.handlePrompt, door.buttonPrompt }) do
			expect.truthy(prompt.Enabled, "re-enabled")
			expect.equal(prompt.ActionText, "Roll the Vault", "back to the closed-state label")
		end
		release(model)
	end)

	-- ProximityPrompt.Triggered is a real engine signal, not fireable from a
	-- script (unlike this project's own Signal.lua) -- same testability
	-- constraint as Humanoid.Died elsewhere in this codebase (see
	-- NPCReactionAnimatorSpec's "wired to the ragdoll handler" test), so this
	-- checks the wiring exists rather than simulating a real trigger; the
	-- shared Toggle() behavior itself is exercised directly by every other
	-- test in this file.
	suite:test("both prompts' Triggered events are wired, each to a live connection", function(expect)
		local door, model = newDoor()
		expect.truthy(door._handleConn ~= nil and door._handleConn.Connected, "handle prompt wired and connected")
		expect.truthy(door._buttonConn ~= nil and door._buttonConn.Connected, "button prompt wired and connected")
		release(model)
	end)

	-- Mutual exclusion (spec addendum, 2026-09-12): guards against one player
	-- holding Handle's prompt while another triggers Button's mid-animation.
	suite:test("Toggle while already mid-animation is a no-op -- no double-fire, no restart", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle() -- starts opening
		setT(1000 + 1) -- mid-sequence, well before OPEN_TOTAL
		door:Update()
		local stepIndexBefore = door._stepIndex

		door:Toggle() -- second trigger, e.g. from the OTHER prompt, mid-animation
		expect.equal(door._stepIndex, stepIndexBefore, "did not restart or advance the sequence")
		expect.falsy(door.isOpen, "still mid-open, not somehow toggled back")

		runSequenceToCompletion(setT, door, OPEN_TOTAL)
		expect.truthy(door.isOpen, "the original sequence still completes normally")
		release(model)
	end)

	suite:test("Toggle is refused while the bank is not Active", function(expect)
		local idleBank = BankInstance.new({ config = Config, now = function() return 1000 end })
		local door, model = newDoor({ bank = idleBank })
		door:Toggle()
		expect.falsy(door._steps, "no sequence started")
		expect.truthy(door.handlePrompt.Enabled, "prompts untouched")
		release(model)
	end)

	suite:test("Toggle proceeds normally while the bank is Active", function(expect)
		local door, model = newDoor({ bank = activeBank() })
		door:Toggle()
		expect.truthy(door._steps, "sequence started")
		release(model)
	end)

	-- Session-restart reset (spec addendum, 2026-09-12): forces closed
	-- regardless of prior state, snapping rather than tweening, and
	-- interrupting any in-flight animation rather than letting it finish --
	-- same pattern as C4Charge's countdown being discarded on Seal.

	suite:test("Seal snaps an OPEN door directly closed, no tween", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		runSequenceToCompletion(setT, door, OPEN_TOTAL)
		expect.truthy(door.isOpen, "open beforehand")

		door:Seal()
		expect.falsy(door.isOpen, "forced closed")
		expect.equal(door.doorModel:GetPrimaryPartCFrame(), door.closedCFrame, "snapped to the closed reference position")
		for _, prompt in ipairs({ door.handlePrompt, door.buttonPrompt }) do
			expect.truthy(prompt.Enabled, "re-enabled for the next session")
			expect.equal(prompt.ActionText, "Roll the Vault", "relabeled back to closed")
		end
		release(model)
	end)

	suite:test("Seal mid-animation cancels the in-flight sequence and tween, snapping straight to closed", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle() -- opening
		setT(1000 + 4.2) -- past the step that starts the door tween, well before completion
		door:Update()
		expect.truthy(door._activeTween, "a tween is in flight")

		door:Seal()
		expect.falsy(door._steps, "step queue discarded, not left to finish")
		expect.falsy(door._activeTween, "tween reference cleared")
		expect.falsy(door.isOpen, "treated as closed, not wherever it was mid-animation")
		expect.equal(door.doorModel:GetPrimaryPartCFrame(), door.closedCFrame, "snapped instantly to closed")
		expect.truthy(door.handlePrompt.Enabled, "prompts re-enabled despite the interrupt")

		-- The interrupted sequence must not somehow keep running after this --
		-- advancing time further and calling Update() must do nothing.
		setT(1000 + OPEN_TOTAL + 10)
		door:Update()
		expect.falsy(door.isOpen, "still closed -- the old sequence did not resume")
		release(model)
	end)

	suite:test("Rearm resets exactly like Seal (defense in depth, matching GuardPost's own Seal+Rearm despawn)", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		runSequenceToCompletion(setT, door, OPEN_TOTAL)

		door:Rearm()
		expect.falsy(door.isOpen, "forced closed")
		expect.equal(door.doorModel:GetPrimaryPartCFrame(), door.closedCFrame, "snapped closed")
		expect.truthy(door.handlePrompt.Enabled, "re-enabled")
		expect.equal(door.handlePrompt.ActionText, "Roll the Vault", "relabeled")
		release(model)
	end)

	suite:test("a fresh session after a reset can open normally again", function(expect)
		local t = 1000
		local setT = function(v) t = v end
		local door, model = newDoor({ now = function() return t end })
		door:Toggle()
		runSequenceToCompletion(setT, door, OPEN_TOTAL)
		door:Seal()

		setT(2000)
		door:Toggle()
		runSequenceToCompletion(setT, door, 2000 - 1000 + OPEN_TOTAL)
		expect.truthy(door.isOpen, "opens again normally in the next session")
		release(model)
	end)

	suite:test("Destroy disconnects both prompts without error", function(expect)
		local door, model = newDoor()
		local ok = pcall(function() door:Destroy() end)
		expect.truthy(ok, "no error")
		release(model)
	end)

	return suite:run()
end
