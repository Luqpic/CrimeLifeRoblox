-- Removed by CityCleanup Task 2. Original path: Workspace.Model.Part.Script ; copies: 1 ; Adler-32: f77557d8
--- This will cause a brick to go in motion unanchored or not! ---

while true do
wait()
for i= 1, 40 do
script.Parent.CFrame = script.Parent.CFrame * CFrame.new(0,-0.3,0)
wait()
end
for i= 1, 40 do
script.Parent.CFrame = script.Parent.CFrame * CFrame.new(0,0.3,0)
wait()
end
end