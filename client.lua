RegisterNetEvent('playermanager:ping')

AddEventHandler('playermanager:ping', function()
	TriggerServerEvent('playermanager:pong')
end)
