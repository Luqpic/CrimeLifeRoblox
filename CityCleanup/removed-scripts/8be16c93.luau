-- Removed by CityCleanup Task 2. Original path: Workspace.Sparkling Power Water.DropperConfig ; copies: 2 ; Adler-32: 8be16c93
return { --do not rename this module script!!!
	MeshDrop = {
		Enabled = true, --whether or not this dropper drops meshes
		MeshId = "rbxassetid://100856357", --what mesh to drop
		TextureId = "rbxassetid://50891381", --a texture for the mesh
		MeshScale = Vector3.new(1,1,1), --scale of the mesh
	},
	Default = {
		ShowDrop = true, --if disabled this dropper will just give the owner cash instead of spawning a part
		DropSize = Vector3.new(1,1,1), --size of the drop
		DropOffset = Vector3.new(0,0,0), --offset from the "Drop" part
		DropOrientation = Vector3.new(0,0,0), --orientation of the drop
		DropShadow = false, --enable/disable castshadow
		DropSpeed = 3.5, --one drop appears every ... seconds
		DropExpiration = 20, --after being dropped, the drop
		DropTransparency = 0, --how transparent the drop is
	},
	Currency = { --value of the drop for each currency
		Cash = 2000,
	},
	ClickerName = "", --name of the proximityprompt/clickdetector which you want to use for clicking, set to "" to disable
	DropTags = {
		TagTextMaxDistance = 20,
		AlwaysOnTop = true,
		Enabled = true,
	},
	RunFunction = function(drop)
		
	end,
}