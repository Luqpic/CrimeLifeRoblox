-- Edit is the truth (developer rule, 2026-11-20): every NPC that stands up in Play has a rig on its marker in Edit,
-- taken at boot by ServerScriptService.Heist.EditRig; the admin GUIs live in StarterGui in Edit and are taken back
-- into ServerStorage.AdminPanel at boot.
return function(t)
	local CollectionService = game:GetService("CollectionService")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local StarterGui = game:GetService("StarterGui")
	local EditRig = require(ServerScriptService.Heist.EditRig)
	local expect = t.expect

	t.test("take: the marker moves to its rig (less lift) and the rig leaves; nothing left to take is nil", function()
		local marker = Instance.new("Part")
		marker.CFrame = CFrame.new(0, 5000, 0)
		local rig = Instance.new("Model")
		local root = Instance.new("Part")
		root.Parent = rig
		rig.PrimaryPart = root
		rig:PivotTo(CFrame.new(4, 5003.2, -2))
		rig.Parent = marker
		expect.equal(EditRig.take(marker, 3.2), rig)
		expect.equal(rig.Parent, nil)
		expect.near((marker.Position - Vector3.new(4, 5000, -2)).Magnitude, 0, 1e-4)
		expect.equal(EditRig.take(marker, 3.2), nil)
		marker:Destroy()
	end)

	t.test("in Play no marker still holds its Edit rig (criminal pads, civilian spawners, heist posts and spawns)", function()
		local markers = {}
		for _, tag in { "EnemySpawnPoint", "NPCSpawner" } do
			for _, marker in CollectionService:GetTagged(tag) do
				table.insert(markers, marker)
			end
		end
		for _, folderName in { "HeistMarkers", "NewsStationMarkers" } do
			local folder = workspace:FindFirstChild(folderName)
			for _, marker in (if folder then folder:GetChildren() else {}) do
				table.insert(markers, marker)
			end
		end
		local left = {}
		for _, marker in markers do
			if marker:IsA("BasePart") and marker:FindFirstChildWhichIsA("Model") then
				table.insert(left, marker:GetFullName())
			end
		end
		expect.equal(table.concat(left, ", "), "")
	end)

	t.test("the admin GUIs are back in ServerStorage.AdminPanel, switched on, and gone from StarterGui", function()
		for _, name in { "AdminHudGui", "AdminPanelGui" } do
			expect.equal(StarterGui:FindFirstChild(name), nil)
			local gui = ServerStorage.AdminPanel:FindFirstChild(name)
			expect.truthy(gui ~= nil and gui.Enabled)
		end
	end)
end
