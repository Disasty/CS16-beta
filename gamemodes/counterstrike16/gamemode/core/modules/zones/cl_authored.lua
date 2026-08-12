--[[
	Drawing the zones a developer has placed.

	Authoring something you cannot see is guesswork, and the whole reason these
	exist is that the map doesn't carry them - so there is nothing else on
	screen to tell you where you put the last one.

	Developer-only for now. Rescue zones will want showing to Counter-Terrorists
	once there is a hostage to drag into one, but that belongs with the
	objective rather than here.
]]

CS16.HostageSpots = CS16.HostageSpots or {}
CS16.RescueZones  = CS16.RescueZones or {}
CS16.BRSpawns     = CS16.BRSpawns or {}
CS16.BRLoot       = CS16.BRLoot or {}

net.Receive( "CS16.Zones", function()
	local data = util.JSONToTable( net.ReadString() ) or {}

	CS16.HostageSpots, CS16.RescueZones = {}, {}
	CS16.BRSpawns, CS16.BRLoot = {}, {}

	for _, spot in ipairs( data.brspawns or {} ) do
		CS16.BRSpawns[ #CS16.BRSpawns + 1 ] = {
			pos = Vector( spot.pos[ 1 ], spot.pos[ 2 ], spot.pos[ 3 ] ),
			yaw = spot.yaw or 0,
		}
	end

	for _, spot in ipairs( data.brloot or {} ) do
		CS16.BRLoot[ #CS16.BRLoot + 1 ] = {
			pos = Vector( spot.pos[ 1 ], spot.pos[ 2 ], spot.pos[ 3 ] ),
		}
	end

	for _, spot in ipairs( data.hostages or {} ) do
		CS16.HostageSpots[ #CS16.HostageSpots + 1 ] = {
			pos = Vector( spot.pos[ 1 ], spot.pos[ 2 ], spot.pos[ 3 ] ),
			yaw = spot.yaw or 0,
		}
	end

	for _, zone in ipairs( data.rescue or {} ) do
		CS16.RescueZones[ #CS16.RescueZones + 1 ] = {
			pos    = Vector( zone.pos[ 1 ], zone.pos[ 2 ], zone.pos[ 3 ] ),
			radius = zone.radius or 200,
		}
	end
end )

--[[
	Whether the markers are drawn at all.

	They used to be on permanently for anybody with the rank, which is right when
	you are setting a map up and wrong every other minute - a developer playing a
	round had twenty-eight purple posts and their labels between them and the
	map, whichever side they were on.

	Two switches rather than one, because the two sets are placed in different
	sittings and there is no reason turning on the battle royale markers should
	bring the hostage ones with them.

	Archived convars rather than a Lua flag, so a choice made once survives the
	map change that follows every match. Default on: somebody who has just placed
	a spawn should see it without having to find a menu first.
]]
local SHOW_BR = CreateClientConVar( "cs16_show_br_markers", "1", true, false,
	"Draw battle royale spawn and loot markers. Developers only." )

local SHOW_HOSTAGE = CreateClientConVar( "cs16_show_hostage_markers", "1", true, false,
	"Draw hostage spot and rescue zone markers. Developers only." )

function CS16.ShowBRMarkers()      return SHOW_BR:GetBool() end
function CS16.ShowHostageMarkers() return SHOW_HOSTAGE:GetBool() end

local HOSTAGE_COL = Color( 90, 200, 90 )
local RESCUE_COL  = Color( 108, 160, 220 )

-- Distinct from the two above, and from each other, because on a map being set
-- up for everything at once you need to tell four kinds of marker apart.
local SPAWN_COL = Color( 235, 170, 60 )
local LOOT_COL  = Color( 200, 100, 220 )

