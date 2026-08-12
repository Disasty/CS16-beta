--[[
	Damage scaling.

	The SWEP pack never scales damage by hitgroup - it reads the hitgroup once,
	to size the knockback force, and applies the same flat number wherever you
	hit. So a rifle headshot did exactly what a leg shot did, which is most of
	why the whole arsenal felt weak.

	ScalePlayerDamage is the right place for it: the engine has already resolved
	which body part was hit by the time it runs, so this needs no knowledge of
	how any individual weapon fires. Every gun in the pack is covered by one
	rule, including any added later.

	See CS16.Config.Damage for the numbers and why they are what they are.
]]

-- The weapon a hit came from, or nil for anything that isn't a gun - grenades,
-- fall damage, the bomb. Those keep their own damage untouched.
local function WeaponOf( dmginfo )
	local inflictor = dmginfo:GetInflictor()
	if IsValid( inflictor ) and inflictor:IsWeapon() then return inflictor:GetClass() end

	--[[
		Bullets name the player as the inflictor rather than the gun, so fall
		back to whatever the attacker is holding. Hits land in the same frame
		they were fired, so the active weapon is still the one that fired them.
	]]
	local attacker = dmginfo:GetAttacker()

	if IsValid( attacker ) and attacker:IsPlayer() then
		local wep = attacker:GetActiveWeapon()
		if IsValid( wep ) then return wep:GetClass() end
	end
end

function GM:ScalePlayerDamage( ply, hitgroup, dmginfo )
	local cfg = CS16.Config.Damage

	--[[
		Deliberately not calling the base implementation.

		base's version applies its own head multiplier, which would compound
		with ours and put a headshot somewhere near eight times a body shot.
		Ours replaces it outright.
	]]
	local scale = cfg.Hitgroups[ hitgroup ] or 1

	local class = WeaponOf( dmginfo )
	if class and cfg.Weapons[ class ] then scale = scale * cfg.Weapons[ class ] end

	scale = scale * ( cfg.Scale or 1 )

	if scale ~= 1 then dmginfo:ScaleDamage( scale ) end
end

--[[
	Explosions, which arrive by a different road entirely.

	Not in ScalePlayerDamage above, however much it looks like the right home:
	that hook is only called for damage that has a hitgroup - a trace that hit a
	limb. An explosion is applied straight through TakeDamageInfo and never goes
	near it, so a multiplier put there does nothing at all and does it silently.
	Confirmed by instrumenting the hook and watching a grenade go off without it
	ever being called.

	EntityTakeDamage sees everything, which is the whole reason to use it, and it
	runs before armour takes its cut - so the multiplier applies to the full
	blast and armour then absorbs its share of a number worth absorbing.

	Keyed on the inflictor, which for an explosion is the grenade itself. That
	also sidesteps a trap in WeaponOf: it falls back to whatever the attacker is
	holding when the inflictor isn't a gun, so grenade damage routed through the
	rules above would have picked up the multiplier of the rifle in their hands.
]]
hook.Add( "EntityTakeDamage", "CS16.ExplosiveDamage", function( target, dmginfo )
	local inflictor = dmginfo:GetInflictor()
	if not IsValid( inflictor ) then return end

	local boost = CS16.Config.Damage.Explosives[ inflictor:GetClass() ]
	if not boost then return end

	dmginfo:ScaleDamage( boost * ( CS16.Config.Damage.Scale or 1 ) )
end )
