-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.Body.Brakes._main ; copies: 1 ; Adler-32: 4aa26aeb
grp1 = script.Parent.G1:GetChildren()
while true do
wait(0)
if script.Parent.on.Value == true then
	
	for i = 1,#grp1 do
	grp1[i].Braking.Enabled = true
	end
	
	for i = 1,#grp1 do
	grp1[i].Lights.Enabled = true
	end
else
	for i = 1,#grp1 do
	grp1[i].Braking.Enabled = false
	end
	for i = 1,#grp1 do
	grp1[i].Lights.Enabled = false
	end

end
end