--[[
	Map volumes - bomb sites and buy zones.

	Real CS maps carry these as brush entities, which we register in
	entities/entities/ so the engine keeps them. This collects them once the
	map is up and provides the containment tests the buy menu and bomb logic
	will need.

	The /areas tool will later be able to override or supply these for maps
	that don't ship them.
]]

CS16.BombSites = CS16.BombSites or {}
CS16.BuyZones  = CS16.BuyZones  or {}

function CS16.CacheZones()
	CS16.BombSites = {}
	CS16.BuyZones  = {}

	-- Sites are lettered in map order. dust2 lists A first; the areas tool
	-- will be able to correct this if a map disagrees.
	local letters = { "A", "B", "C", "D" }

	for i, ent in ipairs( ents.FindByClass( "func_bomb_target" ) ) do
		local mins, maxs = ent:WorldSpaceAABB()

		CS16.BombSites[ #CS16.BombSites + 1 ] = {
			entity = ent,
			letter = letters[ i ] or tostring( i ),
			mins   = mins,
			maxs   = maxs,
		}
	end

	for _, ent in ipairs( ents.FindByClass( "func_buyzone" ) ) do
		local mins, maxs = ent:WorldSpaceAABB()

		CS16.BuyZones[ #CS16.BuyZones + 1 ] = {
			entity = ent,
			mins   = mins,
			maxs   = maxs,
		}
	end

	if SERVER then
		MsgN( ("[CS 1.6] Zones: %d bomb site(s), %d buy zone(s)."):format(
			#CS16.BombSites, #CS16.BuyZones ) )
	end
end

local function WithinBox( pos, mins, maxs )
	return pos.x >= mins.x and pos.x <= maxs.x
	   and pos.y >= mins.y and pos.y <= maxs.y
	   and pos.z >= mins.z and pos.z <= maxs.z
end

-- Returns the bomb site table the position sits in, or nil.
function CS16.GetBombSiteAt( pos )
	for _, site in ipairs( CS16.BombSites ) do
		if WithinBox( pos, site.mins, site.maxs ) then return site end
	end
end

function CS16.InBuyZone( ply )
	-- A map with no buy zones at all would otherwise lock everyone out of
	-- buying entirely, so treat the whole map as purchasable instead.
	if #CS16.BuyZones == 0 then return true end

	local pos = ply:GetPos()

	for _, zone in ipairs( CS16.BuyZones ) do
		if WithinBox( pos, zone.mins, zone.maxs ) then return true end
	end

	return false
end

--[[
	Which objective this map plays.

	The map decides, exactly as CS does it - somewhere with hostage spots
	authored onto it is a rescue map, somewhere with bomb sites is a defusal
	map. Nobody switches anything, and the mode stays competitive either way.

	Both halves are required. Spots with nowhere to take them, or a rescue point
	with nobody to bring to it, is half-finished authoring rather than a hostage
	map, and treating it as one would produce a round that cannot be won.

	It lives here, in the shared zone module, rather than with the hostage logic
	because sv_rounds has to ask it and loads first - and because it is a
	question about what was authored onto the map, which is what this file is.

	The two realms answer from different places, the same split CS16.ModeID
	uses: the server counts what it loaded, while the client reads a global,
	because the authored positions themselves are only sent to developers. The
	answer is public even though the data behind it isn't.
]]
function CS16.IsHostageMap()
	if CLIENT then return GetGlobalBool( "CS16.HostageMap", false ) end

	return #( CS16.HostageSpots or {} ) > 0 and #( CS16.RescueZones or {} ) > 0
end

hook.Add( "InitPostEntity", "CS16.CacheZones", function()
	CS16.CacheZones()
end )
