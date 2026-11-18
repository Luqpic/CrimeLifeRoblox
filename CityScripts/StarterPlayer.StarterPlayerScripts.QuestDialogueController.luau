-- Drives the conversation on every quest-giver NPC, one DialogModule object per NPC, built from
-- QuestConfig rather than hand-wired per quest -- adding quest #2 is a table entry, not another
-- script.
--
-- Deliberately lives in StarterPlayerScripts rather than on the NPC itself: a LocalScript parented
-- into Workspace never executes (Roblox only runs them under the Character, Backpack, PlayerGui,
-- PlayerScripts or ReplicatedFirst), so an NPC-parented copy would be silently inert. The NPC is
-- reached from here instead.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))
local questsRoot = ReplicatedStorage:WaitForChild("Quests")
local QuestConfig = require(questsRoot:WaitForChild("QuestConfig"))

local player = Players.LocalPlayer
local remotes = questsRoot:WaitForChild("Remotes")
local acceptQuestRequest = remotes:WaitForChild("AcceptQuestRequest")
local turnInQuestRequest = remotes:WaitForChild("TurnInQuestRequest")

local questsFolder = Workspace:WaitForChild("Quests")

-- No timeout on purpose. This place has StreamingEnabled, so an NPC's parts arrive when the region
-- streams in, which a slow connection can push past any fixed deadline -- and a timeout here fails
-- PERMANENTLY: the NPC is never wired again even once the player walks right up to it. Waiting
-- indefinitely inside a spawned task costs nothing and always converges.
--
-- The quest NPCs are also marked ModelStreamingMode.Persistent, so they replicate whole at join and
-- are never streamed back out -- which matters doubly now that each one carries its own response
-- buttons: streaming one out would destroy them under a live DialogModule.

-- The rig ships with the stock Animate LocalScript, but a LocalScript parented into Workspace never
-- executes -- so it plays nothing, and its PlayEmote BindableFunction has no OnInvoke bound. Calling
-- Invoke on an unbound BindableFunction yields forever, which would hang whatever thread triggered
-- the emote and leave the conversation (and its camera FOV source) open indefinitely.
--
-- So the two clips this NPC actually needs are driven directly, reading their ids out of the Animate
-- config children so those remain the single place the animations are configured. Playing them from
-- the client keeps this NPC's presentation per-player, consistent with the dialogue system itself,
-- which is entirely client-local.
local function setupNpcAnimation(npc: Model)
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end

	local animate = npc:FindFirstChild("Animate")
	local function idFrom(configName: string): string?
		local config = animate and animate:FindFirstChild(configName)
		local animation = config and config:FindFirstChildOfClass("Animation")
		return animation and animation.AnimationId
	end

	local idleId = idFrom("idle")
	if idleId then
		local animation = Instance.new("Animation")
		animation.AnimationId = idleId
		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if ok and track then
			track.Looped = true
			track.Priority = Enum.AnimationPriority.Idle
			track:Play()
		end
	end

	local pointId = idFrom("point")
	if not pointId then
		return nil
	end

	-- Returned rather than played here: the caller fires it on accept. Action priority plays it over
	-- the looping idle, which is left running underneath so it resumes by itself when the emote ends.
	--
	-- Loaded once and reused, so repeatedly triggering the emote restarts the one track instead of
	-- stacking a fresh track on the Animator every time.
	local pointTrack: AnimationTrack? = nil
	return function()
		if not pointTrack then
			local animation = Instance.new("Animation")
			animation.AnimationId = pointId
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if not ok or not track then
				return
			end
			pointTrack = track
			-- Stated explicitly rather than inherited. The asset happens to declare Looped = false
			-- already, but the stock Animate script does not rely on that either -- it carries its own
			-- emoteNames table where `point = false` means non-looping. Pinning it here keeps the
			-- behaviour independent of what the asset declares.
			track.Looped = false
			track.Priority = Enum.AnimationPriority.Action
		end

		local current = pointTrack :: AnimationTrack
		-- Already pointing: leave it alone rather than restarting. The prompt has HoldDuration 0, so
		-- it can be tapped repeatedly, and the accept branch is gated on the CLIENT's view of quest
		-- state -- which still reads "not accepted" until the server's attribute replicates back. Two
		-- taps in that window both take the Offer branch and both fire the emote.
		if current.IsPlaying then
			return
		end
		current:Play()
	end
