--[[
	Team Deathmatch.

	One continuous game rather than a series of rounds: warmup until there are
	people, then live until a side reaches the score limit or the clock runs out,
	then a short result and a map reload for the next one.

	Nothing here touches buying, respawning or friendly fire - those are settings
	on the registration, handled by the framework. What is left is the score, the
	loadout you keep, and knowing when it is over.
]]

local cfg = CS16.Config.TDM

--[[ State ]]

--[[
	The same globals every other mode drives, so the HUD, the scoreboard and the
	round-state accessors work here without knowing this mode exists.
]]
local function SetState( state, duration )
	SetGlobalInt( "CS16.State", state )
	SetGlobalFloat( "CS16.PhaseEnd", duration and ( CurTime() + duration ) or 0 )
end

local function Playing( fn )
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then fn( ply ) end
	end
end

local function TeamScore( teamID )
	return CS16.GetScore( teamID )
end

local function AddScore( teamID, amount )
	local key = teamID == TEAM_T and "CS16.ScoreT" or "CS16.ScoreCT"
	SetGlobalInt( key, GetGlobalInt( key, 0 ) + amount )
end

--[[ Loadout ]]

--[[
	What you bought is what you come back with.

	Snapshotted with the framework's own CaptureLoadout rather than by tracking
	individual purchases, which means it picks up everything without having to
	understand any of it - guns, grenades, armour, the helmet, ammunition
	counts. Taken after the purchase completes, so it records what you actually
	ended up holding rather than what you asked for.
]]
hook.Add( "CS16Bought", "CS16.TDMRemember", function( ply )
	if not CS16.IsPlayingTeam( ply:Team() ) then return end

	ply.CS16TDMKit = CS16.CaptureLoadout( ply )
end )

--[[
	Only on purchase, deliberately - not also on death.

	Capturing at death looks like the thorough thing to do and is actively wrong
	here: by the time PlayerDeath runs, the drop-on-death rules have already
	taken your primary and secondary off you, so the snapshot is a knife and
	nothing else. It passed a "did we get anything" check and overwrote the good
	kit, and every respawn after your first came with a knife.

	Buying is the only thing that should define the loadout anyway - that is what
	the mode is - so picking a rifle up off the floor doesn't change what you
	come back with, and neither does throwing the grenades you were given.
]]

