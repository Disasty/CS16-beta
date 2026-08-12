--[[
	Spawning props, and getting rid of them again.

	A developer tool, so everything here is gated on the rank and nothing is
	reachable from a normal round. It exists because building a scene to test
	something - cover to shoot around, a crate to check a bot can climb - is
	otherwise a job for a text editor and a map compile.

	What may be destroyed is decided here - see CS16.CanRemoveProp - while the
	phaser reads the keys that ask for it. The rules belong with the props, the
	input belongs with the weapon.
]]

util.AddNetworkString( "CS16.SpawnProp" )

--[[
	A ceiling, because a developer with a spawn menu and a scroll wheel can put
	seven hundred physics props into a live round without meaning to, and the
	first anybody else knows about it is the tickrate.

	Per player, counted from what is actually still alive rather than from a
	tally, so removing props makes room again without any bookkeeping.
]]
local PROP_LIMIT = 150

local function PropsOwnedBy( ply )
	local n = 0

	for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
		if ent.CS16PropOwner == ply then n = n + 1 end
	end

	return n
end

--[[
	Whether this is one of ours to destroy.

	Deliberately narrow. A developer pointing a phaser at the map and pressing a
	key should not be able to delete the map: anything the BSP placed is refused,
	as is anything alive or carried. What is left is the loose physics props this
	menu put there.
]]
function CS16.CanRemoveProp( ent )
	if not IsValid( ent ) then return false end
	if ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() then return false end
	if ent:CreatedByMap() then return false end

	return ent.CS16Prop == true
end

--[[
	Put one in the world, in front of whoever asked for it.

	Placed against whatever they were looking at rather than dropped at their
	feet, and lifted clear by the model's own bounds - spawning on the surface
	itself buries half of every prop whose origin is not at its base, which is
	most of them.
]]
local function Spawn( ply, model )
	local tr = ply:GetEyeTrace()
	if not tr.Hit then return end

	local ent = ents.Create( "prop_physics" )
	if not IsValid( ent ) then return end

	ent:SetModel( model )

	--[[
		Facing the person who spawned it, which is what you want nine times in
		ten - most of these props have a front, and a crate turned away from you
		reads as the wrong prop entirely.
	]]
	ent:SetAngles( Angle( 0, ply:EyeAngles().y + 180, 0 ) )
	ent:SetPos( tr.HitPos )
	ent:Spawn()
	ent:Activate()

	-- After Spawn, because the bounds are not known until the model is loaded.
	ent:SetPos( tr.HitPos + tr.HitNormal * -ent:OBBMins().z )

	ent.CS16Prop      = true
	ent.CS16PropOwner = ply

	--[[
		Registered with the engine's undo stack rather than a list of our own.
		It already handles the player leaving, the entity being removed by
		something else, and the ordering - all of which a hand-rolled stack gets
		wrong the first time.
	]]
	undo.Create( "Prop" )
		undo.SetPlayer( ply )
		undo.AddEntity( ent )
		undo.SetCustomUndoText( "Undone " .. string.GetFileFromFilename( model ) )
	undo.Finish()

	return ent
end

net.Receive( "CS16.SpawnProp", function( len, ply )
	if not IsValid( ply ) or not CS16.IsDeveloper( ply ) then return end

	local model = net.ReadString()

	--[[
		Checked against the shipped list rather than trusted. This is a net
		message: what arrives is whatever the sender felt like writing, and
		"any model path on the server" is a much larger surface than a menu of
		seven hundred props.
	]]
	if not CS16.PropIndex[ model ] then return end

	if PropsOwnedBy( ply ) >= PROP_LIMIT then
		ply:ChatPrint( ("[CS 1.6] Prop limit reached (%d). Undo some with Z."):format( PROP_LIMIT ) )
		return
	end

	Spawn( ply, model )
end )

--[[
	Nothing here drives the undo itself.

	gmod_undo belongs to the undo module rather than to sandbox, so it exists in
	every gamemode and already does the whole job: it pops the player's own
	stack, refuses anybody else's, and tells their client what was undone. The
	only part missing was a key bound to it - see cl_propmenu.lua.

	Worth writing down because the obvious-looking undo.Do_Undo is not the one
	you want: it takes a single undo entry, not a player, and handing it a player
	silently removes nothing and reports zero.
]]


--[[
	Props last a round, and no longer.

	Scenery thrown down to test something is rubbish by the next round, and a
	competitive match played around a developer's crates is worse than no props
	at all. So the default is that they go.

	The exception is marked by hand: a prop made permanent stays through round
	changes, and through map changes too, because "permanent" that lasts eleven
	minutes is a strange kind of permanent. Those are written to
	data/cs16/props/<map>.json, the same way authored zones are - see
	core/modules/zones/sv_authored.lua.
]]
local DIR = "cs16/props"

local function Path()
	return ("%s/%s.json"):format( DIR, game.GetMap() )
end

