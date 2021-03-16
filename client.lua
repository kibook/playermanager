RegisterNetEvent("playermanager:ping")
RegisterNetEvent("playermanager:spectate")
RegisterNetEvent("playermanager:summon")

AddEventHandler("playermanager:ping", function()
	TriggerServerEvent("playermanager:pong")
end)

AddEventHandler("playermanager:spectate", function(serverId)
	if serverId then
		NetworkSetInSpectatorMode(true, GetPlayerPed(GetPlayerFromServerId(serverId)))
	else
		NetworkSetInSpectatorMode(false)
	end
end)

AddEventHandler("playermanager:summon", function(serverId)
	SetEntityCoords(PlayerPedId(), GetEntityCoords(GetPlayerPed(GetPlayerFromServerId(serverId))))
end)

CreateThread(function()
	TriggerEvent("chat:addSuggestion", "/ban", "Ban a player", {
		{name = "player", help = "Player name or ID"},
		{name = "reason", help = "Reason for banning"}
	})
	TriggerEvent("chat:addSuggestion", "/kick", "Kick a player", {
		{name = "player", help = "Player name or ID"},
		{name = "reason", help = "Reason for kicking"}
	})
	TriggerEvent("chat:addSuggestion", "/ping", "Test player connections", {
		{name = "player", help = "Player name or ID. Multiple can be specified. Omit to ping all players."}
	})
	TriggerEvent("chat:addSuggestion", "/spectate", "Spectate a player", {
		{name = "player", help = "Player name or ID"}
	})
	TriggerEvent("chat:addSuggestion", "/status", "Show connected players")
	TriggerEvent("chat:addSuggestion", "/summon", "Summon a player to your position", {
		{name = "player", help = "Player name or ID. Multiple can be specified. Omit to summon all players."}
	})
	TriggerEvent("chat:addSuggestion", "/tempban", "Temporarily ban a player", {
		{name = "player", help = "Player name or ID"},
		{name = "until", help = "Date when ban expires, in the form of yyyy-mm-dd hh:mm:ss"},
		{name = "reason", help = "Reason for banning"}
	})
	TriggerEvent("chat:addSuggestion", "/unban", "Unban a player", {
		{name = "license", help = "The license identifier of the player to unban"}
	})
end)
