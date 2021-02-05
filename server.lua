RegisterNetEvent("playermanager:pong")

function GetIdentifier(id, kind)
	local prefix = kind .. ":"

	for _, identifier in ipairs(GetPlayerIdentifiers(id)) do
		if string.sub(identifier, 1, #prefix) == prefix then
			return identifier
		end
	end

	return nil
end

function GetPlayerId(id)
	local players = GetPlayers()

	for _, playerId in ipairs(players) do
		if playerId == id then
			return tonumber(playerId)
		end
	end

	id = string.lower(id)

	for _, playerId in ipairs(players) do
		if string.lower(GetPlayerName(playerId)) == id then
			return tonumber(playerId)
		end
	end

	return nil
end

function StoreBanReason(license, reason)
	MySQL.Async.fetchScalar(
		"SELECT id FROM ban WHERE id = @id",
		{
			["id"] = license
		},
		function(id)
			if id then
				MySQL.Async.execute(
					"UPDATE ban SET reason = @reason WHERE id = @id",
					{
						["reason"] = reason,
						["id"] = id
					})
			else
				MySQL.Async.execute(
					"INSERT INTO ban (id, reason) VALUES (@id, @reason)",
					{
						["id"] = license,
						["reason"] = reason
					})
			end
		end)

end

function GetPlayersFromArgs(args)
	local players

	if #args > 0 then
		players = {}

		for _, arg in ipairs(args) do
			local id = GetPlayerId(arg)

			if id then
				table.insert(players, id)
			else
				print("No player with name or ID: " .. arg)
			end
		end
	else
		players = GetPlayers()
	end

	return players
end

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
	local player = source
	local license = GetIdentifier(player, "license")

	print(string.format("Connecting: %s %s %s", name, license, GetPlayerEndpoint(player)))

	deferrals.defer()

	Wait(0)

	deferrals.update("Checking bans...")

	MySQL.ready(function()
		MySQL.Async.fetchScalar("SELECT reason FROM ban WHERE id = @id",
		{
			["id"] = license
		},
		function(banReason)
			Wait(0)

			if banReason then
				deferrals.done(string.format("Banned: %s", banReason))
				print(string.format("Banned: %s %s: %s", name, license, banReason))
			else
				deferrals.done()
			end
		end)
	end)
end)

AddEventHandler("playerDropped", function(reason)
	print(string.format("Dropped: %s %s (%s)", GetPlayerName(source), GetPlayerEndpoint(source), reason))
end)

AddEventHandler("playermanager:pong", function()
	print("Received pong from " .. source)
end)

RegisterCommand("ban", function(source, args, user)
	if #args < 2 then
		print("You must specify a player and a reason")
		return
	end

	local id = GetPlayerId(args[1])
	local reason = args[2]

	if id then
		local license = GetIdentifier(id, "license")
		MySQL.ready(function()
			StoreBanReason(license, reason)
		end)
		DropPlayer(id, "Banned: " .. reason)
	else
		MySQL.ready(function()
			StoreBanReason(args[1], reason)
		end)
	end
end, true)

RegisterCommand("kick", function(source, args, user)
	if #args < 2 then
		print("You must specify a player and reason")
		return
	end

	local id = GetPlayerId(args[1])
	local reason = args[2]

	if id then
		DropPlayer(id, "Kicked: " .. reason)
	else
		print("No player with name or ID: " .. args[1])
	end
end, true)

RegisterCommand("kickall", function(source, args, raw)
	if #args < 1 then
		print("You must specify a reason")
		return
	end

	local reason = args[1]

	for _, player in ipairs(GetPlayers()) do
		DropPlayer(player, "Kicked: " .. reason)
	end
end, true)

RegisterCommand("unban", function(source, args, user)
	if #args < 1 then
		print("You must specify a license to unban")
		return
	end

	local license = args[1]

	MySQL.ready(function()
		MySQL.Async.execute("DELETE FROM ban WHERE id = @id", {
			["@id"] = license
		})
	end)
end, true)

RegisterCommand("listbans", function(source, args, raw)
	MySQL.ready(function()
		MySQL.Async.fetchAll("SELECT id, reason FROM ban", {}, function(results)
			if results then
				for _, ban in ipairs(results) do
					print(ban.id, ban.reason)
				end
			end
		end)
	end)
end, true)

RegisterCommand("status", function(source, args, user)
	for _, id in ipairs(GetPlayersFromArgs(args)) do
		print(string.format("[%d] %s %s %s %d", id, GetPlayerName(id), GetIdentifier(id, "license"), GetPlayerEndpoint(id), GetPlayerPing(id)))
	end
end, true)

RegisterCommand("ping", function(source, args, raw)
	for _, player in ipairs(GetPlayersFromArgs(args)) do
		TriggerClientEvent("playermanager:ping", player)
		print("Sent ping to " .. player)
	end
end, true)

RegisterCommand("spectate", function(source, args, raw)
	if #args > 0 then
		local id = GetPlayerId(args[1])

		if id then
			TriggerClientEvent("playermanager:spectate", source, id)
		else
			print("No player with name or ID: " .. args[1])
		end
	else
		TriggerClientEvent("playermanager:spectate", source)
	end
end, true)

RegisterCommand("summon", function(source, args, raw)
	for _, player in ipairs(GetPlayersFromArgs(args)) do
		if player ~= source then
			TriggerClientEvent("playermanager:summon", player, source)
		end
	end
end, true)
