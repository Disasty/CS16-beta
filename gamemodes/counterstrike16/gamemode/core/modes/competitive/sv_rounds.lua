--[[
	The round state machine - the heart of the gamemode.

	warmup -> freeze -> live -> end -> freeze -> ...

	Everything else hangs off this: when you may buy, when you get a body, when
	the bomb can be planted. Bomb win conditions land in sv_objectives later;
	for now a live round is decided by elimination or by the clock.
]]

util.AddNetworkString( "CS16.Sound" )

local function SetState( state, duration )
	SetGlobalInt( "CS16.State", state )
	SetGlobalFloat( "CS16.PhaseEnd", duration and ( CurTime() + duration ) or 0 )
end

-- Who is on a side right now, used to decide whether a round can start.
local function RosterCount()
	local n = 0

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then n = n + 1 end
	end

	return n
end

--[[
	Who is actually contesting the current round.

	This deliberately reads CS16RoundTeam - the side a player was on when the
	round started - rather than their current team. Counting live team
	membership would mean someone joining mid-round registered as a dead member
	of that side and instantly ended the round for the other one.
]]
local function RoundCounts()
	local t, ct, tAlive, ctAlive = 0, 0, 0, 0

	for _, ply in ipairs( player.GetAll() ) do
		local side = ply.CS16RoundTeam

		if side == TEAM_T then
			t = t + 1
			if ply:Alive() then tAlive = tAlive + 1 end
		elseif side == TEAM_CT then
			ct = ct + 1
			if ply:Alive() then ctAlive = ctAlive + 1 end
		end
	end

	return t, ct, tAlive, ctAlive
end

local function EnoughPlayers()
	return RosterCount() >= CS16.Config.Round.MinPlayers
end

-- A contested round needs somebody on each side. Without that we still let the
-- round run so a lone developer can move around, we just don't score it.
local function BothTeamsPopulated()
	local t, ct = RoundCounts()
	return t > 0 and ct > 0
end

-- CanTakeBody is this mode's answer to a question the framework asks, so it
-- lives with the rest of its policy in sh_competitive.lua.

local function ForEachPlayer( fn )
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then fn( ply ) end
	end
end

