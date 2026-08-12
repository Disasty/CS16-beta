--[[
	Phase: a developer who isn't there.

	Invisible is only part of it. A body nobody can see still blocks a doorway,
	still stops a bullet and still makes footsteps, and any one of those gives
	you away faster than being visible would - a bot walking into thin air is
	more obvious than a bot walking past you. So phasing covers all four:

	  * the player model, and the world model of whatever they're carrying
	  * collision, so people and their bullets pass straight through
	  * footsteps
	  * their row on other people's scoreboards

	Server-side, because every one of those has to be true for everybody else
	rather than just locally. SetNoDraw sets EF_NODRAW, which the engine
	networks, so the invisibility costs nothing to replicate.

	Developer team only, on the same reasoning as noclip: being invisible in a
	real round is cheating rather than testing.
]]

util.AddNetworkString( "CS16.Phase" )

-- CS16.IsPhased lives in core/libraries/sh_phase.lua: the client needs the same answer
-- for the menu toggle and for hiding phased developers from the scoreboard.

--[[
	Weapons are re-hidden rather than hidden once, because the set changes
	underneath us: buying, switching and respawning all produce weapon entities
	that know nothing about phase. Cheaper to reassert than to find every place
	a weapon can appear.
]]
local function ApplyWeapons( ply, hidden )
	for _, wep in ipairs( ply:GetWeapons() ) do
		if wep:GetNoDraw() ~= hidden then wep:SetNoDraw( hidden ) end
	end
end

function CS16.SetPhased( ply, on )
	on = on and true or false

	ply:SetNWBool( "CS16.Phased", on )

	ply:SetNoDraw( on )
	ply:DrawShadow( not on )

	--[[
		DEBRIS passes through players and the bullets they fire while still
		resting on the floor, which is exactly what's wanted: you can walk
		around normally, nobody can walk into you, and nobody's shots stop in
		mid-air against something they can't see.
	]]
	ply:SetCollisionGroup( on and COLLISION_GROUP_DEBRIS or COLLISION_GROUP_PLAYER )

	ApplyWeapons( ply, on )
end

net.Receive( "CS16.Phase", function( _, ply )
	local wanted = net.ReadBool()

	if not CS16.IsDeveloper( ply ) or ply:Team() ~= TEAM_DEV then
		ply:ChatPrint( "Phase is for the developer team." )
		return
	end

	CS16.SetPhased( ply, wanted )
	ply:ChatPrint( wanted and "Phased - nobody can see or touch you."
		or "Unphased." )
end )

--[[
	Keep the weapons hidden as the set changes.

	A timer rather than a hook on every path that can hand out a weapon: there
	are several - the loadout, the buy menu, picking something up - and missing
	one would mean a rifle floating along on its own behind an invisible man.
	It only runs while somebody is phased.
]]
timer.Create( "CS16.PhaseWeapons", 0.25, 0, function()
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPhased( ply ) then ApplyWeapons( ply, true ) end
	end
end )

-- Footsteps would give the game away on their own.
hook.Add( "PlayerFootstep", "CS16.PhaseSilence", function( ply )
	if CS16.IsPhased( ply ) then return true end
end )

--[[
	Phase can't survive leaving the team it belongs to, or a respawn that hands
	back a fresh collision group and a visible model.
]]
hook.Add( "PlayerSpawn", "CS16.PhaseRestore", function( ply )
	if not CS16.IsPhased( ply ) then return end

	--[[
		Deferred a frame on purpose. hook.Add handlers run before the gamemode's
		own PlayerSpawn, so reapplying here directly would be undone moments
		later by the spawn that triggered it - the loadout and a fresh collision
		group both land after this returns.
	]]
	timer.Simple( 0, function()
		if not IsValid( ply ) then return end
		CS16.SetPhased( ply, ply:Team() == TEAM_DEV )
	end )
end )