end

local function wireQuestNpc(questId: string, quest)
	local npc = questsFolder:WaitForChild(quest.npcName)
	local root = npc:WaitForChild("HumanoidRootPart")
	local prompt = root:WaitForChild("ProximityPrompt")

	local dialogObject = DialogModule.new(quest.name, npc, prompt)
	local playPointEmote = setupNpcAnimation(npc)

	-- What response slots 1/2 mean for whatever was last shown. Set fresh immediately before every
	-- triggerDialog call, because the same two slots mean different things depending on quest state.
	local currentMode: string? = nil

	-- Rebuilds dialog slot 1 in place rather than appending, so every interaction reflects the
	-- player's CURRENT state instead of whatever it was the first time this NPC was talked to.
	-- DialogModule exposes `dialogs` as a plain field with no accessor, so assigning into it is
	-- consistent with how the module presents itself.
	local function refreshDialog()
		local state = player:GetAttribute(QuestConfig.stateAttributeFor(questId))
		local progress = (player:GetAttribute(QuestConfig.progressAttributeFor(questId)) :: number?) or 0
		local level = (player:GetAttribute("Level") :: number?) or 1
		local completions = (player:GetAttribute(QuestConfig.completionsAttributeFor(questId)) :: number?) or 0

		-- The givers are crooked cops paying a criminal off the books (police and wanted, 2026-11-17).
		local text, responses, mode
		if state == QuestConfig.STATE_COMPLETED then
			text = `Those {quest.objectiveEnemyNamePlural} won't be missed. Not a word, ever.`
			responses = { "Anytime." }
			mode = "Completed"
		elseif state == QuestConfig.STATE_READY_TO_TURN_IN then
			text = `Clean work. {quest.objectiveTarget} {quest.objectiveEnemyNamePlural} gone. Your envelope's ready.`
			responses = { "Turn in quest", "Not yet" }
			mode = "ReadyToTurnIn"
		elseif state == QuestConfig.STATE_ACCEPTED then
			text = `Keep it quiet. {progress}/{quest.objectiveTarget} {quest.objectiveEnemyNamePlural} cleared so far.`
			responses = { "Understood" }
			mode = "InProgress"
		elseif level < quest.requiredLevel then
			text = "Not yet, kid. Earn a rep first."
			responses = { "Okay" }
			mode = "UnderLevel"
		else
			-- A repeatable quest lands back here after being turned in, so the offer acknowledges
			-- previous runs rather than greeting the player as though they had never done it.
			text = if completions > 0
				then `Back again? {quest.description} Same envelope.`
				else `Off the books: {quest.description} Cash, no questions.`
			responses = { "Accept", "Not right now" }
			mode = "Offer"
		end

		dialogObject.dialogs[1] = { text = text, responses = responses }
		currentMode = mode
	end

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		refreshDialog()
		dialogObject:triggerDialog(triggeringPlayer, 1)
	end)

	-- Dying mid-conversation leaves the object thinking it is still active, so the next attempt to
	-- talk would start a second response loop on top of the first. Closing it on respawn resets
	-- that state and restores the proximity prompts this NPC disabled when the conversation opened.
	player.CharacterAdded:Connect(function()
		if dialogObject.active then
			dialogObject:hideGui()
		end
	end)

	dialogObject.responded:Connect(function(responseNum: number)
		if currentMode == "Offer" and responseNum == 1 then
			acceptQuestRequest:FireServer(questId)
			if playPointEmote then
				playPointEmote()
			end
			dialogObject:hideGui("You never heard it from me.")
		elseif currentMode == "ReadyToTurnIn" and responseNum == 1 then
			turnInQuestRequest:FireServer(questId)
			-- Same single, non-looping, already-playing-guarded track the accept branch uses, so
			-- claiming cannot stack a second emote or leave one running.
			if playPointEmote then
				playPointEmote()
			end
			dialogObject:hideGui("Count it later. And we never met.")
		else
			dialogObject:hideGui()
		end
	end)
end

-- Spawned per quest so one missing or slow-to-replicate NPC cannot block wiring the others.
for questId, quest in QuestConfig.Quests do
	task.spawn(wireQuestNpc, questId, quest)
end
