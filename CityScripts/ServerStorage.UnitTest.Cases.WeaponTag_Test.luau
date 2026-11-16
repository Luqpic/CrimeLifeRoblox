-- WeaponTag_Test: every Tool under ServerStorage.Weapons carries the CollectionService tag "Weapon"
-- (phase 3 gate G9: the heist trigger checks the tag; an untagged weapon cannot start a robbery).
return function(t)
	t.test("every Tool under ServerStorage.Weapons is tagged Weapon", function()
		local missing, count = {}, 0
		for _, d in ipairs(game:GetService("ServerStorage").Weapons:GetDescendants()) do
			if d:IsA("Tool") then
				count += 1
				if not d:HasTag("Weapon") then table.insert(missing, d.Name) end
			end
		end
		t.expect.truthy(count > 0)
		if #missing > 0 then error(#missing .. " of " .. count .. " untagged: " .. table.concat(missing, ", "), 0) end
	end)
end
