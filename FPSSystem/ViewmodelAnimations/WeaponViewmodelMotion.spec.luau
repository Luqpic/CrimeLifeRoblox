-- Run against the real models and Tools in Edit mode; no character or network mocks.
return function(Motion, viewmodels, weapons)
	local checks = 0
	local function check(value, message)
		checks += 1
		assert(value, message)
	end
	check(Motion ~= nil, "Weapon-specific viewmodel motion is missing")
	local function finite(cf)
		for _,v in {cf:GetComponents()} do if v ~= v or math.abs(v) == math.huge then return false end end
		return true
	end
	local function close(a,b)
		local delta = a:ToObjectSpace(b)
		local _, angle = delta:ToAxisAngle()
		return delta.Position.Magnitude < 0.001 and math.abs(angle) < 0.001
	end
	local models = 0
	for _,tool in weapons:GetChildren() do
		if not tool:IsA("Tool") then continue end
		local template = viewmodels:FindFirstChild(tool:GetAttribute("viewModel"))
		check(template ~= nil, tool.Name .. " has no viewmodel")
		local model = template:Clone()
		local originals = {}
		for _,joint in model:GetDescendants() do if joint:IsA("Motor6D") then originals[joint]=joint.C0 end end
		local sounds = {}
		local motion = Motion.new(model, tool, function(name) table.insert(sounds,name) end)
		motion:equip()
		for _=1,120 do check(finite(motion:step(1/60,0,false)), tool.Name.." invalid idle") end
		local body = model:FindFirstChild("BodyJoint",true)
		local rest = body.C0
		motion:shoot("Shoot")
		for _=1,12 do motion:step(1/60,0,false) end
		check(not close(body.C0,rest),tool.Name.." attack does not articulate BodyJoint")
		for _=1,180 do motion:step(1/60,0,false) end
		check(close(body.C0,rest),tool.Name.." recoil/swing fails to settle")
		if motion.kind == "melee" then
			local contacts = {}
			local hit = tool:GetAttribute("swingDelay") or .2
			local expected = {
				Shoot={-.06,-.12,-.43,-58,5,12},
				Shoot2={-.32,.02,-.34,-26,-42,28},
				Shoot3={.16,-.06,-.39,-32,34,-24},
			}
			for _,variant in {"Shoot","Shoot2","Shoot3"} do
				motion:shoot(variant)
				motion:step(hit*.55,0,false)
				local windup=motion.poses.Body
				motion:step(hit*.45,0,false)
				local contact=motion.poses.Body
				local e=expected[variant]
				local target=CFrame.new(e[1],e[2],e[3])*CFrame.Angles(math.rad(e[4]),math.rad(e[5]),math.rad(e[6]))
				check(close(contact,target),tool.Name.." "..variant.." misses timed contact")
				check(not close(windup,contact),tool.Name.." "..variant.." lacks windup")
				for _,other in contacts do check(not close(contact,other),tool.Name.." duplicate swing") end
				table.insert(contacts,contact)
				motion:step(.28,0,false)
				check(close(body.C0,rest),tool.Name.." "..variant.." fails to recover")
			end
		end
		if not tool:GetAttribute("infiniteAmmo") then
			motion:reload(1)
			motion:step(0.35,0,false)
			local left = model:FindFirstChild("LeftArmJoint",true)
			local movingLeft = left.C0
			motion:cancelReload()
			for _=1,60 do motion:step(1/60,0,false) end
			check(not close(left.C0,movingLeft),tool.Name.." cancelled reload leaves hand displaced")
			check(close(body.C0,rest),tool.Name.." cancelled reload leaves weapon tilted")
			table.clear(sounds)
			motion:reload(0.5)
			motion:step(0.6,0,false)
			check(close(body.C0,rest),tool.Name.." reload overrun leaves weapon tilted")
			check(#sounds > 0,tool.Name.." skips reload sound markers on a slow frame")
			local soundCount = #sounds
			motion:step(1,0,false)
			check(#sounds == soundCount,tool.Name.." repeats completed sound markers")
		end
		motion:setAiming(true)
		for _=1,30 do check(finite(motion:step(1/30,38,true)),tool.Name.." invalid aim/sprint blend") end
		motion:setAiming(false)
		for _=1,90 do motion:shoot("Shoot"); check(finite(motion:step(1/60,38,true)),tool.Name.." sustained fire diverges") end
		motion:reset()
		for joint,original in originals do check(close(joint.C0,original),tool.Name.." reset fails to restore "..joint.Name) end
		check(close(motion:step(0.5,38,true),CFrame.identity),tool.Name.." inactive motion persists")
		motion:destroy()
		model:Destroy()
		models+=1
	end
	return {models=models,checks=checks}
end
