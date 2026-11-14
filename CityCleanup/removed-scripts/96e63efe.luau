-- Removed by CityCleanup Task 2. Original path: Workspace.Bartenders.Barista.Animation ; copies: 23 ; Adler-32: 96e63efe
local animation = script:WaitForChild('Animation')
local humanoid = script.Parent:WaitForChild('NPC')
local idle = humanoid:LoadAnimation(animation)

idle:Play()
idle.Looped = true