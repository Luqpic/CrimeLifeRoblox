--!strict
-- Dropped duffels (2026-11-20, developer: "if a player dies, they drop their duffelbag in which other players or
-- themselves can carry"; pickers "2 minutes" and "Anyone"). A robber who dies with cash in the bag drops it where they
-- fell: the DuffelBag model on the ground with a "Pick up bag" prompt for Config.DroppedBagSeconds, while that run of
-- the robbery lasts. Whoever picks it up joins the robbery (AddParticipant, which also clears their forfeit latch) and
-- gets the cash in their own bag over the cap (AddBonus), so the location's getaway banks it as usual and a later
-- death drops it again. Unclaimed, the bag and its cash are gone. The death handlers of LocationServer (SlowFoods,
-- Gas2Go, NewsStation) and HeistServer (the Bank) call Drop after Forfeit:Die.
--
-- deps = { instance (BankInstance), template (Model), toast(player, text), parent?, isAlive?(player) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HeistConfig = require(ReplicatedStorage.HeistShared.Config)

local DuffelDrop = {}
DuffelDrop.__index = DuffelDrop

local function isAlive(player: any): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

function DuffelDrop.new(deps)
	assert(deps and deps.instance and deps.template, "DuffelDrop requires an instance and a template")
	return setmetatable({
		instance = deps.instance,
		template = deps.template,
		toast = deps.toast or function() end,
		parent = deps.parent or Workspace,
		isAlive = deps.isAlive or isAlive,
		_bags = {}, -- [Model] = { amount, runId }
	}, DuffelDrop)
end

-- `amount` Cash of `owner`'s bag on the ground below `position`; returns the bag model (nil when nothing drops).
function DuffelDrop:Drop(owner: any, amount: number, position: Vector3): Model?
	local instance = self.instance
	if amount <= 0 or instance:GetState() ~= "Active" then
		return nil
	end
	local bag = self.template:Clone()
	bag.Name = "DroppedDuffel"
	for _, part in bag:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false -- shots pass through it
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bag, typeof(owner) == "Instance" and owner.Character or bag }
	local hit = Workspace:Raycast(position, Vector3.new(0, -12, 0), params)
	local ground = if hit then hit.Position else position - Vector3.new(0, 3, 0)
	local _, size = bag:GetBoundingBox()
	bag:PivotTo(CFrame.new(ground + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.random() * 2 * math.pi, 0))

	local cash = math.floor(amount)
	bag:SetAttribute("Cash", cash)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up bag"
	prompt.ObjectText = string.format("%d %s", cash, HeistConfig.CurrencyName)
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = bag.PrimaryPart or bag:FindFirstChildWhichIsA("BasePart", true)
	prompt.Triggered:Connect(function(picker)
		self:PickUp(bag, picker)
	end)
	bag.Parent = self.parent

	local runId = instance:GetRunId()
	self._bags[bag] = { amount = amount, runId = runId }
	self.toast(owner, "Your bag dropped where you fell. Get it back within 2 minutes.")
	task.spawn(function()
		local expires = os.clock() + HeistConfig.DroppedBagSeconds
		while bag.Parent and os.clock() < expires and instance:GetState() == "Active" and instance:GetRunId() == runId do
			task.wait(1)
		end
		self._bags[bag] = nil
		bag:Destroy()
	end)
	return bag
end

-- The prompt's server side: a living player takes the bag into this robbery's bag. True when it was taken.
function DuffelDrop:PickUp(bag: Model, picker: any): boolean
	local record = self._bags[bag]
	local instance = self.instance
	if not record or not self.isAlive(picker) then
		return false
	end
	if instance:GetState() ~= "Active" or instance:GetRunId() ~= record.runId then
		return false
	end
	instance:AddParticipant(picker)
	local left = record.amount
	while left > 0 do
		local chunk = math.min(left, HeistConfig.MaxBagGrant) -- AddBonus refuses more than one grant's worth
		if not instance:AddBonus(picker, chunk) then
			break
		end
		left -= chunk
	end
	if left == record.amount then
		return false
	end
	self._bags[bag] = nil
	bag:Destroy()
	self.toast(picker, string.format("Picked up %d %s. Get clear to bank it.", math.floor(record.amount - left), HeistConfig.CurrencyName))
	return true
end

return DuffelDrop
