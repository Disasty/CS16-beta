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
		live walk speed as well as our cache makes this self-healing rather
		than depending on somebody remembering to clear the cache on spawn.
	]]
	if ply.CS16LastSpeed == speed and ply:GetWalkSpeed() == speed then return end
	ply.CS16LastSpeed = speed

	ply:SetWalkSpeed( speed )

	-- GMod runs +speed as a sprint. CS uses that key to walk quietly, so we
	-- point "run" at the slower value and let the normal speed be full pace.
	ply:SetRunSpeed( speed * CS16.Config.WalkSpeedMultiplier )
	ply:SetSlowWalkSpeed( speed * CS16.Config.WalkSpeedMultiplier )
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