function CS16.ClearProps( ply, includePerma )
	local n = 0

	for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
		if ent.CS16Prop
			and ( includePerma or not ent.CS16PropPerma )
			and ( not ply or ent.CS16PropOwner == ply )
		then
			SafeRemoveEntity( ent )
			n = n + 1
		end
	end

	return n
end

--[[
	Vectors and angles go out as plain numbers.

	util.TableToJSON will write a Vector happily enough; what comes back is a
	table that only looks like one, with no metatable, and the first thing to do
	arithmetic on it errors a long way from here.
]]
local function Save()
	file.CreateDir( DIR )

	local out = {}

	for _, ent in ipairs( ents.FindByClass( "prop_physics" ) ) do
		if not ent.CS16PropPerma then continue end

		local pos, ang = ent:GetPos(), ent:GetAngles()
		local phys     = ent:GetPhysicsObject()

		out[ #out + 1 ] = {
			model  = ent:GetModel(),
			pos    = { math.Round( pos.x, 1 ), math.Round( pos.y, 1 ), math.Round( pos.z, 1 ) },
			ang    = { math.Round( ang.p, 1 ), math.Round( ang.y, 1 ), math.Round( ang.r, 1 ) },
			frozen = IsValid( phys ) and not phys:IsMotionEnabled() or false,
		}
	end

	file.Write( Path(), util.TableToJSON( out, true ) )
end

CS16.SavePermaProps = Save

function CS16.LoadPermaProps()
	local raw = file.Read( Path(), "DATA" )
	if not raw then return 0 end

	local data = util.JSONToTable( raw )
	if not data then
		ErrorNoHalt( ("[CS 1.6] %s is not valid JSON; no permanent props loaded.\n"):format( Path() ) )
		return 0
	end

	local n = 0

	for _, row in ipairs( data ) do
		-- Validated on the way back in as well as on the way out: the file is
		-- editable by hand and a bad model name is a broken entity.
		if CS16.PropIndex[ row.model ] then
			local ent = ents.Create( "prop_physics" )

			if IsValid( ent ) then
				ent:SetModel( row.model )
				ent:SetPos( Vector( row.pos[ 1 ], row.pos[ 2 ], row.pos[ 3 ] ) )
				ent:SetAngles( Angle( row.ang[ 1 ], row.ang[ 2 ], row.ang[ 3 ] ) )
				ent:Spawn()
				ent:Activate()

				ent.CS16Prop      = true
				ent.CS16PropPerma = true

				if row.frozen then
					local phys = ent:GetPhysicsObject()
					if IsValid( phys ) then phys:EnableMotion( false ) phys:Sleep() end
				end

				n = n + 1
			end
		end
	end

	if n > 0 then MsgN( ("[CS 1.6] Restored %d permanent prop(s)."):format( n ) ) end

	return n
end

hook.Add( "InitPostEntity", "CS16.LoadPermaProps", function()
	CS16.LoadPermaProps()
end )

hook.Add( "CS16RoundStarted", "CS16.ClearDevProps", function()
	local n = CS16.ClearProps( nil, false )
	if n > 0 then MsgN( ("[CS 1.6] Cleared %d prop(s) for the new round."):format( n ) ) end
end )

--[[
	Making one permanent, or letting it go again.

	Acts on whatever the phaser is carrying, falling back to whatever is being
	looked at - the same order the delete uses, and for the same reason: a held
	prop is unambiguous, a traced one is a guess.
]]
local function Aimed( ply )
	local wep = ply:GetActiveWeapon()

	if IsValid( wep ) and wep:GetClass() == "weapon_cs16_phaser" then
		local held = wep:GetHeldEntity()
		if IsValid( held ) then return held end
	end

	return ply:GetEyeTrace().Entity
end

CS16.AddCommand( "permaprop", {
	permission  = "map",
	description = "Keep the prop you're holding or looking at through round and map changes.",

	callback = function( ply )
		local ent = Aimed( ply )

		if not IsValid( ent ) or not ent.CS16Prop then
			ply:ChatPrint( "[CS 1.6] Point at a prop you spawned, or hold one with the phaser." )
			return
		end

		ent.CS16PropPerma = not ent.CS16PropPerma
		Save()

		ply:ChatPrint( ent.CS16PropPerma
			and "[CS 1.6] Prop kept. It will survive round and map changes."
			or  "[CS 1.6] Prop released. It will go at the end of the round." )
	end,
} )

CS16.AddCommand( "clearprops", {
	permission  = "map",
	args        = "[all|perma]",
	description = "Remove spawned props. 'all' includes everybody's, 'perma' includes the kept ones.",

	callback = function( ply, args )
		local what     = string.lower( args[ 1 ] or "" )
		local everyone = what == "all"
		local perma    = what == "perma"

		local n = CS16.ClearProps( ( everyone or perma ) and nil or ply, perma )
		if perma then Save() end

		ply:ChatPrint( ("[CS 1.6] Removed %d prop(s)%s."):format( n,
			perma and " including permanent ones" or everyone and " (all players)" or "" ) )
	end,
} )
