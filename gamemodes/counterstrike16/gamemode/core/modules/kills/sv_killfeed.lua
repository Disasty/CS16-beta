--[[
	Kill feed, server half.

	The base gamemode has its own death notice, fed by GM:SendDeathNotice from
	base's PlayerDeath - but we override PlayerDeath outright and never call the
	baseclass, so it has never received anything. Its icons are all HL2 weapons
	regardless, so this broadcasts our own and cl_killfeed draws it in the 1.6
	style.
]]

util.AddNetworkString( "CS16.Kill" )

local KILL_PLAYER  = 0
local KILL_SUICIDE = 1
local KILL_WORLD   = 2

hook.Add( "PlayerDeath", "CS16.KillFeed", function( victim, inflictor, attacker )
	if not IsValid( victim ) then return end

	local kind   = KILL_WORLD
	local weapon = ""

	if IsValid( attacker ) and attacker:IsPlayer() then
		if attacker == victim then
			kind = KILL_SUICIDE
		else
			kind = KILL_PLAYER

			local wep = attacker:GetActiveWeapon()
			if IsValid( wep ) then weapon = wep:GetClass() end
		end
	end

	net.Start( "CS16.Kill" )
		net.WriteUInt( kind, 2 )

		if kind == KILL_PLAYER then
			-- Entity for the "was that me" check, name so the entry survives
			-- the killer disconnecting before it fades.
			net.WriteEntity( attacker )
			net.WriteString( attacker:Nick() )
			net.WriteUInt( attacker:Team(), 11 )
		end

		net.WriteEntity( victim )
		net.WriteString( victim:Nick() )
		net.WriteUInt( victim:Team(), 11 )

		net.WriteString( weapon )
		net.WriteBool( victim:LastHitGroup() == HITGROUP_HEAD )
	net.Broadcast()
end )
