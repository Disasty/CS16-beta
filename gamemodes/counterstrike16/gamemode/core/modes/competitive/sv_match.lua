--[[
	The match around the rounds: halftime, overtime, and when it's over.

	MR12. Twelve rounds a half, sides swap at the break, first to thirteen
	takes it. Twelve all after twenty-four goes to overtime - six rounds, first
	to four of them, swapping again halfway. A drawn overtime starts another
	one, so a match always produces a result.

	Rather than working any of that out from the score each time, a *period*
	holds three numbers: the score that wins it, the round it ends on, and the
	round the sides swap. Regulation and every overtime are then the same shape,
	and adding another overtime is just setting them again.
]]

local function Rounds()
	return CS16.GetScore( TEAM_T ) + CS16.GetScore( TEAM_CT )
end

--[[ Periods ]]

local function BeginRegulation()
	local cfg = CS16.Config.Match

	CS16.PeriodTarget = cfg.WinScore
	CS16.PeriodEnd    = cfg.MaxRounds
	CS16.PeriodSwapAt = cfg.HalfLength

	SetGlobalInt( "CS16.Overtime", 0 )
end

local function BeginOvertime()
	local cfg = CS16.Config.Match.Overtime

	-- Scores are level here by definition, so either side is the base.
	local base = CS16.GetScore( TEAM_T )

	CS16.PeriodTarget = base + cfg.WinsNeeded
	CS16.PeriodEnd    = Rounds() + cfg.Rounds
	CS16.PeriodSwapAt = Rounds() + math.floor( cfg.Rounds / 2 )

	SetGlobalInt( "CS16.Overtime", CS16.GetOvertime() + 1 )

	-- Overtime starts everyone on a fresh economy, as CS does.
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then CS16.ResetMoney( ply ) end
	end

	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( ("[CS 1.6] Overtime %d - first to %d.")
			:format( CS16.GetOvertime(), CS16.PeriodTarget ) )
	end
end

function CS16.MatchWinner()
	local target = CS16.PeriodTarget or CS16.Config.Match.WinScore

	if CS16.GetScore( TEAM_T ) >= target then return TEAM_T end
	if CS16.GetScore( TEAM_CT ) >= target then return TEAM_CT end

	return nil
end

--[[ Halftime ]]

function CS16.SwapSides()
	local t, ct = CS16.GetScore( TEAM_T ), CS16.GetScore( TEAM_CT )

	SetGlobalInt( "CS16.ScoreT",  ct )
	SetGlobalInt( "CS16.ScoreCT", t )

	--[[
		Collected first, then moved. Reading team membership while changing it
		would mean a player swapped to CT could be seen again as a CT and sent
		straight back.
	]]
	local movers = {}

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then
			movers[ #movers + 1 ] = { ply = ply, to = ( ply:Team() == TEAM_T ) and TEAM_CT or TEAM_T }
		end
	end

	for _, move in ipairs( movers ) do
		-- SetTeam rather than JoinTeam: this is the one time a side change
		-- isn't a choice, so none of the joining rules apply. The lock moves
		-- with them so they stay committed to their new side.
		CS16.SetTeam( move.ply, move.to )
		CS16.SetTeamLock( move.ply, move.to )
	end
end

--[[ What happens after a round ]]

--[[
	Decides the next step once a round's result is in. Returns true if it took
	over, meaning the round machine should not start another round itself.
]]
function CS16.AdvanceMatch()
	if not CS16.PeriodTarget then BeginRegulation() end

	if CS16.MatchWinner() then
		CS16.EndMatch()
		return true
	end

	-- Period played out level: another six rounds to settle it.
	if Rounds() >= CS16.PeriodEnd then
		BeginOvertime()
		CS16.StartHalftime()
		return true
	end

	if Rounds() == CS16.PeriodSwapAt then
		CS16.StartHalftime()
		return true
	end

	return false
end

--[[ End of match ]]

function CS16.EndMatch()
	if CS16.MatchIsOver() then return end

	SetGlobalBool( "CS16.MatchOver", true )
	SetGlobalInt( "CS16.MatchWinner", CS16.MatchWinner() or 0 )

	local winner = CS16.MatchWinner()
	local label  = "The match is a draw."

	if winner == TEAM_T then
		label = "Terrorists win the match."
	elseif winner == TEAM_CT then
		label = "Counter-Terrorists win the match."
	end

	--[[
		Announced before the hook rather than after, so anything that pays out on
		the match ending - experience, in particular - lands underneath the
		result rather than on top of it.
	]]
	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[CS 1.6] " .. label )
		ply:Freeze( false )
	end

	hook.Run( "CS16MatchEnded", winner )

	--[[
		Reload the map. That resets the scores, the period and every team lock
		in one go - the locks are cleared on load precisely so this is the only
		thing that has to happen for people to pick sides again.
	]]
	timer.Simple( CS16.Config.Match.EndDelay, function()
		game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
	end )
end

hook.Add( "InitPostEntity", "CS16.ResetMatch", function()
	SetGlobalBool( "CS16.MatchOver", false )
	SetGlobalInt( "CS16.MatchWinner", 0 )

	BeginRegulation()
end )

--[[ Testing aids ]]

CS16.AddCommand( "setscore", {
	permission  = "round",
	args        = "<t> <ct>",
	description = "Set the round score directly, for testing halftime and match end.",
	callback = function( ply, args )
		local t  = tonumber( args[ 1 ] )
		local ct = tonumber( args[ 2 ] )

		if not t or not ct or t < 0 or ct < 0 then
			ply:ChatPrint( "Usage: /setscore <t> <ct>" )
			return
		end

		SetGlobalInt( "CS16.ScoreT",  math.floor( t ) )
		SetGlobalInt( "CS16.ScoreCT", math.floor( ct ) )

		ply:ChatPrint( ("[CS 1.6] Score set to %d - %d. Rounds played: %d, swap at %d, ends at %d.")
			:format( t, ct, t + ct, CS16.PeriodSwapAt or 0, CS16.PeriodEnd or 0 ) )
	end,
} )

CS16.AddCommand( "halftime", {
	permission  = "round",
	description = "Swap sides and run the halftime break immediately.",
	callback = function( ply )
		CS16.StartHalftime()
	end,
} )
