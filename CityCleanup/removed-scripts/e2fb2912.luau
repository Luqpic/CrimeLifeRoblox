-- Removed by CityCleanup Task 2. Original path: Workspace.Model.0.2FlashAlarm.Flash.Script ; copies: 29 ; Adler-32: e2fb2912

local light = script.Parent.PointLight

while true do
	wait (0.2) 
	light.Enabled = true
	wait (0.2) 
	light.Enabled = false

end