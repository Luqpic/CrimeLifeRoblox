--!nocheck
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Blaster.Constants)
local CameraAuthority = require(ReplicatedStorage.Modules.CameraAuthority)
local disconnectAndClear = require(ReplicatedStorage.Utility.disconnectAndClear)
local WeaponViewmodelMotion = require(script.Parent.WeaponViewmodelMotion)
local playSoundFromSource = require(script.Parent.Parent.Utility.playSoundFromSource)
local playRandomSoundFromSource = require(script.Parent.Parent.Utility.playRandomSoundFromSource)

local camera = Workspace.CurrentCamera
local player = Players.LocalPlayer
local viewModels = ReplicatedStorage.Blaster.ViewModels

-- Third person: fixed offset from the character's head (side, up, backward), rebuilt from scratch
-- every frame using only Classic camera's rotation. This gives a consistent zoom distance whenever
-- third person is toggled on, instead of inheriting whatever distance Classic's own zoom happened to
-- be left at (e.g. still zoomed in close from having just been in first person).
local THIRD_PERSON_OFFSET = CFrame.new(2.5, 1.5, 5)

-- Unequip camera reset: pulls the camera back to a clear, fixed third-person distance once no
-- weapon is equipped, then restores the normal free-zoom range. equippedCount is module-level (shared
-- by every Tool's ViewModelController, since they all require this same module) so that swapping
-- between weapons -- unequip old, equip new -- doesn't let the old tool's reset clobber the new tool's
-- camera setup: the reset only actually runs once the count confirms no weapon is equipped at all.
local UNEQUIPPED_ZOOM_DISTANCE = 10
local equippedCount = 0

local ViewModelController = {}
ViewModelController.__index = ViewModelController

-- Arm clothing: dresses the viewmodel's bare arms in a sleeve mesh textured with whatever shirt
-- the player is actually wearing, so first-person hands match the character's real outfit.
local ARM_NAMES = { "LeftArm", "RightArm" }
local R15_ARM_NAMES = {
	LeftArm = "LeftUpperArm",
	RightArm = "RightUpperArm",
}
local SLEEVE_MESH_ID = "rbxassetid://488154609"
local SLEEVE_MESH_SCALE = Vector3.new(0.006, 0.02, 0.006)

local function createSleeve(name: string, armPart: BasePart, character: Model, shirtTemplate: string?): BasePart
	local sleeve = Instance.new("Part")
	sleeve.Name = name
	sleeve.Size = armPart.Size
	sleeve.Anchored = false
	sleeve.CanCollide = false
	sleeve.CanQuery = false
	sleeve.CanTouch = false
	sleeve.Massless = true
	sleeve.CastShadow = false
	sleeve.Material = Enum.Material.SmoothPlastic

	-- Fall back to the character's real arm color (skin tone) when there's no shirt to texture with.
	local referencePart = character:FindFirstChild(R15_ARM_NAMES[armPart.Name] or armPart.Name)
	sleeve.Color = (referencePart and referencePart:IsA("BasePart")) and referencePart.Color or armPart.Color
	sleeve.CFrame = armPart.CFrame * CFrame.Angles(math.rad(90), 0, 0)
	sleeve.Parent = armPart.Parent

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.FileMesh
	mesh.MeshId = SLEEVE_MESH_ID
	mesh.Scale = SLEEVE_MESH_SCALE
	mesh.Parent = sleeve

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = armPart
	weld.Part1 = sleeve
	weld.Parent = armPart

	if shirtTemplate then
		local decal = Instance.new("Decal")
		decal.Name = "SleeveDecal"
		decal.Texture = shirtTemplate
		decal.Face = Enum.NormalId.Back
		decal.Parent = sleeve
	end

	return sleeve
end

local function applyArmsClothing(viewModel: Model)
	local character = Players.LocalPlayer.Character
	if not character then
		return
	end

	local shirt = character:FindFirstChildOfClass("Shirt")
	local shirtTemplate = shirt and shirt.ShirtTemplate

	for _, armName in ARM_NAMES do
		local armPart = viewModel:FindFirstChild(armName, true)
		if not armPart then
			continue
		end
		armPart.Transparency = 1
		createSleeve(armName .. "Sleeve", armPart, character, shirtTemplate)
	end
end

function ViewModelController.new(blaster: Tool)
	-- Despite the blaster streaming mode being set to Atomic, objects outside of workspace are not streamed.
	-- This means we need to WaitForChild, since the blaster will be parented to the player's Backpack initially.
	local handle = blaster:WaitForChild("Handle")
	local sounds = blaster:WaitForChild("Sounds")

	local viewModelName = blaster:GetAttribute(Constants.VIEW_MODEL_ATTRIBUTE)
	local viewModelTemplate = viewModels[viewModelName]

	local viewModel = viewModelTemplate:Clone()
	local muzzle = viewModel:FindFirstChild("MuzzleAttachment", true)
	assert(muzzle, `{viewModel} is missing MuzzleAttachment!`)

	applyArmsClothing(viewModel)

	-- The viewmodel is parented into Workspace to render, which puts the player's own first-person
	-- weapon geometry directly in the path of their own shots. A thin ray (every gun's rayRadius is
	-- 0.4-0.5) slips past it, but a fatter one does not: the crowbar's swings were being absorbed by
	-- its own viewmodel 2.83 studs from the camera, which is what made melee hits feel like they
	-- "needed a certain angle" -- only swings angled away from the viewmodel got through. The Tool's
	-- own parts are already tagged for exactly this reason; the viewmodel was simply missed.
	for _, descendant in viewModel:GetDescendants() do
		if descendant:IsA("BasePart") then
			CollectionService:AddTag(descendant, Constants.RAY_EXCLUDE_TAG)
		end
	end


	-- The viewModel needs to be parented to the DataModel in order to load animations, otherwise it will throw an error
	viewModel.Parent = ReplicatedStorage

	-- Melee trail. Resolved from both models because the viewmodel is hidden in third person and
	-- the Tool is hidden in first person -- same split the muzzle already uses below in update().
	local trail = viewModel:FindFirstChild("Trail", true)
	local toolTrail = blaster:FindFirstChild("Trail", true)

	-- Shipped asset references remain in the template for rollback; authored joint motion owns playback.
	local shootNames = {}
	for _, animation in viewModel.Animations:GetChildren() do
		if animation:IsA("Animation") and animation.Name:lower():find("shoot") then
			table.insert(shootNames, animation.Name)
		end
	end
	table.sort(shootNames)
	if #shootNames == 0 then table.insert(shootNames, "Shoot") end

	local self = {
		enabled = false,
		blaster = blaster,
		handle = handle,
		model = viewModel,
		muzzle = muzzle,
		shootNames = shootNames,
		toolInstances = {},
		connections = {},
		stride = 0,
		bobbing = 0,
		thirdPerson = false,
		trail = trail, -- nil for every weapon except the crowbar
		toolTrail = toolTrail,
		lastShootAnimation = nil,
		trailSequence = 0,
	}
	setmetatable(self, ViewModelController)
	self.motion = WeaponViewmodelMotion.new(viewModel, blaster, function(name)
		local sound = sounds:FindFirstChild(name)
		if sound and sound:IsA("Sound") then
			playSoundFromSource(sound, SoundService)
		elseif sound and sound:IsA("Folder") and #sound:GetChildren() > 0 then
			playRandomSoundFromSource(sound, SoundService)
		end
	end)

	return self
end

function ViewModelController:update(deltaTime: number)
	local player = game.Players.LocalPlayer
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or not character:FindFirstChild("Head") then
		return
	end

	local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.thirdPerson

	self.model.Parent = Workspace
	for _, part in self.model:GetDescendants() do
		if part:IsA("BasePart") or part:IsA("Decal") then
			part.LocalTransparencyModifier = if isFirstPerson then 0 else 1
		end
	end

	for _, instance in self.toolInstances do
		instance.LocalTransparencyModifier = if isFirstPerson then 1 else 0
	end

	if isFirstPerson then
		local viewmodelMuzzle = self.model:FindFirstChild("MuzzleAttachment", true)
		local toolMuzzle = self.blaster:FindFirstChild("MuzzleAttachment", false)
		if viewmodelMuzzle then
			self.muzzle = viewmodelMuzzle
		end
	else
		local toolMuzzle = self.blaster:FindFirstChild("MuzzleAttachment", true)
		local viewmodelMuzzle = self.model:FindFirstChild("MuzzleAttachment", false)
		if toolMuzzle then
			self.muzzle = toolMuzzle
		end
	end

	-- MouseBehavior is owned by CameraAuthority now (set once in enable()/disable()), not every frame.
	if not isFirstPerson then
		local head = character:FindFirstChild("Head")
		local headPosition = if head then head.Position else humanoidRootPart.Position
		camera.CFrame = CFrame.new(headPosition) * camera.CFrame.Rotation * THIRD_PERSON_OFFSET

		local cameraForward = camera.CFrame.LookVector
		local flatDirection = Vector3.new(cameraForward.X, 0, cameraForward.Z).Unit

		local newRotation = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + flatDirection)

		humanoidRootPart.CFrame = humanoidRootPart.CFrame:Lerp(newRotation, 0.2)
	end

	local moveSpeed = (humanoidRootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local motionOffset = self.motion:step(deltaTime, moveSpeed, humanoidRootPart:GetAttribute("IsSprinting") == true)
	self.model:PivotTo(camera.CFrame * Constants.VIEW_MODEL_OFFSET * motionOffset)
end

function ViewModelController:checkForToolInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Decal")) then
		return
	end

	local tool = instance:FindFirstAncestorOfClass("Tool")
	if not tool then
		return
	end

	table.insert(self.toolInstances, instance)
end

function ViewModelController:hideToolInstances()
	local character = self.blaster.Parent

	table.insert(
		self.connections,
		character.DescendantAdded:Connect(function(descendant: Instance)
			self:checkForToolInstance(descendant)
		end)
	)

	table.insert(
		self.connections,
		character.DescendantRemoving:Connect(function(descendant: Instance)
			local index = table.find(self.toolInstances, descendant)
			if index then
				table.remove(self.toolInstances, index)
			end
		end)
	)

	for _, descendant in character:GetDescendants() do
		self:checkForToolInstance(descendant)
	end
end

function ViewModelController:stopHidingToolInstances()
	table.clear(self.toolInstances)
	disconnectAndClear(self.connections)
end

function ViewModelController:getMuzzlePosition(): Vector3
	return self.muzzle.WorldPosition
end

function ViewModelController:playShootAnimation(): string?
	local isFirstPerson = player.CameraMode == Enum.CameraMode.LockFirstPerson or not self.thirdPerson

	local options = {}
	for _, name in self.shootNames do
		if #self.shootNames == 1 or name ~= self.lastShootAnimation then table.insert(options, name) end
	end
	local pickedName = options[math.random(1, #options)]
	self.lastShootAnimation = pickedName
	self.motion:shoot(pickedName)

	-- A melee weapon has no muzzle flash, so its MuzzleAttachment is deliberately empty. Indexing
	-- the emitters directly would throw here, and an error raised inside shoot()'s call chain leaves
	-- BlasterController's self.shooting flag set, permanently soft-locking the weapon.
	local flashEmitter = self.muzzle:FindFirstChild("FlashEmitter")
	if flashEmitter then
		flashEmitter:Emit(1)
	end

	if isFirstPerson then
		local circleEmitter = self.muzzle:FindFirstChild("CircleEmitter")
		if circleEmitter then
			circleEmitter:Emit(1)
		end
	end

	-- Whichever model the player is actually looking at owns the visible trail.
	local trail = if isFirstPerson then self.trail else self.toolTrail
	if trail then
		self.trailSequence += 1
		local sequence = self.trailSequence
		trail.Enabled = true
		-- Keep the unchanged third-person clip's original one-second trail.
		local trailDuration = if isFirstPerson then (self.blaster:GetAttribute(Constants.SWING_DELAY_ATTRIBUTE) or 0.2) + 0.18 else 1
		task.delay(trailDuration, function()
			if self.trailSequence == sequence and trail.Parent then trail.Enabled = false end
		end)
	end

	return pickedName
end

function ViewModelController:playReloadAnimation(reloadTime: number)
	self.motion:reload(reloadTime)
end

function ViewModelController:cancelReloadAnimation()
	self.motion:cancelReload()
end

function ViewModelController:setAiming(aiming: boolean)
	self.motion:setAiming(aiming)
end

function ViewModelController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	equippedCount += 1

	-- Always start a fresh equip in first person; players opt into third person with the toggle key.
	-- CameraMode has to be forced to LockFirstPerson here too, not just inferred from self.thirdPerson --
	-- otherwise the camera stays wherever Classic zoom last left it (e.g. still zoomed/shifted out from
	-- third person), while the viewmodel renders as if the camera were at the character's head -- the
	-- camera and the character's body end up visible at the same time.
	self.thirdPerson = false
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	CameraAuthority.MouseBehavior:Set("Blaster", Enum.MouseBehavior.LockCenter)

	RunService:BindToRenderStep(
		Constants.VIEW_MODEL_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 1,
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
	self.model.Parent = Workspace
	self:hideToolInstances()

	self.motion:equip()

	-- Explicit, marker-independent equip sound. See the loading loop for why this does not rely on
	-- the animation carrying a "Sound" marker. Plays even if the Equip animation itself failed to
	-- load, since the sound is not conditional on the track.
	local equipSounds = self.blaster:FindFirstChild("Sounds")
	local equipSound = equipSounds and equipSounds:FindFirstChild("Equip")
	if equipSound and equipSound:IsA("Sound") then
		playSoundFromSource(equipSound, self.handle)
	end
end

function ViewModelController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	equippedCount -= 1

	RunService:UnbindFromRenderStep(Constants.VIEW_MODEL_BIND_NAME)
	self.model.Parent = nil
	self:stopHidingToolInstances()

	-- Undo the Set("Blaster", ...) from enable() -- MouseBehavior falls back to whatever the next
	-- highest-priority source wants (e.g. ShiftLock) instead of unconditionally resetting to Default.
	CameraAuthority.MouseBehavior:Clear("Blaster")

	-- Undo the LockFirstPerson forced in enable() -- without a weapon equipped the camera should be
	-- free to orbit/zoom normally again.
	player.CameraMode = Enum.CameraMode.Classic

	-- Pull the camera back to a clear third-person distance so it's obvious no weapon is active.
	-- Deferred so a same-frame re-equip (swapping weapons) is reflected in equippedCount before this
	-- decides whether to actually run, instead of always firing on every single unequip.
	task.defer(function()
		if equippedCount > 0 then
			return
		end
		CameraAuthority.MinZoomDistance:Set("Blaster", UNEQUIPPED_ZOOM_DISTANCE)
		CameraAuthority.MaxZoomDistance:Set("Blaster", UNEQUIPPED_ZOOM_DISTANCE)
		task.wait()
		if equippedCount > 0 then
			return
		end
		CameraAuthority.MinZoomDistance:Clear("Blaster")
		CameraAuthority.MaxZoomDistance:Clear("Blaster")
	end)

	self.motion:reset()
	self.trailSequence += 1
	if self.trail then self.trail.Enabled = false end
	if self.toolTrail then self.toolTrail.Enabled = false end
end

function ViewModelController:toggleThirdPerson()
	if not self.enabled then
		return
	end
	self.thirdPerson = not self.thirdPerson
	player.CameraMode = if self.thirdPerson then Enum.CameraMode.Classic else Enum.CameraMode.LockFirstPerson
end

function ViewModelController:destroy()
	disconnectAndClear(self.connections)
	self:disable()
	self.motion:destroy()
	self.model:Destroy()
end

return ViewModelController
