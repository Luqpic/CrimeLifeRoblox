return function(t)
	local QuestConfig = require(game.ReplicatedStorage.Quests.QuestConfig)
	local expect = t.expect
	t.test("reach is a positive number", function()
		expect.equal(typeof(QuestConfig.MAX_INTERACT_DISTANCE), "number")
		expect.truthy(QuestConfig.MAX_INTERACT_DISTANCE > 0)
	end)
	t.test("a player at the giver is within reach", function()
		expect.truthy(QuestConfig.withinReach(Vector3.new(0, 3, 0), Vector3.new(0, 3, 0)))
	end)
	t.test("a player one stud past the limit is not", function()
		local d = QuestConfig.MAX_INTERACT_DISTANCE + 1
		expect.falsy(QuestConfig.withinReach(Vector3.new(d, 0, 0), Vector3.zero))
	end)
	t.test("a NaN position is never within reach", function()
		expect.falsy(QuestConfig.withinReach(Vector3.new(0 / 0, 0, 0), Vector3.zero))
	end)
end
