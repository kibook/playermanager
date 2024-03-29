RegisterNetEvent("playermanager:pong")
RegisterNetEvent("playermanager:summon")

local function getIdentifier(id, kind)
	local prefix = kind .. ":"

	for _, identifier in ipairs(GetPlayerIdentifiers(id)) do
		if string.sub(identifier, 1, #prefix) == prefix then
			return identifier
		end
	end

	return nil
end

local function getPlayerId(id)
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

local sql = {}

function sql.scalar(query, params)
	local p = promise.new()

	exports.oxmysql:scalar(query, params, function(result)
		p:resolve(result)
	end)

	return p
end

function sql.execute(query, params)
	local p = promise.new()

	exports.oxmysql:execute(query, params, function(result)
		if result then
			p:resolve(result)
		else
			p:reject("Executing failed")
		end
	end)

	return p
end

function sql.transaction(query, params)
	local p = promise.new()

	exports.oxmysql:transaction(query, params, function(success)
		if success then
			p:resolve()
		else
			p:reject("Transaction failed")
		end
	end)

	return p
end

local function getBanId(identifier)
	return sql.scalar("SELECT id FROM playermanager_ban WHERE identifier = @identifier", {["identifier"] = identifier})
end

local function storeBanReason(identifier, name, reason)
	return getBanId(identifier):next(function(id)
		if id then
			return sql.execute(
				"UPDATE playermanager_ban SET reason = @reason WHERE id = @id",
				{
					["reason"] = reason,
					["id"] = id
				})
		else
			return sql.execute(
				"INSERT INTO playermanager_ban (identifier, name, reason) VALUES (@identifier, @name, @reason)",
				{
					["identifier"] = identifier,
					["name"] = name,
					["reason"] = reason
				})
		end
	end)
end

local function storeTempBanReason(identifier, name, reason, expires)
	return getBanId(identifier):next(function(id)
		if id then
			return sql.execute(
				"UPDATE playermanager_ban SET reason = @reason, expires = @expires WHERE id = @id",
				{
					["reason"] = reason,
					["expires"] = expires,
					["id"] = id
				})
		else
			return sql.execute(
				"INSERT INTO playermanager_ban (identifier, name, reason, expires) VALUES (@identifier, @name, @reason, @expires)",
				{
					["identifier"] = identifier,
					["name"] = name,
					["reason"] = reason,
					["expires"] = expires
				})
		end
	end)
end

local function getPlayersFromArgs(args)
	local players

	if #args > 0 then
		players = {}

		for _, arg in ipairs(args) do
			local id = getPlayerId(arg)

			if id then
				table.insert(players, id)
			else
				print("No player with name or ID: " .. arg)
			end
		end
	else
		players = GetPlayers()
	end

	table.sort(players)

	return players
end

local function clearExpiredBans()
	return sql.execute("DELETE FROM playermanager_ban WHERE expires < NOW()")
end

local function log(format, ...)
	print(string.format(format, ...))
end

local function getMaxClients()
	return GetConvarInt("sv_maxclients", 32)
end

local function unban(identifier)
	return sql.execute("DELETE FROM playermanager_ban WHERE identifier = @identifier", {
		["identifier"] = identifier
	})
end

local queue = {
	players = {}
}

function queue:push(player)
	table.insert(self.players, player)
end

function queue:pop()
	table.remove(self.players, 1)
end

function queue:getPosition(player)
	for i = 1, #self.players do
		if self.players[i] == player then
			return i
		end
	end
end

function queue:getLength()
	return #self.players
end

function queue:isFull()
	if Config.queue.size then
		return self:getLength() >= Config.queue.size
	else
		return false
	end
end

local function enqueuePlayer(source, name, ip, deferrals)
	deferrals.update("Checking queue...")

	Citizen.Wait(0)

	if queue:isFull() then
		deferrals.done("The queue is currently full. Please try joining again later.")
		log("Dropped: %s %s (Queue full)", name, ip)
	else
		queue:push(source)

		while true do
			local numPlayers = #GetPlayers()
			local queuePos = queue:getPosition(source)

			if not GetPlayerEndpoint(source) then
				log("Dropped: %s %s (Left queue)", name, ip)
				break
			end

			if numPlayers < getMaxClients() and queuePos <= 1 then
				break
			end

			deferrals.update(("Queue position: %d/%d"):format(queuePos, queue:getLength()))

			Citizen.Wait(1000)
		end

		queue:pop()
	end
end

local function getBan(identifier)
	return sql.execute("SELECT reason, DATE_FORMAT(expires, '%Y-%m-%d %H:%i:%s') as expires FROM playermanager_ban WHERE identifier = @identifier", {["identifier"] = identifier}):next(function(results)
		return results[1]
	end)
end

local function getAllBans()
	return sql.execute("SELECT identifier, name, reason, DATE_FORMAT(expires, '%Y-%m-%d %H:%i:%s') as expires FROM playermanager_ban")
end

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
	local source = source
	local identifier = getIdentifier(source, Config.dbIdentifier)
	local ip = GetPlayerEndpoint(source)

	log("Connecting: %s %s %s", name, identifier, ip)

	deferrals.defer()

	Citizen.Wait(0)

	deferrals.update("Checking players...")

	for _, player in ipairs(GetPlayers()) do
		local playerIdentifier = getIdentifier(player, Config.dbIdentifier)

		if identifier == playerIdentifier then
			deferrals.done("You are already connected to this server. If you are reconnecting, please wait one minute and try again. To prevent this in the future, quit the game by pressing F8 and selecting Quit instead of using the pause menu.")
			log("Dropped: %s %s (Already connected): Already connected", name, ip)
		end
	end

	Citizen.Wait(0)

	deferrals.update("Checking bans...")

	Citizen.Wait(0)

	getBan(identifier):next(function(ban)
		if ban then
			local message

			if ban.expires then
				message = string.format("Banned until %s: %s", ban.expires, ban.reason)
			else
				message = string.format("Banned: %s", ban.reason)
			end

			deferrals.done(message)

			log("Dropped: %s %s (%s)", name, ip, message)
		else
			if Config.queue.enabled then
				enqueuePlayer(source, name, ip, deferrals)
			elseif #GetPlayers() >= getMaxClients() then
				deferrals.done("The server is currently full. Please try joining again later.")
				log("Dropped: %s %s (Server full)")
			end

			deferrals.update("Now entering the server...")

			Citizen.Wait(0)

			deferrals.done()
		end
	end)
end)

