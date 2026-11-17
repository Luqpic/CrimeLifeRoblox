-- Drives the Illegal Supplier's conversation, using the SAME DialogModule engine and the SAME
-- billboard response UI as the "FPS System" place's quest givers -- this file is the direct
-- counterpart of that place's QuestDialogueController and is deliberately shaped like it, so the
-- merge is a folder union rather than a reconciliation.
--
-- WHY THE SUPPLIER AT ALL: mechanically it is a mini-quest. You walk up, it asks whether you are
-- carrying, you hand over and get paid. That is the same shape as "accept / turn in", so it gets
-- the same presentation rather than a second, parallel dialog system.
--
-- Deliberately lives in StarterPlayerScripts rather than on the NPC: a LocalScript parented into
-- Workspace never executes (Roblox only runs them under the Character, Backpack, PlayerGui,
-- PlayerScripts or ReplicatedFirst), so an NPC-parented copy would be silently inert.
--
-- WHAT MOVED SERVER -> CLIENT: the prompt used to be answered by SuppliesServer, which fired an
-- OpenSupplierDialog remote back at the one player to raise a ScreenGui. The conversation is now
-- opened straight off prompt.Triggered here, exactly as the quest NPCs do it. The outcome is still
-- fully server-authoritative -- SubmitSupplierChoice/SupplierResult are untouched, and CarryState
-- is still re-checked at the moment "yes" is actually clicked, never upfront.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DialogModule = require(ReplicatedStorage:WaitForChild("DialogModule"))
local remotes = ReplicatedStorage:WaitForChild("HeistShared"):WaitForChild("Remotes")
local submitChoice = remotes:WaitForChild("SubmitSupplierChoice")
local supplierResult = remotes:WaitForChild("SupplierResult")

local player = Players.LocalPlayer

-- Dialog 1 is the offer; dialog 2 is the "where do I find these" explainer. Two entries rather than
-- one mutated in place, because the explainer is reachable from the offer AND leads back into the
-- same sale -- it is a second node in the conversation, not a different state of the first.
local OFFER_TEXT = "You holding? I move supplies, no questions, cash on the spot."
local OFFER_RESPONSES = {
	"Yeah, take them off my hands.",
	"Where do I even find supplies?",
	"Not today.",
}

-- Accurate to where supplies actually come from: SlowFoods and Gas2Go both spawn carryable supply
-- objects worth 10,000, and the NewsStation's camera is worth 20,000. Kept factual on purpose -- a
-- hint that sends the player somewhere with no supplies is worse than no hint.
local EXPLAIN_TEXT = "Hit the diner or the gas station and grab what's not nailed down. "
	.. "The news station keeps a camera that's worth double. Carry it back here."
local EXPLAIN_RESPONSES = {
	"Actually, I'm carrying some now.",
	"Got it.",
}

local QUIP_DECLINE = "Suit yourself."
local QUIP_GO_LOOK = "Don't keep me waiting."
local QUIP_SOLD = "Pleasure doing business."
local QUIP_EMPTY = "You're not carrying anything. Come back when you are."

local npcModel = workspace:WaitForChild("Illegal Supplier")
-- The rig is a child model of the same name; the prompt lives on a sibling Interaction part, so the
-- two are resolved separately rather than assuming one contains the other.
local rig = npcModel:WaitForChild("Illegal Supplier")
local prompt = npcModel:WaitForChild("Interaction"):WaitForChild("ProximityPrompt")

local dialogObject = DialogModule.new("Illegal Supplier", rig, prompt)
dialogObject.dialogs[1] = { text = OFFER_TEXT, responses = OFFER_RESPONSES }
dialogObject.dialogs[2] = { text = EXPLAIN_TEXT, responses = EXPLAIN_RESPONSES }

-- Set while a sale is in flight. SupplierResult is a broadcast-shaped remote with no conversation
-- id on it, so without this a result arriving after the player has already walked away (which
-- closes the conversation from DialogModule's own distance loop) would type a quip onto a plate
-- that is no longer on screen.
local awaitingResult = false

local function sell()
	awaitingResult = true
	submitChoice:FireServer()
end

prompt.Triggered:Connect(function(triggeringPlayer)
	if triggeringPlayer ~= player then
		return
	end
	awaitingResult = false
	dialogObject:triggerDialog(triggeringPlayer, 1)
end)

dialogObject.responded:Connect(function(responseNum: number, dialogNum: number)
	if dialogNum == 1 then
		if responseNum == 1 then
			sell()
		elseif responseNum == 2 then
			-- Second node, same conversation: triggerDialog re-types into the same plate and re-arms
			-- the response rows, so no hideGui in between.
			dialogObject:triggerDialog(player, 2)
		else
			dialogObject:hideGui(QUIP_DECLINE)
		end
	elseif dialogNum == 2 then
		if responseNum == 1 then
			sell()
		else
			dialogObject:hideGui(QUIP_GO_LOOK)
		end
	end
end)

-- Deliberately NOT closed here on "sold": the server fires RobberySuccess separately, and
-- HeistClient's CashClaimVFX already answers that with the cash burst. Closing on the quip keeps
-- the two from talking over each other.
supplierResult.OnClientEvent:Connect(function(outcome)
	if not awaitingResult then
		return
	end
	awaitingResult = false
	if outcome == "sold" then
		dialogObject:hideGui(QUIP_SOLD)
	elseif outcome == "no_supplies" then
		dialogObject:hideGui(QUIP_EMPTY)
	elseif outcome == "bank_only" then
		-- Heist layers 2026-11-17: the server's toast says why; just close the plate.
		dialogObject:hideGui()
	end
end)

-- Dying mid-conversation leaves the object thinking it is still active, so the next attempt to talk
-- would start a second response loop on top of the first. Closing it on respawn resets that state
-- and restores the proximity prompt this conversation disabled when it opened.
player.CharacterAdded:Connect(function()
	awaitingResult = false
	if dialogObject.active then
		dialogObject:hideGui()
	end
end)
