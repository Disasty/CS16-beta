--[[
	Map data we have to author ourselves.

	sh_zones reads what the map carries - buy zones, and bomb sites where there
	are any. Ported 1.6 maps often carry less than that: cs16_italy has two buy
	zones, nine spawns a side, and nothing else. No hostages, no rescue point,
	nothing to build a hostage round on.

	So the parts a map doesn't provide get placed by hand and saved per map.
	That is what this is: a developer stands where a hostage should be, says so,
	and it persists.

	It comes from one of two places, in this order:

	  1. data/cs16/zones/<map>.json - what this server has authored, if anything.
	  2. maps/<map>.lua next door   - what the gamemode ships for that map.

	The shipped set is the reason a fresh clone plays at all. Hostage rescue with
	no hostages and battle royale with no spawns are not modes, they're empty
	maps, and none of it can be read out of a BSP. So the layouts are committed
	as content.

	The server's own file wins outright wherever it exists, and is written the
	moment anybody places anything - so a server is never stuck with the shipped
	layout, and never has to ask permission to diverge from it. /zonesreset
	throws the local set away and goes back to the defaults; /zonesexport turns
	the local set into a replacement for the shipped file.
]]

CS16.HostageSpots = CS16.HostageSpots or {}
CS16.RescueZones  = CS16.RescueZones or {}

--[[
	Battle royale needs two more sets, and needs them badly enough that it can't
	use the map's own spawns at all.

	A 1.6 map puts nine Terrorist spawns in one room and nine Counter-Terrorist
	spawns in another, because that is what a round-based game wants. Dropped
	into a free-for-all it means ten people materialising shoulder to shoulder
	and half of them dead before they have turned around. So the spawns get
	placed by hand, spread across the whole map.

	Loot points are where guns appear, once each at the start of a match.
]]
CS16.BRSpawns = CS16.BRSpawns or {}
CS16.BRLoot   = CS16.BRLoot or {}

local DIR = "cs16/zones"

local function Path()
	return ("%s/%s.json"):format( DIR, game.GetMap() )
end

--[[
	Vectors are stored as three numbers rather than as Vectors.

	util.TableToJSON will happily write a Vector, and what comes back is a table
	that only looks like one - it has no metatable, so the first thing that
	tries to do arithmetic on it errors somewhere far away from here.
]]
local function Pack( vec )
	return { math.Round( vec.x, 1 ), math.Round( vec.y, 1 ), math.Round( vec.z, 1 ) }
end

--[[
	Tolerant of both shapes on the way back in, so one reader handles both
	sources: the JSON carries three numbers, the shipped Lua writes Vectors
	because a hand-edited file should look like Lua rather than like a dump.
]]
local function Unpack( t )
	if isvector( t ) then return t end
	return Vector( t[ 1 ] or 0, t[ 2 ] or 0, t[ 3 ] or 0 )
end