--[[
	A ring on the floor, drawn as line segments.

	Not a filled circle: the floor these sit on is rarely flat, and a solid disc
	either z-fights with it or floats above it. A ring traced down onto the
	surface follows the ground.
]]
local function Ring( pos, radius, col, segments )
	segments = segments or 32

	render.SetColorMaterial()

	local last
	for i = 0, segments do
		local a = ( i / segments ) * math.pi * 2
		local p = pos + Vector( math.cos( a ) * radius, math.sin( a ) * radius, 2 )

		if last then render.DrawLine( last, p, col, true ) end
		last = p
	end
end

hook.Add( "PostDrawTranslucentRenderables", "CS16.DrawZones", function( _, sky )
	if sky then return end

	local ply = LocalPlayer()
	if not IsValid( ply ) or not CS16.IsDeveloper( ply ) then return end

	cam.IgnoreZ( true )

	if CS16.ShowHostageMarkers() then
		for _, spot in ipairs( CS16.HostageSpots ) do
			-- A post where they'll stand, and a stub showing which way they face.
			render.DrawLine( spot.pos, spot.pos + Vector( 0, 0, 72 ), HOSTAGE_COL, true )
			render.DrawLine( spot.pos + Vector( 0, 0, 36 ),
				spot.pos + Vector( 0, 0, 36 ) + Angle( 0, spot.yaw, 0 ):Forward() * 24,
				HOSTAGE_COL, true )

			Ring( spot.pos, 20, HOSTAGE_COL, 16 )
		end

		for _, zone in ipairs( CS16.RescueZones ) do
			Ring( zone.pos, zone.radius, RESCUE_COL )
			render.DrawLine( zone.pos, zone.pos + Vector( 0, 0, 96 ), RESCUE_COL, true )
		end
	end

	if not CS16.ShowBRMarkers() then
		cam.IgnoreZ( false )
		return
	end

	--[[
		Spawns get a post and a facing stub like hostages do, because the
		direction matters as much as the position - and a wide ring, since the
		point of placing these by hand is judging how far apart they are.
	]]
	for _, spot in ipairs( CS16.BRSpawns ) do
		render.DrawLine( spot.pos, spot.pos + Vector( 0, 0, 72 ), SPAWN_COL, true )
		render.DrawLine( spot.pos + Vector( 0, 0, 40 ),
			spot.pos + Vector( 0, 0, 40 ) + Angle( 0, spot.yaw, 0 ):Forward() * 32,
			SPAWN_COL, true )

		Ring( spot.pos, 24, SPAWN_COL, 16 )
		Ring( spot.pos, 220, SPAWN_COL, 24 )
	end

	for _, spot in ipairs( CS16.BRLoot ) do
		render.DrawLine( spot.pos, spot.pos + Vector( 0, 0, 48 ), LOOT_COL, true )
		Ring( spot.pos, 16, LOOT_COL, 12 )
	end

	cam.IgnoreZ( false )
end )

-- Labels, so it's obvious which is which without counting rings.
hook.Add( "HUDPaint", "CS16.LabelZones", function()
	local ply = LocalPlayer()
	if not IsValid( ply ) or not CS16.IsDeveloper( ply ) then return end

	local function Label( pos, text, col )
		local screen = ( pos + Vector( 0, 0, 80 ) ):ToScreen()
		if not screen.visible then return end

		CS16.DrawText( text, "CS16.Small", screen.x, screen.y, col, TEXT_ALIGN_CENTER )
	end

	if CS16.ShowHostageMarkers() then
		for i, spot in ipairs( CS16.HostageSpots ) do
			Label( spot.pos, "HOSTAGE " .. i, HOSTAGE_COL )
		end

		for i, zone in ipairs( CS16.RescueZones ) do
			Label( zone.pos, ("RESCUE %d (r%d)"):format( i, zone.radius ), RESCUE_COL )
		end
	end

	if CS16.ShowBRMarkers() then
		for i, spot in ipairs( CS16.BRSpawns ) do
			Label( spot.pos, "SPAWN " .. i, SPAWN_COL )
		end

		for i, spot in ipairs( CS16.BRLoot ) do
			Label( spot.pos, "LOOT " .. i, LOOT_COL )
		end
	end
end )
