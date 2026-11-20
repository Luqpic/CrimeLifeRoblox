local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local InputCategorizer = require(script.Parent.InputCategorizer)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)

local player = Players.LocalPlayer
local playerGui = player.PlayerGui
local blasterGuiTemplate = script.BlasterGui
local reticleGuiTemplate = script.ReticleGui
local hitmarkerSound = script.Hitmarker
local HITMARKER_SOUND_VOLUME = hitmarkerSound.Volume
-- Richer hit feedback (combat, 2026-11-20): a body hit marks white, a server-confirmed headshot red with a higher
-- ding, a kill a bigger red X with a lower, louder one. The server confirms through the existing DamageIndicator
-- (isHeadshot) and KillConfirmed remotes.
local remotes = ReplicatedStorage.Blaster.Remotes
local HIT_COLOR = Color3.fromRGB(255, 255, 255)
local HEADSHOT_COLOR = Color3.fromRGB(255, 62, 65)
local MARKS = {
	hit = { color = HIT_COLOR, rotation = 0, scale = 2, pitch = 1, volume = 1 },
	headshot = { color = HEADSHOT_COLOR, rotation = 0, scale = 2.3, pitch = 1.3, volume = 1.2 },
	kill = { color = HEADSHOT_COLOR, rotation = 45, scale = 2.8, pitch = 0.8, volume = 1.6 },
}
-- Dry-fire click for a trigger press the client's own fire-rate cooldown held back (BlasterController).
local dryFireSound = script.DryFire

local AMMO_TEXT_FORMAT_STRING = `<font transparency="0.5">%s</font>%s`

local GuiController = {}
GuiController.__index = GuiController

function GuiController.new(blaster: Tool)
	local magazineSize = blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	local leadingZeros = #tostring(magazineSize)
	local infiniteAmmo = blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) or false

	local blasterGui = blasterGuiTemplate:Clone()
	-- Weapons are identified by name rather than an icon, matching the backpack (Roblox's default
	-- backpack falls back to the Tool's name once TextureId is empty). The name never changes for
	-- the life of this GUI, so it is set once here.
	blasterGui.Blaster.IconLabel.Visible = false
	blasterGui.Blaster.NameLabel.Text = blaster.Name
	-- An infinite-ammo weapon (melee) has no count worth showing, so the readout is hidden outright
	-- rather than left displaying a number that never moves.
	blasterGui.Blaster.Ammo.Visible = not infiniteAmmo
	blasterGui.Blaster.Ammo.MagazineLabel.Text = `/{magazineSize}`
	blasterGui.Enabled = false
	blasterGui.Parent = playerGui

	local reticleGui = reticleGuiTemplate:Clone()
	reticleGui.Enabled = false
	reticleGui.Parent = playerGui

	local scaleTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local transparencyTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local hitmarkerScaleTween = TweenService:Create(reticleGui.Hitmarker.UIScale, scaleTweenInfo, { Scale = 1 })
	local hitmarkerTransparencyTween =
		TweenService:Create(reticleGui.Hitmarker, transparencyTweenInfo, { GroupTransparency = 1 })

	local self = {
		blaster = blaster,
		blasterGui = blasterGui,
		reticleGui = reticleGui,
		hitmarkerScaleTween = hitmarkerScaleTween,
		hitmarkerTransparencyTween = hitmarkerTransparencyTween,
		enabled = false,
		leadingZeros = leadingZeros,
		infiniteAmmo = infiniteAmmo,
		ammo = 0,
		reloading = false,
		connections = {},
	}
	setmetatable(self, GuiController)
	-- The server's word on a hit this player landed: a headshot or a kill re-marks the reticle (only while this
	-- weapon's reticle is the live one).
	local damageIndicator = remotes:FindFirstChild("DamageIndicator")
	if damageIndicator then
		table.insert(self.connections, damageIndicator.OnClientEvent:Connect(function(_humanoid, _total, isHeadshot)
			if self.enabled and isHeadshot then
				self:showHitmarker("headshot")
			end
		end))
	end
	local killConfirmed = remotes:FindFirstChild("KillConfirmed")
	if killConfirmed then
		table.insert(self.connections, killConfirmed.OnClientEvent:Connect(function()
			if self.enabled then
				self:showHitmarker("kill")
			end
		end))
	end
	self:initialize()
	return self
end

function GuiController:initialize()
	table.insert(
		self.connections,
		self.blasterGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:updateScale()
		end)
	)

	table.insert(
		self.connections,
		InputCategorizer.lastInputCategoryChanged:Connect(function()
			self:updateAlignment()
		end)
	)

	self:updateScale()
	self:updateAlignment()
