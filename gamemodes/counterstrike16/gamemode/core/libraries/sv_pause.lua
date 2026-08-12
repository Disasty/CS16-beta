--[[
	Pausing a live game.

	A developer tool, for the case where you are laying spawns out on a map that
	is being played on and the round keeps ending underneath you. Everybody in
	the match stops where they are; developers and spectators carry on as
	normal, which is the whole point of it.

	The clock stops too, and that is the half that actually matters. Freezing
	ten people while the round timer runs out anyway would solve nothing.
	CS16.PhaseEnd is a single global holding an absolute time, and every mode
	reads it, so holding it forward by the time that passes pauses competitive,
	gungame, team deathmatch and battle royale without any of them knowing.
]]

local paused = false
local at     = 0

function CS16.IsPaused()
	return paused
end

--[[
	Frozen where they stand.

	Freeze is engine-level and blocks movement whatever anything else does with
	the command, which matters because bots have their movement written for them
	every tick - see the pause check in sv_bots. Buttons are cleared separately
	below, because being frozen does not stop a trigger finger.
]]
local function Apply( ply )
	if not IsValid( ply ) then return end

	if paused and CS16.IsPlayingTeam( ply:Team() ) then
		ply:Freeze( true )
	else
		ply:Freeze( false )
	end
end

function CS16.SetPaused( on, by )
	if paused == on then return end

	paused = on
	at     = CurTime()

	SetGlobalBool( "CS16.Paused", paused )

	for _, ply in ipairs( player.GetAll() ) do Apply( ply ) end

	local who = IsValid( by ) and by:Nick() or "The server"

	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( ("[CS 1.6] %s %s the game."):format( who, paused and "paused" or "resumed" ) )
	end
end

--[[
	Hold the clock still by pushing its end away at the rate time passes.

	Cheaper and far less invasive than teaching four separate round machines
	what a pause is: they each keep asking "is CurTime past PhaseEnd yet", and
	the answer simply stays no.
]]
hook.Add( "Think", "CS16.PauseClock", function()
	if not paused then return end

	local now  = CurTime()
	local step = now - at
	at = now

	local phaseEnd = CS16.GetPhaseEnd()

	-- Zero means no clock is running - warmup, or a mode without a limit.
	if phaseEnd > 0 then
		SetGlobalFloat( "CS16.PhaseEnd", phaseEnd + step )
	end
end )

--[[
	No shooting either.

	Freeze stops the feet and nothing else, and a paused round that can still be
	won by whoever happens to be looking at somebody is not paused.
]]
hook.Add( "StartCommand", "CS16.PauseCommand", function( ply, cmd )
	if not paused then return end
	if not CS16.IsPlayingTeam( ply:Team() ) then return end

	cmd:ClearMovement()
	cmd:ClearButtons()
end )

-- Somebody joining or changing sides mid-pause gets the same treatment.
hook.Add( "PlayerSpawn",        "CS16.PauseApply", Apply )
hook.Add( "PlayerChangedTeam",  "CS16.PauseApply", Apply )

--[[
	A pause must never outlive the person who set it.

	Left running after the last developer disconnects it would freeze the server
	for everybody with nobody able to lift it - and the round clock would sit
	there being pushed forward forever.
]]
hook.Add( "PlayerDisconnected", "CS16.PauseGuard", function( ply )
	if not paused then return end

	for _, other in ipairs( player.GetAll() ) do
		if other ~= ply and other:Team() == TEAM_DEV then return end
	end

	CS16.SetPaused( false )
end )

CS16.AddCommand( "pause", {
	permission  = "round",
	description = "Freeze everyone in the match and stop the clock. Again to resume.",

	callback = function( ply )
		CS16.SetPaused( not paused, ply )
	end,
} )
