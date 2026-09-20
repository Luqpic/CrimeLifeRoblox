return function(Motion,models,weapons)
	local checks=0
	for _,name in {"Crowbar","Baton"} do
		local model=models[name]:Clone()
		local m=Motion.new(model,weapons[name])
		m:equip()
		local root=m:step(1,0,false)
		assert(root.Position.Y<-.29,name.." carry not lowered") checks+=1
		for _,variant in {"Shoot","Shoot2","Shoot3"} do
			m:shoot(variant) m:step(.31,38,true)
			assert(m.swing and m.sprint<.001,name.." sprint mixes into swing recovery") checks+=1
			m:step(1,0,false)
		end
		m:shoot("Shoot") m:step(.12,0,false)
		local body=model:FindFirstChild("BodyJoint",true)
		local before=body.C0
		m:shoot("Shoot2") m:step(0,0,false)
		local delta=before:ToObjectSpace(body.C0)
		local _,angle=delta:ToAxisAngle()
		assert(delta.Position.Magnitude<.001 and math.abs(angle)<.001,name.." interrupted swing snaps") checks+=1
		m:destroy() model:Destroy()
	end
	return {weapons=2,checks=checks}
end
