-- Re-runnable Edit build (2026-11-20): the instances the shoulder camera needs besides its scripts.
--   ReplicatedStorage.Blaster.Remotes.AimPitch (RemoteEvent, reliable since the Task 2 review: the closing 0 must arrive):
--   ShoulderCamera -> ServerScriptService.Blaster.Scripts.AimPitch
--   TouchInputController.BlasterTouchGui.Buttons.ViewButton / SwapButton: the phone's VIEW and SWAP buttons, styled
--   like ReloadButton (black at 0.5, round), 64 x 64, labelled in Montserrat Heavy. VIEW sits up-left of Reload, SWAP above
--   VIEW; centres (56, 0) and (56, -80) in the 280 x 290 Buttons frame keep 16 px clear of Shoot and 30 px of Reload.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage.Blaster.Remotes
local old = remotes:FindFirstChild("AimPitch")
if old and not old:IsA("RemoteEvent") then
	old:Destroy()
end
if not remotes:FindFirstChild("AimPitch") then
	local remote = Instance.new("RemoteEvent")
	remote.Name = "AimPitch"
	remote.Parent = remotes
end

local buttons = ReplicatedStorage.Blaster.Scripts.TouchInputController.BlasterTouchGui.Buttons
local template = buttons.ReloadButton
local function build(name: string, text: string, y: number)
	local old = buttons:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local button = template:Clone()
	button.Name = name
	button.Size = UDim2.fromOffset(64, 64)
	button.Position = UDim2.new(0.2, 0, 0, y)
	local icon = button:FindFirstChild("IconLabel")
	if icon then
		icon:Destroy()
	end
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0.25
	label.TextSize = 14
	label.Parent = button
	button.Parent = buttons
	return button
end
build("ViewButton", "VIEW", 0)
build("SwapButton", "SWAP", -80)
return "built"
