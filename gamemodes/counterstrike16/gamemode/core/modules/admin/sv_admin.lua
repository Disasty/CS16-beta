--[[
	Rank persistence and the moderation commands.

	Ranks live in data/cs16/ranks.json keyed by SteamID64, so they survive name
	changes and restarts. The only way to create the first Developer is
	cs16_setrank from the server console - the handler rejects the call
	outright if it came from a player, which is a property of where the command
	originated rather than a permission lookup that could be got wrong.
]]

local RANK_FILE = "cs16/ranks.json"

CS16.RankStore = CS16.RankStore or {}

--[[
	Ranks are stored as a list of records rather than a table keyed by
	SteamID64.

	That's not stylistic. A SteamID64 is a 17-digit number, and JSON object
	keys that look numeric come back from util.JSONToTable as Lua numbers -
	where a double can't represent 17 significant digits, so 76561197960287930
	returned as 7.6561197960288e+16. Saving worked; the corruption happened on
	reload, and the lookup silently missed every time. As a value inside a
	record the id stays a string and round-trips intact.
]]
local function SaveRanks()
	local list = {}

	for steamid, rank in pairs( CS16.RankStore ) do
		list[ #list + 1 ] = { steamid = steamid, rank = rank }
	end

	file.CreateDir( "cs16" )
	file.Write( RANK_FILE, util.TableToJSON( list, true ) )
end

local function LoadRanks()
	CS16.RankStore = {}

	if not file.Exists( RANK_FILE, "DATA" ) then return end

	local data = util.JSONToTable( file.Read( RANK_FILE, "DATA" ) or "" )
	if not data then return end

	-- Current format: a list of { steamid, rank }.
	if data[ 1 ] then
		for _, entry in ipairs( data ) do
			if istable( entry ) and entry.steamid and CS16.Ranks[ entry.rank ] then
				CS16.RankStore[ tostring( entry.steamid ) ] = entry.rank
			end
		end

		return
	end

	-- Legacy format: keyed by SteamID64. Anything that survived as a clean
	-- digit string is salvageable; the mangled scientific-notation keys are
	-- not, and are dropped.
	for id, rank in pairs( data ) do
		id = tostring( id )

		if string.match( id, "^%d+$" ) and #id >= 17 and CS16.Ranks[ rank ] then
			CS16.RankStore[ id ] = rank
		end
	end

	SaveRanks()
	MsgN( "[CS 1.6] Converted ranks.json to the current format." )
end

LoadRanks()

function CS16.ApplyRank( ply )
	local rank = CS16.RankStore[ ply:SteamID64() or "" ] or CS16.DefaultRank
	if not CS16.Ranks[ rank ] then rank = CS16.DefaultRank end

	ply:SetNWString( "CS16Rank", rank )
end

function CS16.SetRank( steamid64, rank )
	if not CS16.Ranks[ rank ] then return false end

	if rank == CS16.DefaultRank then
		CS16.RankStore[ steamid64 ] = nil
	else
		CS16.RankStore[ steamid64 ] = rank
	end
	SaveRanks()

	-- Push it to them immediately if they're on the server.
	for _, ply in ipairs( player.GetAll() ) do
		if ply:SteamID64() == steamid64 then
			CS16.ApplyRank( ply )
			ply:ChatPrint( "Your rank is now " .. CS16.Ranks[ rank ].name .. "." )
			break
		end
	end

	return true
end

hook.Add( "PlayerInitialSpawn", "CS16.ApplyRank", function( ply )
	CS16.ApplyRank( ply )
end )

--[[ Player lookup ]]

-- Accepts a SteamID64, a STEAM_0:... id, or a case-insensitive partial name.
-- Returns player, steamid64 - either may be nil if only one could be resolved.
function CS16.FindPlayer( query )
	if not query or query == "" then return nil, nil end

	if string.match( query, "^%d+$" ) and #query >= 17 then
		for _, ply in ipairs( player.GetAll() ) do
			if ply:SteamID64() == query then return ply, query end
		end
		return nil, query
	end

	if string.match( query, "^STEAM_%d:%d:%d+$" ) then
		local id64 = util.SteamIDTo64( query )
		for _, ply in ipairs( player.GetAll() ) do
			if ply:SteamID64() == id64 then return ply, id64 end
		end
		return nil, id64
	end

	local needle  = string.lower( query )
	local matches = {}

	for _, ply in ipairs( player.GetAll() ) do
		if string.find( string.lower( ply:Nick() ), needle, 1, true ) then
			matches[ #matches + 1 ] = ply
		end
	end

	if #matches == 1 then return matches[ 1 ], matches[ 1 ]:SteamID64() end
	if #matches > 1 then return nil, nil, "ambiguous" end

	return nil, nil
end

--[[ Console-only rank assignment ]]

concommand.Add( "cs16_setrank", function( ply, cmd, args )
	-- When this comes from the server console the caller is invalid. No player
	-- can reach this branch regardless of their rank.
	if IsValid( ply ) then
		ply:ChatPrint( "cs16_setrank can only be run from the server console." )
		return
	end

	local query = args[ 1 ]
	local rank  = string.lower( args[ 2 ] or "" )

	if not query or rank == "" then
		MsgN( "Usage: cs16_setrank <name|steamid|steamid64> <user|admin|developer>" )
		return
	end

	if not CS16.Ranks[ rank ] then
		MsgN( "Unknown rank '" .. rank .. "'. Valid ranks: user, admin, developer." )
		return
	end

	local target, id64, err = CS16.FindPlayer( query )
	if err == "ambiguous" then
		MsgN( "'" .. query .. "' matches more than one player. Be more specific." )
		return
	end

	if not id64 then
		MsgN( "No player found matching '" .. query .. "'. Use a SteamID64 to set a rank offline." )
		return
	end

	CS16.SetRank( id64, rank )
	MsgN( ("[CS 1.6] %s is now %s."):format(
		IsValid( target ) and target:Nick() or id64, CS16.Ranks[ rank ].name ) )
end )

concommand.Add( "cs16_listranks", function( ply )
	if IsValid( ply ) then return end

	MsgN( "[CS 1.6] Assigned ranks:" )
	local any = false
	for id64, rank in pairs( CS16.RankStore ) do
		any = true
		MsgN( ("  %s  %s"):format( id64, rank ) )
	end
	if not any then MsgN( "  (none - everyone is a User)" ) end
end )

--[[ Moderation commands ]]

local function Announce( text )
	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[CS 1.6] " .. text )
	end
end

-- Shared front half of every command that acts on another player.
local function ResolveTarget( ply, args )
	local target, _, err = CS16.FindPlayer( args[ 1 ] )

	if err == "ambiguous" then
		ply:ChatPrint( "That matches more than one player." )
		return nil
	end

	if not IsValid( target ) then
		ply:ChatPrint( "No such player." )
		return nil
	end

	if not CS16.CanTarget( ply, target ) then
		ply:ChatPrint( "You cannot target that player." )
		return nil
	end

	return target
end

CS16.AddCommand( "kick", {
	permission  = "kick",
	args        = "<player> [reason]",
	description = "Remove a player from the server.",
	callback = function( ply, args )
		local target = ResolveTarget( ply, args )
		if not target then return end

		local reason = table.concat( args, " ", 2 )
		if reason == "" then reason = "No reason given" end

		Announce( ("%s kicked %s (%s)"):format( ply:Nick(), target:Nick(), reason ) )
		target:Kick( reason )
	end,
} )

CS16.AddCommand( "ban", {
	permission  = "ban",
	args        = "<player> <minutes> [reason]",
	description = "Ban a player. Use 0 minutes for permanent.",
	callback = function( ply, args )
		local target = ResolveTarget( ply, args )
		if not target then return end

		local minutes = tonumber( args[ 2 ] )
		if not minutes or minutes < 0 then
			ply:ChatPrint( "Give a ban length in minutes (0 = permanent)." )
			return
		end

		local reason = table.concat( args, " ", 3 )
		if reason == "" then reason = "No reason given" end

		local steamid = target:SteamID()
		Announce( ("%s banned %s for %s (%s)"):format( ply:Nick(), target:Nick(),
			minutes == 0 and "ever" or ( minutes .. " min" ), reason ) )

		target:Kick( "Banned: " .. reason )

		-- banid + writeid so the ban lands in banned_user.cfg and survives a
		-- restart, which Player:Ban alone does not guarantee.
		game.ConsoleCommand( ("banid %d %s kick\n"):format( minutes, steamid ) )
		game.ConsoleCommand( "writeid\n" )
	end,
} )

CS16.AddCommand( "mute", {
	permission  = "mute",
	args        = "<player>",
	description = "Block a player's voice and text chat for this session.",
	callback = function( ply, args )
		local target = ResolveTarget( ply, args )
		if not target then return end

		target.CS16Muted = true
		Announce( ("%s muted %s"):format( ply:Nick(), target:Nick() ) )
	end,
} )

CS16.AddCommand( "unmute", {
	permission  = "mute",
	args        = "<player>",
	description = "Restore a muted player's chat.",
	callback = function( ply, args )
		local target, _, err = CS16.FindPlayer( args[ 1 ] )
		if err == "ambiguous" or not IsValid( target ) then
			ply:ChatPrint( "No such player." )
			return
		end

		target.CS16Muted = nil
		Announce( ("%s unmuted %s"):format( ply:Nick(), target:Nick() ) )
	end,
} )

CS16.AddCommand( "help", {
	description = "List the commands you can run.",
	callback = function( ply )
		ply:ChatPrint( "[CS 1.6] Available commands:" )

		for name, cmd in SortedPairs( CS16.Commands ) do
			if CS16.CanRunCommand( ply, cmd ) then
				ply:ChatPrint( ("  /%s %s - %s"):format(
					name, cmd.args or "", cmd.description or "" ) )
			end
		end
	end,
} )

--[[ Chat routing ]]

function GM:PlayerSay( ply, text, teamChat )
	local name, args = CS16.ParseCommand( text )

	if name then
		local cmd = CS16.GetCommand( name )

		if not cmd then
			ply:ChatPrint( "Unknown command. Try /help." )
			return ""
		end

		if not CS16.CanRunCommand( ply, cmd ) then
			ply:ChatPrint( "You don't have permission to do that." )
			return ""
		end

		if cmd.callback then cmd.callback( ply, args, text ) end
		return ""
	end

	if ply.CS16Muted then
		ply:ChatPrint( "You are muted." )
		return ""
	end

	return text
end

--[[
	Voice muting is enforced in core/libraries/sv_voice.lua, which owns
	PlayerCanHearPlayersVoice. Defining that here as well would mean whichever
	file loaded second silently won, taking the other's rules with it - so the
	mute check lives alongside the team rules it has to combine with.
]]
