local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local InputCategorizer = require(script.Parent.InputCategorizer)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local touchGuiTemplate = script.BlasterTouchGui

local TouchInputController = {}
TouchInputController.__index = TouchInputController

function TouchInputController.new(blaster: Tool)
	local touchGui = touchGuiTemplate:Clone()
	touchGui.Enabled = false
	touchGui.Parent = playerGui

	local self = {
		blaster = blaster,
		gui = touchGui,
		enabled = false,
		connections = {},
	}
	setmetatable(self, TouchInputController)
	return self
end

function TouchInputController:updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(self.gui.AbsoluteSize.X, self.gui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < Constants.UI_SMALL_SCREEN_THRESHOLD
	self.gui.UIScale.Scale = if isSmallScreen then Constants.UI_SMALL_SCREEN_SCALE else 1
end

function TouchInputController:enableTouchInput()
	self.gui.Enabled = true
	-- Since we're going to be manually activating the blaster with a gui button, we disable the default tool activation
	self.blaster.ManualActivationOnly = true
end

function TouchInputController:disableTouchInput()
	self.gui.Enabled = false
	self.blaster.ManualActivationOnly = false
end

function TouchInputController:onReloadButtonInput(inputObject: InputObject)
	if inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if self.reloadCallback then
		self.reloadCallback()
	end
end

function TouchInputController:onShootButtonInput(inputObject: InputObject)
	if inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Save this inputObject as the current object being held to shoot. InputObjects are persistent as long
	-- as the user's finger stays down, so we can check later to see if this input has stopped.
	self.shootInputObject = inputObject
	self.blaster:Activate()
end

-- Since the user may swipe off of the shoot button by aiming around, we need to listen to all input ended
-- events in order to check when they actually stop holding the shoot button.
function TouchInputController:onInputEnded(inputObject: InputObject)
	if self.shootInputObject == inputObject then
		self.shootInputObject = nil
		self.blaster:Deactivate()
	end
end

function TouchInputController:setReloadCallback(callback: () -> ())
	self.reloadCallback = callback
end

-- (2026-11-20) the third-person buttons: VIEW toggles first / third person; SWAP, shown only in third person
-- (player attribute ViewMode), swaps the shoulder.
function TouchInputController:setViewCallbacks(toggleView: () -> (), swapShoulder: () -> ())
	self.toggleViewCallback = toggleView
	self.swapShoulderCallback = swapShoulder
end

function TouchInputController:updateSwapButton()
	self.gui.Buttons.SwapButton.Visible = player:GetAttribute("ViewMode") ~= "first"
end

function TouchInputController:enable()
	if self.enabled then
		return
	end

	self.enabled = true

	table.insert(
		self.connections,
		InputCategorizer.lastInputCategoryChanged:Connect(function(lastInputCategory)
			self:onLastInputCategoryChanged(lastInputCategory)
		end)
	)

	table.insert(
		self.connections,
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale()
		end)
	)

	table.insert(
		self.connections,
		self.gui.Buttons.ShootButton.InputBegan:Connect(function(inputObject: InputObject)
			-- Change events will fire even though we're listening to InputBegan, we need to ignore those
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end
			self:onShootButtonInput(inputObject)
		end)
	)

	table.insert(
		self.connections,
		self.gui.Buttons.ReloadButton.InputBegan:Connect(function(inputObject: InputObject)
			-- Change events will fire even though we're listening to InputBegan, we need to ignore those
			if inputObject.UserInputState == Enum.UserInputState.Change then
				return
			end
			self:onReloadButtonInput(inputObject)
		end)
	)

	for buttonName, callbackName in { ViewButton = "toggleViewCallback", SwapButton = "swapShoulderCallback" } do
		table.insert(
			self.connections,
			self.gui.Buttons[buttonName].InputBegan:Connect(function(inputObject: InputObject)
				if
					inputObject.UserInputType == Enum.UserInputType.Touch
					and inputObject.UserInputState == Enum.UserInputState.Begin
					and self[callbackName]
				then
					self[callbackName]()
				end
			end)
		)
	end
	table.insert(
		self.connections,
		player:GetAttributeChangedSignal("ViewMode"):Connect(function()
			self:updateSwapButton()
		end)
	)
	self:updateSwapButton()

	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(inputObject: InputObject)
			self:onInputEnded(inputObject)
		end)
	)

	local lastInputCategory = InputCategorizer.getLastInputCategory()
	self:onLastInputCategoryChanged(lastInputCategory)
	self:updateScale()
end

function TouchInputController:disable()
	if not self.enabled then
		return
	end

	self.enabled = false
	self:disableTouchInput()
	disconnectAndClear(self.connections)
end

function TouchInputController:onLastInputCategoryChanged(lastInputCategory)
	if lastInputCategory == InputCategorizer.InputCategory.Touch then
		self:enableTouchInput()
	else
		self:disableTouchInput()
	end
end

function TouchInputController:destroy()
	self:disable()
	self.gui:Destroy()
end

return TouchInputController
