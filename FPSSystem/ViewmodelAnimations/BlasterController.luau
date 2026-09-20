-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Constants
local Constants = require(ReplicatedStorage.Blaster.Constants)
local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)
local TouchInputController = require(script.Parent.TouchInputController)
local CameraRecoiler = require(script.Parent.CameraRecoiler)
local ViewModelController = require(script.Parent.ViewModelController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local GuiController = require(script.Parent.GuiController)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)
local getRayDirections = require(script.Parent.Parent.Utility.getRayDirections)
local drawRayResults = require(script.Parent.Parent.Utility.drawRayResults)
local castRays = require(script.Parent.Parent.Utility.castRays)
local canDamageHumanoid = require(script.Parent.Parent.Utility.canDamageHumanoid)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local remotes = ReplicatedStorage.Blaster.Remotes
local shootRemote = remotes.Shoot
local reloadRemote = remotes.Reload

-- Shotgun-only pacing. PUMP_CYCLE_SECONDS is the pump action after each shot; the shell time scale
-- makes every shell but the last slightly quicker, so a full reload lands near the old total.
local PUMP_CYCLE_SECONDS = 0.25
local SHOTGUN_SHELL_TIME_SCALE = 0.85

local ZOOMED_FOV = 50
local CAMERA_OFFSET_ZOOMED = Vector3.new(0, 0, -2)
local ZOOMED_SENSITIVITY_SCALE = 0.5 -- Adjust this value to decrease sensitivity when zoomed in

local AIM_ASSIST_BIND_NAME = "AimAssist"
local AIM_ASSIST_CONE_ANGLE = math.rad(10)
local AIM_STICK_SPEED = 0.01

local random = Random.new()

local BlasterController = {}
BlasterController.__index = BlasterController

function BlasterController.new(blaster: Tool)
	local viewModelController = ViewModelController.new(blaster)
	local guiController = GuiController.new(blaster)
	local touchInputController = TouchInputController.new(blaster)
	local characterAnimationController = CharacterAnimationController.new(blaster)

	local self = {
		blaster = blaster,
		viewModelController = viewModelController,
		guiController = guiController,
		touchInputController = touchInputController,
		characterAnimationController = characterAnimationController,
		activated = false,
		equipped = false,
		shooting = false,
		ammo = blaster:GetAttribute(Constants.AMMO_ATTRIBUTE),
		reloading = blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE),
		infiniteAmmo = blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) or false,
		isShotgun = blaster:GetAttribute(Constants.ISSHOTGUN_ATTRIBUTE) or false,
		reloadCancelRequested = false,
		connections = {},
		isZoomedIn = false,
		isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.GamepadEnabled,
		aimAssistBound = false,
	}
	setmetatable(self, BlasterController)

	self:initialize()

	return self
end

function BlasterController:isHumanoidAlive(): boolean
	return self.humanoid and self.humanoid.Health > 0
end

function BlasterController:canShoot(): boolean
	local hasAmmo = self.infiniteAmmo or self.ammo > 0
	return self:isHumanoidAlive() and self.equipped and hasAmmo and not self.reloading
end

function BlasterController:canReload(): boolean
	-- An infinite-ammo weapon (melee) has nothing to reload, so the whole reload flow -- animation,
	-- remote, HUD state -- must never start.
	if self.infiniteAmmo then
		return false
	end

	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)
	return self:isHumanoidAlive() and self.equipped and self.ammo < magazineSize and not self.reloading
end

function BlasterController:recoil()
	local recoilMin = self.blaster:GetAttribute(Constants.RECOIL_MIN_ATTRIBUTE)
	local recoilMax = self.blaster:GetAttribute(Constants.RECOIL_MAX_ATTRIBUTE)

	local xDif = recoilMax.X - recoilMin.X
	local yDif = recoilMax.Y - recoilMin.Y
	local x = recoilMin.X + random:NextNumber() * xDif
	local y = recoilMin.Y + random:NextNumber() * yDif

	local recoil = Vector2.new(math.rad(-x), math.rad(y))

	CameraRecoiler.recoil(recoil)
end

