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

function StoreBanReason(license, name, reason)
	exports.ghmattimysql:scalar(
		"SELECT id FROM ban WHERE id = @id",
		{
			["id"] = license
		},
		function(id)
			if id then
				exports.ghmattimysql:execute(
					"UPDATE ban SET reason = @reason WHERE id = @id",
					{
						["reason"] = reason,
						["id"] = id
					})
			else
				exports.ghmattimysql:execute(
					"INSERT INTO ban (id, name, reason) VALUES (@id, @reason)",
					{
						["id"] = license,
						["name"] = name,
						["reason"] = reason
					})
			end
		end)
end

function StoreTempBanReason(license, name, reason, expires)
	exports.ghmattimysql:scalar(
		"SELECT id FROM ban WHERE id = @id",
		{
			["id"] = license
		},
		function(id)
			if id then
				exports.ghmattimysql:execute(
					"UPDATE ban SET reason = @reason, expires = @expires WHERE id = @id",
					{
						["reason"] = reason,
						["expires"] = expires,
						["id"] = id
					})
			else
				exports.ghmattimysql:execute(
					"INSERT INTO ban (id, name, reason, expires) VALUES (@id, @name, @reason, @expires)",
					{
						["id"] = license,
						["name"] = name,
						["reason"] = reason,
						["expires"] = expires
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

function ClearExpiredBans()
	exports.ghmattimysql:execute("DELETE FROM ban WHERE expires < NOW()")
end

function Log(format, ...)
	print(string.format(format, ...))
end

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
	local player = source
	local license = GetIdentifier(player, "license")
	local ip = GetPlayerEndpoint(player)

	Log("Connecting: %s %s %s", name, license, ip)

	deferrals.defer()

	Wait(0)

	deferrals.update("Checking bans...")

	exports.ghmattimysql:execute(
		"SELECT reason, DATE_FORMAT(expires, '%Y-%m-%d %H:%i:%s') as expires FROM ban WHERE id = @id",
		{
			["id"] = license
		},
		function(results)
			Wait(0)

			if results and results[1] then
				local banReason = results[1].reason
				local expires = results[1].expires

				local message

				if expires then
					message = string.format("Banned until %s: %s", expires, banReason)
				else
					message = string.format("Banned: %s", banReason)
				end

				deferrals.done(message)

				Log(message)
			else
				deferrals.done()
			end
		end)
end)

AddEventHandler("playerDropped", function(reason)
	Log("Dropped: %s %s (%s)", GetPlayerName(source), GetPlayerEndpoint(source), reason)
end)

AddEventHandler("playermanager:pong", function()
	print("Received pong from " .. source)
end)

RegisterCommand("ban", function(source, args, raw)
	if #args < 2 then
		print("Usage: ban <player> <reason>")
		return
	end

	local ref = args[1]

	local id = GetPlayerId(ref)

	table.remove(args, 1)
	local reason = table.concat(args, " ")

	if id then
		local license = GetIdentifier(id, "license")
		local name = GetPlayerName(id)

		StoreBanReason(license, name, reason)

		DropPlayer(id, "Banned: " .. reason)
	else
		StoreBanReason(ref, "", reason)
	end
end, true)

RegisterCommand("tempban", function(source, args, raw)
	if #args < 3 then
		print("Usage: ban <player> <expires> <reason>")
		return
	end

	local ref = args[1]
	local expires = args[2]

	local id = GetPlayerId(ref)

	table.remove(args, 1)
	table.remove(args, 1)
	local reason = table.concat(args, " ")

	if id then
		local license = GetIdentifier(id, "license")
		local name = GetPlayerName(id)

		StoreTempBanReason(license, name, reason, expires)

		DropPlayer(id, "Banned until " .. expires .. ": " .. reason)
	else
		StoreTempBanReason(ref, "", reason, expires)
	end
end, true)

RegisterCommand("kick", function(source, args, raw)
	if #args < 2 then
		print("You must specify a player and reason")
		return
	end

	local ref = args[1]

	table.remove(args, 1)
	local reason = table.concat(args, " ")

	local id = GetPlayerId(ref)

	if id then
		DropPlayer(id, "Kicked: " .. reason)
	else
		print("No player with name or ID: " .. ref)
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

RegisterCommand("unban", function(source, args, raw)
	if #args < 1 then
		print("You must specify a license to unban")
		return
	end

	local license = args[1]

	exports.ghmattimysql:execute("DELETE FROM ban WHERE id = @id", {
		["id"] = license
	})
end, true)

RegisterCommand("listbans", function(source, args, raw)
	exports.ghmattimysql:execute("SELECT id, name, reason, DATE_FORMAT(expires, '%Y-%m-%d %H:%i:%s') as expires FROM ban", {}, function(results)
		if results then
			for _, ban in ipairs(results) do
				print(ban.id, ban.name, ban.expires, ban.reason)
			end
		end
	end)
end, true)

RegisterCommand("status", function(source, args, raw)
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

CreateThread(function()
	while true do
		ClearExpiredBans()
		Wait(30000)
	end
end)