end

function GuiController:updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(self.blasterGui.AbsoluteSize.X, self.blasterGui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < Constants.UI_SMALL_SCREEN_THRESHOLD
	self.blasterGui.UIScale.Scale = if isSmallScreen then Constants.UI_SMALL_SCREEN_SCALE else 1
end

function GuiController:updateAlignment()
	local lastInputCategory = InputCategorizer.getLastInputCategory()
	if lastInputCategory == InputCategorizer.InputCategory.Touch then
		-- Align the blaster UI to the center of the screen, since the touch controls cover the bottom right corner
		self.blasterGui.Blaster.AnchorPoint = Vector2.new(0.5, 1)
		-- Slight vertical offset to account for the backpack UI
		self.blasterGui.Blaster.Position = UDim2.new(0.5, 0, 1, -65)
	else
		-- Middle-right: bottom-right is the notification stack's territory now (see
		-- NotificationController), so the ammo/weapon readout moved up to stay clear of it.
		self.blasterGui.Blaster.AnchorPoint = Vector2.new(1, 0.5)
		self.blasterGui.Blaster.Position = UDim2.new(1, -20, 0.5, 0)
	end
end

function GuiController:updateAmmoText()
	if self.infiniteAmmo then
		return
	end

	local zeroText = ""
	local ammoText = ""

	-- A shotgun reloads shell by shell, so its count rises through the reload and is shown as it does;
	-- a magazine weapon keeps the dashes until the whole magazine is in.
	if self.reloading and not self.blaster:GetAttribute(Constants.ISSHOTGUN_ATTRIBUTE) then
		zeroText = string.rep("-", self.leadingZeros)
	else
		ammoText = tostring(self.ammo)
		local numZeros = self.leadingZeros - #ammoText
		if numZeros > 0 then
			-- Add leading zeros to the ammo text, using rich text to give them a higher transparency
			zeroText = string.rep("0", numZeros)
		end
	end

	self.blasterGui.Blaster.Ammo.AmmoLabel.Text = string.format(AMMO_TEXT_FORMAT_STRING, zeroText, ammoText)
end

function GuiController:setAmmo(ammo: number)
	self.ammo = ammo
	self:updateAmmoText()
end

function GuiController:setReloading(reloading: boolean)
	self.reloading = reloading
	self:updateAmmoText()
end

function GuiController:playDryFire()
	dryFireSound:Play()
end

function GuiController:showHitmarker(kind: string?)
	local mark = MARKS[kind or "hit"] or MARKS.hit
	for _, line in self.reticleGui.Hitmarker:GetChildren() do
		if line:IsA("Frame") then
			line.BackgroundColor3 = mark.color
		end
	end
	self.reticleGui.Hitmarker.Rotation = mark.rotation
	-- Slightly delay the hitmarker sound so it doesn't overlap the shooting sound
	task.delay(Constants.HITMARKER_SOUND_DELAY, function()
		hitmarkerSound.PlaybackSpeed = mark.pitch
		hitmarkerSound.Volume = HITMARKER_SOUND_VOLUME * mark.volume
		hitmarkerSound:Play()
	end)

	if self.hitmarkerScaleTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerScaleTween:Cancel()
	end
	if self.hitmarkerTransparencyTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerTransparencyTween:Cancel()
	end

	self.reticleGui.Hitmarker.GroupTransparency = 0
	self.reticleGui.Hitmarker.UIScale.Scale = mark.scale

	self.hitmarkerScaleTween:Play()
	self.hitmarkerTransparencyTween:Play()
end

function GuiController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	self.blasterGui.Enabled = true
	self.reticleGui.Enabled = true

	UserInputService.MouseIconEnabled = false
end

function GuiController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	self.blasterGui.Enabled = false
	self.reticleGui.Enabled = false

	UserInputService.MouseIconEnabled = true
end

function GuiController:destroy()
	self:disable()
	disconnectAndClear(self.connections)
	self.blasterGui:Destroy()
	self.reticleGui:Destroy()
end

return GuiController
