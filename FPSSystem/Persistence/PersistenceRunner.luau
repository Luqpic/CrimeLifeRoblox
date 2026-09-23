-- A ModuleScript's hooks connect only when something requires it, and nothing else does.
require(game:GetService("ServerScriptService").Persistence.Scripts.ProfileGateway).start()