function CS16.SaveZones()
	file.CreateDir( DIR )

	local out = { hostages = {}, rescue = {}, brspawns = {}, brloot = {} }

	for _, spot in ipairs( CS16.HostageSpots ) do
		out.hostages[ #out.hostages + 1 ] = { pos = Pack( spot.pos ), yaw = math.Round( spot.yaw, 1 ) }
	end

	for _, zone in ipairs( CS16.RescueZones ) do
		out.rescue[ #out.rescue + 1 ] = { pos = Pack( zone.pos ), radius = math.Round( zone.radius, 1 ) }
	end

	for _, spot in ipairs( CS16.BRSpawns ) do
		out.brspawns[ #out.brspawns + 1 ] = { pos = Pack( spot.pos ), yaw = math.Round( spot.yaw, 1 ) }
	end

	for _, spot in ipairs( CS16.BRLoot ) do
		out.brloot[ #out.brloot + 1 ] = { pos = Pack( spot.pos ) }
	end

	file.Write( Path(), util.TableToJSON( out, true ) )
end

--[[
	The shipped defaults, one file per map.

	Included by its full Lua path rather than the short relative one. Both
	resolve, but the relative form hands back nil instead of the table the file
	returns - it loads, and the result is silently thrown away. That failure
	looks exactly like a map with no defaults, so it is worth the longer string.
]]
local MAPS = "counterstrike16/gamemode/core/modules/zones/maps/%s.lua"

local function Defaults()
	local path = MAPS:format( game.GetMap() )
	if not file.Exists( path, "LUA" ) then return end

	local ok, data = pcall( include, path )

	if not ok then
		ErrorNoHalt( ("[CS 1.6] Zone defaults for %s failed to load: %s\n"):format( game.GetMap(), data ) )
		return
	end

	return istable( data ) and data or nil
end

--[[
	Where this map's layout comes from, for the /zones readout: "server" if this
	server has authored its own, "gamemode" for the shipped set, "none" if the
	map has neither and hostage rescue and battle royale are unplayable on it.
]]
CS16.ZonesSource = "none"

function CS16.LoadZones()
	CS16.HostageSpots, CS16.RescueZones = {}, {}
	CS16.BRSpawns, CS16.BRLoot = {}, {}

	--[[
		The server's file replaces the shipped one rather than merging into it.

		Merging sounds friendlier and isn't: it has no answer for "I deleted a
		hostage the gamemode ships", which would simply come back on the next
		map load. Replacing costs nothing, because an override is always written
		out of the live tables - and those were seeded from the defaults, so the
		first edit on a stock map saves the defaults plus that edit.
	]]
	local raw  = file.Read( Path(), "DATA" )
	local data = raw and util.JSONToTable( raw )

	if raw and not data then
		ErrorNoHalt( ("[CS 1.6] %s is not valid JSON; falling back to the shipped defaults.\n"):format( Path() ) )
	end

	CS16.ZonesSource = data and "server" or "gamemode"

	data = data or Defaults()

	if not data then
		CS16.ZonesSource = "none"
		MsgN( ("[CS 1.6] No zones for %s - it ships none and this server has authored none."):format( game.GetMap() ) )
		return
	end

	for _, spot in ipairs( data.hostages or {} ) do
		CS16.HostageSpots[ #CS16.HostageSpots + 1 ] = {
			pos = Unpack( spot.pos ),
			yaw = tonumber( spot.yaw ) or 0,
		}
	end

	for _, zone in ipairs( data.rescue or {} ) do
		CS16.RescueZones[ #CS16.RescueZones + 1 ] = {
			pos    = Unpack( zone.pos ),
			radius = tonumber( zone.radius ) or 160,
		}
	end

	for _, spot in ipairs( data.brspawns or {} ) do
		CS16.BRSpawns[ #CS16.BRSpawns + 1 ] = {
			pos = Unpack( spot.pos ),
			yaw = tonumber( spot.yaw ) or 0,
		}
	end

	for _, spot in ipairs( data.brloot or {} ) do
		CS16.BRLoot[ #CS16.BRLoot + 1 ] = { pos = Unpack( spot.pos ) }
	end

	MsgN( ("[CS 1.6] Zones for %s (%s): %d hostage spot(s), %d rescue zone(s), %d BR spawn(s), %d loot point(s)."):format(
		game.GetMap(), CS16.ZonesSource == "server" and "this server's" or "shipped",
		#CS16.HostageSpots, #CS16.RescueZones, #CS16.BRSpawns, #CS16.BRLoot ) )
end

--[[
	Published to everyone rather than only to whoever placed them.

	Developers need to see what they've authored, and the rescue zones have to
	be drawn for players eventually anyway - a Counter-Terrorist dragging a
	hostage needs to know where they're taking them.
]]
function CS16.PublishZones()
	local out = { hostages = {}, rescue = {}, brspawns = {}, brloot = {} }

	for _, spot in ipairs( CS16.HostageSpots ) do
		out.hostages[ #out.hostages + 1 ] = { pos = Pack( spot.pos ), yaw = spot.yaw }
	end

	for _, zone in ipairs( CS16.RescueZones ) do
		out.rescue[ #out.rescue + 1 ] = { pos = Pack( zone.pos ), radius = zone.radius }
	end

	for _, spot in ipairs( CS16.BRSpawns ) do
		out.brspawns[ #out.brspawns + 1 ] = { pos = Pack( spot.pos ), yaw = spot.yaw }
	end

	for _, spot in ipairs( CS16.BRLoot ) do
		out.brloot[ #out.brloot + 1 ] = { pos = Pack( spot.pos ) }
	end

	net.Start( "CS16.Zones" )
		net.WriteString( util.TableToJSON( out ) )
	net.Broadcast()
end

util.AddNetworkString( "CS16.Zones" )

hook.Add( "InitPostEntity", "CS16.LoadZones", function()
	CS16.LoadZones()
end )

-- Anyone joining needs them too, and the map's zones don't change often enough
-- to be worth anything cleverer.
hook.Add( "PlayerInitialSpawn", "CS16.SendZones", function( ply )
	timer.Simple( 2, function()
		if IsValid( ply ) then CS16.PublishZones() end
	end )
end )

--[[ Where a developer is standing ]]

--[[
	Dropped to the floor rather than taken from the eye or the feet.

	A hostage placed at eye height hovers; one placed at the exact feet
	position can end up a unit inside the floor depending on where you stood.
	Tracing down from just above finds the surface either way.
]]
local function FloorUnder( ply )
	local tr = util.TraceLine( {
		start  = ply:GetPos() + Vector( 0, 0, 32 ),
		endpos = ply:GetPos() - Vector( 0, 0, 128 ),
		filter = ply,
		mask   = MASK_SOLID_BRUSHONLY,
	} )

	return tr.Hit and tr.HitPos or ply:GetPos()
end

--[[ Commands ]]

CS16.AddCommand( "hostagespot", {
	permission  = "map",
	args        = "[clear]",
	description = "Place a hostage where you stand, or clear them all.",

	callback = function( ply, args )
		if string.lower( args[ 1 ] or "" ) == "clear" then
			CS16.HostageSpots = {}
			CS16.SaveZones()
			CS16.PublishZones()

			ply:ChatPrint( "[CS 1.6] Hostage spots cleared." )
			return
		end

		CS16.HostageSpots[ #CS16.HostageSpots + 1 ] = {
			pos = FloorUnder( ply ),
			-- Facing where you were, so hostages don't all stare north.
			yaw = ply:EyeAngles().y,
		}

		CS16.SaveZones()
		CS16.PublishZones()

		ply:ChatPrint( ("[CS 1.6] Hostage spot %d placed."):format( #CS16.HostageSpots ) )
	end,
} )

CS16.AddCommand( "rescuezone", {
	permission  = "map",
	args        = "[radius|clear]",
	description = "Place a rescue zone where you stand, or clear them all.",

	callback = function( ply, args )
		local first = string.lower( args[ 1 ] or "" )

		if first == "clear" then
			CS16.RescueZones = {}
			CS16.SaveZones()
			CS16.PublishZones()

			ply:ChatPrint( "[CS 1.6] Rescue zones cleared." )
			return
		end

		-- Generous by default: a rescue point you have to stand exactly on is
		-- a worse experience than one you can walk into.
		local radius = math.Clamp( tonumber( first ) or 200, 64, 1024 )

		CS16.RescueZones[ #CS16.RescueZones + 1 ] = {
			pos    = FloorUnder( ply ),
			radius = radius,
		}

		CS16.SaveZones()
		CS16.PublishZones()

		ply:ChatPrint( ("[CS 1.6] Rescue zone %d placed, radius %d."):format(
			#CS16.RescueZones, radius ) )
	end,
} )

--[[
	Battle royale spawns.

	Placed one at a time by walking somewhere and saying so, which is slow but is
	the only way to get them spread properly - the whole reason these exist is
	that no automatic placement knows which corners of a map are worth starting
	in and which are a dead end behind a crate.

	Facing is recorded too, so you spawn looking at the room rather than at a
	wall.
]]
--[[
	Taking one out of the middle by its number.

	Undo only ever reaches the last thing placed, which is fine while you are
	laying a map out and useless afterwards - by the time you have played on it
	the spawn you want rid of is number four of ten, and clearing the lot to
	rebuild nine good ones is not a real option.

	The numbers are the ones drawn on the markers in the world, so what you
	remove is what you were looking at. Removing renumbers everything after it,
	which is unavoidable with a plain list and worth knowing before you delete
	three in a row from memory.
]]
local function RemoveByID( ply, list, raw, label )
	local id = tonumber( raw )

	if not id or id < 1 or id > #list or id % 1 ~= 0 then
		ply:ChatPrint( ("[CS 1.6] Give a %s number between 1 and %d."):format( label, #list ) )
		return
	end

	table.remove( list, id )

	CS16.SaveZones()
	CS16.PublishZones()

	ply:ChatPrint( ("[CS 1.6] Removed %s %d. %d left, renumbered."):format( label, id, #list ) )
end

CS16.AddCommand( "brspawn", {
	permission  = "map",
	args        = "[clear|undo|remove <id>]",
	description = "Place a battle royale spawn where you stand.",

	callback = function( ply, args )
		local first = string.lower( args[ 1 ] or "" )

		if first == "clear" then
			CS16.BRSpawns = {}
			CS16.SaveZones() CS16.PublishZones()
			ply:ChatPrint( "[CS 1.6] Battle royale spawns cleared." )
			return
		end

		--[[
			Undo, because these get placed dozens at a time and a mis-step
			otherwise means clearing the lot and starting again.
		]]
		if first == "undo" then
			if #CS16.BRSpawns == 0 then
				ply:ChatPrint( "[CS 1.6] No spawns to undo." )
				return
			end

			table.remove( CS16.BRSpawns )
			CS16.SaveZones() CS16.PublishZones()
			ply:ChatPrint( ("[CS 1.6] Removed the last spawn. %d left."):format( #CS16.BRSpawns ) )
			return
		end

		if first == "remove" then
			RemoveByID( ply, CS16.BRSpawns, args[ 2 ], "spawn" )
			return
		end

		CS16.BRSpawns[ #CS16.BRSpawns + 1 ] = {
			pos = FloorUnder( ply ),
			yaw = ply:EyeAngles().y,
		}

		CS16.SaveZones() CS16.PublishZones()
		ply:ChatPrint( ("[CS 1.6] Battle royale spawn %d placed."):format( #CS16.BRSpawns ) )
	end,
} )

--[[
	Where a gun appears, once each, at the start of a match. Which gun is decided
	then rather than now, so the same map plays differently every time.
]]
CS16.AddCommand( "brloot", {
	permission  = "map",
	args        = "[clear|undo|remove <id>]",
	description = "Place a battle royale weapon spawn where you stand.",

	callback = function( ply, args )
		local first = string.lower( args[ 1 ] or "" )

		if first == "clear" then
			CS16.BRLoot = {}
			CS16.SaveZones() CS16.PublishZones()
			ply:ChatPrint( "[CS 1.6] Loot points cleared." )
			return
		end

		if first == "undo" then
			if #CS16.BRLoot == 0 then
				ply:ChatPrint( "[CS 1.6] No loot points to undo." )
				return
			end

			table.remove( CS16.BRLoot )
			CS16.SaveZones() CS16.PublishZones()
			ply:ChatPrint( ("[CS 1.6] Removed the last loot point. %d left."):format( #CS16.BRLoot ) )
			return
		end

		if first == "remove" then
			RemoveByID( ply, CS16.BRLoot, args[ 2 ], "loot point" )
			return
		end

		CS16.BRLoot[ #CS16.BRLoot + 1 ] = { pos = FloorUnder( ply ) }

		CS16.SaveZones() CS16.PublishZones()
		ply:ChatPrint( ("[CS 1.6] Loot point %d placed."):format( #CS16.BRLoot ) )
	end,
} )

--[[
	Back to the shipped layout.

	The counterpart to every command above: those all write an override the
	moment they're used, and without this there would be no way back short of
	deleting a file on the host by hand. A server can try changes knowing the
	gamemode's own set is one command away.
]]
CS16.AddCommand( "zonesreset", {
	permission  = "map",
	description = "Discard this server's zone edits and go back to the shipped defaults.",

	callback = function( ply )
		if not file.Exists( Path(), "DATA" ) then
			ply:ChatPrint( "[CS 1.6] This server hasn't edited this map - already on the shipped layout." )
			return
		end

		file.Delete( Path() )
		CS16.LoadZones()
		CS16.PublishZones()

		if CS16.ZonesSource == "none" then
			ply:ChatPrint( "[CS 1.6] Edits discarded. This map ships no defaults, so it now has nothing." )
			return
		end

		ply:ChatPrint( ("[CS 1.6] Edits discarded. Back to the shipped layout: %d hostage(s), %d rescue zone(s), %d BR spawn(s), %d loot point(s)."):format(
			#CS16.HostageSpots, #CS16.RescueZones, #CS16.BRSpawns, #CS16.BRLoot ) )
	end,
} )

--[[
	Turning what's been authored here into what the gamemode ships.

	Lua rather than a copy of the JSON, because the shipped files are source:
	they get read, reviewed and hand-edited like any other file in the gamemode,
	and a wall of bare coordinate arrays is none of those things.

	It writes to data/ and asks you to move it, which is clumsy but honest -
	file.Write cannot reach outside data/ no matter where the file belongs.

	And it lands as .lua.txt rather than .lua, because file.Write refuses the
	.lua extension outright: the write is rejected and nothing is returned to
	say so, leaving an export that reports success and produces no file.
]]
-- A level-two long bracket, because what it holds is itself a block comment -
-- the plain [[ ]] form ends early on the header's own closing brackets.
local EXPORT = [==[--[[
	Shipped zone defaults for %s.

	The parts this map doesn't carry in its BSP, placed by hand and committed so
	they travel with the gamemode. Hostage rescue and battle royale are unplayable
	without them, and nothing in a ported 1.6 map provides them.

	A server that wants different ones places them in-game with /hostagespot,
	/rescuezone, /brspawn and /brloot; that saves to data/cs16/zones/%s.json,
	which wins over this file from then on. /zonesreset goes back to these,
	/zonesexport writes a replacement for this file. See sv_authored.lua.
]]

]==]

local function Num( v )
	local r = math.Round( v or 0, 1 )
	return r % 1 == 0 and tostring( math.floor( r ) ) or tostring( r )
end

local function Literal( vec )
	return ("Vector( %s, %s, %s )"):format( Num( vec.x ), Num( vec.y ), Num( vec.z ) )
end

CS16.AddCommand( "zonesexport", {
	permission  = "map",
	description = "Write this map's layout out as a shippable defaults file.",

	callback = function( ply )
		local map = game.GetMap()

		local out = { EXPORT:format( map, map ), "return {\n" }

		local sections = {
			{ "hostages", "Where the hostages stand at the start of a round.",         CS16.HostageSpots, true,  false },
			{ "rescue",   "Walk one into here and it's saved.",                        CS16.RescueZones,  false, true  },
			{ "brspawns", "Spread across the whole map - ten people, no two in a room.", CS16.BRSpawns,   true,  false },
			{ "brloot",   "One gun each, decided at match start rather than here.",    CS16.BRLoot,       false, false },
		}

		for i, section in ipairs( sections ) do
			local key, blurb, rows, yaw, radius = unpack( section )

			if i > 1 then out[ #out + 1 ] = "\n" end
			out[ #out + 1 ] = ("\t-- %s\n"):format( blurb )

			if #rows == 0 then
				out[ #out + 1 ] = ("\t%s = {},\n"):format( key )
			else
				out[ #out + 1 ] = ("\t%s = {\n"):format( key )

				for _, row in ipairs( rows ) do
					local bits = { "pos = " .. Literal( row.pos ) }
					if yaw    then bits[ #bits + 1 ] = "yaw = "    .. Num( row.yaw )    end
					if radius then bits[ #bits + 1 ] = "radius = " .. Num( row.radius ) end

					out[ #out + 1 ] = ("\t\t{ %s },\n"):format( table.concat( bits, ", " ) )
				end

				out[ #out + 1 ] = "\t},\n"
			end
		end

		out[ #out + 1 ] = "}\n"

		local dest = ("%s/%s.lua.txt"):format( DIR, map )
		file.CreateDir( DIR )
		file.Write( dest, table.concat( out ) )

		if not file.Exists( dest, "DATA" ) then
			ply:ChatPrint( ("[CS 1.6] Export failed - could not write data/%s."):format( dest ) )
			return
		end

		ply:ChatPrint( ("[CS 1.6] Written to garrysmod/data/%s"):format( dest ) )
		ply:ChatPrint( ("[CS 1.6] Move it to gamemodes/counterstrike16/gamemode/core/modules/zones/maps/%s.lua to ship it (dropping the .txt)."):format( map ) )
	end,
} )

--[[
	Whether a point can actually be walked to.

	Being on the navmesh is not the same as being connected to it. A generated
	mesh can leave islands - de_vertigo_csbeta has a single area of 567 with
	nothing adjacent to it at all - and a loot point on one looks perfectly
	healthy while being unreachable by every bot on the server.

	Tested against a spawn rather than in the abstract, because "reachable" only
	means anything relative to somewhere people start.
]]
local function Reachable( pos )
	local area = navmesh.GetNearestNavArea( pos, false, 200, false, true, -2 )
	if not IsValid( area ) then return false, "not on the navmesh" end

	if #CS16.BRSpawns == 0 then return true end

	for _, spawn in ipairs( CS16.BRSpawns ) do
		if CS16.FindPath( spawn.pos, pos ) then return true end
	end

	return false, "on the mesh but cut off from every spawn"
end

CS16.CheckBRPoint = Reachable

--[[
	Audit everything placed on this map.

	Placing thirty points by hand and finding out which are dead by watching a
	bot walk into a wall is a poor way to spend an evening.
]]
CS16.AddCommand( "brcheck", {
	permission  = "map",
	description = "Check every battle royale spawn and loot point can be reached.",

	callback = function( ply )
		if not navmesh.IsLoaded() then
			ply:ChatPrint( "[CS 1.6] No navmesh on this map, so nothing can be checked." )
			return
		end

		local bad = 0

		for i, spawn in ipairs( CS16.BRSpawns ) do
			local area = navmesh.GetNearestNavArea( spawn.pos, false, 200, false, true, -2 )

			if not IsValid( area ) then
				bad = bad + 1
				ply:ChatPrint( ("[CS 1.6] SPAWN %d is not on the navmesh."):format( i ) )
			end
		end

		for i, loot in ipairs( CS16.BRLoot ) do
			local ok, why = Reachable( loot.pos )

			if not ok then
				bad = bad + 1
				ply:ChatPrint( ("[CS 1.6] LOOT %d is unreachable - %s."):format( i, why ) )
			end
		end

		ply:ChatPrint( bad == 0
			and ("[CS 1.6] All %d spawns and %d loot points check out."):format( #CS16.BRSpawns, #CS16.BRLoot )
			or  ("[CS 1.6] %d problem(s). Move them with the C menu's REMOVE rows."):format( bad ) )
	end,
} )

--[[
	Reload the map you are on.

	Faster than typing changelevel with the map name, which is the whole point -
	authoring a layout means doing this over and over to see it fresh, and
	de_vertigo_csbeta is not a name anybody wants to type forty times.

	Deferred a moment so the reply reaches everybody before the server stops
	answering. Announced to the whole server rather than only the person who
	pressed it: being dropped without warning reads as a crash.
]]
CS16.AddCommand( "reloadmap", {
	permission  = "map",
	description = "Restart the current map.",

	callback = function( ply )
		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s is reloading the map."):format( ply:Nick() ) )
		end

		timer.Simple( 1, function()
			game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
		end )
	end,
} )

CS16.AddCommand( "zones", {
	permission  = "map",
	description = "What this map has been set up with.",

	callback = function( ply )
		local source = CS16.ZonesSource == "server" and "this server's edits"
			or CS16.ZonesSource == "gamemode" and "shipped with the gamemode"
			or "nothing authored"

		ply:ChatPrint( ("[CS 1.6] %s (%s): %d hostage spot(s), %d rescue zone(s), %d bomb site(s), %d BR spawn(s), %d loot point(s)."):format(
			game.GetMap(), source, #CS16.HostageSpots, #CS16.RescueZones, #CS16.BombSites,
			#CS16.BRSpawns, #CS16.BRLoot ) )

		for i, spot in ipairs( CS16.HostageSpots ) do
			ply:ChatPrint( ("  hostage %d: %s"):format( i, tostring( spot.pos ) ) )
		end

		for i, zone in ipairs( CS16.RescueZones ) do
			ply:ChatPrint( ("  rescue %d: %s r%d"):format( i, tostring( zone.pos ), zone.radius ) )
		end
	end,
} )
