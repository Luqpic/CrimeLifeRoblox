-- Melee combos, heavy swings and block (combat depth, developer picker 2026-11-20), the client side of one melee weapon,
-- owned by its BlasterController. A press swings at once: the next combo step plays Slash1, 2 or 3 on the character.
-- Held past the swing's cooldown the weapon coils (Charge) and the server is told (Combat.Remotes.MeleeCharge with that
-- swing's timestamp); let go HEAVY_HOLD or more after the swing for a heavy (Heavy), sooner and the coil is dropped.
-- F, gamepad L1 or the touch BLOCK button held: block (the Hold clip is the guard). The server
-- (ServerScriptService.Blaster.Scripts.MeleeMoves) decides every multiplier; this only predicts the step to animate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local MeleeRules = require(ReplicatedStorage.Combat.MeleeRules)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local remotes = ReplicatedStorage:WaitForChild("Combat"):WaitForChild("Remotes")
local chargeRemote = remotes:WaitForChild("MeleeCharge")
local blockRemote = remotes:WaitForChild("Block")
local player = Players.LocalPlayer

local MeleeController = {}
MeleeController.__index = MeleeController

function MeleeController.new(controller)
	return setmetatable({
		controller = controller, -- the BlasterController
		step = 0,
		lastSwing = nil :: number?,
		held = false,
		coiling = false,
		blocking = false,
		tracks = {} :: { [string]: AnimationTrack },
		animator = nil :: Animator?,
		connections = {},
		touchBlockInput = nil :: InputObject?,
	}, MeleeController)
end

function MeleeController:_cooldown(): number
	local rateOfFire = self.controller.blaster:GetAttribute(Constants.RATE_OF_FIRE_ATTRIBUTE)
	return 60 / (if typeof(rateOfFire) == "number" and rateOfFire > 0 then rateOfFire else 60)
end

-- One track per clip per Animator, loaded on first use (a new character gets new tracks).
function MeleeController:_track(name: string): AnimationTrack?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	if self.animator ~= animator then
		self.animator = animator
		self.tracks = {}
	end
	local track = self.tracks[name]
	if not track then
		local ok, loaded = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = MeleeRules.CLIPS[name]
			return animator:LoadAnimation(animation)
		end)
		if not ok or not loaded then
			return nil
		end
		loaded.Priority = Enum.AnimationPriority.Action4
		self.tracks[name] = loaded
		track = loaded
	end
	return track
end

function MeleeController:_play(name: string, looped: boolean?)
	local track = self:_track(name)
	if track then
		track.Looped = looped == true
		track:Play(0.08)
	end
end

function MeleeController:_stop(name: string)
	local track = self.tracks[name]
	if track and track.IsPlaying then
		track:Stop(0.12)
	end
end

function MeleeController:_dropCoil(tellServer: boolean)
	if self.coiling then
		self.coiling = false
		self:_stop("Charge")
		if tellServer then
			chargeRemote:FireServer(false)
		end
	end
end

-- BlasterController.activate: swing (the next combo step) unless blocking or still in the cooldown.
function MeleeController:press()
	local controller = self.controller
	if self.blocking or controller.shooting or not controller:canShoot() then
		return
	end
	local before = controller.lastShotTime
	controller:startShooting() -- the light swing: BlasterController.shoot stamps lastShotTime
	local swing = controller.lastShotTime
	if swing == nil or swing == before then
		return
	end
	self.held = true
	self.step = MeleeRules.nextStep(self.step, self.lastSwing, swing, self:_cooldown())
	self.lastSwing = swing
	self:_play("Slash" .. self.step)
	task.delay(self:_cooldown(), function()
		if self.held and self.lastSwing == swing and controller.equipped and not self.blocking then
			self.coiling = true
			self:_play("Charge", true)
			chargeRemote:FireServer(swing)
		end
	end)
end

-- BlasterController.deactivate: a coil held HEAVY_HOLD past its swing becomes the heavy; sooner, it is dropped.
function MeleeController:release()
	self.held = false
	if not self.coiling then
		return
	end
	local controller = self.controller
	local swing = self.lastSwing
	if swing and controller.equipped and controller:canShoot() and Workspace:GetServerTimeNow() - swing >= MeleeRules.HEAVY_HOLD then
		self:_dropCoil(false)
		self.step = 0
		controller.shooting = true
		controller:shoot()
		self.lastSwing = controller.lastShotTime
		self:_play("Heavy")
		task.delay(self:_cooldown(), function()
			controller.shooting = false
		end)
	else
		self:_dropCoil(true)
	end
end

function MeleeController:setBlock(on: boolean)
	if on == self.blocking or (on and not self.controller.equipped) then
		return
	end
	self.blocking = on
	if on then
		self:_dropCoil(true)
		self:_play("Hold", true)
	else
		self:_stop("Hold")
	end
	blockRemote:FireServer(on)
end

-- BlasterController.equip: the block inputs, and the touch BLOCK button in place of RELOAD (melee never reloads).
function MeleeController:enable()
	local buttons = self.controller.touchInputController.gui.Buttons
	buttons.ReloadButton.Visible = false
	buttons.BlockButton.Visible = true
	for name in MeleeRules.CLIPS do
		self:_track(name) -- loaded now: the first coil, heavy or guard would otherwise wait for the download
	end
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and (input.KeyCode == MeleeRules.BLOCK_KEY or input.KeyCode == MeleeRules.BLOCK_PAD) then
			self:setBlock(true)
		end
	end))
	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == MeleeRules.BLOCK_KEY or input.KeyCode == MeleeRules.BLOCK_PAD or input == self.touchBlockInput then
			self.touchBlockInput = nil
			self:setBlock(false)
		end
	end))
	table.insert(self.connections, buttons.BlockButton.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch and input.UserInputState == Enum.UserInputState.Begin then
			self.touchBlockInput = input
			self:setBlock(true)
		end
	end))
end

-- BlasterController.unequip: let go of everything.
function MeleeController:disable()
	disconnectAndClear(self.connections)
	self.held = false
	self.touchBlockInput = nil
	self:_dropCoil(true)
	self:setBlock(false)
end

return MeleeController
