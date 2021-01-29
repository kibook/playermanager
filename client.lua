RegisterNetEvent('playermanager:ping')

AddEventHandler('playermanager:ping', function()
	TriggerServerEvent('playermanager:pong')
end)

CreateThread(function()
	TriggerEvent('chat:addSuggestion', '/kick', 'Kick a player', {
		{name = 'player', help = 'Player name or ID'},
		{name = 'reason', help = 'Reason for kicking'}
	})
	TriggerEvent('chat:addSuggestion', '/ban', 'Ban a player', {
		{name = 'player', help = 'Player name or ID'},
		{name = 'reason', help = 'Reason for banning'}
	})
	TriggerEvent('chat:addSuggestion', '/unban', 'Unban a player', {
		{name = 'license', help = 'The license identifier of the player to unban'}
	})
	TriggerEvent('chat:addSuggestion', '/ping', 'Test player connections', {
		{name = 'player', help = 'Player name or ID. Multiple can be specified. Omit to ping all players.'}
	})
	TriggerEvent('chat:addSuggestion', '/status', 'Show connected players', {})
end)
