-- Re-runnable build for the eight pistols/shotguns added 2026-09-24. Run in Studio (Edit, command bar
-- or MCP execute_luau). Reads the raw models in Workspace.Pistols / Workspace.Shotguns, whose moving
-- pieces are tagged with a MovingPiece attribute ("Magazine" or "Pump"), and (re)creates for each:
--   ServerStorage.Weapons.<name>                   Tool: donor clone, donor trims replaced by the new mesh
--   ReplicatedStorage.Blaster.ViewModels.<name>    donor skeleton kept whole + hidden, new mesh hung off it
-- Magazine pieces weld to the donor's animated Magazine part (reload drops them, the left hand follows).
-- Pump pieces weld to a new Pump part on a Body->Pump Motor6D that WeaponViewmodelMotion racks per shot.
local W = game.ServerStorage.Weapons
local VMS = game.ReplicatedStorage.Blaster.ViewModels
local V2 = Vector2.new
local SPECS = {
	{src=workspace.Pistols["GLOCK 17"], name="Glock 18", donor="Glock 17", len=1.80,
	 stats={Category="Pistol",Price=850,damage=18,rateOfFire=1000,magazineSize=33,range=700,spread=2.6,recoilMin=V2(-1,6),recoilMax=V2(3,11),reloadTime=1.9,fireMode="Auto"}},
	{src=workspace.Pistols["SIG SAUER M17 / P320"], name="SIG M17", donor="Glock 17", len=1.97,
	 stats={Category="Pistol",Price=500,damage=23,rateOfFire=600,magazineSize=17,range=900,spread=1.5,recoilMin=V2(0,10),recoilMax=V2(3,14),reloadTime=1.5,fireMode="Semi"}},
	{src=workspace.Pistols["M45A1"], name="M45A1", donor="Glock 17", len=2.15, sounds="M1911",
	 stats={Category="Pistol",Price=700,damage=40,rateOfFire=420,magazineSize=7,range=950,spread=2.0,recoilMin=V2(0,17),recoilMax=V2(5,23),reloadTime=1.35,fireMode="Semi"}},
	{src=workspace.Pistols["H&K USP COMPACT"], name="USP Compact", donor="Glock 17", len=1.67,
	 stats={Category="Pistol",Price=525,damage=27,rateOfFire=520,magazineSize=12,range=800,spread=1.9,recoilMin=V2(0,13),recoilMax=V2(4,18),reloadTime=1.35,fireMode="Semi"}},
	{src=workspace.Shotguns["REMINGTON 870, PICATINNY RAIL"], name="Remington 870", donor="Mossberg 590", len=6.9,
	 stats={Category="Shotgun",Price=800,damage=16,rateOfFire=85,magazineSize=7,range=560,spread=8.5,recoilMin=V2(-6,25),recoilMax=V2(10,35),reloadTime=0.5,fireMode="Semi"}},
	{src=workspace.Shotguns["REMINGTON 870, SAWED OFF"], name="Sawed-Off 870", donor="Mossberg 590", len=4.9, shiftX=-1.4,
	 stats={Category="Shotgun",Price=650,damage=14,rateOfFire=95,magazineSize=4,range=380,spread=13,recoilMin=V2(-6,30),recoilMax=V2(12,42),reloadTime=0.45,fireMode="Semi"}},
	{src=workspace.Shotguns["BAIKAL MP-153"], name="MP-153", donor="Mossberg 590", len=7.6, sounds="Benelli M4",
	 stats={Category="Shotgun",Price=1050,damage=14,rateOfFire=170,magazineSize=5,range=560,spread=9,recoilMin=V2(8,26),recoilMax=V2(12,36),reloadTime=0.5,fireMode="Semi"}},
	{src=workspace.Shotguns["FRANCHI SPAS-12, EXTENDED STOCK"], name="SPAS-13", donor="Mossberg 590", len=7.3, sounds="Spas 12",
	 stats={Category="Shotgun",Price=1150,damage=16,rateOfFire=120,magazineSize=8,range=600,spread=8,recoilMin=V2(8,26),recoilMax=V2(12,36),reloadTime=0.5,fireMode="Semi"}},
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
	local donorTool, donorVM = W[s.donor], VMS[s.donor]
	local old = W:FindFirstChild(s.name) if old then old:Destroy() end
	old = VMS:FindFirstChild(s.name) if old then old:Destroy() end

	local dBody = donorTool.Blaster.Body
	local dLo, dHi = visibleExtents(donorTool.Blaster, dBody.CFrame)
	local vmRef = donorVM.Blaster:FindFirstChild("Mesh1") or donorVM.Blaster.Body -- the VM part that IS the Tool's Body
	local T = donorVM.Blaster.Body.CFrame:ToObjectSpace(vmRef.CFrame) -- Tool-Body space -> VM-Body space
	local dVMMuzzle = T:PointToObjectSpace(donorVM.Blaster.Body.MuzzleAttachment.Position)
	local inset = dVMMuzzle.X - dLo.X

	local G = CFrame.fromMatrix(s.src:GetPivot().Position, NATIVE_FWD, NATIVE_UP)
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
			made[i] = p
			weld(anchorFor and anchorFor(piece, p) or body, p)
		end
		return made
	end

	-- Tool (third person / shop): everything rigid on Body.
	local tool = donorTool:Clone()
	tool.Name = s.name
	tool.TextureId = ""
	if s.sounds then tool.Sounds:Destroy() W[s.sounds].Sounds:Clone().Parent = tool end
	for key, v in s.stats do tool:SetAttribute(key, v) end
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

	tool.Parent = W
	vm.Parent = VMS
	table.insert(report, string.format("%s k=%.3f parts=%d moving=[%s]", s.name, k, #placed, table.concat(moving, ",")))
end
return table.concat(report, "\n")
