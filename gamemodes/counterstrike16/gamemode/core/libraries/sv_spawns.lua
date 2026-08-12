--[[
	Spawn point handling.

	de_dust2 (and every real CS map) carries info_player_terrorist /
	info_player_counterterrorist entities. GMod has no such classes, so we
	register them as scripted entities in entities/entities/ - that makes the
	engine hand us the map's own spawns, angles included.

	If a map turns out to have none, we fall back to anything spawn-shaped so
	the gamemode still boots rather than dumping everyone at the origin.
]]

CS16.SpawnPoints = CS16.SpawnPoints or {}

local FALLBACK_CLASSES = {
	"info_player_start",
	"info_player_deathmatch",
	"info_player_counterterrorist",
	"info_player_terrorist",
}

function CS16.CacheSpawnPoints()
	CS16.SpawnPoints = {
		[ TEAM_T ]  = ents.FindByClass( "info_player_terrorist" ),
		[ TEAM_CT ] = ents.FindByClass( "info_player_counterterrorist" ),
	}

	local fallback = {}
	for _, class in ipairs( FALLBACK_CLASSES ) do
		for _, ent in ipairs( ents.FindByClass( class ) ) do
			fallback[ #fallback + 1 ] = ent
		end
	end
	CS16.SpawnPoints.fallback = fallback

	MsgN( ("[CS 1.6] Spawns: %d T, %d CT, %d fallback."):format(
		#CS16.SpawnPoints[ TEAM_T ],
		#CS16.SpawnPoints[ TEAM_CT ],
		#fallback ) )
end

-- A spawn is blocked if a live player is already standing in it.
local function IsBlocked( ent )
	local pos = ent:GetPos()
	for _, other in ipairs( ents.FindInBox( pos + Vector( -16, -16, 0 ), pos + Vector( 16, 16, 72 ) ) ) do
		if other:IsPlayer() and other:Alive() then return true end
	end
	return false
end

function GM:PlayerSelectSpawn( ply, transition )
	local points = CS16.SpawnPoints[ ply:Team() ]
	if not points or #points == 0 then
		points = CS16.SpawnPoints.fallback
	end
	if not points or #points == 0 then return end

	-- Walk the list from a random offset so players spread across the spawns
	-- instead of stacking on the first free one.
	local count  = #points
	local offset = math.random( count )

	for i = 0, count - 1 do
		local ent = points[ ( ( offset + i - 1 ) % count ) + 1 ]
		if IsValid( ent ) and not IsBlocked( ent ) then
			return ent
		end
	end

	-- Everything is occupied - take one anyway rather than failing to spawn.
	return points[ offset ]
end
