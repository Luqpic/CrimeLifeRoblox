--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local NPCSpawnManager = {}
NPCSpawnManager.__index = NPCSpawnManager

-- Owns the FULL population of one kind of NPC at one location (e.g. every
-- Bank Clerk, or every SlowFoods Cashier) -- registered ONCE per location
-- as a single BankInstance component (spec addendum, 2026-09-09), unlike
-- the individual per-NPC registry binding this replaces. That distinction
-- matters: an NPC instance is now destroyed and a fresh one recloned every
-- cooldown-end regardless of whether it died, so nothing about it can be a
-- static, bind-once-at-boot registry component anymore -- something has to
-- own creating/destroying instances across the server's whole lifetime,
-- and that's this manager, not NPCReactionAnimator itself (which only ever
-- owns ONE instance's DURING-session lifecycle, for however long that
-- particular instance happens to exist).
--
-- deps:
--   template: Model to clone for each spawn point (an inert ModelTemplates
--     entry, never itself tagged/parented into the live world)
--   npcTag: CollectionService tag applied to every clone (e.g. "BankClerk")
--   spawnerTemplateValue: matches each NPCSpawner placeholder's own
--     NPCTemplate attribute, so one shared "NPCSpawner" tag can mark
--     placeholders for multiple different NPC populations/locations
--     without a separate tag per kind
--   npcParent: Instance every clone is parented under
--   controllerClass: the per-NPC controller class (NPCReactionAnimator),
--     injected rather than required directly -- lets tests substitute a
--     lightweight fake instead of loading real animations/rig requirements
--   controllerDeps: forwarded verbatim to controllerClass.new(model, deps)
function NPCSpawnManager.new(deps)
	assert(deps and deps.template, "NPCSpawnManager requires a template")
	assert(deps.npcTag, "NPCSpawnManager requires an npcTag")
	assert(deps.spawnerTemplateValue, "NPCSpawnManager requires a spawnerTemplateValue")
	assert(deps.npcParent, "NPCSpawnManager requires an npcParent")
	assert(deps.controllerClass, "NPCSpawnManager requires a controllerClass")

	local self = setmetatable({
		template = deps.template,
		npcTag = deps.npcTag,
		spawnerTemplateValue = deps.spawnerTemplateValue,
		npcParent = deps.npcParent,
		controllerClass = deps.controllerClass,
		controllerDeps = deps.controllerDeps or {},
		_npcs = {},
	}, NPCSpawnManager)

	-- The very first construction (server boot) has nothing tracked in
	-- self._npcs yet to hand to the normal _destroyAll -- but the ORIGINAL,
	-- pre-placed NPCs (or leftovers from some earlier, untracked state) may
	-- still be sitting in the world under npcParent. Clear those by tag,
	-- scoped to this location's own container so this can never touch the
	-- other location's same-named-but-differently-tagged population,
	-- before the first real generation is cloned in.
	self:_clearPreexisting()
	self:_spawnAll()

	return self
end

function NPCSpawnManager:_clearPreexisting()
	for _, instance in ipairs(CollectionService:GetTagged(self.npcTag)) do
		if instance:IsDescendantOf(self.npcParent) then
			local ok, err = pcall(function() instance:Destroy() end)
			if not ok then warn("[NPCSpawnManager] failed to clear a pre-existing " .. self.npcTag .. ": " .. tostring(err)) end
		end
	end
end

-- Edit is the truth (developer rule, 2026-11-20): a placeholder's Model child is its NPC as the developer sees it in
-- Edit. On the server the first search (at boot) takes it: the placeholder moves to it and it leaves the world
-- (ServerScriptService.Heist.EditRig), so moving the rig in Edit moves the NPC. The clone still comes from `template`.
function NPCSpawnManager:_findSpawners()
	local spawners = {}
	for _, part in ipairs(CollectionService:GetTagged("NPCSpawner")) do
		if part:GetAttribute("NPCTemplate") == self.spawnerTemplateValue then
			if RunService:IsServer() and part:FindFirstChildWhichIsA("Model") then
				require((game:GetService("ServerScriptService") :: any).Heist.EditRig).take(part)
			end
			table.insert(spawners, part)
		end
	end
	return spawners
end

-- One clone per spawner. A single bad clone/controller-construction must
-- not stop the rest from spawning, same resilience principle as
-- ComponentRegistry:BindAll.
function NPCSpawnManager:_spawnAll()
	for _, spawner in ipairs(self:_findSpawners()) do
		local ok, result = pcall(function()
			local clone = self.template:Clone()
			clone:PivotTo(spawner.CFrame)
			clone.Parent = self.npcParent
			CollectionService:AddTag(clone, self.npcTag)
			return self.controllerClass.new(clone, self.controllerDeps)
		end)
		if ok then
			table.insert(self._npcs, result)
		else
			warn(string.format("[NPCSpawnManager] failed to spawn %s at %s: %s",
				self.npcTag, spawner:GetFullName(), tostring(result)))
		end
	end
end

function NPCSpawnManager:_destroyAll()
	for _, npc in ipairs(self._npcs) do
		local ok, err = pcall(function()
			npc:Destroy()
			if npc.model then npc.model:Destroy() end
		end)
		if not ok then
			warn(string.format("[NPCSpawnManager] failed to destroy an npc: %s", tostring(err)))
		end
	end
	self._npcs = {}
end

-- RobberyActive becomes true: every currently-live NPC reacts. One bad
-- controller must not stop the rest from reacting.
function NPCSpawnManager:OnSessionStart()
	for _, npc in ipairs(self._npcs) do
		local ok, err = pcall(npc.OnSessionStart, npc)
		if not ok then warn("[NPCSpawnManager] OnSessionStart failed on an npc: " .. tostring(err)) end
	end
end

-- Session end: survivors revert Scared -> Idle; a dead one stays ragdolled
-- untouched (both handled by NPCReactionAnimator:Seal itself) -- nothing
-- is destroyed here. Recloning is a cooldown-END event (Rearm, below), not
-- a session-end one, so a dead NPC's corpse (and a survivor's calmed idle)
-- is what actually persists visually through the cooldown.
function NPCSpawnManager:Seal()
	for _, npc in ipairs(self._npcs) do
		local ok, err = pcall(npc.Seal, npc)
		if not ok then warn("[NPCSpawnManager] Seal failed on an npc: " .. tostring(err)) end
	end
end

-- Cooldown ends -- the location becomes robbable again. EVERY NPC at this
-- location is destroyed and a fresh generation is cloned from the
-- NPCSpawner placeholders, unconditionally, regardless of whether any of
-- them died last session (spec addendum, 2026-09-09: recloning replaces
-- restore-in-place entirely -- one consistent path, no per-NPC "did this
-- one die" branching needed here).
function NPCSpawnManager:Rearm()
	self:_destroyAll()
	self:_spawnAll()
end

function NPCSpawnManager:Destroy()
	self:_destroyAll()
end

return NPCSpawnManager
