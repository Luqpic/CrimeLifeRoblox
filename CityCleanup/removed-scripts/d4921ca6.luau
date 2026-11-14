-- Removed by CityCleanup Task 2. Original path: Workspace.x6m.Body.Seat.Player Positioner.L ; copies: 4 ; Adler-32: d4921ca6
script:WaitForChild("Seat")
local C=game.Players.LocalPlayer.Character
local S=script.Seat.Value
local A=C.Animate
local WS={}
local HW={}

local Idle={
CFrame.new(-1.90734863e-005, 0.862603664, 0.219264984, 0.999999881, -0.000311874377, 1.54431982e-005, 0.000311874523, 0.99999994, 2.98705913e-008, -1.54408608e-005, 3.45511495e-008, 1), --Torso
CFrame.new(0.000118255615, 1.5005424, 0, 1, 0, 0, 0, 1, 2.33724151e-012, 0, 2.33724151e-012, 1), --Head
CFrame.new(-1.0352478, 0.489854336, -1.00377846, 0.938584805, -0.0783924535, -0.336024374, -0.34022674, -0.0480434, -0.939115047, 0.0574759319, 0.995763958, -0.0717641339), --Larm
CFrame.new(1.03522873, 0.489875317, -1.00376892, 0.938586116, 0.0783698261, 0.33602649, 0.340227544, -0.048043333, -0.939114749, -0.0574545339, 0.995765924, -0.0717563108), --Rarm
CFrame.new(-0.499889374, -1.30657601, -1.17677879, 1, 5.44342256e-005, 2.01785588e-006, -7.46516162e-006, 0.173648208, -0.98480773, -5.39576431e-005, 0.98480773, 0.173648193), --Lleg
CFrame.new(0.500106812, -1.30656874, -1.1767807, 1, 5.43468086e-005, 2.10525468e-006, -7.36393849e-006, 0.173648208, -0.98480773, -5.38867316e-005, 0.98480773, 0.173648193) --Rleg
}

local LeanIn={
CFrame.new(-1.90734863e-005, 0.862603664, 0.219264984, 0.999999881, -0.000311874377, 1.54431982e-005, 0.000311874523, 0.99999994, 2.98705913e-008, -1.54408608e-005, 3.45511495e-008, 1), --Torso
CFrame.new(0.000118255615, 1.5005424, 0, 1, 0, 0, 0, 1, 2.33724151e-012, 0, 2.33724151e-012, 1), --Head
CFrame.new(-1.0352478, 0.489854336, -1.00377846, 0.938584805, -0.0783924535, -0.336024374, -0.34022674, -0.0480434, -0.939115047, 0.0574759319, 0.995763958, -0.0717641339), --Larm
CFrame.new(1.03522873, 0.489875317, -1.00376892, 0.938586116, 0.0783698261, 0.33602649, 0.340227544, -0.048043333, -0.939114749, -0.0574545339, 0.995765924, -0.0717563108), --Rarm
CFrame.new(-0.499889374, -1.30657601, -1.17677879, 1, 5.44342256e-005, 2.01785588e-006, -7.46516162e-006, 0.173648208, -0.98480773, -5.39576431e-005, 0.98480773, 0.173648193), --Lleg
CFrame.new(0.500106812, -1.30656874, -1.1767807, 1, 5.43468086e-005, 2.10525468e-006, -7.36393849e-006, 0.173648208, -0.98480773, -5.38867316e-005, 0.98480773, 0.173648193) --Rleg
}

local LeanRight={
CFrame.new(-1.90734863e-005, 0.862603664, 0.219264984, 0.999999881, -0.000311874377, 1.54431982e-005, 0.000311874523, 0.99999994, 2.98705913e-008, -1.54408608e-005, 3.45511495e-008, 1), --Torso
CFrame.new(0.000117301941, 1.5005424, 0, 0.965925813, -2.66998541e-007, -0.258819014, 2.86119757e-007, 1, 3.6219717e-008, 0.258819044, -1.09043057e-007, 0.965925813), --Head
CFrame.new(-0.900835991, 0.86550045, -0.975072861, 0.819633782, -0.078392081, -0.567498267, -0.571694672, -0.048043523, -0.819058299, 0.0369431898, 0.995763958, -0.0841945857), --Larm
CFrame.new(1.05155945, 0.290840626, -1.01465607, 0.993574679, 0.0783692971, 0.081652686, 0.0855737776, -0.0480434783, -0.995172501, -0.0740681738, 0.995765984, -0.0544410571), --Rarm
CFrame.new(-0.499887466, -1.30657613, -1.17677879, 1, 5.44342256e-005, 2.01785588e-006, -7.46516162e-006, 0.173648208, -0.98480773, -5.39576431e-005, 0.98480773, 0.173648193), --Lleg
CFrame.new(0.500106812, -1.30656886, -1.1767807, 1, 5.43468086e-005, 2.10525468e-006, -7.36393849e-006, 0.173648208, -0.98480773, -5.38867316e-005, 0.98480773, 0.173648193) --Rleg
}

