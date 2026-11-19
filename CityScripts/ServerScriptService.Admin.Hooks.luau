-- Server-only admin seams (2026-11-20). The Scripts that own a behaviour keep it and register an entry point here
-- when they start; Admin.Actions calls it. One ModuleScript both sides require: one server VM, one require cache,
-- under ServerScriptService, so nothing replicates and no client can reach it. An entry is nil until its owner ran.
--   setLevel(player, level)                     Weapons.Scripts.LevelingService
--   giveWeapon(player, name) -> (ok, message)   Weapons.Scripts.WeaponShopService
--   heists[name] = BankInstance                 HeistServer (Bank), SlowFoodsServer, Gas2GoServer, NewsStationServer
return { heists = {} }
