RegisterNetEvent("playermanager:ping")
RegisterNetEvent("playermanager:spectate")
RegisterNetEvent("playermanager:getSummonCoords")
RegisterNetEvent("playermanager:summon")

local function getTeleportTarget()
	local ped = PlayerPedId()
	local veh = GetVehiclePedIsIn(ped, false)
	local mnt = GetMount(ped)

	return (veh == 0 and (mnt == 0 and ped or mnt) or veh)
end

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

AddEventHandler("playermanager:getSummonCoords", function(players)
	TriggerServerEvent("playermanager:summon", players, GetEntityCoords(PlayerPedId()))
end)

AddEventHandler("playermanager:summon", function(coords)
	SetEntityCoords(getTeleportTarget(), coords)
end)

Citizen.CreateThread(function()
	TriggerEvent("chat:addSuggestion", "/ban", "Ban a player", {
		{name = "player", help = "Player name or ID"},
		{name = "reason", help = "Reason for banning"}
	})
	TriggerEvent("chat:addSuggestion", "/kick", "Kick a player", {
		{name = "player", help = "Player name or ID"},
		{name = "reason", help = "Reason for kicking"}
	})
	TriggerEvent("chat:addSuggestion", "/kick_all", "Kick all players", {
		{name = "reason", help = "Reason for kicking"}
	})
	TriggerEvent("chat:addSuggestion", "/list_bans", "List banned players")
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
