--[[
	Gungame: the driver.

	Much simpler than competitive's round machine, because there are no rounds
	to speak of. Warmup until people arrive, a short freeze to spread out, then
	one long live phase that ends when somebody finishes the ladder.

	Everything else about the mode - who carries what, when you come back, how
	big the sides are - is declared in sh_gungame and asked for by the
	framework. This file only owns the things that change over time.
]]

local cfg    = CS16.GunGame
local LADDER = cfg.Ladder

local function SetState( state, duration )
	SetGlobalInt( "CS16.State", state )
	SetGlobalFloat( "CS16.PhaseEnd", duration and ( CurTime() + duration ) or 0 )
end

local function Playing( fn )
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then fn( ply ) end
	end
end

local function RosterCount()
	local n = 0
	Playing( function() n = n + 1 end )
	return n
end

--[[ Rungs ]]

--[[
	Put the rung's weapon in their hands and nothing else.

	Ammo is set rather than given, for the same reason the buy menu sets it: the
	pack's grenades hand you one in their Equip, so adding on top of that gives
	a different answer than the ladder intends.
]]
--[[
	Long enough for a muzzle flash to finish with the weapon that made it.
]]
local STRIP_DELAY = 0.5

function CS16.GunGameEquip( ply )
	local class = LADDER[ CS16.GunGameLevel( ply ) ]
	if not class then return end

	--[[
		The outgoing weapon is taken away a moment later rather than at once.

		A muzzle flash is a separate client-side effect that holds a reference
		to the weapon that fired it and keeps asking that weapon questions for
		several frames afterwards. Delete the weapon underneath it and every one
		of those frames errors, on every client watching. Harmless, but a
		promotion happens on a kill - which is precisely when a muzzle flash is
		in the air - so it filled the console steadily.

		Nothing is lost by waiting: the new weapon is in their hands
		immediately, and on a respawn the loadout has already stripped
		everything, so there's nothing here to wait for.
	]]
	local outgoing = {}

	for _, wep in ipairs( ply:GetWeapons() ) do
		if wep:GetClass() ~= class then outgoing[ #outgoing + 1 ] = wep:GetClass() end
	end

	ply:RemoveAllAmmo()

	CS16.GrantWeapon( ply, class )

	local item = CS16.BuyItemsByClass[ class ]

	if item and item.ammo and item.ammoMax then
		ply:SetAmmo( item.ammoMax, item.ammo )
	end

	ply:SelectWeapon( class )

	if #outgoing == 0 then return end

	timer.Simple( STRIP_DELAY, function()
		if not IsValid( ply ) or not ply:Alive() then return end

		for _, old in ipairs( outgoing ) do
			ply:StripWeapon( old )
		end
	end )
end

local function SetLevel( ply, level )
	ply:SetNWInt( "CS16.GGLevel", level )
	ply:SetNWInt( "CS16.GGKills", 0 )
end

local function Win( ply )
	if CS16.MatchIsOver() then return end

	SetGlobalBool( "CS16.MatchOver", true )
	SetGlobalInt( "CS16.MatchWinner", ply:Team() )
	SetGlobalString( "CS16.MatchWinnerName", ply:Nick() )

	SetState( ROUND_END, nil )

	for _, other in ipairs( player.GetAll() ) do
		other:ChatPrint( ("[CS 1.6] %s finished the ladder and wins the game."):format( ply:Nick() ) )
		other:Freeze( false )
	end

	--[[
		Reload the map, which resets levels, scores and the round state in one
		go - the same ending competitive uses, for the same reason.
	]]
	timer.Simple( CS16.Config.Match.EndDelay, function()
		game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
	end )
end

--[[
	A kill moves you along, and possibly up.

	Only the attacker matters: there's no team score to keep, and dying costs
	you nothing but the three seconds.
]]
local function Scored( ply )
	local level = CS16.GunGameLevel( ply )
	local kills = CS16.GunGameKills( ply ) + 1

	if kills < CS16.GunGameKillsNeeded( level ) then
		ply:SetNWInt( "CS16.GGKills", kills )
		return
	end

	-- The last rung cleared is the match, not a promotion.
	if level >= #LADDER then
		Win( ply )
		return
	end

	SetLevel( ply, level + 1 )

	local class = LADDER[ level + 1 ]

	--[[
		The weapon changes a frame later, deliberately.

		This runs from PlayerDeath, which the engine fires from inside the shot
		that caused the kill - the SWEP's own fire function is still on the
		stack. Stripping the weapon here pulls it out from under itself, and the
		next line that function runs finds no owner and errors.
	]]
	timer.Simple( 0, function()
		if IsValid( ply ) and ply:Alive() then CS16.GunGameEquip( ply ) end
	end )

	ply:ChatPrint( ("Level %d of %d - %s."):format(
		level + 1, #LADDER, CS16.GunGameWeaponName( class ) ) )

	--[[
		Reaching the knife is worth telling the room about: it's the only
		warning anybody gets that the game is one kill from over.
	]]
	if level + 1 >= #LADDER then
		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s is on the knife - one kill to win."):format( ply:Nick() ) )
		end
	end
end

--[[
	The two numbers either side of the clock.

	No team wins a gungame, but a running kill count is more use up there than a
	pair of permanent zeroes, and it gives the sides something to argue about
	while somebody else finishes the ladder.
]]
local function UpdateTeamScores()
	local t, ct = 0, 0

	for _, ply in ipairs( player.GetAll() ) do
		if ply:Team() == TEAM_T then
			t = t + ply:Frags()
		elseif ply:Team() == TEAM_CT then
			ct = ct + ply:Frags()
		end
	end

	SetGlobalInt( "CS16.ScoreT", t )
	SetGlobalInt( "CS16.ScoreCT", ct )
end

hook.Add( "PlayerDeath", "CS16.GunGameScore", function( victim, inflictor, attacker )
	if CS16.GetRoundState() ~= ROUND_LIVE then return end
	if CS16.MatchIsOver() then return end

	UpdateTeamScores()

	if not IsValid( attacker ) or not attacker:IsPlayer() then return end
	if attacker == victim then return end
	if not CS16.IsPlayingTeam( attacker:Team() ) then return end

	Scored( attacker )
end )

--[[ Phases ]]

local function StartWarmup()
	SetState( ROUND_WARMUP, nil )
	SetGlobalInt( "CS16.Winner", 0 )
	SetGlobalString( "CS16.EndReason", "Waiting for players" )

	Playing( function( ply )
		ply:Freeze( false )
		if not ply:Alive() then ply:Spawn() end
	end )
end

local function StartGame()
	SetGlobalInt( "CS16.Round", 1 )
	SetGlobalInt( "CS16.Winner", 0 )
	SetGlobalString( "CS16.EndReason", "" )

	CS16.ClearDroppedWeapons()

	-- State before spawning: PlayerSpawn asks CanTakeBody, which reads it.
	SetState( ROUND_FREEZE, cfg.FreezeTime )

	Playing( function( ply )
		SetLevel( ply, 1 )
		ply:Spawn()
		ply:Freeze( true )
	end )
end

local function StartLive()
	SetState( ROUND_LIVE, cfg.RoundTime > 0 and cfg.RoundTime or nil )
	Playing( function( ply ) ply:Freeze( false ) end )

	-- The same call competitive opens with. There is only one moment in a gun
	-- game where the cage opens, and it deserves the same announcement.
	CS16.BroadcastSound( CS16.Config.Sounds.RoundStart )
end

--[[
	Nobody finished in the time allowed, so the ladder decides it: furthest up
	wins, and the kills banked on the current rung break a tie.
]]
local function WinOnPoints()
	local best, bestLevel, bestKills

	Playing( function( ply )
		local level = CS16.GunGameLevel( ply )
		local kills = CS16.GunGameKills( ply )

		if not best or level > bestLevel or ( level == bestLevel and kills > bestKills ) then
			best, bestLevel, bestKills = ply, level, kills
		end
	end )

	if best then Win( best ) end
end

hook.Add( "Think", "CS16.GunGameThink", function()
	if CS16.MatchIsOver() then return end

	local state = CS16.GetRoundState()
	local now   = CurTime()

	if state == ROUND_WARMUP then
		if RosterCount() >= CS16.Config.Round.MinPlayers then StartGame() end
		return
	end

	if state == ROUND_FREEZE then
		if now >= CS16.GetPhaseEnd() then StartLive() end
		return
	end

	if state == ROUND_LIVE then
		--[[
			Anyone who joined after the game began starts at the bottom rather
			than at whatever the last person to hold their slot had reached. A
			bot swapped in for a leaver is the common case.
		]]
		Playing( function( ply )
			if ply:GetNWInt( "CS16.GGLevel", 0 ) == 0 then SetLevel( ply, 1 ) end
		end )

		if cfg.RoundTime > 0 and now >= CS16.GetPhaseEnd() then WinOnPoints() end
	end
end )

hook.Add( "InitPostEntity", "CS16.GunGameInit", function()
	SetGlobalBool( "CS16.MatchOver", false )
	SetGlobalInt( "CS16.MatchWinner", 0 )
	SetGlobalString( "CS16.MatchWinnerName", "" )

	SetGlobalInt( "CS16.ScoreT", 0 )
	SetGlobalInt( "CS16.ScoreCT", 0 )

	StartWarmup()
end )

--[[ Testing aids ]]

CS16.AddCommand( "gungame", {
	permission  = "round",
	args        = "<1x|2x>",
	description = "Set how many kills each rung of the ladder takes.",

	callback = function( ply, args )
		-- "2", "2x" and "x2" all clearly mean the same thing.
		local wanted = tonumber( string.match( args[ 1 ] or "", "%d+" ) )

		if not wanted or wanted < 1 or wanted > 5 then
			ply:ChatPrint( ("[CS 1.6] The ladder is %dx. Usage: /gungame <1x|2x>")
				:format( CS16.GunGamePace() ) )
			return
		end

		GetConVar( "cs16_gungame_kills" ):SetInt( wanted )

		--[[
			Banked kills are cleared rather than carried over. Otherwise
			dropping to 1x promotes everyone holding a kill on the instant, and
			raising it leaves them needing progress they already thought they
			had - neither of which is what anybody asked for.
		]]
		for _, other in ipairs( player.GetAll() ) do
			if CS16.IsPlayingTeam( other:Team() ) then
				other:SetNWInt( "CS16.GGKills", 0 )
			end
		end

		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s set the ladder to %dx - %d kill%s a rung."):format(
				ply:Nick(), wanted, wanted, wanted == 1 and "" or "s" ) )
		end
	end,
} )

CS16.AddCommand( "setlevel", {
	permission  = "round",
	args        = "<level>",
	description = "Put yourself on a rung of the gungame ladder.",

	callback = function( ply, args )
		local level = math.Clamp( tonumber( args[ 1 ] ) or 1, 1, #LADDER )

		SetLevel( ply, level )
		if ply:Alive() then CS16.GunGameEquip( ply ) end

		ply:ChatPrint( ("Level %d of %d - %s."):format(
			level, #LADDER, CS16.GunGameWeaponName( LADDER[ level ] ) ) )
	end,
} )