function BlasterController:shoot()
	local spread = self.blaster:GetAttribute(Constants.SPREAD_ATTRIBUTE)
	local raysPerShot = self.blaster:GetAttribute(Constants.RAYS_PER_SHOT_ATTRIBUTE)
	local range = self.blaster:GetAttribute(Constants.RANGE_ATTRIBUTE)
	local rayRadius = self.blaster:GetAttribute(Constants.RAY_RADIUS_ATTRIBUTE)
	local swingDelay = self.blaster:GetAttribute(Constants.SWING_DELAY_ATTRIBUTE) or 0

	-- One random pick, used for both views, so the first-person viewmodel and the third-person
	-- character never disagree about which swing/shoot variant is playing.
	local pickedAnimation = self.viewModelController:playShootAnimation()
	self.characterAnimationController:playShootAnimation(pickedAnimation)
	self:recoil()

	if not self.infiniteAmmo then
		self.ammo -= 1
		self.guiController:setAmmo(self.ammo)
	end

	-- Hit resolution is factored out so a melee weapon can defer it until the swing animation has
	-- visually reached the target. Animation, recoil and the ammo decrement stay immediate.
	--
	-- The aim is read live inside here rather than captured before the delay, so a swing connects
	-- wherever the camera is actually pointing at the moment of impact rather than being frozen to
	-- where it pointed when the button was pressed.
	local function resolveHit()
		local now = Workspace:GetServerTimeNow()

		-- In first person the camera sits essentially at the character's head, so it's a valid shot origin.
		-- In third person the camera is shifted off to the shoulder, which the server's validateShot
		-- proximity check would always reject -- so the origin is the gun's actual muzzle position instead,
		-- while still aiming along the camera's look direction (crosshair-based aiming).
		local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.viewModelController.thirdPerson

		local origin
		if isFirstPerson then
			origin = camera.CFrame
		else
			local muzzlePosition = self.viewModelController:getMuzzlePosition()
			origin = CFrame.new(muzzlePosition, muzzlePosition + camera.CFrame.LookVector)
		end

		local rayDirections = getRayDirections(origin, raysPerShot, math.rad(spread), now)
		for index, direction in rayDirections do
			rayDirections[index] = direction * range
		end

		local rayResults = castRays(player, origin.Position, rayDirections, rayRadius)

		local tagged = {}
		local didTag = false
		for index, rayResult in rayResults do
			if rayResult.taggedHumanoid then
				tagged[tostring(index)] = rayResult.taggedHumanoid
				didTag = true
			end
		end

		if didTag then
			self.guiController:showHitmarker()
		end

		shootRemote:FireServer(now, self.blaster, origin, tagged)

		local muzzlePosition = self.viewModelController:getMuzzlePosition()
		drawRayResults(self.blaster, muzzlePosition, rayResults)
	end

	if swingDelay > 0 then
		task.delay(swingDelay, resolveHit)
	else
		resolveHit()
	end
end

