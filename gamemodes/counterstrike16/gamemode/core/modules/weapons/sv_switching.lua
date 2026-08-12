--[[
	Weapon switching: what you hold after throwing something, and Q.
]]

util.AddNetworkString( "CS16.QuickSwitch" )

local PLAYER = FindMetaTable( "Player" )

--[[
	The addon's own extension point, and nothing implemented it.

	Every grenade SWEP ends its throw with

		if self.Owner.CS16_SelectBestWeapon then
			self.Owner:CS16_SelectBestWeapon( self )
		end

	and then removes itself. Since no such method existed the call was silently
	skipped, which is why throwing a grenade left you holding nothing in
	particular and having to switch back by hand.

	Defining it is the whole fix - no addon file is touched, and every grenade
	type picks it up at once because they all already call it.
]]
function PLAYER:CS16_SelectBestWeapon( exclude )
	local wep = CS16.BestWeapon( self, exclude )
	if IsValid( wep ) then self:SelectWeapon( wep:GetClass() ) end
end

--[[ Quick switch ]]

--[[
	Remember what we were holding so Q can go back to it.

	This hook fires before the switch happens, so `old` is genuinely the weapon
	being left behind.
]]
hook.Add( "PlayerSwitchWeapon", "CS16.TrackLastWeapon", function( ply, old, new )
	if IsValid( old ) and old ~= new then ply.CS16LastWeapon = old end
end )

function CS16.QuickSwitch( ply )
	if not ply:Alive() then return end

	local current = ply:GetActiveWeapon()
	local last    = ply.CS16LastWeapon

	-- The ordinary case: straight back to whatever you were on.
	if IsValid( last ) and last ~= current and ply:HasWeapon( last:GetClass() ) then
		ply:SelectWeapon( last:GetClass() )
		return
	end

	--[[
		Nothing to go back to - the first switch of a round, or the last weapon
		was dropped, thrown or taken off you at the buy menu. Fall through to
		stepping the slots instead, so Q always does something.
	]]
	local slot = CS16.WeaponSlot( current )

	-- Holding a grenade or the bomb: there's no sensible "next" from there, so
	-- just take the best gun.
	if not slot or slot == CS16.SLOT_OTHER then
		local wep = CS16.BestWeapon( ply )
		if IsValid( wep ) then ply:SelectWeapon( wep:GetClass() ) end
		return
	end

	--[[
		Step to the next slot we actually have, wrapping round. That's what
		makes it behave with a part-filled loadout: with only a pistol and a
		knife it flips between those two rather than doing nothing when it
		reaches an empty primary slot.
	]]
	for i = 1, 2 do
		local nextSlot = ( ( slot - 1 + i ) % 3 ) + 1
		local wep      = CS16.WeaponInSlot( ply, nextSlot )

		if IsValid( wep ) then
			ply:SelectWeapon( wep:GetClass() )
			return
		end
	end
end

net.Receive( "CS16.QuickSwitch", function( _, ply )
	CS16.QuickSwitch( ply )
end )