AddEventHandler("playerDropped", function(reason)
	log("Dropped: %s %s (%s)", GetPlayerName(source), GetPlayerEndpoint(source), reason)
end)

AddEventHandler("playermanager:pong", function()
	print("Received pong from " .. source)
end)

AddEventHandler("playermanager:summon", function(players, coords)
	for _, player in ipairs(players) do
		TriggerClientEvent("playermanager:summon", player, coords)
	end
end)

RegisterCommand("ban", function(source, args, raw)
	if #args < 2 then
		print("Usage: ban <player> <reason>")
		return
	end

	local ref = args[1]

	local id = getPlayerId(ref)

	table.remove(args, 1)
	local reason = table.concat(args, " ")

	if id then
		local identifier = getIdentifier(id, Config.dbIdentifier)
		local name = GetPlayerName(id)

		storeBanReason(identifier, name, reason)

		DropPlayer(id, "Banned: " .. reason)
	else
		storeBanReason(ref, "", reason)
	end
end, true)

RegisterCommand("tempban", function(source, args, raw)
	if #args < 3 then
		print("Usage: ban <player> <expires> <reason>")
		return
	end

	local ref = args[1]
	local expires = args[2]

	local id = getPlayerId(ref)

	table.remove(args, 1)
	table.remove(args, 1)
	local reason = table.concat(args, " ")

	if id then
		local identifier = getIdentifier(id, Config.dbIdentifier)
		local name = GetPlayerName(id)

		storeTempBanReason(identifier, name, reason, expires)

		DropPlayer(id, "Banned until " .. expires .. ": " .. reason)
	else
		storeTempBanReason(ref, "", reason, expires)
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

	local id = getPlayerId(ref)

	if id then
		DropPlayer(id, "Kicked: " .. reason)
	else
		print("No player with name or ID: " .. ref)
	end
end, true)

RegisterCommand("kick_all", function(source, args, raw)
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
		print("You must specify an identifier to unban")
		return
	end

	local identifier = args[1]

	unban(identifier)
end, true)

RegisterCommand("list_bans", function(source, args, raw)
	getAllBans():next(function(bans)
		for _, ban in ipairs(bans) do
			print(ban.identifier, ban.name, ban.expires, ban.reason)
		end
	end)
end, true)

RegisterCommand("status", function(source, args, raw)
	for _, id in ipairs(getPlayersFromArgs(args)) do
		print(string.format("[%d] %s %s %s %d", id, GetPlayerName(id), getIdentifier(id, Config.dbIdentifier), GetPlayerEndpoint(id), GetPlayerPing(id)))
	end
end, true)

RegisterCommand("ping", function(source, args, raw)
	for _, player in ipairs(getPlayersFromArgs(args)) do
		TriggerClientEvent("playermanager:ping", player)
		print("Sent ping to " .. player)
	end
end, true)

RegisterCommand("spectate", function(source, args, raw)
	if #args > 0 then
		local id = getPlayerId(args[1])

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
	TriggerClientEvent("playermanager:getSummonCoords", source, getPlayersFromArgs(args))
end, true)

Citizen.CreateThread(function()
	while true do
		clearExpiredBans()
		Citizen.Wait(60000)
	end
end)

sql.transaction {
	[[
	CREATE TABLE IF NOT EXISTS playermanager_ban (
		id INT AUTO_INCREMENT NOT NULL,
		identifier VARCHAR(255) NOT NULL,
		name VARCHAR(255) NOT NULL,
		reason VARCHAR(255) NOT NULL,
		expires DATETIME,
		PRIMARY KEY (id)
	)
	]]
}:next(function()
	log("Successfully connected to DB")
end, function(err)
	log("Failed to connect to DB")
end)
