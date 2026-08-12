--[[
	Corrections applied over the addon's weapons.

	Patched here rather than in the addon's files so Workshop updates don't
	quietly undo them, in the same spirit as the scoreboard and the C4 plant
	gate.

	--- Holdtypes ---

	Six weapons declare the wrong one. m4a1 reads "AR2", which is uppercase and
	therefore matches no holdtype at all; awp, scout, g3sg1, sg550 and famas
	read "camera", which is the hold-it-up-to-your-face pose.

	There used to be a second half to this. The same six re-assert their
	holdtype from OnDeploy, choosing it like so:

	    if engine.ActiveGamemode() == "cs16" then targetHold = "camera" end

	The addon deliberately switches to the camera pose for a gamemode named
	"cs16" - presumably its author's own, where it must look right. Ours was
	called exactly that, so we inherited a special case written for somebody
	else's project, and it stamped over every correction a fraction of a second
	after each deploy.

	Renaming this gamemode to counterstrike16 stopped that check matching, so
	the addon now hands us its own default of "ar2" and the wrapper that fought
	it has been deleted. What remains is only the declarations, which are still
	wrong and are what the base reads when a weapon is first set up - before the
	addon's timer gets to it.
]]

local HOLDTYPES = {
	weapon_cs16_m4a1  = "ar2",
	weapon_cs16_awp   = "ar2",
	weapon_cs16_scout = "ar2",
	weapon_cs16_g3sg1 = "ar2",
	weapon_cs16_sg550 = "ar2",
	weapon_cs16_famas = "ar2",
}

hook.Add( "Initialize", "CS16.FixHoldTypes", function()
	for class, holdType in pairs( HOLDTYPES ) do
		local stored = weapons.GetStored( class )
		if stored then stored.HoldType = holdType end
	end
end )

--[[
	--- Muzzle flashes outliving their weapon ---

	The pack's muzzle flash is an effect, sent with fx:SetEntity( self ). Effect
	data carries an entity as an index and the client looks it up on arrival, so
	the answer depends on what holds that index by then rather than on what held
	it when the shot was fired.

	Usually that's the same weapon. In gungame it often isn't: promotions remove
	a weapon and create another on nearly every kill, and a freed index gets
	reused quickly. The effect then finds a perfectly valid entity that simply
	isn't a weapon, its IsValid check passes, and calling a Weapon method on it
	errors on every client watching.

	The race is on the client, in the addon's own effect, between two frames -
	there is nothing the server can do about it, and delaying the weapon's
	removal only narrows the window. So the method is given a truthful answer
	for entities that aren't weapons: no, this is not carried by you.

	Weapons keep their own implementation - the Weapon metatable's version wins
	for anything that actually is one - so this only ever answers for the case
	that was erroring.
]]
if CLIENT then
	local ENTITY = FindMetaTable( "Entity" )

	if not ENTITY.IsCarriedByLocalPlayer then
		function ENTITY:IsCarriedByLocalPlayer()
			return false
		end
	end
end

--[[
	IsStandable, which the planted bomb calls and nothing defines.

	The addon's planted C4 carries a hand-port of the engine's
	ResolveFlyCollisionCustom, and that function ends by asking whether the
	surface it just landed on is something you could stand on. In Source that is
	a method on CBaseEntity; in Lua it is simply not there, so the call throws.

	It throws on the common path, not an exotic one: the branch needs a surface
	normal pointing mostly upwards and a low speed, which describes a bomb coming
	to rest on the floor - so every plant hit it.

	And it is not only console noise. The error aborts the function at that
	line, which is *before* the three calls that bring the bomb to a halt - zero
	velocity, zero angular velocity, and the resting angle. A planted bomb kept
	whatever velocity it landed with and was never parented to the ground it was
	sitting on.

	Supplying the missing helper rather than replacing the function that calls
	it: overriding ResolveFlyCollisionCustom would mean copying sixty lines of
	the addon's physics into this gamemode, which is a fork wearing a different
	hat and would drift the moment the addon updated.

	Guarded, so that if a future GMod or another addon ever provides a real one,
	theirs wins.
]]
if not IsStandable then
	function IsStandable( ent )
		--[[
			The world reads as invalid here, and the world is the single most
			standable thing on the map - it is what the bomb lands on almost
			every time.
		]]
		if not IsValid( ent ) then return true end

		-- Tested against the bitmask directly: Entity has GetSolidFlags but no
		-- IsSolidFlagSet, whatever the name would suggest.
		if bit.band( ent:GetSolidFlags(), FSOLID_NOT_STANDABLE ) ~= 0 then return false end

		local solid = ent:GetSolid()

		-- Brushwork and anything with real collision. Deliberately narrower than
		-- the engine's version, which also accepts immobile bounding boxes: the
		-- only consequence of answering "no" is that the bomb is not parented to
		-- what it is resting on, and everything else in the branch still runs.
		return solid == SOLID_BSP or solid == SOLID_VPHYSICS
	end
end
