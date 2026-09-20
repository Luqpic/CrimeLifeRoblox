return function(Motion,models,weapons)
	local checks=0
	for name,point in {["Kriss Vector"]=Vector3.new(.286,.987,0),
		["AUG A-3"]=Vector3.new(.1811,1.11376,0)} do
		local model=models[name]:Clone()
		local m=Motion.new(model,weapons[name])
		local projected=(CFrame.new(.9,-1.3,-1.3)*CFrame.new(0,-.30,0)*m.aimOffset):PointToWorldSpace(point)
		assert(math.abs(projected.X)<.0001 and math.abs(projected.Y)<.0001,name.." optic off axis")
		checks+=1
		m:destroy() model:Destroy()
	end
	return {weapons=2,checks=checks}
end
