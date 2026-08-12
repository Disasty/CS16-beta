--[[
	Who can hear whom.

	Counter-Strike's rule, which is stricter than it first sounds: you hear
	your own side, and the dead never reach the living. That second half is the
	one that matters competitively - without it a dead player calls out
	positions from the grave and the round is decided by a spectator.

	This owns GM:PlayerCanHearPlayersVoice outright rather than sharing it.
	Muting is enforced here too, even though it belongs to the admin module,
	because a gamemode function can only be defined once and quietly having two
	files fight over it is how one of them silently stops working.
]]

function GM:PlayerCanHearPlayersVoice( listener, talker )
	-- An admin mute beats every other rule.
	if talker.CS16Muted then return false end

	local cfg = CS16.Config.Voice
	if not cfg.TeamOnly then return true end

	if cfg.AllTalkInWarmup and CS16.GetRoundState() == ROUND_WARMUP then
		return true
	end

	local listenerTeam = listener:Team()
	local talkerTeam   = talker:Team()

	-- Spectators are out of the round; they talk among themselves and are not
	-- audible to anybody still playing.
	if not CS16.IsPlayingTeam( talkerTeam ) or not CS16.IsPlayingTeam( listenerTeam ) then
		return listenerTeam == talkerTeam
	end

	if listenerTeam ~= talkerTeam then return false end

	-- Same side, but the dead don't get to advise the living.
	if not talker:Alive() and listener:Alive() then return false end

	return true
end

--[[
	sv_alltalk can short-circuit the above, so a server left with it on would
	quietly ignore every rule here and nobody would know until someone heard
	the other team. Turn it off when we intend voice to be team-only.
]]
hook.Add( "InitPostEntity", "CS16.EnforceTeamVoice", function()
	if not CS16.Config.Voice.TeamOnly then return end

	local alltalk = GetConVar( "sv_alltalk" )

	if alltalk and alltalk:GetBool() then
		RunConsoleCommand( "sv_alltalk", "0" )
		MsgN( "[CS 1.6] sv_alltalk turned off; voice is team-only." )
	end
end )