function BlasterController:startShooting()
	-- A shotgun's shell-by-shell reload is interruptible: firing mid-reload aborts it and fires
	-- whatever is already chambered. Every other weapon keeps the old behaviour of simply being
	-- blocked while reloading (canShoot() below returns false).
	if self.isShotgun and self.reloading then
		self:cancelReload()
		while self.reloading do
			task.wait()
		end
		if self.ammo <= 0 then
			return
		end
	end

	if not self.infiniteAmmo and self.ammo == 0 then
		self:reload()
		return
	end

	if not self:canShoot() then
		return
	end

	if self.shooting then
		return
	end

	local fireMode = self.blaster:GetAttribute(Constants.FIRE_MODE_ATTRIBUTE)
	local rateOfFire = self.blaster:GetAttribute(Constants.RATE_OF_FIRE_ATTRIBUTE)

	if fireMode == Constants.FIRE_MODE.SEMI then
		self.shooting = true
		self:shoot()
		if self.isShotgun then
			task.wait(PUMP_CYCLE_SECONDS)
		end
		task.delay(60 / rateOfFire, function()
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	elseif fireMode == Constants.FIRE_MODE.AUTO then
		task.spawn(function()
			self.shooting = true
			while self.activated and self:canShoot() do
				self:shoot()
				task.wait(60 / rateOfFire)
			end
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	elseif fireMode == Constants.FIRE_MODE.BURST then
		-- Same shape as AUTO but bounded, and deliberately not gated on self.activated: releasing
		-- the trigger mid-burst does not cut the burst short. self.shooting stays true for the whole
		-- burst, so the guard at the top of this function blocks re-triggering until it finishes.
		task.spawn(function()
			self.shooting = true
			for _ = 1, Constants.BURST_ROUND_COUNT do
				if not self:canShoot() then
					break
				end
				self:shoot()
				task.wait(60 / rateOfFire)
			end
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	end
end

function BlasterController:cancelReload()
	self.viewModelController:cancelReloadAnimation()
	self.reloadCancelRequested = true

	if self.reloadTask then
		task.cancel(self.reloadTask)
		self.reloadTask = nil
	end

	self.reloading = false
	self.guiController:setReloading(false)
end

function BlasterController:reload()
	if not self:canReload() then
		return
	end

	local reloadTime = self.blaster:GetAttribute(Constants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = self.blaster:GetAttribute(Constants.MAGAZINE_SIZE_ATTRIBUTE)

	self.reloading = true
	self.reloadCancelRequested = false
	self.guiController:setReloading(self.reloading)
	reloadRemote:FireServer(self.blaster)

	if self.isShotgun then
		-- One shell at a time, abortable between shells and mid-shell. For a shotgun reloadTime is
		-- the per-shell time, so the animation is scaled to each shell's own window rather than to
		-- the whole magazine.
		while self.ammo < magazineSize and self.equipped and not self.reloadCancelRequested do
			local isLastShell = (self.ammo + 1) == magazineSize
			local playTime = if isLastShell then reloadTime else reloadTime * SHOTGUN_SHELL_TIME_SCALE

			self.viewModelController:playReloadAnimation(playTime)
			self.characterAnimationController:playReloadAnimation(playTime)

			local elapsed = 0
			while elapsed < playTime do
				if self.reloadCancelRequested then
					self.reloading = false
					self.guiController:setReloading(false)
					return
				end
				elapsed += task.wait()
			end

			self.ammo += 1
			self.guiController:setAmmo(self.ammo)
		end

		self.reloading = false
		self.guiController:setReloading(false)
	else
		-- Unchanged monolithic reload for every non-shotgun weapon.
		self.viewModelController:playReloadAnimation(reloadTime)
		self.characterAnimationController:playReloadAnimation(reloadTime)

		self.reloadTask = task.delay(reloadTime, function()
			self.ammo = magazineSize
			self.reloading = false
			self.reloadTask = nil
			self.guiController:setAmmo(self.ammo)
			self.guiController:setReloading(self.reloading)
		end)
	end
end

function BlasterController:applyZoom()
	-- Camera ownership (FOV/CameraOffset/mouse sensitivity) goes through CameraAuthority so it
	-- resolves correctly against Crouch/Sprint/ShiftLock instead of last-write-wins.
	CameraAuthority.CameraOffset:Set("ADS", CAMERA_OFFSET_ZOOMED)
	CameraAuthority.FieldOfView:Set("ADS", ZOOMED_FOV)
	CameraAuthority.MouseDeltaSensitivity:Set("ADS", ZOOMED_SENSITIVITY_SCALE)

	self.isZoomedIn = true
	self.viewModelController:setAiming(true)
	self:startAimAssist()
end

function BlasterController:removeZoom()
	CameraAuthority.CameraOffset:Clear("ADS")
	CameraAuthority.FieldOfView:Clear("ADS")
	CameraAuthority.MouseDeltaSensitivity:Clear("ADS")

	self.isZoomedIn = false
	self.viewModelController:setAiming(false)
	self:stopAimAssist()
end

-- Finds the nearest valid enemy within a narrow cone in front of the camera, for the aim assist
-- loop to gently pull the crosshair toward while zoomed in. Reuses the same team-damage rules the
-- server enforces, so assist never latches onto a teammate you couldn't legally hit anyway.
function BlasterController:getClosestAimAssistTarget(): BasePart?
	local closestTarget: BasePart? = nil
	local closestAngle = math.huge

	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then
			continue
		end

		local character = otherPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not (humanoid and rootPart) then
			continue
		end

		if not canDamageHumanoid(player, humanoid) then
			continue
		end

		local direction = (rootPart.Position - camera.CFrame.Position).Unit
		local angle = math.acos(camera.CFrame.LookVector:Dot(direction))

		if angle < AIM_ASSIST_CONE_ANGLE and angle < closestAngle then
			closestAngle = angle
			closestTarget = rootPart
		end
	end

	return closestTarget
end

function BlasterController:startAimAssist()
	if self.isMobile or self.aimAssistBound then
		return
	end
	self.aimAssistBound = true

	RunService:BindToRenderStep(AIM_ASSIST_BIND_NAME, Enum.RenderPriority.Camera.Value, function()
		local target = self:getClosestAimAssistTarget()
		if not target then
			return
		end

		local cameraPos = camera.CFrame.Position
		local direction = (target.Position - cameraPos).Unit
		local newLookVector = camera.CFrame.LookVector:Lerp(direction, AIM_STICK_SPEED)
		camera.CFrame = CFrame.lookAt(cameraPos, cameraPos + newLookVector)
	end)
end

function BlasterController:stopAimAssist()
	if not self.aimAssistBound then
		return
	end
	self.aimAssistBound = false
	RunService:UnbindFromRenderStep(AIM_ASSIST_BIND_NAME)
end

function BlasterController:activate()
	if self.activated then
		return
	end
	self.activated = true

	self:startShooting()
end

function BlasterController:deactivate()
	if not self.activated then
		return
	end
	self.activated = false
end

function BlasterController:equip()
	if self.equipped then
		return
	end
	self.equipped = true

	-- Resync ammo and reloading values
	self.ammo = self.blaster:GetAttribute(Constants.AMMO_ATTRIBUTE)
	self.reloading = self.blaster:GetAttribute(Constants.RELOADING_ATTRIBUTE)
	self.infiniteAmmo = self.blaster:GetAttribute(Constants.INFINITE_AMMO_ATTRIBUTE) or false
	self.isShotgun = self.blaster:GetAttribute(Constants.ISSHOTGUN_ATTRIBUTE) or false

	-- Enable view model
	self.viewModelController:enable()

	-- Enable GUI
	self.guiController:setAmmo(self.ammo)
	self.guiController:setReloading(self.reloading)
	self.guiController:enable()

	-- Enable touch input controller
	self.touchInputController:enable()

	-- Enable character animations
	self.characterAnimationController:enable()

	-- Keep track of the humanoid in the character currently equipping the blaster.
	self.humanoid = self.blaster.Parent:FindFirstChildOfClass("Humanoid")

	-- BreakJointsOnDeath is off (RagdollController owns death presentation instead), so nothing else
	-- guarantees Tool.Unequipped fires when the character dies. Without this, a player who dies
	-- while zoomed into first person stays locked into a first-person view of their own ragdoll,
	-- with no Tool-side event left to reset the camera. unequip() already guards on self.equipped,
	-- so if the native Unequipped also fires the second call is a no-op.
	if self.humanoid then
		self.connections.died = self.humanoid.Died:Connect(function()
			self:unequip()
		end)
	end

	-- Handle zoom events
	self.connections.zoomIn = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:applyZoom()
		end
	end)

	self.connections.zoomOut = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			self:removeZoom()
		end
	end)
end

function BlasterController:unequip()
	if not self.equipped then
		return
	end
	self.equipped = false

	-- Force deactivate the blaster when unequipping it
	self:deactivate()

	-- If the blaster is being reloaded, stop it
	if self.reloadTask then
		task.cancel(self.reloadTask)
		self.reloadTask = nil
	end

	-- Disable view model
	self.viewModelController:disable()

	-- Disable GUI
	self.guiController:disable()

	-- Disable touch input controller
	self.touchInputController:disable()

	-- Disable character animations
	self.characterAnimationController:disable()

	-- Clean up zoom connections
	if self.connections.zoomIn then
		self.connections.zoomIn:Disconnect()
		self.connections.zoomIn = nil
	end
	if self.connections.zoomOut then
		self.connections.zoomOut:Disconnect()
		self.connections.zoomOut = nil
	end
	if self.connections.died then
		self.connections.died:Disconnect()
		self.connections.died = nil
	end

	-- Remove zoom adjustments
	self:removeZoom()
end

function BlasterController:initialize()
	table.insert(
		self.connections,
		self.blaster.Equipped:Connect(function()
			self:equip()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Unequipped:Connect(function()
			self:unequip()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Activated:Connect(function()
			self:activate()
		end)
	)
	table.insert(
		self.connections,
		self.blaster.Deactivated:Connect(function()
			self:deactivate()
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputBegan:Connect(function(inputObject: InputObject, processed: boolean)
			if processed then
				return
			end

			if
				inputObject.KeyCode == Constants.KEYBOARD_RELOAD_KEY_CODE
				or inputObject.KeyCode == Constants.GAMEPAD_RELOAD_KEY_CODE
			then
				self:reload()
			elseif inputObject.KeyCode == Constants.KEYBOARD_TOGGLE_VIEW_KEY_CODE then
				self.viewModelController:toggleThirdPerson()
			end
		end)
	)
end

function BlasterController:destroy()
	self:unequip()
	disconnectAndClear(self.connections)
	self.viewModelController:destroy()
	self.touchInputController:destroy()
	self.characterAnimationController:destroy()
	self.guiController:destroy()
end

return BlasterController

