-- Dropped duffels (2026-11-20): a dead robber's bag lies on the ground; anyone alive picks it up into this run's bag.
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

return function()
	local BankInstance = TestRunner.freshRequire(game.ServerScriptService.Heist.BankInstance)
	local DuffelDrop = TestRunner.freshRequire(game.ServerScriptService.Heist.Services.DuffelDrop)
	local Config = TestRunner.freshRequire(game.ReplicatedStorage.HeistShared.Config)
	local suite = TestRunner.new("DuffelDrop")

	local function rig()
		local t = 1000
		local inst = BankInstance.new({ config = Config, now = function() return t end })
		inst:TryStart("starter")
		local folder = Instance.new("Folder")
		folder.Parent = workspace
		local toasts = {}
		local template = Instance.new("Model")
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Parent = template
		template.PrimaryPart = handle
		local drop = DuffelDrop.new({
			instance = inst,
			template = template,
			parent = folder,
			toast = function(player, text) table.insert(toasts, { player = player, text = text }) end,
			isAlive = function(player) return player ~= "dead" end,
		})
		return inst, drop, folder, toasts
	end

	suite:test("a dropped bag goes to whoever picks it up, once", function(expect)
		local inst, drop, folder, toasts = rig()
		local bag = drop:Drop("owner", 2500, Vector3.new(0, 5000, 0))
		expect.truthy(bag ~= nil and bag.Parent == folder, "on the ground")
		expect.equal(bag:GetAttribute("Cash"), 2500, "carries the amount")
		expect.falsy(drop:PickUp(bag, "dead"), "a dead player cannot take it")
		expect.truthy(drop:PickUp(bag, "p2"), "taken")
		expect.truthy(inst:IsParticipant("p2"), "joins the robbery")
		expect.equal(inst:GetDuffel("p2"), 2500, "the cash is in the picker's bag")
		expect.falsy(bag.Parent ~= nil, "gone from the ground")
		expect.falsy(drop:PickUp(bag, "p3"), "no second pick-up")
		expect.equal(toasts[#toasts].player, "p2", "the picker is told")
		folder:Destroy()
	end)

	suite:test("it lands on top of a full bag and nothing drops when empty", function(expect)
		local inst, drop, folder = rig()
		inst:AddParticipant("p2")
		inst:TryAddDuffel("p2", inst:GetDuffelCap("p2"))
		local bag = drop:Drop("owner", 800, Vector3.new(0, 5000, 0))
		expect.truthy(drop:PickUp(bag, "p2"), "taken over the cap")
		expect.equal(inst:GetDuffel("p2"), inst:GetDuffelCap("p2") + 800, "added over the cap")
		expect.equal(drop:Drop("owner", 0, Vector3.new(0, 5000, 0)), nil, "an empty bag does not drop")
		folder:Destroy()
	end)

	suite:test("once the robbery is over the bag cannot be taken", function(expect)
		local inst, drop, folder = rig()
		local bag = drop:Drop("owner", 1000, Vector3.new(0, 5000, 0))
		inst:_seal("timer_expired")
		expect.falsy(drop:PickUp(bag, "p2"), "refused")
		expect.equal(inst:GetDuffel("p2"), 0, "nothing added")
		folder:Destroy()
	end)

	return suite:run()
end
