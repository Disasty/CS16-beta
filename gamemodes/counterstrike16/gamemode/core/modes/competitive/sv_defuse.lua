--[[
	Defusing.

	This replaces the planted C4's defuse outright rather than patching around
	it, because the addon's version cannot be made to work from the outside.
	Three things are wrong with it at once:

	  * It checks two different distances. You may begin a defuse from roughly
	    64 units away - Source's +use range - but its completion check cancels
	    anything beyond 32. Stand anywhere between the two and the bar runs the
	    full five or ten seconds and then silently does nothing. That is the
	    "it got all the way to the end and didn't defuse" case.

	  * m_bStartDefuse is never set true anywhere, so the guard meant to stop a
	    second defuse starting never fires, and every press of +use spawns
	    another completion timer with its own captured state.

	  * The same dead flag disables its Think entirely, including the on-ground
	    check it contains.

	We keep its net messages, so the addon's own progress bar still draws, and
	we keep writing m_pBombDefuser and m_bIsDefusing, so the team-side checks
	in sv_objectives and the bots' "stay off the defuser" behaviour carry on
	reading the same fields they always did.

	Overriding the method on the stored entity table means no addon file is
	touched and a Workshop update can't undo it.
]]

local function Range( ply, bomb )
	return ply:GetPos():Distance( bomb:GetPos() )
end

local function DefuseTime( ply )
	local cfg = CS16.Config.Bomb

	return ply:HasWeapon( "weapon_cs16_defusekit" )
		and cfg.DefuseTimeKit or cfg.DefuseTime
end

local function SendStatus( ply, defusing, endsAt )
	net.Start( "BombDefuseStatus" )
		net.WriteBool( defusing )
		if defusing then net.WriteFloat( endsAt ) end
	net.Send( ply )
end

-- Speeds the addon itself restores to. Defusing pins you in place.
local function RestoreSpeed( ply )
	if not IsValid( ply ) then return end

	ply:SetSlowWalkSpeed( 100 )
	ply:SetWalkSpeed( 200 )
	ply:SetRunSpeed( 400 )
	ply:SetMaxSpeed( 600 )

	-- Our own movement rules own the real numbers; this just puts the engine
	-- back to something sane before ApplySpeed has its say.
	CS16.ApplySpeed( ply )
end

local function StopDefuse( bomb, reason )
	local ply = IsValid( bomb ) and bomb.m_pBombDefuser or nil

	if IsValid( bomb ) then
		bomb.m_pBombDefuser = nil
		timer.Remove( "CS16.Defuse" .. bomb:EntIndex() )
	end

	if not IsValid( ply ) then return end

	ply.m_bIsDefusing = false
	RestoreSpeed( ply )
	SendStatus( ply, false )

	if reason then ply:ChatPrint( reason ) end
end

CS16.StopDefuse = StopDefuse

--[[
	Everything that has to stay true for a defuse in progress. Checked every
	tick rather than only at the end, so failing tells you immediately instead
	of wasting the round's last five seconds.
]]
local function StillValid( bomb, ply )
	if not IsValid( bomb ) or not IsValid( ply ) then return false end
	if not ply:Alive() or ply:Team() ~= TEAM_CT then return false end
	if not ply:KeyDown( IN_USE ) then return false end

	return true
end

local function BeginDefuse( bomb, ply )
	local endsAt = CurTime() + DefuseTime( ply )

	bomb.m_pBombDefuser      = ply
	bomb.m_flDefuseCountDown = endsAt
	ply.m_bIsDefusing        = true

	ply:SetSlowWalkSpeed( 1 )
	ply:SetWalkSpeed( 1 )
	ply:SetRunSpeed( 1 )
	ply:SetMaxSpeed( 1 )

	ply:EmitSound( "weapons/c4_disarm.wav" )
	SendStatus( ply, true, endsAt )

	--[[
		One timer per bomb, named after it. The addon created a fresh pair on
		every press of +use, so a player tapping the key ended up with several
		overlapping completion timers, each carrying its own stale copy of who
		was defusing and when they started.
	]]
	timer.Create( "CS16.Defuse" .. bomb:EntIndex(), 0.1, 0, function()
		if not StillValid( bomb, ply ) then
			StopDefuse( bomb )
			return
		end

		-- Checked continuously, and it's the same number the completion uses -
		-- there is no distance at which a defuse can look like it's working
		-- and then fail.
		if Range( ply, bomb ) > CS16.Config.Bomb.DefuseRange then
			StopDefuse( bomb, "You moved away from the bomb." )
			return
		end

		if not ply:OnGround() then
			StopDefuse( bomb, "You have to be on the ground to defuse." )
			return
		end

		if CurTime() < endsAt then return end

		-- Done. Clear the timer and the speed pin, but leave m_pBombDefuser
		-- set: removing the bomb is what wins the round, and sv_objectives
		-- reads that field to decide who to pay.
		timer.Remove( "CS16.Defuse" .. bomb:EntIndex() )

		ply.m_bIsDefusing = false
		RestoreSpeed( ply )
		SendStatus( ply, false )

		ply:EmitSound( "weapons/bombdef.wav" )

		-- Before the removal, so anything listening still has a bomb to look at.
		hook.Run( "CS16BombDefused", bomb, ply )

		SafeRemoveEntity( bomb )
	end )
end

hook.Add( "Initialize", "CS16.ReplaceDefuse", function()
	local stored = scripted_ents.GetStored( "ent_cs16_planted_c4" )
	if not stored or not stored.t then return end

	local ent = stored.t

	if ent.CS16DefuseReplaced then return end
	ent.CS16DefuseReplaced = true

	--[[
		ENT:Use calls CS16_Use, so replacing that one method leaves the rest of
		the entity - its beeping, its timer, its explosion - completely alone.
	]]
	function ent:CS16_Use( activator )
		if not IsValid( activator ) or not activator:IsPlayer() then return end
		if activator:Team() ~= TEAM_CT then return end
		if not activator:KeyDown( IN_USE ) then return end

		-- Already working on it.
		if self.m_pBombDefuser == activator and activator.m_bIsDefusing then return end

		-- Somebody else is. sv_objectives blocks this in PlayerUse as well;
		-- repeated here because this is the only thing that starts a defuse.
		if IsValid( self.m_pBombDefuser ) and self.m_pBombDefuser.m_bIsDefusing then return end

		if Range( activator, self ) > CS16.Config.Bomb.DefuseRange then
			activator:ChatPrint( "Get closer to the bomb to defuse it." )
			return
		end

		BeginDefuse( self, activator )
	end
end )

-- A defuser who dies, or a bomb that goes off mid-defuse, leaves a player
-- pinned at walking speed 1 otherwise.
hook.Add( "PlayerDeath", "CS16.CancelDefuse", function( ply )
	if ply.m_bIsDefusing then StopDefuse( CS16.Bomb ) end
end )

hook.Add( "CS16RoundEnded", "CS16.CancelDefuse", function()
	for _, ply in ipairs( player.GetAll() ) do
		if ply.m_bIsDefusing then
			ply.m_bIsDefusing = false
			RestoreSpeed( ply )
			SendStatus( ply, false )
		end
	end
end )
