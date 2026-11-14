-- Removed by CityCleanup Task 2. Original path: Workspace.Stainless Scraps.Decoration.Stainless Scrap Producer.Worker.Animation ; copies: 13 ; Adler-32: 0c304152
local animation = script:WaitForChild('Animation')
local humanoid = script.Parent:WaitForChild('Humanoid')
local idle = humanoid:LoadAnimation(animation)

idle:Play()
idle.Looped = true