RegisterNetEvent('playermanager:pong')

function GetIdentifier(id, kind)
	local identifiers = {}

	for _, identifier in ipairs(GetPlayerIdentifiers(id)) do
		local prefix = kind .. ':'
		local len = string.len(prefix)
		if string.sub(identifier, 1, len) == prefix then
			return string.sub(identifier, len + 1)
		end
	end

	return nil
end

function GetPlayerId(id)
	local players = GetPlayers()

	for _, playerId in ipairs(players) do
		if playerId == id then
			return id
		end
	end

	id = string.lower(id)
	for _, playerId in ipairs(players) do
		local playerName = string.lower(GetPlayerName(playerId))
		if playerName == id then
			return playerId
		end
	end

	return nil
end

function StoreBanReason(license, reason)
	MySQL.Async.fetchScalar(
		'SELECT id FROM ban WHERE id = @id',
		{
			['@id'] = license
		},
		function(id)
			if id then
				MySQL.Async.execute(
					'UPDATE ban SET reason = @reason WHERE id = @id',
					{
						['@reason'] = reason,
						['@id'] = id
					})
			else
				MySQL.Async.execute(
					'INSERT INTO ban (id, reason) VALUES (@id, @reason)',
					{
						['@id'] = license,
						['@reason'] = reason
					})
			end
		end)

end

AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
	local player = source
	local license = GetIdentifier(player, 'license')

	print(string.format('Connecting: %s %s %s', name, license, GetPlayerEndpoint(player)))

	deferrals.defer()

	Wait(0)

	deferrals.update('Checking bans...')

	MySQL.ready(function()
		MySQL.Async.fetchScalar('SELECT reason FROM ban WHERE id = @id',
		{
			['@id'] = license
		},
		function(banReason)
			Wait(0)

			if banReason then
				deferrals.done(string.format('Banned: %s', banReason))
			else
				deferrals.done()
			end
		end)
	end)
end)

AddEventHandler('playerDropped', function(reason)
	print(string.format('Dropped: %s %s (%s)', GetPlayerName(source), GetPlayerEndpoint(source), reason))
end)

AddEventHandler('playermanager:pong', function()
	print('Received pong from ' .. source)
end)

RegisterCommand('ban', function(source, args, user)
	if #args < 2 then
		print('You must specify a player and a reason')
		return
	end

	local id = GetPlayerId(args[1])
	local reason = args[2]

	if id then
		local license = GetIdentifier(id, 'license')
		MySQL.ready(function()
			StoreBanReason(license, reason)
		end)
		DropPlayer(id, 'Banned: ' .. reason)
	else
		MySQL.ready(function()
			StoreBanReason(args[1], reason)
		end)
	end
end, true)

RegisterCommand('kick', function(source, args, user)
	if #args < 2 then
		print('You must specify a player and reason')
		return
	end

	local id = GetPlayerId(args[1])
	local reason = args[2]

	if id then
		DropPlayer(id, 'Kicked: ' .. reason)
	else
		print('No player with name or ID: ' .. args[1])
	end
end, true)

RegisterCommand('unban', function(source, args, user)
	if #args < 1 then
		print('You must specify a license to unban')
		return
	end

	local license = args[1]

	MySQL.ready(function()
		MySQL.Async.execute('DELETE FROM ban WHERE id = @id', {
			['@id'] = license
		})
	end)
end, true)

RegisterCommand('status', function(source, args, user)
	for _, id in ipairs(GetPlayers()) do
		print(string.format('[%d] %s %s %s', id, GetPlayerName(id), GetIdentifier(id, 'license'), GetPlayerEndpoint(id)))
	end
end, true)

RegisterCommand('ping', function(source, args, raw)
	local players

	if #args > 0 then
		players = {}

		for _, arg in ipairs(args) do
			table.insert(players, tonumber(arg))
		end
	else
		players = GetPlayers()
	end

	for _, player in ipairs(players) do
		local id = GetPlayerId(player)

		if id then
			TriggerClientEvent('playermanager:ping', id)
			print('Sent ping to ' .. player)
		else
			print('No splayer with name or ID: ' .. player)
		end
	end
end, true)
