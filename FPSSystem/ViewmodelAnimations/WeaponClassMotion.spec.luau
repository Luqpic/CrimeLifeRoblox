-- Three approved showcase rigs. This catches falling back to the old shared carry/recoil.
return function(Motion, models, weapons)
	local results, failures, carries, shots = {}, {}, {}, {}
	local gripTargets = {
		["Glock 17"]={RightArm=Vector3.new(.23,.18,-.43),LeftArm=Vector3.new(-.08,.12,-.47)},
		AK47={RightArm=Vector3.new(.28,-.20,.75),LeftArm=Vector3.new(-.03,-.10,-1.48)},
		["Mossberg 590"]={RightArm=Vector3.new(.18,-.20,.95),LeftArm=Vector3.new(-.03,-.32,-2.05)},
	}
	local function check(ok,message)
		if not ok then table.insert(failures,message) end
	end
	for _,name in {"Glock 17","AK47","Mossberg 590"} do
		local model=models[name]:Clone()
		local tool=weapons[name]
		local body=model:FindFirstChild("BodyJoint",true)
		local original=body.C0
		local m=Motion.new(model,tool)
		for armName,target in gripTargets[name] do
			local data=m.joints[armName]
			local hand=data.joint.Part0.CFrame*data.base*data.joint.C1:Inverse()*CFrame.new(0,0,-data.joint.Part1.Size.Z/2)
			check((model:GetPivot():PointToObjectSpace(hand.Position)-target).Magnitude<.03,name..": "..armName.." misses carry grip")
		end
		m:equip() m:step(1,0,false)
		local carry=body.C0
		carries[name]=original:ToObjectSpace(carry)
		check(carries[name].Position.Magnitude>.15,name..": carry still uses original body pose")
		m:shoot("Shoot") m:step(.05,0,false)
		shots[name]=CFrame.new(body.C0.Position-carry.Position)*body.C0.Rotation*carry.Rotation:Inverse()
		check(shots[name].Position.Magnitude>.04,name..": recoil not readable")
		m:step(2,0,false)
		check(carry:ToObjectSpace(body.C0).Position.Magnitude<.001,name..": shot fails to return to carry")
		m:reload(1) m:step(.4,0,false)
		check(carry:ToObjectSpace(body.C0).Position.Magnitude>.2,name..": reload does not present weapon")
		m:cancelReload() m:step(1,0,false)
		check(carry:ToObjectSpace(body.C0).Position.Magnitude<.001,name..": cancel fails to restore carry")
		m:reset()
		check(original:ToObjectSpace(body.C0).Position.Magnitude<.001,name..": unequip does not restore original")
		m:destroy() model:Destroy()
		table.insert(results,name)
	end
	local pistolPitch=math.abs(select(1,shots['Glock 17']:ToOrientation()))
	local riflePitch=math.abs(select(1,shots.AK47:ToOrientation()))
	check(pistolPitch>riflePitch*1.8,"Pistol should flip upward more than shouldered rifle")
	check(shots['Mossberg 590'].Position.Magnitude>shots.AK47.Position.Magnitude*1.4,"Shotgun kick should be heavier than rifle")
	check((carries['Glock 17'].Position-carries.AK47.Position).Magnitude>.1,"Pistol/rifle carry must be distinct")
	assert(#failures==0,table.concat(failures,'\n'))
	return {weapons=results,checks=27}
end