--[[
	A bot's kit, redrawn every spawn.

	See the note on cfg.BotPrimaries for why this is a random draw rather than a
	trip through the buy menu. Ammunition comes from the catalogue entry so a
	bot is not left with a rifle and one magazine.
]]
local function EquipBot( bot )
	local function give( class )
		local wep = CS16.GrantWeapon( bot, class )
		if not IsValid( wep ) then return end

		local item = CS16.BuyItemsByClass[ class ]
		if item and item.ammo and item.ammoMax then
			bot:SetAmmo( item.ammoMax, item.ammo )
		end
	end

	give( cfg.BotPrimaries[ math.random( #cfg.BotPrimaries ) ] )
	give( cfg.BotSecondaries[ math.random( #cfg.BotSecondaries ) ] )

	bot:Give( CS16.KNIFE )
end

function CS16.TDMEquip( ply )
	ply:RemoveAllAmmo()
	ply:StripWeapons()

	if ply:IsBot() then
		EquipBot( ply )
		return
	end

	local kit = ply.CS16TDMKit

	if kit and #kit.weapons > 0 then
		CS16.RestoreLoadout( ply, kit )
		return
	end

	-- Nothing bought yet: the same opening competitive gives you.
	for _, class in ipairs( cfg.Starting ) do
		CS16.GrantWeapon( ply, class )
	end

	ply:Give( CS16.KNIFE )
end

--[[ Ammunition ]]

--[[
	Reserve ammunition never goes down.

	Reloading still costs you the time and the animation - the magazine empties
	and has to be filled - but the number beside it does not move. Running dry in
	a mode with no economy and instant respawns just means walking to a corner
	and waiting, which is nobody's idea of deathmatch.

	Done by putting the reserve back rather than by intercepting the reload:
	every gun in the pack reloads its own way and there is no single hook they
	all pass through, but they all draw from the same ammo pool afterwards.

	The level held is the most you have ever had of that calibre this life, not
	the catalogue's maximum. Buying a rifle hands over more than the catalogue
	lists, so holding to that number would make the reserve visibly tick *down*
	after every purchase and settle lower - which is the one thing this is
	supposed to stop. Whatever you were given is the number that stays.

	Only weapons with a magazine, which is what excludes grenades: they hold no
	clip, so they never match, and an endless supply of those would be a very
	different mode from the one being asked for.
]]
local nextTopUp = 0

local function HoldAmmo( ply )
	local held = ply.CS16TDMAmmo
	if not held then held = {} ply.CS16TDMAmmo = held end

	for _, wep in ipairs( ply:GetWeapons() ) do
		if wep:GetMaxClip1() > 0 then
			local ammoType = wep:GetPrimaryAmmoType()

			if ammoType and ammoType >= 0 then
				local have = ply:GetAmmoCount( ammoType )
				local mark = held[ ammoType ]

				if not mark or have > mark then
					-- A new high: buying, or a fresh loadout. That becomes the level.
					held[ ammoType ] = have
				elseif have < mark then
					ply:SetAmmo( mark, ammoType )
				end
			end
		end
	end
end

hook.Add( "Think", "CS16.TDMAmmo", function()
	if not cfg.UnlimitedAmmo then return end
	if CurTime() < nextTopUp then return end
	nextTopUp = CurTime() + 0.4

	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() and CS16.IsPlayingTeam( ply:Team() ) then
			HoldAmmo( ply )
		end
	end
end )

--[[
	Forgotten on respawn, so the level is set fresh by whatever you come back
	holding. Without this, dropping to a pistol would still hold a rifle's worth
	of reserve for a calibre you are no longer carrying.
]]
hook.Add( "PlayerSpawn", "CS16.TDMAmmoReset", function( ply )
	ply.CS16TDMAmmo = nil
end )

--[[ Scoring ]]

hook.Add( "PlayerDeath", "CS16.TDMScore", function( victim, inflictor, attacker )
	if CS16.GetRoundState() ~= ROUND_LIVE then return end
	if not IsValid( attacker ) or not attacker:IsPlayer() then return end
	if attacker == victim then return end
	if not CS16.IsPlayingTeam( attacker:Team() ) then return end

	--[[
		A team kill scores nothing, for the same reason it costs a frag and pays
		no experience: otherwise the fastest way to the score limit is to shoot
		your own side, who are not trying to stop you.
	]]
	if attacker:Team() == victim:Team() then return end

	AddScore( attacker:Team(), 1 )
end )

--[[ The game ]]

local function StartWarmup()
	SetState( ROUND_WARMUP, nil )

	SetGlobalInt( "CS16.ScoreT", 0 )
	SetGlobalInt( "CS16.ScoreCT", 0 )
	SetGlobalInt( "CS16.Winner", 0 )
	SetGlobalString( "CS16.EndReason", "Waiting for players" )

	Playing( function( ply )
		ply:Freeze( false )
		if not ply:Alive() then ply:Spawn() end
	end )
end

local function StartGame()
	SetGlobalInt( "CS16.Round", 1 )
	SetGlobalInt( "CS16.ScoreT", 0 )
	SetGlobalInt( "CS16.ScoreCT", 0 )
	SetGlobalString( "CS16.EndReason", "" )

	SetState( ROUND_LIVE, cfg.TimeLimit > 0 and cfg.TimeLimit or nil )

	--[[
		Belt and braces on top of Dropping being off.

		Nothing should be on the floor to begin with, but this mode never ends a
		round, so anything that does get there stays for the whole game - and
		the start of a new one is the only chance to sweep it.
	]]
	if CS16.ClearDroppedWeapons then CS16.ClearDroppedWeapons() end

	--[[
		Everybody starts fresh, including their kit. Carrying a loadout across
		the start of a new game would hand whoever was here first a rifle
		against everyone else's pistol.
	]]
	Playing( function( ply )
		ply.CS16TDMKit = nil
		ply:Freeze( false )
		ply:Spawn()
	end )

	CS16.BroadcastSound( CS16.Config.Sounds.RoundStart )
end

local function EndGame( winner, reason )
	SetState( ROUND_END, cfg.EndTime )

	SetGlobalBool( "CS16.MatchOver", true )
	SetGlobalInt( "CS16.MatchWinner", winner or 0 )
	SetGlobalInt( "CS16.Winner", winner or 0 )
	SetGlobalString( "CS16.EndReason", reason or "" )

	if winner == TEAM_T then
		CS16.BroadcastSound( CS16.Config.Sounds.WinT )
	elseif winner == TEAM_CT then
		CS16.BroadcastSound( CS16.Config.Sounds.WinCT )
	else
		CS16.BroadcastSound( CS16.Config.Sounds.Draw )
	end

	for _, ply in ipairs( player.GetAll() ) do
		ply:Freeze( false )
		ply:ChatPrint( "[CS 1.6] " .. ( reason or "Game over." ) )
	end

	--[[
		A reload, the same way competitive ends a match. It resets the scores,
		everybody's kit and every team lock in one go, and it is the only thing
		that has to happen for the next game to start clean.
	]]
	timer.Simple( cfg.EndTime, function()
		game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
	end )
end

local function EnoughPlayers()
	local t, ct = 0, 0

	for _, ply in ipairs( player.GetAll() ) do
		if ply:Team() == TEAM_T then t = t + 1
		elseif ply:Team() == TEAM_CT then ct = ct + 1 end
	end

	return t > 0 and ct > 0
end

--[[ Driver ]]

hook.Add( "Think", "CS16.TDMThink", function()
	if CS16.MatchIsOver and CS16.MatchIsOver() and CS16.GetRoundState() == ROUND_END then
		return
	end

	local state = CS16.GetRoundState()

	if state == ROUND_WARMUP then
		if EnoughPlayers() then StartGame() end
		return
	end

	if state ~= ROUND_LIVE then return end

	local t, ct = TeamScore( TEAM_T ), TeamScore( TEAM_CT )

	if cfg.ScoreLimit > 0 then
		if t >= cfg.ScoreLimit then
			EndGame( TEAM_T, "Terrorists reached the score limit." )
			return
		end

		if ct >= cfg.ScoreLimit then
			EndGame( TEAM_CT, "Counter-Terrorists reached the score limit." )
			return
		end
	end

	-- The clock. Whoever is ahead takes it; level is a draw.
	if cfg.TimeLimit > 0 and CurTime() >= CS16.GetPhaseEnd() then
		if t > ct then
			EndGame( TEAM_T, "Time up - Terrorists win." )
		elseif ct > t then
			EndGame( TEAM_CT, "Time up - Counter-Terrorists win." )
		else
			EndGame( nil, "Time up - the game is a draw." )
		end
	end
end )

hook.Add( "InitPostEntity", "CS16.TDMStart", function()
	SetGlobalBool( "CS16.MatchOver", false )
	SetGlobalInt( "CS16.MatchWinner", 0 )

	StartWarmup()
end )
