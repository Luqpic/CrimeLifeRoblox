local RunService = game:GetService("RunService")
local TestRunner = require(game.ReplicatedStorage.HeistShared.TestRunner)

-- Add each new spec module name to this list as it is created.
local SPECS = {
	"TestRunnerSpec",
	"ConfigSpec",
	"WorldSpec",
	"BankInstanceSpec",
	"DuffelSpec",
	-- "CurrencySpec" retired in the city (phase 3 G4): ServerStorage.CityQuarantine.RetiredSpecs
	"GateSpec",
	"ZoneSpec",
	"AccessSpec",
	"LaserSpec",
	"HazardSpec",
	"GuardSpec",
	"NetSpec",
	"C4Spec",
	"ForfeitSpec",
	"AccessBarrierSpec",
	"GamepassManagerSpec",
	"UITransitionsSpec",
	"CounterBarrierSpec",
	"NPCReactionAnimatorSpec",
	"RobbableObjectSpec",
	"RestaurantConfigSpec",
	"NPCSpawnManagerSpec",
	"CashClaimVFXSpec",
	"VaultDoorSpec",
	"HighlightSequencerSpec",
	"DisplayLightsSpec",
	"SafeSpec",
	"SafeCodeSpec",
	"DuffelBagAttachmentSpec",
	"Gas2GoConfigSpec",
	"SupplyObjectSpec",
	"CarryStateSpec",
	"LockedDoorSpec",
	"NewsStationConfigSpec",
	"MasterComputerSpec",
	"NewsStationSafeSpec",
	"LocationServerSpec",
	"GetawaySpec",
	"SupplierSaleSpec", -- city, phase 3 Task 5
	"CarryGetawaySpec", -- heist layers 2026-11-17
	"FleeingManagerSpec", -- heist layers 2026-11-17 (Task 3)
	"Gas2GoRipSpec", -- heist layers 2026-11-17 (Task 4)
	"BroadcastDeskSpec", -- heist layers 2026-11-17 (Task 5)
	"DepositBoxLootSpec", -- heist layers 2026-11-17 (Task 6)
	"DepositBoxesSpec", -- heist layers 2026-11-17 (Task 6)
	"SlowFoodsKeySpec", -- open items pass 2026-11-18
	"BroadcastHooksSpec", -- open items pass 2026-11-18
	"HeistPoliceSpec", -- heist police and Bank guards 2026-11-20
	"DuffelDropSpec", -- dropped duffels 2026-11-20
}

return function()
	-- Studio-only tripwire. Nothing in the shipped game requires this module --
	-- the suite is invoked by hand during development -- so this guards against
	-- a future live Script ever picking it up by accident, not against a caller
	-- that exists today. It matters because the specs are NOT side-effect free:
	-- many build fixture models parented straight into Workspace, and several
	-- only tear them down AFTER asserting, so a failing suite leaks them. On a
	-- live server that would mean spawning stray Safes/MasterComputers/parts
	-- into the running game. Returns rather than errors so an accidental caller
	-- degrades quietly instead of taking a live server down with it.
	if not RunService:IsStudio() then
		warn("[RunAll] spec suite refused to run outside Studio -- tests are not side-effect free")
		return "RunAll: skipped (not running in Studio)"
	end

	local folder = game.ServerScriptService.Heist.Tests
	local results = {}
	for _, name in ipairs(SPECS) do
		local mod = folder:FindFirstChild(name)
		if not mod then
			table.insert(results, { name = name, passed = 0, failed = 1,
				failures = { { label = "module missing", err = name .. " not found" } } })
		else
			local ok, res = pcall(function() return TestRunner.freshRequire(mod)() end)
			if ok then
				table.insert(results, res)
			else
				table.insert(results, { name = name, passed = 0, failed = 1,
					failures = { { label = "suite errored", err = tostring(res) } } })
			end
		end
	end
	return TestRunner.report(results)
end
