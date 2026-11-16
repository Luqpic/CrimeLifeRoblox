--!strict
-- Supplies Robbery (spec addendum, 2026-09-19): the genuinely GLOBAL half
-- of the feature -- one player, one Backpack (Carry State is meaningful
-- regardless of which location the player is standing in), and one shared
-- Illegal Supplier NPC (not owned by either SlowFoodsServer or
-- Gas2GoServer). The per-location supply pickups themselves are built and
-- owned by SlowFoodsServer.lua/Gas2GoServer.lua, same pattern as every
-- other robbable object in this codebase -- this script only ever touches
-- the shared Carry State singleton and the standalone NPC.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HeistConfig = require(ReplicatedStorage.HeistShared.Config)
local Net = require(ServerScriptService.Heist.Services.Net)
-- Global singleton, shared with HeistServer/SlowFoodsServer/Gas2GoServer --
-- see CarryState's own header for why this must never be constructed a
-- second time.
local carryState = require(ReplicatedStorage.SharedSystems.CarryState)
-- Singleton, shared with every other robbery-site script -- see
-- CurrencyService for why this must never be constructed a second time.
local currency = require(ServerScriptService.PlayerData.CurrencyService)
local SupplierSale = require(ServerScriptService.Heist.Services.SupplierSale)

-- Net.setup() is idempotent (FindFirstChild before creating each remote),
-- same as every other robbery-site script independently calling it --
-- confirmed safe to call here as a 4th, fully independent instance around
-- the same underlying ReplicatedStorage.HeistShared.Remotes folder.
local net = Net.setup()

-- Already manually placed in Workspace (confirmed, no script-driven
-- placement/positioning/balancing needed) -- referenced directly by path.
local illegalSupplier = workspace["Illegal Supplier"]
local rig = illegalSupplier["Illegal Supplier"]
local humanoid = rig:WaitForChild("Humanoid")

-- Explicit damage-interception invincibility, not just a high MaxHealth
-- (spec: this NPC must never actually die regardless of how damage is
-- dealt -- guards, lasers, C4 splash, anything). BreakJointsOnDeath=false
-- is a redundant second layer in case Health ever transiently reaches 0
-- despite the revert below firing synchronously on every decrease.
humanoid.BreakJointsOnDeath = false
humanoid.HealthChanged:Connect(function(newHealth)
	if newHealth < humanoid.MaxHealth then
		humanoid.Health = humanoid.MaxHealth
	end
end)

-- Idle only (spec) -- reuses the SAME animation id already confirmed for
-- Bank Clerks/Cashiers, but loaded directly here rather than through
-- NPCReactionAnimator: that class exists for the Surprised/Scared REACTION
-- sequence, which this NPC never needs.
do
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
	local anim = Instance.new("Animation")
	anim.AnimationId = "rbxassetid://" .. HeistConfig.IllegalSupplierIdleAnim
	local track = animator:LoadAnimation(anim)
	track.Looped = true
	track:Play()
end

-- Physics-drop (spec addendum, 2026-09-20): places the drop point a couple
-- studs in front of the character at roughly chest/waist height, then lets
-- SupplyObject's own physics-active state carry it down from there --
-- deliberately not trying to compute a "resting on the floor" position by
-- hand.
local function computeDropCFrame(character): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return character:GetPivot() end -- fallback, matches prior behavior
	return root.CFrame * CFrame.new(0, 0, -2)
end

-- Dialog wiring: the conversation is opened CLIENT-side now, straight off the same
-- ProximityPrompt, by StarterPlayerScripts.SupplierDialogueController -- the same way the
-- "FPS System" place's quest NPCs do it, so the two dialogue systems are one system.
--
-- This script deliberately no longer answers the prompt. What it still owns is the part that
-- must never be client-side: which outcome the player gets is decided HERE, once "yes" is
-- actually clicked, with CarryState:Consume re-checked at that exact moment -- never upfront
-- when the prompt is first held, and never on the client's say-so.
--
-- Net's OpenSupplierDialog remote is left defined but is no longer fired by anything; removing
-- it would touch Net's remote list, which every robbery-site script shares.

net:OnSupplierChoiceSubmitted(function(player)
	-- Per-location cash-out generalization (spec addendum, 2026-09-2X):
	-- grants THIS SPECIFIC supply object's own cashOutAmount, not a flat
	-- global constant -- SlowFoods/Gas2Go's own supplies still pass 10000
	-- (unchanged), NewsStation's ExpensiveCamera passes 20000.
	-- City (phase 3 Task 5): the sale is decided by Heist.Services.SupplierSale, which also
	-- requires the seller's living character within 15 studs of the supplier: the dialog is
	-- client-side, so the server proves the reach. A refused sale keeps the carry and answers
	-- nothing (a real client is always within the prompt's 10 studs).
	local paid, outcome = SupplierSale.try(player, {
		carryState = carryState,
		currency = currency,
		supplierPosition = illegalSupplier.Interaction.Position,
	})
	if outcome == "too_far" then return end
	if paid > 0 then
		-- Reuses the EXACT confirmed Claim-zone cash-out pattern verbatim --
		-- the existing client-side CashClaimVFX needs zero changes.
		net:NotifyRobberySuccess(player)
		-- Same shared kaching asset already backing RegisterRobSound/ATMRobSound/
		-- SafeRobSound/BankRegisterRobSound everywhere else in this project (spec
		-- addendum, 2026-09-2X) -- pre-placed on the Illegal Supplier's own
		-- Interaction part, alongside (not replacing) the CashClaimVFX/
		-- RobberySuccess flow above.
		local kaching = illegalSupplier.Interaction:FindFirstChild("RedemptionKachingSound")
		if kaching then
			local sok, serr = pcall(function() kaching:Play() end)
			if not sok then warn("[SuppliesServer] RedemptionKachingSound failed: " .. tostring(serr)) end
		end
		net:SupplierResult(player, "sold")
	else
		net:SupplierResult(player, "no_supplies")
	end
end)

-- Drop button: an unprivileged claim, re-validated server-side --
-- CarryState:Drop is already a no-op for a player who isn't carrying.
net:OnDropRequested(function(player)
	if not carryState:IsCarrying(player) then return end
	local character = player.Character
	local cframe = character and computeDropCFrame(character)
	if not cframe then return end
	carryState:Drop(player, cframe)
end)

-- Death-while-carrying: independent Died wiring, entirely decoupled from
-- each location's own forfeiture logic (multiple listeners on the same
-- Humanoid.Died coexist fine) -- captures the CFrame at the very start of
-- the callback, before anything about the character can be torn down.
local function watchCharacter(player, character)
	local humanoid2 = character:WaitForChild("Humanoid", 5)
	if not humanoid2 then return end
	humanoid2.Died:Connect(function()
		if carryState:IsCarrying(player) then
			carryState:Drop(player, computeDropCFrame(character))
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	if player.Character then watchCharacter(player, player.Character) end
	player.CharacterAdded:Connect(function(character) watchCharacter(player, character) end)
	-- City (phase 3 Task 5): a character removed without dying (LoadCharacter, anything that
	-- skips Died) drops the carry where it stood, so a removed character keeps nothing. After a
	-- death the Died handler above has already dropped it and this is a no-op.
	player.CharacterRemoving:Connect(function(character)
		if carryState:IsCarrying(player) then
			carryState:Drop(player, computeDropCFrame(character))
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	carryState:Forget(player)
end)
