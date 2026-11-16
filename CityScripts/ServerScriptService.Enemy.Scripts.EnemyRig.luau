-- EnemyRig: turns a rig template from ServerStorage.EnemyTemplates into a live enemy body, shared by
-- EnemySpawner (gangs) and Wanted.PoliceDispatcher (police). Extracted from EnemySpawner without change of
-- behaviour (police and wanted, Task 2, 2026-11-17): the helpers below are EnemySpawner's, moved verbatim;
-- build() and place() are the two halves of what trySpawn did between choosing a template and EnemyAI.new.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BlasterConstants = require(ReplicatedStorage.Blaster.Constants)
local Constants = require(ReplicatedStorage.Enemy.Constants)
local RagdollController = require(ReplicatedStorage.Modules.RagdollController)
local templateConfig = require(ReplicatedStorage.Enemy.templateConfig)

-- The overhead name/health billboard. Lives here rather than on the templates because
-- stripClientScripts below destroys every BaseScript in a freshly cloned rig -- baked onto a
-- template, the two Scripts driving this billboard would be destroyed before ever running.
local enemyGuiTemplate = ReplicatedStorage.GuiTemplates:WaitForChild("EnemyGUI")

local EnemyRig = {}

-- Living enemies must not collide with EACH OTHER.
--
-- Every type spawns from a SINGLE point with a cap of 10, so rigs are routinely placed on top of
-- one another -- isSpawnPointClear only keeps them away from PLAYERS, nothing stops a rig landing
-- inside its own kind. Two interpenetrating Humanoids each treat the other as ground and step up
-- onto it, so they climb each other indefinitely. Measured live before this fix: a constant +7.7
-- studs/s with no decay at all (a collision impulse would decay under gravity), one rig reaching
-- 365 studs, with the closest pair pinned at ~1.57 studs for the whole run. That is the "enemies
-- flying straight up when they clash" report.
--
-- Same mechanism RagdollController already uses for corpses: one collision group that simply does
-- not collide with itself. ONLY the self-pairing is disabled, so enemies still collide with the
-- world and with players, and weapon raycasts -- which run against the default group -- are
-- unaffected.
local ENEMY_COLLISION_GROUP = "EnemyCharacter"
local collisionGroupReady = false

local function ensureCollisionGroup(): boolean
	if collisionGroupReady then
		return true
	end
	local ok = pcall(function()
		-- Registering twice throws, and this may already exist from a previous call.
		if not PhysicsService:IsCollisionGroupRegistered(ENEMY_COLLISION_GROUP) then
			PhysicsService:RegisterCollisionGroup(ENEMY_COLLISION_GROUP)
		end
		PhysicsService:CollisionGroupSetCollidable(ENEMY_COLLISION_GROUP, ENEMY_COLLISION_GROUP, false)
	end)
	collisionGroupReady = ok
	return ok
end

-- Strips everything that only makes sense for a player-controlled character. The runtime rig ships
-- with an `Animate` LocalScript, and the blaster Tool carries the client-side controller script that
-- drives the viewmodel, camera recoil and HUD -- none of which an enemy has or should run.
local function stripClientScripts(root: Instance): number
	local removed = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Prepares the Tool that came with a cloned template. The weapon is part of the rig rather than
-- looked up by name, so "which gun does this enemy carry" is an editable property of the template.
local function prepareWeapon(character: Model, config): Tool?
	local weapon = character:FindFirstChildOfClass("Tool")
	if not weapon then
		-- Fall back to the shared weapon name for a template that ships without one.
		local fallback = ServerStorage.Weapons:FindFirstChild(Constants.ENEMY_WEAPON_NAME)
		if not fallback or not fallback:IsA("Tool") then
			warn(`EnemySpawner: {character.Name} has no Tool and no "{Constants.ENEMY_WEAPON_NAME}" in ServerStorage.Weapons`)
			return nil
		end
		weapon = fallback:Clone()
		weapon.Parent = character
	end

	stripClientScripts(weapon)
	weapon:SetAttribute(BlasterConstants.AMMO_ATTRIBUTE, weapon:GetAttribute(BlasterConstants.MAGAZINE_SIZE_ATTRIBUTE))
	weapon:SetAttribute(BlasterConstants.RELOADING_ATTRIBUTE, false)

	-- Enemy-specific damage. Because this Tool belongs to a clone, writing the attribute here tunes
	-- this enemy's output only: the ServerStorage.Weapons template a player picks up is untouched. The resolver reads
	-- damage off whichever Tool it was handed, so nothing in the shared shot path knows about this.
	if config.damageOverride then
		weapon:SetAttribute(BlasterConstants.DAMAGE_ATTRIBUTE, config.damageOverride)
	end

	return weapon