--[[
	One Terrorist carries the bomb each round, drawn at random.

	Note the C4 SWEP plants anywhere it likes right now - the addon has no
	bomb-site check of its own. Gating that to func_bomb_target is a job for
	sv_objectives.
]]
local function AssignBomb()
	-- A rescue map has nowhere to plant it. Handing one out anyway would give a
	-- Terrorist a bomb, a HUD carrier line, and no way to use either.
	if CS16.IsHostageMap() then return end

	local candidates = {}

	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16RoundTeam == TEAM_T and ply:Alive() then
			candidates[ #candidates + 1 ] = ply
		end
	end

	if #candidates == 0 then return end

	local carrier = candidates[ math.random( #candidates ) ]
	carrier:Give( "weapon_cs16_c4" )
	carrier:GiveAmmo( 1, "CS16_C4", true )

	-- The whole T side needs to know who has it.
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16RoundTeam == TEAM_T then
			ply:ChatPrint( ply == carrier
				and "You have the bomb. Plant it at a bomb site."
				or ( carrier:Nick() .. " has the bomb." ) )
		end
	end
end

local function BombInPlay()
	return CS16.IsBombPlanted() or #ents.FindByClass( "weapon_cs16_c4" ) > 0
end

--[[
	Anyone who reached a side just after the round was snapshotted.

	StartRound records who is contesting the round, and everything downstream
	reads that record rather than live team membership - which is what stops
	someone joining mid-round from instantly ending it for the side they joined.
	The price is that anyone arriving a moment too late sat the whole round out,
	invisibly.

	`/bots 10` followed straight away by `/restartround` is the case that showed
	it: the bots aren't on a side yet when the round is snapshotted, so the
	round ran with an empty roster. No Terrorist meant nobody could be given the
	bomb, and no roster at all meant the win checks saw an unpopulated round and
	could only ever call it a draw - which is why a restarted round always ended
	that way unless a bomb happened to be down already.

	Freeze time is exactly the window where the roster is still settling, so
	arrivals during it are admitted rather than shut out.
]]
local function AdmitLateArrivals()
	local joined = false

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) and not ply.CS16RoundTeam then
			ply.CS16RoundTeam = ply:Team()

			if not ply:Alive() then ply:Spawn() end
			ply:Freeze( true )

			joined = true
		end
	end

	-- A Terrorist who arrived after the draw was made still has to be able to
	-- receive the bomb, or their side has no way to win.
	if joined and not BombInPlay() then AssignBomb() end
end

-- Round announcements play flat in everyone's ears rather than from a position
-- in the world, so they go out as a net message the client plays 2D.
local function PlaySound( key )
	local path = CS16.Config.Sounds[ key ]
	if not path or path == "" then return end

	net.Start( "CS16.Sound" )
		net.WriteString( path )
	net.Broadcast()
end

--[[ Phases ]]

function CS16.StartWarmup()
	SetState( ROUND_WARMUP, nil )
	SetGlobalInt( "CS16.Winner", 0 )
	SetGlobalString( "CS16.EndReason", "Waiting for players" )

	ForEachPlayer( function( ply )
		ply:Freeze( false )
		if not ply:Alive() then ply:Spawn() end
	end )
end

function CS16.StartRound()
	SetGlobalInt( "CS16.Round", CS16.GetRoundNumber() + 1 )
	SetGlobalInt( "CS16.Winner", 0 )
	SetGlobalString( "CS16.EndReason", "" )

	-- Sweep away last round's bomb and anything dropped, before anyone spawns
	-- on top of it. Otherwise guns pile up map-wide across a match.
	CS16.ClearBomb()
	CS16.ClearDroppedWeapons()

	-- State goes first: PlayerSpawn asks CanTakeBody, which needs to already
	-- see the freeze phase or nobody would get a body.
	SetState( ROUND_FREEZE, CS16.Config.Round.FreezeTime )

	-- Snapshot who is contesting this round. Anyone who joins after this point
	-- sits out until the next one.
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then
			ply.CS16RoundTeam = ply:Team()

			--[[
				Anyone who genuinely survived keeps their kit; PlayerLoadout
				picks this up and restores it instead of handing out the
				starting pistol.

				Survived is stricter than Alive on purpose - see its comment;
				a mid-round joiner is alive but empty-handed.
			]]
			ply.CS16Carry = CS16.Survived( ply ) and CS16.CaptureLoadout( ply ) or nil

			ply:Spawn()
			ply:Freeze( true )
		else
			ply.CS16RoundTeam = nil
			ply.CS16Carry     = nil
		end
	end

	-- After the spawn loop: PlayerLoadout strips weapons, so handing the bomb
	-- out any earlier would throw it straight back away.
	AssignBomb()

	--[[
		The counterpart to CS16RoundEnded, for whatever the map's objective needs
		setting up - hostages placed, on Italy. Fired at the top of freeze rather
		than on going live so it's all standing there before the cage opens.
	]]
	hook.Run( "CS16RoundStarted", CS16.GetRoundNumber() )
end

--[[
	The break between halves. Sides swap here rather than at the moment the
	round ended, so the scoreboard people are looking at during the break is
	already the right way round.
]]
function CS16.StartHalftime()
	CS16.SwapSides()

	SetState( ROUND_HALFTIME, CS16.Config.Match.HalftimeLength )

	ForEachPlayer( function( ply )
		ply:Freeze( false )
	end )

	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( "[CS 1.6] Halftime - sides swapped." )
	end

	hook.Run( "CS16HalftimeStarted" )
end

function CS16.StartLive()
	SetState( ROUND_LIVE, CS16.Config.Round.RoundTime )

	ForEachPlayer( function( ply )
		ply:Freeze( false )
	end )

	PlaySound( "RoundStart" )
end

function CS16.EndRound( winner, reason )
	SetState( ROUND_END, CS16.Config.Round.EndTime )
	SetGlobalInt( "CS16.Winner", winner or 0 )
	SetGlobalString( "CS16.EndReason", reason or "" )

	-- Let people move again while the result is on screen.
	ForEachPlayer( function( ply ) ply:Freeze( false ) end )

	if winner == TEAM_T then
		SetGlobalInt( "CS16.ScoreT", CS16.GetScore( TEAM_T ) + 1 )
		PlaySound( "WinT" )
	elseif winner == TEAM_CT then
		SetGlobalInt( "CS16.ScoreCT", CS16.GetScore( TEAM_CT ) + 1 )
		PlaySound( "WinCT" )
	else
		PlaySound( "Draw" )
	end

	if winner then CS16.AwardRoundMoney( winner ) end

	--[[
		Take the bomb out with the round.

		It used to survive until the next round started, so a round won by
		wiping the CTs would still detonate a few seconds later - killing the
		Terrorists who had already won it, and reading as though the round had
		been waiting on the bomb all along.
	]]
	if CS16.ClearBomb then CS16.ClearBomb() end

	hook.Run( "CS16RoundEnded", winner, reason )
end

local function CheckRoundWinConditions()
	local t, ct, tAlive, ctAlive = RoundCounts()

	--[[
		Each side is judged on its own count rather than behind a single
		"are both sides populated" gate. That gate could suppress a perfectly
		legitimate elimination win whenever one side's participant count read
		as zero, which would leave a round running on regardless.

		A side can only be wiped out if it actually fielded someone.
	]]

	-- Wiping the CTs wins it outright, bomb or no bomb. A planted bomb with
	-- nobody left alive to defuse it is already a Terrorist win.
	if ct > 0 and ctAlive == 0 then
		CS16.EndRound( TEAM_T, "Counter-Terrorists eliminated" )
		return
	end

	if t > 0 and tAlive == 0 then
		-- Killing the last Terrorist doesn't win the round if the bomb is
		-- already down - the CTs still have to go and defuse it.
		if CS16.IsBombPlanted() then return end

		CS16.EndRound( TEAM_CT, "Terrorists eliminated" )
	end
end

--[[ Driver ]]

hook.Add( "Think", "CS16.RoundThink", function()
	-- Match won: everything stops until the map reloads.
	if CS16.MatchIsOver() then return end

	local state = CS16.GetRoundState()
	local now   = CurTime()

	if state == ROUND_WARMUP then
		if EnoughPlayers() then CS16.StartRound() end
		return
	end

	if state == ROUND_FREEZE then
		AdmitLateArrivals()

		if now >= CS16.GetPhaseEnd() then CS16.StartLive() end
		return
	end

	if state == ROUND_LIVE then
		CheckRoundWinConditions()

		-- It may have ended already.
		if CS16.GetRoundState() ~= ROUND_LIVE then return end

		if now >= CS16.GetPhaseEnd() then
			-- Once the bomb is down the round clock stops mattering; the bomb
			-- timer decides it from here.
			if CS16.IsBombPlanted() then return end

			if BothTeamsPopulated() then
				--[[
					The clock belongs to the defender, and which side that is
					depends on the objective. The Terrorists are attacking a
					bomb site, so running out of time loses it for them; on a
					rescue map they're guarding the hostages, so the same clock
					running out means the Counter-Terrorists failed.
				]]
				if CS16.IsHostageMap() then
					CS16.EndRound( TEAM_T, "Hostages were not rescued" )
				else
					CS16.EndRound( TEAM_CT, "Terrorists ran out of time" )
				end
			else
				CS16.EndRound( nil, "Time expired" )
			end
		end
		return
	end

	if state == ROUND_HALFTIME then
		if now >= CS16.GetPhaseEnd() then CS16.StartRound() end
		return
	end

	if state == ROUND_END then
		if now < CS16.GetPhaseEnd() then return end

		-- The match layer decides what follows: a winner, overtime, or the
		-- halftime break. If it takes over, no round starts here.
		if CS16.AdvanceMatch() then return end

		if EnoughPlayers() then
			CS16.StartRound()
		else
			CS16.StartWarmup()
		end
	end
end )

function CS16.ResetScores()
	SetGlobalInt( "CS16.ScoreT", 0 )
	SetGlobalInt( "CS16.ScoreCT", 0 )
	SetGlobalInt( "CS16.Round", 0 )
end

hook.Add( "InitPostEntity", "CS16.RoundInit", function()
	CS16.ResetScores()
	CS16.StartWarmup()
end )

--[[ Developer controls ]]

CS16.AddCommand( "restartround", {
	permission  = "round",
	description = "Force a new round to start immediately.",
	callback = function( ply )
		ply:ChatPrint( "Restarting round." )
		CS16.StartRound()
	end,
} )

-- Answers "why hasn't this round ended yet" without guesswork.
CS16.AddCommand( "roundinfo", {
	permission  = "round",
	description = "Show the live round counts the win checks are reading.",
	callback = function( ply )
		local t, ct, tAlive, ctAlive = RoundCounts()

		ply:ChatPrint( ("[CS 1.6] state=%s  bomb=%s"):format(
			CS16.RoundStateNames[ CS16.GetRoundState() ] or "?",
			CS16.IsBombPlanted() and "planted" or "no" ) )

		ply:ChatPrint( ("[CS 1.6] T %d/%d alive   CT %d/%d alive"):format(
			tAlive, t, ctAlive, ct ) )
	end,
} )

CS16.AddCommand( "resetscore", {
	permission  = "round",
	description = "Reset the round score to 0 - 0.",
	callback = function( ply )
		CS16.ResetScores()
		ply:ChatPrint( "Score reset." )
	end,
} )
