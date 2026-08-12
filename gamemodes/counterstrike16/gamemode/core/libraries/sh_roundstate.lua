--[[
	Round state: the vocabulary every game mode speaks.

	This file only ever *reads*. Which mode is running decides what writes these
	- competitive's round machine today, deathmatch's tomorrow - but the HUD,
	the scoreboard, the bots and the announcer all ask the same questions
	whichever it is, so the questions live here rather than in any one mode.

	That's also what makes it safe to keep the whole set shared: every accessor
	reads a networked global with a default, so a mode that never writes one
	simply gets the default. A deathmatch with no bomb doesn't need to define
	IsBombPlanted to say "no" - it just never sets it.

	State rides on globals rather than a custom net message: they're small, they
	change rarely, and GMod replicates them for free.
]]

ROUND_WARMUP = 0
ROUND_FREEZE = 1
ROUND_LIVE   = 2
ROUND_END      = 3
ROUND_HALFTIME = 4

CS16.RoundStateNames = {
	[ ROUND_WARMUP ] = "Warmup",
	[ ROUND_FREEZE ] = "Freeze",
	[ ROUND_LIVE ]   = "Live",
	[ ROUND_END ]      = "Round over",
	[ ROUND_HALFTIME ] = "Halftime",
}

function CS16.GetRoundState()
	return GetGlobalInt( "CS16.State", ROUND_WARMUP )
end

-- When the current phase runs out. Meaningless during warmup.
function CS16.GetPhaseEnd()
	return GetGlobalFloat( "CS16.PhaseEnd", 0 )
end

function CS16.GetPhaseRemaining()
	return math.max( 0, CS16.GetPhaseEnd() - CurTime() )
end

function CS16.GetRoundNumber()
	return GetGlobalInt( "CS16.Round", 0 )
end

function CS16.GetScore( t )
	if t == TEAM_T then return GetGlobalInt( "CS16.ScoreT", 0 ) end
	if t == TEAM_CT then return GetGlobalInt( "CS16.ScoreCT", 0 ) end
	return 0
end

function CS16.GetMoney( ply )
	return ply:GetNWInt( "CS16.Money", 0 )
end

-- 0 when the round is still running or ended in a draw.
function CS16.GetRoundWinner()
	return GetGlobalInt( "CS16.Winner", 0 )
end

function CS16.GetRoundEndReason()
	return GetGlobalString( "CS16.EndReason", "" )
end

--[[
	Match state, shared so the HUD can announce a result whatever produced it.
	Any mode that ends is expected to set these.
]]
function CS16.MatchIsOver()
	return GetGlobalBool( "CS16.MatchOver", false )
end

-- 0 for a draw.
function CS16.GetMatchWinner()
	return GetGlobalInt( "CS16.MatchWinner", 0 )
end

--[[
	The winning player's name, when a mode is won by a person rather than a
	side - gungame's ladder is finished by somebody in particular.

	Empty for the modes where it isn't, which is why the HUD can prefer it when
	set and fall back to the team without knowing which mode is running.
]]
function CS16.GetMatchWinnerName()
	return GetGlobalString( "CS16.MatchWinnerName", "" )
end

-- 0 during regulation, then 1 for the first overtime and so on. Modes without
-- overtime never write it, so it reads 0 and nothing has to ask whether the
-- concept applies.
function CS16.GetOvertime()
	return GetGlobalInt( "CS16.Overtime", 0 )
end

--[[
	Bomb state.

	Read here rather than in the objective that writes it, so the HUD and the
	bots see exactly the same thing the round logic does - and so a mode with no
	bomb answers "no" for free.
]]
function CS16.IsBombPlanted()
	return GetGlobalBool( "CS16.BombPlanted", false )
end

function CS16.GetBombRemaining()
	return math.max( 0, GetGlobalFloat( "CS16.BombExplodeAt", 0 ) - CurTime() )
end

--[[
	Whoever is currently defusing, or NULL.

	Three separate things need it: the HUD warns the team, the bots keep clear,
	and the server decides who's allowed to start. The addon provides no signal
	of its own, so the defuse publishes it here.
]]
function CS16.GetDefuser()
	return GetGlobalEntity( "CS16.Defuser", NULL )
end

-- Round time counts down as mm:ss, the way the 1.6 HUD showed it.
function CS16.FormatTime( seconds )
	seconds = math.max( 0, math.ceil( seconds ) )
	return ("%d:%02d"):format( math.floor( seconds / 60 ), seconds % 60 )
end
