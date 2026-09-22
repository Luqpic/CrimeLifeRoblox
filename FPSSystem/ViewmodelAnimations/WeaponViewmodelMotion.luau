-- Authored first-person joint poses. Times are normalized to the existing gameplay durations.
-- No animation upload or per-frame Instances; all changes apply to the client's cloned rig.
local Motion = {}
Motion.__index = Motion
local I = CFrame.identity
local function pose(x,y,z,pitch,yaw,roll)
	return CFrame.new(x,y,z) * CFrame.Angles(math.rad(pitch or 0),math.rad(yaw or 0),math.rad(roll or 0))
end
-- Linear keyframe interpolation, matching Enum.PoseEasingStyle.Linear in the Animation Editor.
-- Was smoothstep t*t*(3-2*t); kept as a named hook so an easing swap stays one edit.
local function ease(t) return t end
local function sample(keys,t,smoothMotion)
	if t <= keys[1][1] then return keys[1][2] end
	for i=2,#keys do
		local a,b=keys[i-1],keys[i]
		if t <= b[1] then
			local alpha=(t-a[1])/(b[1]-a[1])
			alpha=if smoothMotion then alpha*alpha*(3-2*alpha) else ease(alpha)
			return a[2]:Lerp(b[2],alpha)
		end
	end
	return keys[#keys][2]
end
-- The two original idle clips' first poses, baked so equip never waits for an asset download.
local rifleRight=CFrame.new(-.499999,.017364,-.098480,.984808,0,.173648,.030154,.984808,-.171010,-.171010,.173648,.969846)
local rifleLeft=CFrame.new(.346411,.307476,.324749,.866028,0,-.499996,-.171005,.939698,-.296192,.469843,.342012,.813803)
local pistolRight=CFrame.new(-.480284,-.002977,-.131788,.980888,.022704,.193245,0,.993169,-.116688,-.194574,.114458,.974187)
local pistolLeft=CFrame.new(.460241,-.178339,-.076939,.822718,-.160241,-.545397,0,.959445,-.281892,.568450,.231918,.789353)

-- Every shipped viewmodel is classified explicitly (shop categories are not mechanical types).
local profiles = {
	["AK47"]={"rock",1.00,.42}, ["AKM"]={"rock",1.18,.46},
	["AMB-17"]={"rock",.78,.38}, ["APS"]={"pistol",.68,.30},
	["AR-18"]={"rifle",.90,.40}, ["AUG A-3"]={"bullpup",.90,.44},
	["Baton"]={"melee",.78,.32}, ["Benelli M4"]={"shell",1.30,.43},
	["Crowbar"]={"melee",1.00,.42}, ["Deagle"]={"pistol",1.38,.38},
	-- Knife: the Crowbar's melee profile verbatim, so it carries and swings identically. The two
	-- numbers are carry length and grip; the blade is shorter than a crowbar, so they may want
	-- bringing in once someone has looked at it.
	["Knife"]={"melee",1.00,.42},
	["FN P90"]={"top",.62,.37}, ["Glock 17"]={"pistol",.78,.30},
	["HCAR"]={"rifle",1.42,.55}, ["HK G3"]={"rifle",1.30,.48},
	["Itacha Mag-10"]={"shell",1.65,.55}, ["Kriss Vector"]={"rifle",.56,.34},
	["M14 EBR"]={"rock",1.35,.48}, ["M16A1"]={"rifle",.86,.40},
	["M1911"]={"pistol",1.12,.34}, ["MP443"]={"pistol",.82,.32},
	["MP9"]={"rifle",.52,.30}, ["Mateba 2006M"]={"revolver",1.55,.42},
	["Mossberg 590"]={"pump",1.50,.48}, ["PB"]={"pistol",.58,.32},
	["S&W 29"]={"revolver",1.65,.46}, ["Scar L"]={"rifle",.98,.42},
	["Sig MPX"]={"rifle",.60,.34}, ["Spas 12"]={"pump",1.55,.50},
}

-- Approved showcase pass: deliberately different silhouettes and action phrasing.
-- Carry is a persistent joint pose, blended out for ADS; action keys are relative to carry.
local showcase = {
	["Glock 17"]={carry=pose(-.40,.18,-.42,0,-3,-5),omega=25,kick={.045,.22,14,-1,-2},
		grips={RightArm=Vector3.new(.23,.18,-.43),LeftArm=Vector3.new(-.08,.12,-.47)},
		reload={
			Body={{0,I},{.16,pose(-.05,.65,-.18,12,40,-20)},{.70,pose(-.05,.65,-.18,12,40,-20)},
				{.82,pose(-.08,.40,-.12,8,22,-12)},{1,I}},
			Magazine={{0,I},{.16,I},{.32,pose(-.06,-.95,.12,8,0,-8)},
				{.48,pose(-.06,-.95,.12,8,0,-8)},{.60,pose(0,-.22,.04,0,0,0)},{.66,I},{1,I}},
			LeftArm={{0,I},{.14,pose(-.04,-.08,.04,0,0,-4)},{.32,pose(-.12,-.14,.10,8,-8,-12)},
				{.50,pose(-.12,-.14,.10,8,-8,-12)},{.66,I},
				{.76,pose(-.16,.35,-.24,-12,10,-15)},{.84,pose(-.16,.35,.02,-8,10,-10)},{1,I}},
		},markers={{.20,"MagOut"},{.66,"MagIn"},{.84,"Charger"}}},
	["AK47"]={carry=pose(-.22,.04,-.65,-2,1,-2),omega=28,kick={.01,.24,3.8,-.45,-.6},
		grips={RightArm=Vector3.new(.28,-.20,.75),LeftArm=Vector3.new(-.03,-.10,-1.48)},
		reload={
			Body={{0,I},{.16,pose(-.55,.62,-.9,5,25,-12)},
				{.74,pose(-.55,.62,-.9,5,25,-12)},{.88,pose(-.20,.25,-.3,3,10,-6)},{1,I}},
			Magazine={{0,I},{.16,pose(0,0,.08,18,0,0)},{.32,pose(-.10,-1.05,.32,28,0,-10)},
				{.45,pose(-.10,-1.05,.32,28,0,-10)},{.58,pose(0,-.25,.19,24,0,0)},
				{.67,I},{1,I}},
			LeftArm={{0,I},{.16,pose(.28,-.60,.65,0,0,-6)},
				{.40,pose(.28,-.60,.65,6,-6,-8)},{.67,pose(.28,-.60,.65,0,0,0)},
				{.76,pose(.34,.55,.70,-10,-18,14)},{.84,pose(.34,.55,1.04,-8,-18,14)},
				{.91,pose(.16,.20,.08,0,-8,6)},{1,I}},
			ChargingHandle={{0,I},{.76,I},{.84,pose(0,0,.34,0,0,0)},{.89,I},{1,I}},
		},markers={{.22,"MagOut"},{.67,"MagIn"},{.84,"Charger"}}},
	["Mossberg 590"]={carry=pose(-.30,.14,-.38,0,-2,-5),omega=18,kick={.04,.34,8.5,-.3,-1.2},
		grips={RightArm=Vector3.new(.18,-.20,.95),LeftArm=Vector3.new(-.03,-.32,-2.05)},
		reload={
			Body={{0,I},{.18,pose(.15,.70,-.60,5,35,15)},
				{.78,pose(.15,.70,-.60,5,35,15)},{1,I}},
			LeftArm={{0,I},{.23,pose(-.32,-.62,.48,10,-15,-18)},
				{.42,pose(-.26,-.38,.55,6,-12,-14)},{.64,pose(-.08,.12,.50,-8,8,-6)},
				{.76,pose(.02,.18,.38,-10,5,-3)},{1,I}},
		},markers={{.72,"MagIn"}}},
}

local function reloadTracks(kind)
	local pistol=kind=="pistol"
	local shell=kind=="shell" or kind=="pump"
	local revolver=kind=="revolver"
	local roll=if shell then -18 elseif revolver then -32 elseif pistol then -20 else -14
	local hold=pose(-.12,.08,.12,if shell then 9 else 13,-8,roll)
	local body={{0,I},{.14,hold},{.76,hold},{.9,pose(0,.015,-.035,-3,1,2)},{1,I}}
	if shell then
		return {
			Body={{0,I},{.18,hold},{.73,hold},{1,I}},
			LeftArm={{0,I},{.23,pose(-.32,-.55,.22,18,-20,-20)},
				{.48,pose(-.12,-.20,.10,-12,8,-10)},{.68,pose(.04,.06,-.15,-16,6,-4)},{1,I}},
		},{{.62,"MagIn"}}
	end
	if revolver then
		-- The imported revolvers have no separate cylinder joint. Keep their grip mesh attached;
		-- bring the supporting hand to the breech, eject, load and close with a wrist return.
		return {
			Body=body,
			LeftArm={{0,I},{.16,pose(-.18,.18,-.18,-14,-18,-18)},
				{.28,pose(-.38,.26,-.24,-26,-28,-22)},{.40,pose(-.48,-.52,.12,24,-15,-30)},
				{.58,pose(-.22,.22,-.10,-18,12,-10)},{.70,pose(-.08,.13,-.24,-8,8,-4)},
				{.82,pose(-.03,.04,-.06,0,0,8)},{1,I}},
			RightArm={{0,I},{.2,pose(0,0,0,0,0,6)},{.76,pose(0,0,0,0,0,6)},{1,I}},
		},{{.26,"MagOut"},{.64,"MagIn"}}
	end
	local out=if kind=="top" then pose(-.12,.62,.10,0,0,-12)
		elseif kind=="bullpup" then pose(-.06,-.7,.18,8,0,-8)
		elseif kind=="rock" then pose(-.08,-.78,.28,24,0,-8)
		else pose(-.08,if pistol then -.7 else -.95,.10,8,0,-8)
	local insert=if kind=="top" then pose(-.06,.34,.04,0,0,-4)
		elseif kind=="rock" then pose(0,-.24,.16,18,0,0)
		else pose(0,-.24,.02,0,0,0)
	return {
		Body=body,
		Magazine={{0,I},{.16,I},{.32,out},{.48,out},{.61,insert},{.69,I},{1,I}},
		LeftArm={{0,I},{.14,pose(-.06,-.05,.02,0,0,-6)},{.40,pose(-.13,-.12,.05,8,-8,-10)},
			{.64,I},{.76,pose(-.1,.12,-.16,-10,12,-12)},{.87,pose(-.08,.05,.08,4,4,-4)},{1,I}},
		ChargingHandle={{0,I},{.74,I},{.82,pose(0,0,.22,0,0,0)},{.88,I},{1,I}},
	},{{.20,"MagOut"},{.67,"MagIn"},{.82,"Charger"}}
end

local drawPoses = {
	pistol=pose(.12,-.55,.22,-24,8,18),
	revolver=pose(.18,-.62,.28,-28,12,24),
	rifle=pose(.18,-.58,.38,-16,20,26),
	rock=pose(.20,-.60,.40,-18,18,30),
	bullpup=pose(.12,-.44,.24,-12,24,18),
	top=pose(.10,-.42,.24,-10,14,16),
	shell=pose(.20,-.65,.40,-20,12,22),
	pump=pose(.20,-.65,.40,-20,12,22),
	melee=pose(.35,-.55,.20,-35,-20,42),
}

local swingEnds={
	Shoot=pose(-.06,-.12,-.43,-58,5,12),
	Shoot2=pose(-.32,.02,-.34,-26,-42,28),
	Shoot3=pose(.16,-.06,-.39,-32,34,-24),
}
local swingWindups={
	Shoot=pose(.10,.12,.12,24,-6,-12),
	Shoot2=pose(.14,.04,.10,12,26,-20),
	Shoot3=pose(-.12,.06,.14,16,-22,16),
}

function Motion.new(model,tool,emit)
	local name=tool:GetAttribute("viewModel") or model.Name
	local profile=profiles[name]
	assert(profile,"No viewmodel animation profile: "..name)
	local authored=showcase[name]
	local batonGrip=if name=="Baton" then Vector3.new(.14142,-.79,-1.40245)
		elseif name=="Knife" then Vector3.new(.18342,-.50,-1.10746) else nil
	if not authored and profile[1]~="melee" then
		local kind=profile[1]
		local family=if kind=="pistol" or kind=="revolver" then showcase["Glock 17"]
			elseif kind=="shell" or kind=="pump" then showcase["Mossberg 590"] else showcase.AK47
		local tracks,markers=reloadTracks(kind)
		if kind=="pistol" or kind=="shell" or kind=="pump" then
			tracks,markers=family.reload,family.markers
		elseif kind~="revolver" then
			-- Keep each magazine's extraction direction and rig-specific hand path.
			tracks.Body=family.reload.Body
		end
		-- Other meshes retain their own corrected arm rests, not the showcase grip coordinates.
		authored={carry=family.carry,omega=family.omega,kick=family.kick,grips={},reload=tracks,markers=markers}
	end
	local joints={}
	local pivot=model:GetPivot()
	local animations=model:FindFirstChild("Animations")
	local idle=animations and animations:FindFirstChild("Idle")
	local rifle=idle and idle.AnimationId=="rbxassetid://17649922695"
	for _,joint in model:GetDescendants() do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local part=joint.Part1.Name
			local rest=I
			if part=="RightArm" then rest=if rifle then rifleRight else pistolRight
			elseif part=="LeftArm" and joint.Part0.Name=="Magazine" then rest=if rifle then rifleLeft else pistolLeft end
			local base=joint.C0*rest
			local hand=authored and authored.grips[part]
			if batonGrip and part=="RightArm" then hand=batonGrip end
			if name=="Knife" and part=="LeftArm" then hand=Vector3.new(-.10,-.57,-1.03) end
			if hand then
				-- Place the front end of each whole-arm rig at its authored grip, with
				-- the forearm extending back toward the corresponding shoulder.
				local shoulder=hand+Vector3.new(if part=="RightArm" then .45 else -.8,-.65,3.8)
				local arm=CFrame.lookAt(hand,hand+(hand-shoulder))*CFrame.new(0,0,joint.Part1.Size.Z/2)
				base=joint.Part0.CFrame:ToObjectSpace(pivot*arm)*joint.C1
			end
			joints[part]={joint=joint,original=joint.C0,transform=joint.Transform,
				base=base,basis=pivot:ToObjectSpace(joint.Part0.CFrame).Rotation}
		end
	end
	-- The two shipped idle clips are generic and were never authored against these weapon meshes, so
	-- the hand they place can rest up to ~1.1 studs off the weapon's centre plane. The error flips
	-- sign between rifles and shotguns, so no single baked rest constant fixes it. Walk the joint
	-- chain to find where each hand actually lands in weapon space and cancel only its off-plane
	-- drift; the clip's along-weapon and vertical placement is left alone.
	local function frameInBody(name)
		local acc,guard=I,0
		while name~="Body" and guard<8 do
			local d=joints[name]
			if not d then return nil end
			acc=d.base*d.joint.C1:Inverse()*acc
			name=d.joint.Part0.Name
			guard+=1
		end
		return if name=="Body" then acc else nil
	end
	for _,armName in {"LeftArm","RightArm"} do
		-- Explicit mesh-specific grips already account for their side of the weapon.
		if authored and authored.grips[armName] then continue end
		if batonGrip and armName=="RightArm" then continue end
		if name=="Knife" and armName=="LeftArm" then continue end
		local data=joints[armName]
		local frame=data and frameInBody(armName)
		local parent=data and frameInBody(data.joint.Part0.Name)
		if frame and parent then
			-- Whichever end of the arm is nearer the weapon origin is the hand.
			local half=data.joint.Part1.Size.Z/2
			local a=(frame*CFrame.new(0,0,-half)).Position
			local b=(frame*CFrame.new(0,0,half)).Position
			local drift=if a.Magnitude<b.Magnitude then a.Z else b.Z
			data.base=CFrame.new(parent:VectorToObjectSpace(Vector3.new(0,0,-drift)))*data.base
		end
	end

	local tracks,markers=reloadTracks(profile[1])
	if authored then tracks,markers=authored.reload,authored.markers end
	local muzzle=model:FindFirstChild("MuzzleAttachment",true)
	local sight=if muzzle then pivot:PointToObjectSpace(muzzle.WorldPosition) else Vector3.new(0,0,-2)
	-- Root-space optic centres, calibrated against the screen centre in ADS.
	local optic=({["Kriss Vector"]=Vector3.new(.286,.987,0),
		["AUG A-3"]=Vector3.new(.1811,1.11376,0)})[model.Name]
	local aimOffset=CFrame.new(math.clamp(-.9-sight.X,-1.5,1.5),math.clamp(1.3-sight.Y-.14,-1.5,1.5),-.12)
	if optic then
		-- Cancel the camera mount (-1.3 Y) and the full-ADS lowering (-.30 Y).
		aimOffset=CFrame.new(-.9-optic.X,1.6-optic.Y,-.12)
	end
	return setmetatable({model=model,tool=tool,kind=profile[1],power=profile[2],equipTime=profile[3],
		joints=joints,tracks=tracks,markers=markers,authored=authored,emit=emit or function() end,
		aimOffset=aimOffset,
		active=false,clock=0,stride=0,aim=0,aimTarget=0,sprint=0,move=0,
		recoil=0,recoilVelocity=0,lastShot=-100,swing=nil,reloadState=nil,recover=nil,equipAge=nil,
		poses={},},Motion)
end

function Motion:equip()
	self:reset()
	self.active=true
	self.equipAge=0
end

function Motion:setAiming(value)
	self.aimTarget=if value and self.kind~="melee" then 1 else 0
end

function Motion:shoot(variant)
	if not self.active then return end
	self:cancelReload()
	self.lastShot=self.clock
	if self.kind=="melee" then
		local hit=math.max(self.tool:GetAttribute("swingDelay") or .2,.05)
		self.swing={age=0,hit=hit,duration=hit+.27,variant=variant or "Shoot",
			fromBody=self.poses.Body or I,fromLeft=self.poses.LeftArm or I,fromRight=self.poses.RightArm or I}
	else
		-- Critically damped impulse: preserves continuity at high fire rates and cannot accumulate forever.
		self.recoilVelocity=math.min(self.recoilVelocity+43*self.power,110)
	end
	self.emit("Shoot")
end

function Motion:reload(duration)
	if not self.active or self.kind=="melee" or duration<=0 then return end
	self.swing=nil
	self.recoil=0
	self.recoilVelocity=0
	self.recover=nil
	self.reloadState={age=0,duration=duration,nextMarker=1}
end

function Motion:cancelReload()
	if self.reloadState then
		local previous={}
		for name,cf in self.poses do previous[name]=cf end
		self.recover={age=0,poses=previous}
		self.reloadState=nil
	end
end

function Motion:step(dt,speed,sprinting)
	if not self.active then return I end
	dt=math.max(dt,0)
	self.clock+=dt
	local blend=1-math.exp(-14*dt)
	local attacking=self.swing~=nil or self.clock-self.lastShot<.22
	local aiming=if self.reloadState or self.equipAge then 0 else self.aimTarget
	self.aim+=(aiming-self.aim)*blend
	local run=if sprinting and speed>1 and not attacking and not self.reloadState and self.aimTarget==0 then 1 else 0
	self.sprint+=(run-self.sprint)*(1-math.exp(-11*dt))
	self.move+=(math.clamp(speed/20,0,1)-self.move)*blend
	self.stride=(self.stride+math.min(speed,45)*.40*dt)%(math.pi*2)
	local omega=(if self.authored then self.authored.omega else 22)*1.15
	local c=self.recoilVelocity+omega*self.recoil
	local decay=math.exp(-omega*dt)
	self.recoil=(self.recoil+c*dt)*decay
	self.recoilVelocity=(self.recoilVelocity-omega*c*dt)*decay
	local p={Body=I,LeftArm=I,RightArm=I,Magazine=I,ChargingHandle=I}
	if self.equipAge then
		self.equipAge+=dt
		local t=math.min(self.equipAge/(self.equipTime*.85),1)
		p.Body=sample({{0,drawPoses[self.kind]},{.65,pose(0,.035,-.055,3,-1,-3)},{1,I}},t)
		p.LeftArm=sample({{0,pose(-.12,-.12,.15,14,-12,-12)},{.8,I},{1,I}},t)
		if t>=1 then self.equipAge=nil end
	end
	local r=self.reloadState
	if r then
		r.age+=dt
		-- Quicker presentation/recovery, while the original reload lock still owns ADS timing.
		local t=math.min(r.age/(r.duration*.88),1)
		for name,keys in self.tracks do p[name]=sample(keys,t) end
		while self.markers[r.nextMarker] and self.markers[r.nextMarker][1]<=t do
			self.emit(self.markers[r.nextMarker][2])
			r.nextMarker+=1
		end
		if r.age>=r.duration then self.reloadState=nil end
	elseif self.recover then
		self.recover.age+=dt
		local a=ease(math.min(self.recover.age/.12,1))
		for name,cf in self.recover.poses do p[name]=cf:Lerp(I,a) end
		if a>=1 then self.recover=nil end
	end
	local s=self.swing
	if s then
		s.age+=dt
		local t=math.min(s.age/s.duration,1)
		local contact=s.hit/s.duration
		local wind=swingWindups[s.variant] or swingWindups.Shoot
		local finish=swingEnds[s.variant] or swingEnds.Shoot
		p.Body=sample({{0,s.fromBody},{contact*.55,wind},{contact,finish},{contact+.14,finish:Lerp(I,.25)},{1,I}},t,true)
		-- The support arm counterbalances instead of being frozen to the striking hand.
		p.LeftArm=sample({{0,s.fromLeft},{contact*.55,pose(-.12,-.16,.08,8,-10,-12)},
			{contact,pose(-.22,-.18,.15,14,-18,-18)},{1,I}},t,true)
		p.RightArm=sample({{0,s.fromRight},{contact,pose(0,0,0,0,0,if s.variant=="Shoot3" then -6 else 6)},{1,I}},t,true)
		-- The baton and gripping hand move together; avoid twisting the hand off its handle.
		if self.model.Name=="Baton" or self.model.Name=="Knife" then p.RightArm=I end
		if t>=1 then self.swing=nil end
	elseif self.kind~="melee" then
		local kick=self.recoil*(1-.45*self.aim)
		local k=self.authored and self.authored.kick
		p.Body=p.Body*(if k then pose(0,k[1]*kick,k[2]*kick,k[3]*kick,k[4]*kick,k[5]*kick)
			else pose(0,.015*kick,.14*kick,4.5*kick,-.65*kick,-.8*kick))
		-- Pump weapons have no isolated fore-end mesh; the support hand performs the cycle.
		if self.kind=="pump" and not r then
			local age=self.clock-self.lastShot
			if age>=.09 and age<.49 then
				p.LeftArm=sample({{.09,I},{.23,pose(0,-.035,if self.authored then .55 else .30,3,0,0)},
					{.31,pose(0,-.035,if self.authored then .55 else .30,3,0,0)},{.43,I},{.49,I}},age)
			end
		end
	end
	-- Both knife hands remain locked to the handle through equip and all swings.
	if self.model.Name=="Knife" then p.LeftArm=I p.RightArm=I end
	self.poses=p
	for name,data in self.joints do
		local cf=p[name] or I
		if name=="Body" and self.authored then
			cf=self.authored.carry:Lerp(I,self.aim)*cf
		end
		local b=data.basis
		local translate=b:VectorToObjectSpace(cf.Position)
		local rotate=b:Inverse()*cf.Rotation*b
		data.joint.Transform=I
		data.joint.C0=CFrame.new(data.base.Position+translate)*rotate*data.base.Rotation
	end
	local calm=1-.9*self.aim
	local breath=pose(math.sin(self.clock*1.8)*.008*calm,math.sin(self.clock*2.2)*.012*calm,0,
		math.sin(self.clock*1.8)*.18*calm,0,math.sin(self.clock*1.1)*.20*calm)
	local stride=self.stride
	local walking=pose(math.sin(stride)*.024*self.move*calm,math.cos(stride*2)*.027*self.move*calm,0,
		math.sin(stride*2)*.25*self.move*calm,math.sin(stride)*.25*self.move*calm,math.sin(stride)*.5*self.move*calm)
	local runPose=if self.kind=="melee" then pose(.08,-.20,.1,12,-12,-20)
		elseif self.kind=="pistol" or self.kind=="revolver" then pose(.04,-.18,.12,18,-8,-12)
		elseif self.kind=="bullpup" or self.kind=="top" then pose(.10,-.20,.14,-8,14,-18)
		else pose(.12,-.25,.18,-12,18,-22)
	-- Lower the rendered rig relative to the camera in both hip-fire and ADS.
	-- Translation only: camera orientation, crosshair and ballistic ray are unchanged.
	local hipHeight=if self.model.Name=="Knife" then .58 elseif self.kind=="melee" then -.32 else -.16
	local lower=CFrame.new(0,hipHeight*(1-self.aim)-.30*self.aim,0)
	return lower*I:Lerp(self.aimOffset,self.aim)*I:Lerp(runPose,self.sprint)*breath*walking
end

function Motion:reset()
	self.active=false
	self.clock=0 self.stride=0 self.aim=0 self.aimTarget=0 self.sprint=0 self.move=0
	self.recoil=0 self.recoilVelocity=0 self.lastShot=-100
	self.swing=nil self.reloadState=nil self.recover=nil self.equipAge=nil self.poses={}
	for _,data in self.joints do data.joint.C0=data.original data.joint.Transform=data.transform end
end

function Motion:destroy()
	self:reset()
	table.clear(self.joints)
end

return Motion
