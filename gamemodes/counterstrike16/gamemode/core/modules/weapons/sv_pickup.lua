--[[
	Taking a weapon off the floor: the sound, and what ends up in your hands.

	Both halves hang off the addon's dropped-weapon entity, which is what a
	dropped gun becomes and also what battle royale scatters as loot, so one
	override covers the floor of a firefight and a looted map equally.

	Wrapped rather than rewritten, in the same spirit as the rest of
	sh_weaponfixes: whatever else the entity does when it is picked up still
	happens, and a Workshop update to it is not silently reverted.
]]

--[[
	1.6's own weapon pickup sound, which ships with the pack.

	Its ammo boxes already play items/9mmclip1.wav, the clip sound, so this is
	deliberately the other one: a gun and a magazine should not sound the same
	when the difference is what you can do next.

	Emitted on the player rather than sent to them as a flat sound, so somebody
	standing next to you hears you take it, quietly. The level is low enough
	that it does not carry down a corridor and give you away.
]]
local PICKUP_SOUND = "items/gunpickup2.wav"
local PICKUP_LEVEL = 60

--[[
	Whether picking this up should put it in your hands.

	The rule is only ever "is this better than what I am holding", using the
	slot order that everything else in the gamemode already agrees on: primary
	beats secondary beats knife. Walking over a rifle with a knife out arms
	you; walking over a pistol with a rifle out does not disturb you.

	Grenades, the bomb and the defuse kit all sit in SLOT_OTHER and are
	excluded outright. Being handed a smoke because you stepped on one, in the
	middle of a fight you were winning with a rifle, is the exact opposite of
	helpful - and it is why the addon's own "select what you picked up" setting
	is not good enough on its own.
]]
local function ShouldSwitchTo( ply, wep )
	if not IsValid( wep ) then return false end

	local slot = CS16.WeaponSlot( wep )
	if slot == CS16.SLOT_OTHER then return false end

	local held = ply:GetActiveWeapon()
	if not IsValid( held ) then return true end

	local heldSlot = CS16.WeaponSlot( held )
	if not heldSlot then return true end

	return slot < heldSlot
end

hook.Add( "Initialize", "CS16.WeaponPickupFeedback", function()
	local stored = scripted_ents.GetStored( "cs16_item_weapon" )
	if not stored or not stored.t or not stored.t.OnPickup then return end

	local original = stored.t.OnPickup

	function stored.t:OnPickup( ply )
		--[[
			Remembered before the original runs, because the entity has a
			setting of its own that selects whatever you just picked up. Ours
			is the rule that decides, so where that setting disagrees the
			weapon you had is put back rather than left swapped out from under
			you.
		]]
		local before = ply:GetActiveWeapon()

		original( self, ply )

		if not IsValid( ply ) or not ply:Alive() then return end

		ply:EmitSound( PICKUP_SOUND, PICKUP_LEVEL, 100, 0.7 )

		--[[
			Deferred a tick. Give attaches the weapon during OnPickup, and
			asking for it by class in the same frame can find it before it is
			ready to be selected.
		]]
		local class = self.m_strWeapon

		timer.Simple( 0, function()
			if not IsValid( ply ) or not ply:Alive() then return end

			local wep = ply:GetWeapon( class )
			if not IsValid( wep ) then return end

			if ShouldSwitchTo( ply, wep ) then
				ply:SelectWeapon( class )
			elseif IsValid( before ) and ply:GetActiveWeapon() ~= before then
				ply:SelectWeapon( before:GetClass() )
			end
		end )
	end
end )
