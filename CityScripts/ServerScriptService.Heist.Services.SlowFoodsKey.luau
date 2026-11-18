--!strict
-- Open items pass 2026-11-18: SlowFoods' manager-key layer wiring, moved out of SlowFoodsServer unchanged so
-- SlowFoodsKeySpec can drive it. A bank component (register it after the storage-room door, then storageSafe).
--   Give(player): FleeingManager's onKeyTaken. One key per run, for the player who caught the Manager (player
--     attribute SlowFoodsKey); cleared on Seal, Rearm, the holder's death (Humanoid.Died) and leave (Forget).
--   UseKey(player): the "Use Key" prompt on the storage-room door, shown to everyone while the door is shut
--     in an Active run; opens the door (door:Open) for the key holder only.
--   storageSafe: a RobbableObject paying the key holder safeAmount over the bag cap (AddBonus). Final review
--     2026-11-18: a carrier can't rob it, its hold is timed on the server, its reach re-measured.
--
-- deps = { bank, net, carryState, notifyRefused(player, reason), door ({Open(player) -> boolean}),
--   useKeyPrompt: ProximityPrompt, safeModel: Model, safePromptTemplate: ProximityPrompt, safeAmount: number,
--   playRobSound?(part), measure?(player) -> number? (safe reach), clock? (safe hold) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RobbableObject = require(ReplicatedStorage.SharedSystems.RobbableObject)

local SlowFoodsKey = {}
SlowFoodsKey.__index = SlowFoodsKey
SlowFoodsKey.KEY_ATTRIBUTE = "SlowFoodsKey"
SlowFoodsKey.NO_KEY_MESSAGE = "You need the manager's key."
SlowFoodsKey.KEY_TAKEN_MESSAGE = "You took the manager's key."

function SlowFoodsKey.new(deps)
	local self = setmetatable({ _deps = deps, holder = nil :: any, _diedConn = nil :: RBXScriptConnection? }, SlowFoodsKey)
	local carryState = deps.carryState
	self.storageSafe = RobbableObject.new(deps.safeModel, {
		bank = deps.bank,
		promptTemplate = deps.safePromptTemplate,
		amount = deps.safeAmount,
		payWith = "bonus",
		isBlocked = function(player) return carryState:IsCarrying(player) or not self:HasKey(player) end,
		blockedReason = "no_key",
		onRefused = function(player, reason)
			if reason == "no_key" and carryState:IsCarrying(player) then reason = "carrying_supplies" end
			if reason == "no_key" then deps.net:Toast(player, SlowFoodsKey.NO_KEY_MESSAGE) else deps.notifyRefused(player, reason) end
		end,
		playRobSound = deps.playRobSound,
		enforceHold = true,
		checkReach = true,
		measure = deps.measure,
		clock = deps.clock,
	})
	self._useKeyConn = deps.useKeyPrompt.Triggered:Connect(function(player) self:UseKey(player) end)
	return self
end

function SlowFoodsKey:HasKey(player): boolean
	return self.holder ~= nil and player == self.holder
end

function SlowFoodsKey:Clear()
	if self._diedConn then
		self._diedConn:Disconnect()
		self._diedConn = nil
	end
	if self.holder then self.holder:SetAttribute(SlowFoodsKey.KEY_ATTRIBUTE, nil) end
	self.holder = nil
end

function SlowFoodsKey:Give(player)
	self:Clear()
	self.holder = player
	player:SetAttribute(SlowFoodsKey.KEY_ATTRIBUTE, true)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then self._diedConn = humanoid.Died:Connect(function() self:Clear() end) end
	self._deps.net:Toast(player, SlowFoodsKey.KEY_TAKEN_MESSAGE)
end

-- Key F (the lockpick keeps E). The server measures the reach to the prompt's part itself.
function SlowFoodsKey:UseKey(player)
	local deps = self._deps
	local prompt = deps.useKeyPrompt
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then return end
	if (root.Position - prompt.Parent.Position).Magnitude > prompt.MaxActivationDistance then return end
	-- Leftovers (2026-11-18): a bystander is told to join rather than to find a key.
	if not deps.bank:IsParticipant(player) then
		deps.notifyRefused(player, "not_participant")
		return
	end
	if not self:HasKey(player) then
		deps.net:Toast(player, SlowFoodsKey.NO_KEY_MESSAGE)
		return
	end
	if deps.door:Open(player) then prompt.Enabled = false end
end

-- PlayerRemoving: the key goes with its holder; a begun safe hold is forgotten.
function SlowFoodsKey:Forget(player)
	if player == self.holder then self:Clear() end
	self.storageSafe:Forget(player)
end

-- Any death: a begun safe hold is forgotten (the holder's own key is cleared by its Died connection).
function SlowFoodsKey:OnDied(player)
	self.storageSafe:Forget(player)
end

function SlowFoodsKey:OnSessionStart()
	self._deps.useKeyPrompt.Enabled = true
end

function SlowFoodsKey:Seal()
	self:Clear()
	self._deps.useKeyPrompt.Enabled = false
end

function SlowFoodsKey:Rearm()
	self:Clear()
end

function SlowFoodsKey:Destroy()
	self._useKeyConn:Disconnect()
	self:Clear()
end

return SlowFoodsKey
