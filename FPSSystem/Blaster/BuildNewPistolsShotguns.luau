-- Re-runnable build for the eight pistols/shotguns and the RPG added 2026-09-24. Run in Studio (Edit, command bar
-- or MCP execute_luau). Reads the raw models in Workspace.Pistols / Workspace.Shotguns, whose moving
-- pieces are tagged with a MovingPiece attribute ("Magazine" or "Pump"), and (re)creates for each:
--   ServerStorage.Weapons.<name>                   Tool: donor clone, donor trims replaced by the new mesh
--   ReplicatedStorage.Blaster.ViewModels.<name>    donor skeleton kept whole + hidden, new mesh hung off it
-- Magazine pieces weld to the donor's animated Magazine part (reload drops them, the left hand follows).
-- Pump pieces weld to a new Pump part on a Body->Pump Motor6D that WeaponViewmodelMotion racks per shot.
-- Rocket pieces weld to Body and are tagged HideWhenEmpty: the loaded round, hidden while the weapon is
-- empty (WeaponShopService does the Tool, ViewModelController the viewmodel).
local W = game.ServerStorage.Weapons
local VMS = game.ReplicatedStorage.Blaster.ViewModels
local V2 = Vector2.new
-- A source model looked up without erroring: the Pistols/Shotguns sources were deleted once their weapons
-- shipped, and a spec whose source is gone is skipped (its built Tool and viewmodel are left as they are)
-- rather than failing the whole build.
local function source(...)
	local node = workspace
	for _, name in { ... } do
		node = node and node:FindFirstChild(name)
	end
	return node