end

-- Clones `template` into an enemy body, not yet in the world: renamed "Enemy", scripts stripped, weapon
-- prepared, health and speeds from the template's attributes, the EnemyGUI nameplate reading `label`
-- (upper-cased), tag Constants.ENEMY_TAG and attribute EnemyTemplate = the template's name. Returns the
-- character, its weapon and its config, or nil (with a warning) for an unusable template.
function EnemyRig.build(template: Model, label: string): (Model?, Tool?, any)
	local character = template:Clone()
	character.Name = "Enemy"
	-- Safety net: the template is already script-free, but a hand-edited one might not be, and an
	-- enemy must carry no client-side scripts.
	stripClientScripts(character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not character.PrimaryPart then
		character:Destroy()
		warn(`EnemySpawner: template {template.Name} has no Humanoid or no PrimaryPart`)
		return nil, nil, nil
	end

	-- This enemy type's tunables, read off the attributes the designer set on the template.
	local config = templateConfig.read(character)

	local weapon = prepareWeapon(character, config)
	if not weapon then
		character:Destroy()
		return nil, nil, nil
	end

	humanoid.MaxHealth = config.maxHealth
	humanoid.Health = config.maxHealth
	humanoid.WalkSpeed = config.walkSpeed

	-- Replaces Roblox's own built-in nameplate, which is switched off on the templates themselves.
	-- Attached here, well after stripClientScripts ran above, so the two Scripts riding inside this
	-- clone survive -- that ordering is the whole reason this needs no further wiring.
	local head = character:FindFirstChild("Head")
	if head then
		local enemyGui = enemyGuiTemplate:Clone()
		-- The rig is named "Enemy" for every type (targeting, tagging and damage validation all key on
		-- that), so the nameplate cannot read the model name -- it would say "Enemy" above every NPC.
		-- The label is the real one: Thug, Smuggler, Offender, Police, and so on.
		local nameLabel = enemyGui:FindFirstChild("Name", true)
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = string.upper(label)
		end
		enemyGui.Parent = head
	end

	-- Tagged before the AI starts, because canDamageHumanoid reads this tag to decide that enemies
	-- do not shoot each other.
	CollectionService:AddTag(character, Constants.ENEMY_TAG)
	-- Which template this clone came from. The clone is renamed to the generic "Enemy" above, so
	-- without this nothing downstream can tell a dead Thug from any other enemy type -- which is
	-- exactly what a kill-count quest objective needs.
	character:SetAttribute("EnemyTemplate", template.Name)

	return character, weapon, config
end

-- Puts a built body into the world at `cframe` under `parent`: equipped, in the no-self-collision group,
-- physics pinned to the server, ready to ragdoll. EnemyAI.new comes next.
function EnemyRig.place(character: Model, weapon: Tool, cframe: CFrame, parent: Instance)
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	character:PivotTo(cframe)
	character.Parent = parent

	-- Equipping is what creates the normal Tool grip joint, exactly as it did before the templates
	-- existed -- so the grip structure the ragdoll relies on staying rigid is unchanged.
	pcall(function()
		humanoid:EquipTool(weapon)
	end)

	-- These characters are driven entirely by the server, so pin their physics to the server. Without
	-- this the engine can hand ownership to whichever client is nearest, which makes server-driven
	-- movement visibly stutter for everyone else.
	--
	-- The same pass assigns the no-self-collision group (see ENEMY_COLLISION_GROUP above). Done here
	-- rather than on the templates because it has to cover the equipped Tool's parts too -- those are
	-- welded into the rig and would otherwise grind against a neighbouring enemy.
	local useCollisionGroup = ensureCollisionGroup()
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			if useCollisionGroup then
				part.CollisionGroup = ENEMY_COLLISION_GROUP
			end
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end

	-- Cleared before the enemy can ever die: if BreakJointsOnDeath is still true at the moment of
	-- death the engine tears the rig apart and there is nothing coherent left to ragdoll.
	RagdollController.prepare(character)
end

return EnemyRig
