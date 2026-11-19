-- Out-of-combat regen (combat balance, 2026-11-20). Named Health on purpose: a Script of this name in
-- StarterCharacterScripts replaces Roblox's default Health script, which healed 1 % of MaxHealth a second with no
-- delay. Here a character heals Combat.REGEN_PER_SECOND of its MaxHealth a second once Combat.REGEN_DELAY seconds have
-- passed since it last lost health, until full; at full health it sleeps until its health changes. Server side; it
-- only ever raises Health, so WantedService's damage record (drops only) and the death screen are not touched.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(ReplicatedStorage.Enemy.Combat)

local humanoid = script.Parent:WaitForChild("Humanoid") :: Humanoid
local lastHealth = humanoid.Health
local hurtAt = -math.huge

humanoid.HealthChanged:Connect(function(health)
	if health < lastHealth then
		hurtAt = os.clock()
	end
	lastHealth = health
end)

while humanoid.Health > 0 do
	if humanoid.Health >= humanoid.MaxHealth then
		humanoid.HealthChanged:Wait()
	else
		local dt = task.wait(Combat.REGEN_TICK)
		humanoid.Health = Combat.regenStep(humanoid.Health, humanoid.MaxHealth, os.clock() - hurtAt, dt)
	end
end