end
local SPECS = {
	{src=source("Pistols", "GLOCK 17"), name="Glock 18", icon="rbxassetid://131817905527310", donor="Glock 17", len=1.80,
	 stats={Category="Pistol",Price=850,damage=18,rateOfFire=1000,magazineSize=33,range=700,spread=2.6,recoilMin=V2(-1,6),recoilMax=V2(3,11),reloadTime=1.9,fireMode="Auto"}},
	{src=source("Pistols", "SIG SAUER M17 / P320"), name="SIG M17", icon="rbxassetid://88683475230170", donor="Glock 17", len=1.97,
	 stats={Category="Pistol",Price=500,damage=23,rateOfFire=600,magazineSize=17,range=900,spread=1.5,recoilMin=V2(0,10),recoilMax=V2(3,14),reloadTime=1.5,fireMode="Semi"}},
	{src=source("Pistols", "M45A1"), name="M45A1", icon="rbxassetid://109363317738894", donor="Glock 17", len=2.15, sounds="M1911",
	 stats={Category="Pistol",Price=700,damage=40,rateOfFire=420,magazineSize=7,range=950,spread=2.0,recoilMin=V2(0,17),recoilMax=V2(5,23),reloadTime=1.35,fireMode="Semi"}},
	{src=source("Pistols", "H&K USP COMPACT"), name="USP Compact", icon="rbxassetid://138547885966752", donor="Glock 17", len=1.67,
	 stats={Category="Pistol",Price=525,damage=27,rateOfFire=520,magazineSize=12,range=800,spread=1.9,recoilMin=V2(0,13),recoilMax=V2(4,18),reloadTime=1.35,fireMode="Semi"}},
	{src=source("Shotguns", "REMINGTON 870, PICATINNY RAIL"), name="Remington 870", icon="rbxassetid://134927232970402", donor="Mossberg 590", len=6.9,
	 stats={Category="Shotgun",Price=800,damage=16,rateOfFire=85,magazineSize=7,range=560,spread=8.5,recoilMin=V2(-6,25),recoilMax=V2(10,35),reloadTime=0.5,fireMode="Semi"}},
	{src=source("Shotguns", "REMINGTON 870, SAWED OFF"), name="Sawed-Off 870", icon="rbxassetid://111525487459957", donor="Mossberg 590", len=4.9, shiftX=-1.4,
	 stats={Category="Shotgun",Price=650,damage=14,rateOfFire=95,magazineSize=4,range=380,spread=13,recoilMin=V2(-6,30),recoilMax=V2(12,42),reloadTime=0.45,fireMode="Semi"}},
	{src=source("Shotguns", "BAIKAL MP-153"), name="MP-153", icon="rbxassetid://89072275856972", donor="Mossberg 590", len=7.6, sounds="Benelli M4",
	 stats={Category="Shotgun",Price=1050,damage=14,rateOfFire=170,magazineSize=5,range=560,spread=9,recoilMin=V2(8,26),recoilMax=V2(12,36),reloadTime=0.5,fireMode="Semi"}},
	{src=source("Shotguns", "FRANCHI SPAS-12, EXTENDED STOCK"), name="SPAS-13", icon="rbxassetid://108464871855791", donor="Mossberg 590", len=7.3, sounds="Spas 12",
	 stats={Category="Shotgun",Price=1150,damage=16,rateOfFire=120,magazineSize=8,range=600,spread=8,recoilMin=V2(8,26),recoilMax=V2(12,36),reloadTime=0.5,fireMode="Semi"}},
	-- Gamepass weapon: no Price (the donor's is cleared -- a leftover Price would make it cash-buyable),
	-- `Gamepass` names the Monetization.Constants pass that unlocks it. Lies with its muzzle along -Z and
	-- top along +X, unlike the pistols/shotguns. Explosion stats are read by ShotResolver.
	{src=source("RPG"), name="RPG", icon="rbxassetid://123274987878588", donor="AK47", len=8.5, projectile="RPGRocket",
	 nativeFwd=Vector3.new(0,0,-1), nativeUp=Vector3.new(1,0,0), shootSound="rbxassetid://112670894256968",
	 -- Per-slot sound overrides; "" silences a slot. The reload is ONE 2.17 s sound on the first reload cue
	 -- (MagOut, ~0.5 s in), so MagIn/Charger are silenced rather than replaying it. Impact plays where a
	 -- round explodes (ShotResolver.explode).
	 soundIds={Equip="rbxassetid://127644583196232", MagOut="rbxassetid://5278373892", MagIn="", Charger="",
	  Impact="rbxassetid://130495957969380"},
	 -- ShopViewRotation is KEPT from the AK47: the RPG shares its body frame, so the shop preview needs the
	 -- same 180-degree flip (clearing it showed the RPG upside down).
	 clear={"Price"},
	 stats={Category="Launcher",Gamepass="RPG",damage=200,rateOfFire=30,magazineSize=1,range=600,spread=0.5,
	  recoilMin=V2(4,30),recoilMax=V2(8,40),reloadTime=3,fireMode="Semi",raysPerShot=1,rayRadius=0.5,
	  explosionRadius=16,explosionEdgeDamage=0.3,explosionKnockback=65,explosionFlingSpeed=290}},
	 -- 290/65 measured on open baseplate: the killed flew 800-827 studs, a survivor at 12 studs 51 studs.
}
-- All eight sources lie on their side: muzzle along world -X, gun-up along world -Z.
local NATIVE_FWD, NATIVE_UP = Vector3.new(-1,0,0), Vector3.new(0,0,-1)
local R = CFrame.Angles(0, math.pi, 0) -- native gun frame -> donor Body frame (fwd = -X, up = +Y)

local function corners(cf, size, frame, lo, hi)
	for _, sx in {-1,1} do for _, sy in {-1,1} do for _, sz in {-1,1} do
		local p = frame:PointToObjectSpace((cf * CFrame.new(size.X/2*sx, size.Y/2*sy, size.Z/2*sz)).Position)
		lo = lo:Min(p) hi = hi:Max(p)
	end end end
	return lo, hi
end
local function visibleExtents(model, frame)
	local lo, hi = Vector3.one*1e9, -Vector3.one*1e9
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 then lo, hi = corners(p.CFrame, p.Size, frame, lo, hi) end
	end
	return lo, hi
end
local function weld(a, b)
	local w = Instance.new("WeldConstraint") w.Part0 = a w.Part1 = b w.Parent = b
end

local report = {}
for _, s in SPECS do
	if not s.src then
		table.insert(report, s.name .. ": source model missing -- skipped, existing build left untouched")
		continue
	end
	local donorTool, donorVM = W[s.donor], VMS[s.donor]
	local old = W:FindFirstChild(s.name) if old then old:Destroy() end
	old = VMS:FindFirstChild(s.name) if old then old:Destroy() end

	local dBody = donorTool.Blaster.Body
	local dLo, dHi = visibleExtents(donorTool.Blaster, dBody.CFrame)
	local vmRef = donorVM.Blaster:FindFirstChild("Mesh1") or donorVM.Blaster.Body -- the VM part that IS the Tool's Body
	local T = donorVM.Blaster.Body.CFrame:ToObjectSpace(vmRef.CFrame) -- Tool-Body space -> VM-Body space
	local dVMMuzzle = T:PointToObjectSpace(donorVM.Blaster.Body.MuzzleAttachment.Position)
	local inset = dVMMuzzle.X - dLo.X

	local G = CFrame.fromMatrix(s.src:GetPivot().Position, s.nativeFwd or NATIVE_FWD, s.nativeUp or NATIVE_UP)
	local nLo, nHi = Vector3.one*1e9, -Vector3.one*1e9
	for _, p in s.src:GetChildren() do if p:IsA("BasePart") then nLo, nHi = corners(p.CFrame, p.Size, G, nLo, nHi) end end
	local k = s.len / (nHi.X - nLo.X)
	local shiftX = s.shiftX or 0
	-- Rear-top edge of the new mesh on the donor's rear-top edge, so the grip lands in the donor's hand.
	local offset = Vector3.new(dHi.X + shiftX + k*nLo.X, dHi.Y - k*nHi.Y, (dLo.Z+dHi.Z)/2 + k*(nLo.Z+nHi.Z)/2)
	local placed = {}
	for _, p in s.src:GetChildren() do
		if p:IsA("BasePart") then
			local l = G:ToObjectSpace(p.CFrame)
			table.insert(placed, {src=p, cf=CFrame.new(offset) * R * (CFrame.new(l.Position*k) * l.Rotation)})
		end
	end
	local muzzle = Vector3.new(offset.X - k*nHi.X + inset, dVMMuzzle.Y, dVMMuzzle.Z)
	-- A launcher's bore is its rocket, not the donor rifle's barrel: the muzzle goes on the rocket's own
	-- centreline at its tip, so the round that flies starts exactly where the loaded one sat.
	local rocket
	for _, e in placed do
		if e.src:GetAttribute("MovingPiece") == "Rocket" then rocket = e end
	end
	local rocketLo, rocketHi
	if rocket then
		rocketLo, rocketHi = corners(rocket.cf, rocket.src.Size * k, CFrame.identity, Vector3.one*1e9, -Vector3.one*1e9)
		muzzle = Vector3.new(rocketLo.X + 0.05, rocket.cf.Position.Y, rocket.cf.Position.Z)
	end

	-- anchorFor(piece) returns the part a mesh piece welds to; Body unless it is a moving piece.
	local function build(parentModel, body, bodyToFrame, props, anchorFor)
		local made = {}
		for i, e in placed do
			local p = e.src:Clone()
			for a in p:GetAttributes() do p:SetAttribute(a, nil) end
			p.Name = "Mesh" .. i
			p.Size = p.Size * k
			local sm = p:FindFirstChildOfClass("SpecialMesh")
			if sm then sm.Scale = sm.Scale * k sm.Offset = sm.Offset * k end
			p.Anchored = false
			for key, v in props do p[key] = v end
			p.CFrame = body.CFrame * bodyToFrame * e.cf
			p.Parent = parentModel
			local piece = e.src:GetAttribute("MovingPiece")
			if piece == "Rocket" then
				p:SetAttribute("HideWhenEmpty", true)
			end
			made[i] = p
			weld(anchorFor and anchorFor(piece, p) or body, p)
		end
		return made
	end

	-- Tool (third person / shop): everything rigid on Body.
	local tool = donorTool:Clone()
	tool.Name = s.name
	tool.TextureId = s.icon -- icon art: ~/Downloads/New Guns, reduced to 1024px before upload
	if s.sounds then tool.Sounds:Destroy() W[s.sounds].Sounds:Clone().Parent = tool end
	for _, key in s.clear or {} do tool:SetAttribute(key, nil) end
	for key, v in s.stats do tool:SetAttribute(key, v) end
	if s.shootSound then
		local shoot = tool.Sounds.Shoot
		for _, sound in shoot:GetChildren() do if sound:IsA("Sound") then sound.SoundId = s.shootSound end end
	end
	for slot, id in s.soundIds or {} do
		local sound = tool.Sounds:FindFirstChild(slot)
		if not sound then
			sound = Instance.new("Sound")
			sound.Name = slot
			sound.Volume = 1
			sound.RollOffMode = Enum.RollOffMode.InverseTapered
			sound.RollOffMinDistance = 20
			sound.RollOffMaxDistance = 400
			sound.Parent = tool.Sounds
		end
		sound.SoundId = id
	end
	tool:SetAttribute("_ammo", s.stats.magazineSize)
	tool:SetAttribute("_reloading", false)
	tool:SetAttribute("viewModel", s.name)
	local body = tool.Blaster.Body
	for _, c in tool.Blaster:GetChildren() do if c:IsA("BasePart") and c ~= body then c:Destroy() end end
	body.Transparency = 1
	body.Size = Vector3.new(0.2, 0.2, 0.2) -- hidden anchor only; keeps the shop's bounding box on the real mesh
	build(tool.Blaster, body, CFrame.identity, {CanCollide=false, CanTouch=true, CanQuery=true, Massless=true, CastShadow=true})
	body.MuzzleAttachment.Position = muzzle

	-- Viewmodel: donor skeleton kept whole and hidden.
	local vm = donorVM:Clone()
	vm.Name = s.name
	local vBody = vm.Blaster.Body
	for _, c in vm.Blaster:GetChildren() do
		if c:IsA("BasePart") then
			if c.Name:match("^Mesh%d+$") then c:Destroy() else c.Transparency = 1 end
		end
	end
	local pump
	local moving = {}
	build(vm.Blaster, vBody, T, {CanCollide=false, CanTouch=false, CanQuery=false, Massless=true, CastShadow=true},
		function(piece, part)
			if piece == "Magazine" then
				local mag = vm.Blaster:FindFirstChild("Magazine")
				assert(mag, s.donor .. " viewmodel has no Magazine to carry " .. s.name .. "'s magazine")
				table.insert(moving, "Magazine<-" .. part.Name)
				return mag
			elseif piece == "Pump" then
				if not pump then
					pump = Instance.new("Part")
					pump.Name = "Pump"
					pump.Size = Vector3.new(0.2, 0.2, 0.2)
					pump.Transparency = 1
					pump.CanCollide = false pump.CanTouch = false pump.CanQuery = false pump.Massless = true
					pump.CFrame = CFrame.new(part.Position) * vBody.CFrame.Rotation
					pump.Parent = vm.Blaster
					local m6 = Instance.new("Motor6D")
					m6.Name = "PumpJoint"
					m6.Part0 = vBody m6.Part1 = pump
					m6.C0 = vBody.CFrame:ToObjectSpace(pump.CFrame)
					m6.Parent = vBody
				end
				table.insert(moving, "Pump<-" .. part.Name)
				return pump
			end
			return nil
		end)
	vBody.MuzzleAttachment.Position = T:PointToWorldSpace(muzzle)

	-- The round in flight: a copy of the loaded rocket on an invisible Root that sits at the muzzle and
	-- faces down the bore (-Z = direction of travel), with an exhaust point at the rocket's tail.
	if s.projectile and rocket then
		local objects = game.ReplicatedStorage.Blaster.Objects
		local oldRound = objects:FindFirstChild(s.projectile) if oldRound then oldRound:Destroy() end
		local round = Instance.new("Model")
		round.Name = s.projectile
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(0.2, 0.2, 0.2)
		root.Transparency = 1
		root.Anchored = true root.CanCollide = false root.CanQuery = false root.CanTouch = false
		root.CFrame = body.CFrame * CFrame.new(muzzle) * CFrame.Angles(0, math.pi / 2, 0)
		root.Parent = round
		local mesh = rocket.src:Clone()
		for a in mesh:GetAttributes() do mesh:SetAttribute(a, nil) end
		mesh.Name = "Rocket"
		mesh.Size = mesh.Size * k
		mesh.Anchored = true mesh.CanCollide = false mesh.CanQuery = false mesh.CanTouch = false
		mesh.CFrame = body.CFrame * rocket.cf
		mesh.Parent = round
		local exhaust = Instance.new("Attachment")
		exhaust.Name = "Exhaust"
		exhaust.Position = Vector3.new(0, 0, rocketHi.X - rocketLo.X) -- tail, behind the tip
		exhaust.Parent = root
		round.PrimaryPart = root
		round.Parent = objects
		tool:SetAttribute("projectile", s.projectile)
	end

	tool.Parent = W
	vm.Parent = VMS
	table.insert(report, string.format("%s k=%.3f parts=%d moving=[%s]", s.name, k, #placed, table.concat(moving, ",")))
end
return table.concat(report, "\n")