local LeanLeft={
CFrame.new(-1.90734863e-005, 0.862603664, 0.219264984, 0.999999881, -0.000311874377, 1.54431982e-005, 0.000311874523, 0.99999994, 2.98705913e-008, -1.54408608e-005, 3.45511495e-008, 1), --Torso
CFrame.new(0.000117301941, 1.5005424, 0, 0.965925753, 1.58441253e-007, 0.258818984, -1.58470357e-007, 1, -2.08601705e-008, -0.258819044, -2.08549782e-008, 0.965925813), --Head
CFrame.new(-1.03530788, 0.289854288, -1.00377846, 0.980850458, -0.0783925354, 0.178286746, 0.174912497, -0.048043292, -0.983410835, 0.0856577381, 0.995763958, -0.0334114693), --Larm
CFrame.new(0.859836578, 0.836935997, -0.973220825, 0.819634497, 0.0783697814, 0.567500591, 0.571695328, -0.0480433665, -0.819057822, -0.0369248614, 0.995765924, -0.0841816142), --Rarm
CFrame.new(-0.499887466, -1.30657613, -1.17677879, 1, 5.44342256e-005, 2.01785588e-006, -7.46516162e-006, 0.173648208, -0.98480773, -5.39576431e-005, 0.98480773, 0.173648193), --Lleg
CFrame.new(0.500106812, -1.30656886, -1.1767807, 1, 5.43468086e-005, 2.10525468e-006, -7.36393849e-006, 0.173648208, -0.98480773, -5.38867316e-005, 0.98480773, 0.173648193) --Rleg
}


S.ChildRemoved:connect(function(child) if child.Name=="SeatWeld" then for i,v in pairs(WS) do if v~=0 then if v[4]~=nil then v[4]:Destroy() v[1].Part1=v[5] else if v[2]~=nil then v[1].C0=v[2] v[1].C1=v[3] else v[1]:Destroy() end end end end for i,v in pairs(HW) do v[1]:Destroy() v[2]:Destroy() v[3].Transparency=0 end A.Parent=C A.Disabled=false script:Destroy() end end)
function MW(x,y)
	local WW=Instance.new("Weld",x) WW.Part0=x WW.Part1=y return WW
end


