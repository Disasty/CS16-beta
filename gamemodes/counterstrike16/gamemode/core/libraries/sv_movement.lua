--[[
	Per-weapon movement speed.

	The CS16 SWEP base already carries authentic 1.6 speeds (AWP 210, AK 221,
	knife 250) and exposes them through SWEP:GetMaxSpeed, but nothing in
	sandbox ever reads them - it only calls ResetMaxSpeed, which hands control
	back to whatever the gamemode set. So this is where those numbers finally
	take effect.

	We call the method rather than reading SWEP.MaxSpeed directly because some
	weapons override it dynamically; the AWP slows you further while scoped.
]]

function CS16.ApplySpeed( ply )
	local speed = CS16.Config.BaseSpeed

	local wep = ply:GetActiveWeapon()
	if IsValid( wep ) and isfunction( wep.GetMaxSpeed ) then
		speed = wep:GetMaxSpeed() or speed
	end

	--[[
		Respawning resets the engine's own speed values back to GMod defaults
		(400 run / 250 walk), which quietly re-enables sprint. Checking the
		live values as well as our cache makes this self-healing rather than
		depending on somebody remembering to clear the cache on spawn.

		The crouch fraction is checked too, and separately. Our base speed is
		the same 250 Garry's Mod resets walk speed to, so on respawn the walk
		test alone passes, the whole function returns early, and the crouch
		fraction is left sitting at the default it was just reset to.
	]]
	local crouch = CS16.Config.CrouchSpeedMultiplier

	if ply.CS16LastSpeed == speed
		and ply:GetWalkSpeed() == speed
		and math.abs( ply:GetCrouchedWalkSpeed() - crouch ) < 0.001 then
		return
	end

	ply.CS16LastSpeed = speed

	ply:SetWalkSpeed( speed )

	-- GMod runs +speed as a sprint. CS uses that key to walk quietly, so we
	-- point "run" at the slower value and let the normal speed be full pace.
	ply:SetRunSpeed( speed * CS16.Config.WalkSpeedMultiplier )
	ply:SetSlowWalkSpeed( speed * CS16.Config.WalkSpeedMultiplier )

	-- A fraction of walk speed, not an absolute, so it tracks whatever the
	-- weapon in hand allows: an AWP is slow crouched and slower still scoped.
	ply:SetCrouchedWalkSpeed( crouch )
end

--[[
	Fall damage on Half-Life's curve, which 1.6 inherited.

	Garry's Mod answers a flat 10 regardless of how far you fell, so a rooftop
	and a kerb cost the same and there was no reason not to take the drop.

	Straight line between the two speeds in config: nothing below SafeSpeed,
	a full hundred at FatalSpeed, and past that it keeps climbing rather than
	capping, so a truly enormous fall kills through armour the way it should.

	The engine hands us the landing speed rather than the height, which is the
	useful end of it - it already accounts for gravity, and for anything that
	slowed the fall on the way down.
]]
function GM:GetFallDamage( ply, speed )
	local fall = CS16.Config.Fall

	if speed <= fall.SafeSpeed then return 0 end

	local span = fall.FatalSpeed - fall.SafeSpeed
	if span <= 0 then return 0 end

	return ( speed - fall.SafeSpeed ) * ( 100 / span )
end

--[[
	Planting and defusing both pin the player in place by writing their speed
	directly. If we kept reapplying the weapon's speed every tick we'd undo
	that instantly and let people plant on the move, so hand over control for
	as long as either is happening.
]]
local function DrivenExternally( ply )
	if ply.m_bIsDefusing then return true end

	local wep = ply:GetActiveWeapon()
	return IsValid( wep ) and ( wep.Plant or 0 ) > 0
end

function GM:PlayerTick( ply, mv )
	if not ply:Alive() then return end
	-- Anyone with a body moves at CS speeds, developers included - it would be
	-- confusing to test movement from a team that moves differently.
	if not CS16.HasBody( ply:Team() ) then return end
	if DrivenExternally( ply ) then return end

	CS16.ApplySpeed( ply )
end
