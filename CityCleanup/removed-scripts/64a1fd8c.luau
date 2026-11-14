-- Removed by CityCleanup Task 2. Original path: Workspace.Bar Moulder.UpgraderConfig ; copies: 2 ; Adler-32: 64a1fd8c
return { --do not rename this module script!!!
	MeshDrop = {
		Enabled = true, --whether or not this upgrader changes meshes
		MeshId = "rbxassetid://3583612593", --what mesh to change to
		MeshScale = Vector3.new(2.5,2.5,2.5), --scale of the mesh
		OnlyOverwrite = true, --if true this only changes drops already having a mesh, not creating meshes for normal drops
	},
	Default = {
		DropSize = Vector3.new(1,1,1), --size of the drop
		DropShadow = false, --enable/disable castshadow
		DropTransparency = 0, --how transparent the drop is
	},
	Currency = { --value of the drop for each currency
		Cash = 100,
	},
	UpgradeType = "+", --select between "+", "-", "*", "/"
	UpgraderPartName = "UpgraderPart", --must be a part in the purchase or descendant
	RunFunction = function(drop)

	end,
}