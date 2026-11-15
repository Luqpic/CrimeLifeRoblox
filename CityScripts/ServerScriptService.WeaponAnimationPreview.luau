local RunService = game:GetService("RunService")
local folder = workspace:WaitForChild("WeaponAnimationPreview")
if not RunService:IsStudio() then folder:Destroy() return end
local Motion = require(game.ReplicatedStorage.Blaster.Scripts.WeaponViewmodelMotion)
local tools = {}
for _, tool in game.ServerStorage.Weapons:GetDescendants() do
 if tool:IsA("Tool") then tools[tool:GetAttribute("viewModel")] = tool end
end
local entries = {}
for _, model in folder:GetChildren() do
 local tool = tools[model.Name]
 if not tool then continue end
 local motion = Motion.new(model, tool)
 motion:equip()
 local root = model.PrimaryPart or model:FindFirstChild("Root", true)
 local joints = {}
 for _, joint in model:GetDescendants() do
  if joint:IsA("Motor6D") then table.insert(joints, joint) end
 end
 local prompt = root and root:FindFirstChild("TestWeapon")
 if prompt then
  prompt.Triggered:Connect(function(player)
   local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
   local backpack = player:FindFirstChildOfClass("Backpack")
   if not humanoid or not backpack then return end
   humanoid:UnequipTools()
   for _, old in backpack:GetChildren() do
    if old:GetAttribute("AnimationPreviewTool") then old:Destroy() end
   end
   local copy = tool:Clone()
   copy:SetAttribute("AnimationPreviewTool", true)
   copy.Parent = backpack
   humanoid:EquipTool(copy)
  end)
 end
 table.insert(entries, {model=model, motion=motion, tool=tool, root=root, joints=joints, age=0, phase=-1})
end
local phases = {"Equip", "Idle", "Walk", "Sprint", "Aim", "Shoot", "Reload", "Recovery"}
RunService.Heartbeat:Connect(function(dt)
 for _, e in entries do
  e.age += dt
  local phase = math.floor(e.age / 4) % #phases
  local changed = phase ~= e.phase
  if changed then
   e.phase = phase
   e.motion:setAiming(phase == 4)
   if phase == 0 then e.motion:equip()
   elseif phase == 5 then e.motion:shoot("Shoot")
   elseif phase == 6 then e.motion:reload(e.tool:GetAttribute("reloadTime") or 2) end
   local label = e.root and e.root:FindFirstChild("PreviewLabel")
   if label then label.Status.Text = e.model.Name .. "\n" .. phases[phase + 1] end
  end
  if phase == 5 and not changed and math.floor(e.age * 2) ~= math.floor((e.age-dt)*2) then
   e.motion:shoot(({"Shoot", "Shoot2", "Shoot3"})[math.floor(e.age*2)%3+1])
  end
  local offset = e.motion:step(dt, if phase == 2 then 12 elseif phase == 3 then 24 else 0, phase == 3)
  e.model:PivotTo(e.model:GetAttribute("PreviewOrigin") * offset)
  -- Anchored display rigs need explicit parent-to-child joint evaluation.
  local solved = {[e.root]=true}
  for _ = 1, #e.joints do
   for _, joint in e.joints do
    if joint.Part0 and joint.Part1 and solved[joint.Part0] then
     joint.Part1.CFrame = joint.Part0.CFrame * joint.C0 * joint.Transform * joint.C1:Inverse()
     solved[joint.Part1] = true
    end
   end
  end
 end
end)
