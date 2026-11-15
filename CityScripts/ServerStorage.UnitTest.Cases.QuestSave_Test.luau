return function(t)
	local QuestConfig = require(game.ReplicatedStorage.Quests.QuestConfig)
	local expect = t.expect
	local A, R = QuestConfig.STATE_ACCEPTED, QuestConfig.STATE_READY_TO_TURN_IN
	local target = QuestConfig.Quests.Level1Thugs.objectiveTarget

	t.test("an accepted quest comes back with its progress", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = A, progress = 4 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = A, progress = 4 } })
	end)
	t.test("a quest id that no longer exists is dropped", function()
		local q, c = QuestConfig.restore({ Gone = { state = A, progress = 1 } }, { Gone = 3 })
		expect.equal(next(q), nil)
		expect.equal(next(c), nil)
	end)
	t.test("progress at or past the target reads as ready, at the target", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = A, progress = target + 5 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = R, progress = target } })
	end)
	t.test("bad progress becomes 0 and a bad state is dropped", function()
		local q = QuestConfig.restore({
			Level1Thugs = { state = A, progress = 0 / 0 },
			Level10Smugglers = { state = A, progress = -7 },
			Level20Offender = { state = "Hacked", progress = 2 },
			Level35Bandits = "nope",
		}, {})
		expect.deepEqual(q, {
			Level1Thugs = { state = A, progress = 0 },
			Level10Smugglers = { state = A, progress = 0 },
		})
	end)
	t.test("completions keep whole positive counts only", function()
		local _, c = QuestConfig.restore({}, { Level1Thugs = 3.9, Level10Smugglers = 0, Level20Offender = "x", Level35Bandits = 0 / 0 })
		expect.deepEqual(c, { Level1Thugs = 3 })
	end)
	t.test("non-table input is an empty save, and the input is never returned", function()
		local q, c = QuestConfig.restore(nil, 7)
		expect.equal(next(q), nil)
		expect.equal(next(c), nil)
		local saved = {}
		expect.falsy(QuestConfig.restore(saved, saved) == saved)
	end)
	t.test("accepted at exactly the target (a lowered target) reads as ready", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = A, progress = target } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = R, progress = target } })
	end)
	t.test("ready saved with low progress comes back at the target", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = R, progress = 2 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = R, progress = target } })
	end)
	t.test("huge and infinite progress clamp to the target and read as ready", function()
		local q = QuestConfig.restore({
			Level1Thugs = { state = A, progress = 1e12 },
			Level10Smugglers = { state = A, progress = math.huge },
		}, {})
		expect.deepEqual(q, {
			Level1Thugs = { state = R, progress = target },
			Level10Smugglers = { state = R, progress = QuestConfig.Quests.Level10Smugglers.objectiveTarget },
		})
	end)
	t.test("a completed entry stays completed", function()
		local q = QuestConfig.restore({ Level1Thugs = { state = QuestConfig.STATE_COMPLETED, progress = 3 } }, {})
		expect.deepEqual(q, { Level1Thugs = { state = QuestConfig.STATE_COMPLETED, progress = 3 } })
	end)
end
