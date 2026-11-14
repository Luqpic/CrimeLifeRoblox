-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.A-Chassis Tune.Plugins.FirstPerson ; copies: 1 ; Adler-32: 111915ad
local FIRST_PERSON_BTN = Enum.KeyCode.BackSlash

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local car = script.Parent.Car.Value
local plr = game:GetService("Players").LocalPlayer
local camera = workspace.CurrentCamera
local camPart = car.Body.CamLocation
local transTable = {} -- Stores the original transparency of the character. (Certain hats use transparency)
local oldFOV = camera.FieldOfView

local enabled = false
local debounce = false

local maxAngle = 90

function handleInput(inputObject, gameProcessedEvent)
	if not gameProcessedEvent and inputObject.KeyCode == FIRST_PERSON_BTN and not debounce then
		debounce = true
		enabled  = not enabled
		
		if enabled then enableCam() else disableCam() end
		
		debounce = false
	end
end

function enableCam()
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("FirstPerson",Enum.RenderPriority.Camera.Value,updateCam)
	
	plr.Character.Humanoid:UnequipTools() -- We do this so we don't accidentally make something invisible.
	
	-- Make a player's character invisible locally so we don't have anything in our way.
	for _,i in ipairs(plr.Character:GetDescendants()) do
		if i:IsA("BasePart") then
			transTable[i] = i.Transparency
			i.LocalTransparencyModifier = 1
		end
	end
	
	camera.FieldOfView = 60
end

function disableCam()
	print("Camera disabled.")
	RunService:UnbindFromRenderStep("FirstPerson")
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = oldFOV
	
	-- Make them visible again.
	for _,i in ipairs(plr.Character:GetDescendants()) do
		if transTable[i] ~= nil then
			i.LocalTransparencyModifier = transTable[i]
		end
	end
end

function updateCam()
	local head = camPart
	local screenSize = camera.ViewportSize
	local mousePos = UserInputService:GetMouseLocation() 
	local actualPos = screenSize/2 - mousePos
	local camPos = head.CFrame
	local rot = CFrame.Angles(0, math.rad(maxAngle * actualPos.X / (screenSize.X/2)), 0)
	
	local camPos = camPos * rot
	
	camera.CFrame = camPos
end

for _,i in ipairs(plr.Character:GetDescendants()) do
	if i:IsA("BasePart") then
		transTable[i] = i.Transparency
	end
end

car.DriveSeat.ChildRemoved:connect(function(obj) if obj.Name == "SeatWeld" then disableCam() end end)
UserInputService.InputBegan:Connect(handleInput)