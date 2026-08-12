--[[
	Dropping weapons, as 1.6 did it.

	G drops what you're holding, and dying scatters everything except your knife
	and your defuse kit. Anything on the floor can be picked up by whoever
	reaches it.

	Dropped guns become cs16_item_weapon rather than bare weapon entities. The
	addon ships that entity for exactly this purpose: it carries the clip
	across, restores it on pickup, and runs its own pickup checks - which call
	PlayerCanPickupWeapon, so our one-primary-one-secondary rule still applies.
	Using GMod's DropWeapon instead bypassed all of that, which is why picking
	your own gun back up behaved differently depending on where it came from.

	Everything loose is swept at the start of each round, or dropped guns pile
	up map-wide across a match.
]]

util.AddNetworkString( "CS16.DropWeapon" )

--[[
	Stays with you whatever happens.

	The knife because you should never be left holding nothing.

	The defuse kit because it isn't a weapon, it's a thing you bought once for
	the round, and a floor scattered with them turns a Counter-Terrorist dying
	near a site into free kits for everyone who walks past afterwards. It also
	stops Terrorists tripping over kits they're forbidden to pick up anyway.

	Not the bomb: that has to reach the floor, and DropWeaponItem handles it
	specially so the round stays winnable.
]]
local KEEP = {
	[ CS16.KNIFE ]              = true,
	[ "weapon_cs16_defusekit" ] = true,
}

function CS16.CanDropWeapon( ply, wep )
	if not IsValid( wep ) then return false end
	if not CS16.IsPlayingTeam( ply:Team() ) then return false end

	--[[
		Some modes can't have weapons lying about.

		Gungame is the case: what you carry is the whole scoring system, so a
		floor full of other people's guns lets you skip rungs by picking one up
		and killing with that instead. Stopping the drop is the fix rather than
		stopping the pickup, because nothing dropped means nothing to find.
	]]
	if not CS16.ModeSetting( "Dropping", true ) then return false end

	return not KEEP[ wep:GetClass() ]
end

--[[
	The bomb, on the floor where its carrier fell.

	It stays a plain weapon entity rather than becoming an item box, because
	bots look for a loose bomb by class and an item box wouldn't answer that
	search.

	It's also spawned explicitly instead of being handed to Player:DropWeapon.
	The round can't be won while the bomb is missing, so this is the one drop
	that has to be certain: creating the entity ourselves means it exists, has
	no owner, and lies where the carrier died, without depending on how the
	engine treats dropping a weapon a dead player wasn't currently holding.
]]
local function DropBomb( ply )
	local pos = ply:GetPos() + Vector( 0, 0, 24 )
	local yaw = ply:EyeAngles().y

	ply:StripWeapon( "weapon_cs16_c4" )

	local bomb = ents.Create( "weapon_cs16_c4" )
	if not IsValid( bomb ) then return end

	bomb:SetPos( pos )
	bomb:SetAngles( Angle( 0, yaw, 0 ) )
	bomb:Spawn()

	-- A small toss, so it lands beside the body rather than inside it.
	local phys = bomb:GetPhysicsObject()

	if IsValid( phys ) then
		phys:Wake()
		phys:SetVelocity( VectorRand() * 50 + Vector( 0, 0, 80 ) )
	end

	return bomb
end

function CS16.DropWeaponItem( ply, wep )
	if not CS16.CanDropWeapon( ply, wep ) then return end

	if wep:GetClass() == "weapon_cs16_c4" then
		return DropBomb( ply )
	end

	local item = ents.Create( "cs16_item_weapon" )
	if not IsValid( item ) then return end

	-- Set before Spawn: the entity reads self.Model in its Initialize.
	item.Model = wep:GetWeaponWorldModel() or wep.WorldModel

	item:SetPos( ply:EyePos() + ply:GetAimVector() * 16 )
	item:SetAngles( ply:EyeAngles() )
	item:Spawn()

	--[[
		Clip only, deliberately. Reserve ammo is shared by calibre, so taking
		it with the weapon would mean dropping a Glock emptied the magazines
		for the MP5 still in your hands. 1.6 kept your ammo too.

		Read before packing - PackWeapon strips and removes the weapon.
	]]
	item:PackClip( wep:Clip1(), wep:Clip2() )
	item:PackWeapon( wep )

	item:Deploy( ply, ply:GetAimVector() * 250 )

	--[[
		Deploy makes the dropper the owner, and the entity refuses to be picked
		up by its owner - permanently, since nothing ever clears it. Release it
		after a moment so you can retrieve your own weapon, while still not
		catching it the instant you throw it.
	]]
	timer.Simple( 1, function()
		if IsValid( item ) then item:SetOwner( NULL ) end
	end )

	return item
end

function CS16.DropActiveWeapon( ply )
	if not ply:Alive() then return end

	CS16.DropWeaponItem( ply, ply:GetActiveWeapon() )
end

net.Receive( "CS16.DropWeapon", function( len, ply )
	CS16.DropActiveWeapon( ply )
end )

-- Dying scatters the lot, less whatever CanDropWeapon keeps back - the knife,
-- so nobody ends up holding nothing, and the defuse kit.
hook.Add( "PlayerDeath", "CS16.DropOnDeath", function( ply )
	for _, wep in ipairs( ply:GetWeapons() ) do
		CS16.DropWeaponItem( ply, wep )
	end
end )

--[[
	Only the bomb, and only because the round can't be won without it.

	Guns leaving with a disconnecting player is fine - the round carries on
	either way. Team changes are handled in CS16.SetTeam, which has to drop it
	before the side change rather than after.
]]
hook.Add( "PlayerDisconnected", "CS16.DropBombOnLeave", function( ply )
	if ply:HasWeapon( "weapon_cs16_c4" ) then
		CS16.DropWeaponItem( ply, ply:GetWeapon( "weapon_cs16_c4" ) )
	end
end )

--[[
	Everything on the floor, removed. Both forms: item boxes, and the bare
	weapon entities the C4 and anything else stray leaves behind. A weapon
	nobody holds has no owner, which is what tells the two apart.
]]
function CS16.ClearDroppedWeapons()
	for _, item in ipairs( ents.FindByClass( "cs16_item_weapon" ) ) do
		if IsValid( item ) then item:Remove() end
	end

	for _, wep in ipairs( ents.FindByClass( "weapon_cs16_*" ) ) do
		if IsValid( wep ) and not IsValid( wep:GetOwner() ) then
			wep:Remove()
		end
	end
end
