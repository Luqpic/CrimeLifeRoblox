--!strict
-- The Illegal Supplier sale, decided on the server (phase 3 Task 5, audit row 4).
--
-- SubmitSupplierChoice carries no payload and the conversation that sends it is opened client-side
-- (StarterPlayerScripts.SupplierDialogueController), so the server must itself prove the seller is
-- standing at the supplier before CarryState:Consume. Without this a client sold a Gas2Go barrel or a
-- NewsStation camera from the pickup spot, 900 to 1,050 studs away, and skipped the carry.
--
-- MAX_DISTANCE is the supplier prompt's MaxActivationDistance (10) plus 5 studs of slack for the
-- character drifting while the dialog types. A refused sale keeps the carry.
local SupplierSale = {}

SupplierSale.MAX_DISTANCE = 15

-- Heist layers 2026-11-17: heavy loot flagged bankOnly banks only through its getaway.
SupplierSale.BANK_ONLY_TOAST = "The supplier won't touch that. Get it clear of the building instead."

-- The root of a living character, or nil.
local function defaultGetRoot(player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return nil end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- deps: carryState (IsCarrying, Consume), currency (Add), supplierPosition (Vector3),
-- getRoot (optional, test seam). Returns the amount paid (0 when refused) and the outcome:
-- "sold", "no_supplies", "too_far" or "bank_only" (carry kept; the caller toasts BANK_ONLY_TOAST).
function SupplierSale.try(player, deps): (number, string)
	if not deps.carryState:IsCarrying(player) then return 0, "no_supplies" end

	local root = (deps.getRoot or defaultGetRoot)(player)
	if not root or (root.Position - deps.supplierPosition).Magnitude > SupplierSale.MAX_DISTANCE then
		return 0, "too_far"
	end

	local carried = deps.carryState:GetCarried(player)
	if carried and carried.bankOnly == true then return 0, "bank_only" end

	local consumed, supplyObject = deps.carryState:Consume(player)
	if not consumed then return 0, "no_supplies" end
	local amount = supplyObject.cashOutAmount
	deps.currency:Add(player.UserId, amount)
	return amount, "sold"
end

return SupplierSale