if C:FindFirstChild("HumanoidRootPart")~=nil and C:FindFirstChild("Torso")~=nil then
	A.Disabled=true
	A.Parent=script
	S.SeatWeld.C0=CFrame.new()
	S.SeatWeld.C1=CFrame.new()
	C.HumanoidRootPart.RootJoint.Part1=nil
	table.insert(WS,{C.HumanoidRootPart.RootJoint,C.HumanoidRootPart.RootJoint.C0,C.HumanoidRootPart.RootJoint.C1,MW(C.HumanoidRootPart,C.Torso),C.Torso})
	if C.Torso:FindFirstChild("Neck")~=nil then
		local H=C.Head:Clone()
		H.Parent=S.Parent
		local WH=MW(C.Torso,H)
		WH.C0=C.Torso.Neck.C0
		WH.C1=C.Torso.Neck.C0
		C.Head.Transparency=1
		table.insert(HW,{H,WH,C.Head})
		table.insert(WS,{WH,nil,nil,nil,nil})
		for i,v in pairs(C.Head:GetChildren()) do
			if v:IsA("Weld") then
				local pp=v.Part1:Clone()
				pp.Parent=S.Parent
				v.Part1.Transparency=1
				local ww=MW(H,pp)
				ww.C0=v.C0
				ww.C1=v.C1
				table.insert(HW,{pp,ww,v.Part1})
			end
		end	
	else
		table.insert(WS,0)
	end
	if C.Torso:FindFirstChild("Left Shoulder")~=nil then
		C.Torso:FindFirstChild("Left Shoulder").Part1=nil
		table.insert(WS,{C.Torso:FindFirstChild("Left Shoulder"),C.Torso:FindFirstChild("Left Shoulder").C0,C.Torso:FindFirstChild("Left Shoulder").C1,MW(C.Torso,C:FindFirstChild("Left Arm")),C:FindFirstChild("Left Arm")})
	else
		table.insert(WS,0)
	end
	if C.Torso:FindFirstChild("Right Shoulder")~=nil then
		C.Torso:FindFirstChild("Right Shoulder").Part1=nil
		table.insert(WS,{C.Torso:FindFirstChild("Right Shoulder"),C.Torso:FindFirstChild("Right Shoulder").C0,C.Torso:FindFirstChild("Right Shoulder").C1,MW(C.Torso,C:FindFirstChild("Right Arm")),C:FindFirstChild("Right Arm")})
	else
		table.insert(WS,0)
	end
	if C.Torso:FindFirstChild("Left Hip")~=nil then
		C.Torso:FindFirstChild("Left Hip").Part1=nil
		table.insert(WS,{C.Torso:FindFirstChild("Left Hip"),C.Torso:FindFirstChild("Left Hip").C0,C.Torso:FindFirstChild("Left Hip").C1,MW(C.Torso,C:FindFirstChild("Left Leg")),C:FindFirstChild("Left Leg")})
	else
		table.insert(WS,0)
	end
	if C.Torso:FindFirstChild("Right Hip")~=nil then
		C.Torso:FindFirstChild("Right Hip").Part1=nil
		table.insert(WS,{C.Torso:FindFirstChild("Right Hip"),C.Torso:FindFirstChild("Right Hip").C0,C.Torso:FindFirstChild("Right Hip").C1,MW(C.Torso,C:FindFirstChild("Right Leg")),C:FindFirstChild("Right Leg")})
	else
		table.insert(WS,0)
	end
end

for i,v in pairs(WS) do
	if v[4]~=nil then
		v[4].C0=LeanIn[i]
		v[4].C1=CFrame.new()
	else
		v[1].C0=LeanIn[i]
		v[1].C1=CFrame.new()
	end
end

function getC(w,c)
	local ax,ay,az,ar00,ar01,ar02,ar10,ar11,ar12,ar20,ar21,ar22=CFrame.new().components(w.C0)
	local bx,by,bz,br00,br01,br02,br10,ar11,br12,br20,br21,br22=CFrame.new().components(c)
	local ca={ax,ay,az,ar00,ar01,ar02,ar10,ar11,ar12,ar20,ar21,ar22}
	local cb={bx,by,bz,br00,br01,br02,br10,ar11,br12,br20,br21,br22}
	local cd={}
	for i,v in pairs(ca) do
		table.insert(cd,(cb[i]-v)/10)
	end
	return cd
end
function tween(w,cd)
	local cx,cy,cz,cr00,cr01,cr02,cr10,cr11,cr12,cr20,cr21,cr22=CFrame.new().components(w.C0)
	local cc={cx,cy,cz,cr00,cr01,cr02,cr10,cr11,cr12,cr20,cr21,cr22}
	local ce={}
	for i,v in pairs(cc) do
		table.insert(ce,v+cd[i])
	end
	w.C0=CFrame.new(ce[1],ce[2],ce[3],ce[4],ce[5],ce[6],ce[7],ce[8],ce[9],ce[10],ce[11],ce[12])
end
function setPose(p)
	for i,v in pairs(WS) do
		if v[4]~=nil then
			tween(v[4],p[i])
		else
			tween(v[1],p[i])
		end
	end
end
function getPose(p)
	local ps={}
	for i,v in pairs(WS) do
		if v[4]~=nil then
			table.insert(ps,getC(v[4],p[i]))
		else
			table.insert(ps,getC(v[1],p[i]))
		end
	end
	return(ps)
end

local steer=S.Steer
local frame=0
pose=getPose(LeanIn)
while wait() do
		if (S.Steer~=steer or idling==true) then
			steer=S.Steer
			frame=0
			if steer==0 then
				pose=getPose(LeanIn)
			elseif steer==1 then
				pose=getPose(LeanRight)
			else
				pose=getPose(LeanLeft)
			end
			idling=false
		end
	if frame<10 then
		frame=frame+1
		setPose(pose)
	end
end