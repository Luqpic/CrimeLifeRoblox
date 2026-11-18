--!strict
-- Open items pass 2026-11-18: NewsStation's broadcast payoff, moved out of NewsStationServer unchanged so
-- BroadcastHooksSpec can drive it with a real BroadcastDesk. The desk decides when and who; these say what
-- happens then.
--   onLive(player): the city card, every participant raised to at least config.BroadcastHeatFloor stars,
--     every guard alerted.
--   onComplete(players): each participant the desk reports at the desk gets config.BroadcastPayout in the
--     bag through AddBonus (over the cap), with a toast.
--
-- deps = { bank, net, config, wanted ({getHeat(player), addHeat(player, amount, reason)}), guardPosts () -> {GuardPost} }
local BroadcastHooks = {}

function BroadcastHooks.new(deps)
	local bank, net, config, wanted = deps.bank, deps.net, deps.config, deps.wanted
	return {
		onLive = function(player)
			net:NotifyBroadcastHijacked(player.Name)
			for _, participant in ipairs(bank:GetParticipants()) do
				local heat = wanted.getHeat(participant)
				if heat < config.BroadcastHeatFloor then
					wanted.addHeat(participant, config.BroadcastHeatFloor - heat, "broadcast")
				end
			end
			for _, post in ipairs(deps.guardPosts()) do
				post:Alert()
			end
		end,
		onComplete = function(players)
			for _, player in ipairs(players) do
				if bank:AddBonus(player, config.BroadcastPayout) then
					net:Toast(player, string.format("Broadcast complete: %d added to your bag.", config.BroadcastPayout))
				end
			end
		end,
	}
end

return BroadcastHooks
