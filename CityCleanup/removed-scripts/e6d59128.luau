-- Removed by CityCleanup Task 2. Original path: Workspace.HD Admin.CustomFeatures.Client.Modules.ClientCommands ; copies: 1 ; Adler-32: e6d59128
-- << RETRIEVE FRAMEWORK >>
local main = _G.HDAdminMain



-- << CLIENT COMMANDS >>
local module = {
	
	----------------------------------------------------------------------
	["commandName1"] = {
		Function = function(speaker, args)
			
		end;
		};
	
	
	
	
	----------------------------------------------------------------------
	["commandName2"] = {
		Function = function(speaker, args)
			
		end;
		};
	
	
	
	
	----------------------------------------------------------------------
	
};



-- << SETUP >>
for commandName, command in pairs(module) do
	command.Name = commandName
end



return module