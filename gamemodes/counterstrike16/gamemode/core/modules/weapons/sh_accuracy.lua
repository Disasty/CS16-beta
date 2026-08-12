--[[
	Weapon spread scaling.

	The SWEP pack computes its own cone per weapon - a base term plus a bloom
	term that grows with the cube of shots fired - and every one of them
	ultimately calls Player:FireBullets3 with a final spread value. That single
	shared entry point is what makes this possible: one wrapper scales the
	whole arsenal, rather than patching twenty different per-weapon fire
	functions and their individual formulas.

	Scaling here rather than at RecalculateAccuracy is deliberate. The bloom
	term is only part of the cone; the base term dominates while moving, which
	is precisely the case that felt worst. Scaling the final value catches both.

	This is a tuning decision, not a bug fix - the pack isn't wrong, it's just
	harsher than we want. CS16.Config.SpreadScale = 1 restores it exactly.
]]

hook.Add( "Initialize", "CS16.ScaleWeaponSpread", function()
	local scale = CS16.Config.SpreadScale

	-- Nothing to do, and no reason to add a call to every shot fired.
	if not scale or scale == 1 then return end

	local meta = FindMetaTable( "Player" )
	if not meta or not meta.FireBullets3 then return end

	-- Guard against wrapping the wrapper on a map change.
	if meta.CS16SpreadScaled then return end
	meta.CS16SpreadScaled = true

	local original = meta.FireBullets3

	function meta:FireBullets3( vecSrc, shootAngles, flSpread, ... )
		return original( self, vecSrc, shootAngles, ( flSpread or 0 ) * scale, ... )
	end
end )
