-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.DriveSeat.Speedometer V3 ; copies: 1 ; Adler-32: e093ea22
s = script
---------------------------------------------------------------
function onChildAdded(something)
	if something.Name == "SeatWeld" then
		local human = something.part1.Parent:findFirstChild("Humanoid") 
		if (human ~= nil) then
			s.speedo:clone().Parent = game.Players:findFirstChild(human.Parent.Name).PlayerGui
		end
	end
end

function onChildRemoved(something)
	if (something.Name == "SeatWeld") then	
		local human = something.part1.Parent:findFirstChild("Humanoid") 
		if (human ~= nil) then
			print("Human Found")
			game.Players:findFirstChild(human.Parent.Name).PlayerGui.speedo:remove()
		end
	end
end


script.Parent.ChildAdded:connect(onChildAdded)
script.Parent.ChildRemoved:connect(onChildRemoved)