--[[
	Who gets a phaser, and when.

	The weapon itself is entities/weapons/weapon_cs16_phaser.lua and its models
	are under content/; this file only decides who carries one.

	It was an addon until now, which meant the gamemode could not be handed to
	anybody without handing them a second thing to install, and the weapon a
	developer is supposed to spawn holding lived outside the gamemode that
	decides what a developer spawns holding. Both are the same problem.

	An earlier version dressed up GMod's weapon_physgun rather than shipping a
	weapon. That does not work: the physgun's viewmodel is a c_ model drawn by
	bonemerging onto c_arms, so a ported GoldSrc v_ model put on it draws
	nothing at all. See the SWEP's own header.
]]

local PHASER = "weapon_cs16_phaser"

hook.Add( "Initialize", "CS16.PhaserPrecache", function()
	util.PrecacheModel( "models/weapons/cs16_phaser/v_phaser.mdl" )
	util.PrecacheModel( "models/weapons/cs16_phaser/w_phaser.mdl" )
end )

--[[
	Developer-only, enforced rather than assumed.

	Being absent from the buy catalogue is not a restriction on its own:
	CS16.CanPickupWeapon ends with "if not item then return true end", which is
	the path that lets knives, grenades and the C4 be picked up freely - so a
	phaser dropped on death was fair game for any living player.

	One hook covers both routes. The engine consults PlayerCanPickupWeapon when
	you walk over a weapon, and the gamemode's dropped-item box asks through
	hook.Run.
]]
hook.Add( "PlayerCanPickupWeapon", "CS16.PhaserDeveloperOnly", function( ply, wep )
	if not IsValid( wep ) or wep:GetClass() ~= PHASER then return end
	if not IsValid( ply ) or ply:Team() ~= TEAM_DEV then return false end
end )

-- Leaving the developer team takes the phaser with it, so it cannot be carried
-- into a live round by switching sides while holding one.
hook.Add( "PlayerChangedTeam", "CS16.PhaserStripOnLeave", function( ply, old, new )
	if new == TEAM_DEV then return end

	if IsValid( ply ) and ply:HasWeapon( PHASER ) then
		ply:StripWeapon( PHASER )
	end
end )

local function Grant( ply )
	if ply:HasWeapon( PHASER ) then return end

	-- GrantWeapon sets the flag that lets a deliberate hand-over past the
	-- pickup rules. A bare Give is subject to them and gets refused.
	CS16.GrantWeapon( ply, PHASER )
end

--[[
	Handed over on spawn, and held.

	It is the only tool the developer team carries and the reason for being on
	the team, so coming up with a knife out and having to switch is a keypress
	nobody wanted.

	Deferred a tick because PlayerSpawn runs before the gamemode's own loadout,
	which would otherwise strip the phaser straight back off again.
]]
hook.Add( "PlayerSpawn", "CS16.PhaserGive", function( ply )
	timer.Simple( 0, function()
		if not IsValid( ply ) or not ply:Alive() then return end
		if ply:Team() ~= TEAM_DEV then return end

		Grant( ply )
		ply:SelectWeapon( PHASER )
	end )
end )

--[[
	Safety net. The phaser freezes a carried player with MOVETYPE_NONE and
	restores it on release, but a disconnect or an unlucky death could in
	principle leave somebody frozen with no way out. Respawning always frees
	them, whatever happened.
]]
hook.Add( "PlayerSpawn", "CS16.PhaserUnfreeze", function( ply )
	if not ply.CS16PhaserHeld then return end

	ply.CS16PhaserHeld = nil
	ply:SetMoveType( MOVETYPE_WALK )
end )

--[[
	E belongs to the phaser while the phaser is out.

	The base gamemode carries light props on +use - pick one up with your hands
	and walk around with it - and that runs before the weapon ever sees the
	key. Standing close enough to a prop therefore meant pressing E grabbed it
	by hand *as well as* rotating it with the phaser, and the two dragged it in
	different directions. Which is exactly what "acts as if I've grabbed the
	prop directly" is.

	Refused outright while the phaser is the active weapon, because a developer
	holding it has no use for the hands carry and every use for the key.
]]
hook.Add( "AllowPlayerPickup", "CS16.PhaserOwnsUse", function( ply, ent )
	local wep = ply:GetActiveWeapon()

	if IsValid( wep ) and wep:GetClass() == PHASER then return false end
end )

--[[
	And nothing else E would normally talk to, while something is being carried.

	Only while carrying: a developer with the phaser out and empty hands should
	still be able to press buttons and open doors like anybody else. It is only
	when E means "turn this prop" that it must not also mean "use whatever is
	behind it".
]]
hook.Add( "PlayerUse", "CS16.PhaserOwnsUse", function( ply, ent )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) or wep:GetClass() ~= PHASER then return end

	-- GetHeldEntity comes from SetupDataTables and is not there for the first
	-- frames of a weapon's life.
	if wep.GetHeldEntity and IsValid( wep:GetHeldEntity() ) then return false end
end )

--[[
	Admin alone is not enough - an admin who is not on the developer team is
	still a player in a live round, and "developers only" has to mean that.
]]
concommand.Add( "cs16_phaser_give", function( ply )
	if not IsValid( ply ) then return end

	if ply:Team() ~= TEAM_DEV then
		ply:ChatPrint( "[CS 1.6] Developer team only." )
		return
	end

	Grant( ply )
	ply:SelectWeapon( PHASER )
end, nil, "Give yourself the phaser (developer team only)." )
