--[[
	Battle Royale.

	Warmup until there are enough people, then everyone is placed on a spawn of
	their own with a knife, guns appear on every loot point, and it runs until
	one person is left.

	The spawns and the loot points are authored per map - see /brspawn and
	/brloot. Without them the mode has nowhere to put anybody and says so rather
	than dropping ten people into the same doorway.
]]

local cfg = CS16.Config.BR

local function SetState( state, duration )
	SetGlobalInt( "CS16.State", state )
	SetGlobalFloat( "CS16.PhaseEnd", duration and ( CurTime() + duration ) or 0 )
end

local function Playing( fn )
	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then fn( ply ) end
	end
end

local function Contenders()
	local alive = {}

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) and ply:Alive() then
			alive[ #alive + 1 ] = ply
		end
	end

	return alive
end

--[[ Spawns ]]

--[[
	One authored spawn each, handed out by shuffling rather than by picking.

	The whole reason these are placed by hand is that the map's own spawns put
	nine people in one room. Picking at random per player would undo that the
	moment two of them drew the same one, so the list is shuffled once and dealt.

	Held on the player rather than looked up again, because PlayerSelectSpawn is
	asked separately for each of them as they spawn.
]]
local function DealSpawns()
	local pool = {}
	for i, spot in ipairs( CS16.BRSpawns ) do pool[ i ] = spot end

	for i = #pool, 2, -1 do
		local j = math.random( i )
		pool[ i ], pool[ j ] = pool[ j ], pool[ i ]
	end

	local i = 0

	Playing( function( ply )
		i = i + 1
		--[[
			More players than spawns wraps around rather than leaving anybody
			without one. It should not happen - ten spawns for ten players - but
			spawning nobody is a worse failure than spawning two together.
		]]
		ply.CS16BRSpawn = pool[ ( ( i - 1 ) % math.max( #pool, 1 ) ) + 1 ]
	end )
end

hook.Add( "PlayerSelectSpawn", "CS16.BRSpawn", function( ply )
	local spot = ply.CS16BRSpawn
	if not spot then return end

	--[[
		A real spawn entity is expected here, not a position, so one is made and
		moved. Created fresh each time and removed a moment later rather than
		kept around, since a stray info_player_start lying about would be picked
		up by the map's own spawn logic in every other mode.
	]]
	local point = ents.Create( "info_player_terrorist" )
	if not IsValid( point ) then return end

	point:SetPos( spot.pos + Vector( 0, 0, 8 ) )
	point:SetAngles( Angle( 0, spot.yaw, 0 ) )
	point:Spawn()

	SafeRemoveEntityDelayed( point, 1 )

	return point
end )

--[[ Loot ]]

local function ClearLoot()
	for _, ent in ipairs( ents.FindByClass( "cs16_item_weapon" ) ) do
		SafeRemoveEntity( ent )
	end
end

--[[
	A gun on every loot point, once, at the start of the match.

	Built by setting the pickup entity's fields directly rather than by creating
	a weapon and packing it - the entity only ever stores a class name, so
	spawning a real weapon just to delete it again would be work for nothing.
]]
local function SpawnLoot()
	ClearLoot()

	for _, spot in ipairs( CS16.BRLoot ) do
		local class  = cfg.Loot[ math.random( #cfg.Loot ) ]
		local stored = weapons.GetStored( class )
		local item   = ents.Create( "cs16_item_weapon" )

		if IsValid( item ) and stored then
			-- Set before Spawn: the entity reads self.Model in its Initialize.
			item.Model = stored.WorldModel

			item:SetPos( spot.pos + Vector( 0, 0, 6 ) )
			item:SetAngles( Angle( 0, math.random( 360 ), 0 ) )
			item:Spawn()

			item.m_strWeapon = class

			local catalogue = CS16.BuyItemsByClass[ class ]
			local clip      = stored.Primary and stored.Primary.ClipSize or 0

			item:PackClip( clip > 0 and clip or -1, -1 )

			if catalogue and catalogue.ammo then
				item:PackAmmo( catalogue.ammo, ( clip > 0 and clip or 0 ) * cfg.SpareMagazines )
			end
		end
	end

	MsgN( ("[CS 1.6] Battle royale: %d loot point(s) filled."):format( #CS16.BRLoot ) )
end

--[[ Loadout ]]

function CS16.BREquip( ply )
	ply:RemoveAllAmmo()
	ply:StripWeapons()

	-- A knife, and nothing else. The map provides the rest.
	ply:Give( CS16.KNIFE )

	--[[
		And a full vest, which nobody buys because nobody buys anything here.

		Without it the first person to find a rifle ends the round in about two
		shots per opponent, which makes finding one the whole game rather than
		the start of it. Armour buys the other nine long enough to answer.
	]]
	ply:SetArmor( CS16.Config.BR.Armor )
end

--[[
	Pick something up and you draw it.

	Everyone starts on a knife, so without this the first gun you find goes into
	your hands and stays there while you carry on swinging - which looks exactly
	like the pickup not working, and for a bot amounts to it.

	Only when the knife is what you are holding. Once you are armed, walking over
	a pistol should not take a rifle out of your hands mid-fight, and that is a
	decision the player has already made by carrying what they carry.

	Deferred a frame: WeaponEquip fires as the weapon is being attached, and
	selecting it in the middle of that is asking the engine to switch to
	something it has not finished giving you.
]]
hook.Add( "WeaponEquip", "CS16.BRDraw", function( wep, owner )
	if not IsValid( wep ) then return end

	timer.Simple( 0, function()
		if not IsValid( wep ) then return end

		local ply = IsValid( owner ) and owner or wep:GetOwner()
		if not IsValid( ply ) or not ply:IsPlayer() then return end
		if not CS16.IsPlayingTeam( ply:Team() ) or not ply:Alive() then return end

		if wep:GetClass() == CS16.KNIFE then return end

		local held = ply:GetActiveWeapon()
		if IsValid( held ) and held:GetClass() ~= CS16.KNIFE then return end

		ply:SelectWeapon( wep:GetClass() )
	end )
end )

--[[ Bots ]]

--[[
	Find a gun, then find somebody.

	A bot with only a knife has no business hunting - it loses every fight it
	finds - so until it is holding something that shoots, the nearest unclaimed
	loot point is the whole plan. Read off the live pickup entities rather than
	the authored list, so a point somebody has already emptied stops attracting
	anybody.
]]
function CS16.BRBotGoal( bot )
	if IsValid( CS16.GetOwnedOfKind( bot, "primary" ) )
		or IsValid( CS16.GetOwnedOfKind( bot, "secondary" ) )
	then
		return CS16.BotRoamGoal( bot )
	end

	local pos = bot:GetPos()

	-- Nearest first, so the reachability checks below are spent on the ones
	-- actually worth walking to.
	local items = {}

	for _, item in ipairs( ents.FindByClass( "cs16_item_weapon" ) ) do
		if IsValid( item ) then items[ #items + 1 ] = item end
	end

	table.sort( items, function( a, b )
		return pos:DistToSqr( a:GetPos() ) < pos:DistToSqr( b:GetPos() )
	end )

	--[[
		Nearest is not the same as reachable, and the difference is a bot walking
		into a crate for the rest of the match.

		A loot point on top of something needs a crouch-jump to reach, which bots
		do not do reliably - so the nearest gun can be one they will never pick
		up, and without this they keep choosing it over a gun they could actually
		fetch. Asking the pathfinder is the only honest test of whether somewhere
		can be walked to; the hostages learned the same lesson on Italy's
		balconies.

		Only the closest few are checked, because a route is not free and a bot
		that has to consider all twenty-eight is paying for twenty-four answers
		it will not use.
	]]
	local CHECKED = 5

	--[[
		And a give-up clock on top of the route check, because the two catch
		different failures.

		The pathfinder answers whether the navmesh connects, which is not the
		same as whether a bot can get there: a gun on top of a crate is meshed
		and routable and still needs a crouch-jump nobody reliably makes. Left to
		itself a bot will choose that crate over and over, because it is the
		nearest and the route says yes.

		So a target it has been chasing too long is written off - for that bot
		only, since another one approaching from a different side may well manage
		it - and the next candidate gets a turn.
	]]
	bot.CS16BRAvoid = bot.CS16BRAvoid or {}

	if bot.CS16BRTarget then
		if not IsValid( bot.CS16BRTarget ) then
			bot.CS16BRTarget = nil
		elseif CurTime() - ( bot.CS16BRSince or 0 ) > cfg.LootGiveUp then
			bot.CS16BRAvoid[ bot.CS16BRTarget ] = true
			bot.CS16BRTarget = nil
		end
	end

	for i = 1, math.min( CHECKED, #items ) do
		local item = items[ i ]

		if not bot.CS16BRAvoid[ item ] and CS16.FindPath( pos, item:GetPos() ) then
			if bot.CS16BRTarget ~= item then
				bot.CS16BRTarget = item
				bot.CS16BRSince  = CurTime()
			end

			return item:GetPos()
		end
	end

	--[[
		Nothing nearby can be routed to. Rather than grinding at whichever is
		closest, go and find people - the guns that are left are ones this bot
		cannot collect from here anyway, and moving somewhere else may well
		change that.
	]]
	return CS16.BotRoamGoal( bot )
end

--[[ The match ]]

local function Ready()
	return #CS16.BRSpawns > 0 and #Contenders() >= cfg.MinPlayers
end

local function StartWarmup()
	SetState( ROUND_WARMUP, nil )

	SetGlobalInt( "CS16.Winner", 0 )
	CS16.SetRoundEndReason( #CS16.BRSpawns == 0
		and "round.br.nospawns" or "round.waiting" )

	--[[
		Cleared here rather than only at map load, now that warmup is somewhere
		the mode comes back to between rounds rather than a place it starts from
		once. Left set, the previous round's winner would still be on the board
		through the whole of the next one.
	]]
	SetGlobalBool( "CS16.MatchOver", false )
	SetGlobalInt( "CS16.MatchWinner", 0 )
	SetGlobalString( "CS16.MatchWinnerName", "" )

	ClearLoot()

	Playing( function( ply )
		ply:Freeze( false )
		if not ply:Alive() then ply:Spawn() end
	end )
end

--[[
	A fresh face for every bot, every match.

	Players wear whatever they picked; bots have nobody to pick for them, and
	ten of the same model is a poor look for a mode whose whole premise is ten
	strangers who have never met.

	Dealt without replacement while the pool lasts, so a full match is ten
	different people rather than the same two or three rolled over and over -
	which is what random-per-bot gives you far more often than it sounds like
	it should.
]]
local function DealModels()
	local pool = {}

	for _, entry in ipairs( CS16.Config.PickableModels ) do
		pool[ #pool + 1 ] = entry.model
	end

	Playing( function( ply )
		if not ply.CS16Bot then return end
		if #pool == 0 then return end

		ply.CS16PickedModel = table.remove( pool, math.random( #pool ) )
	end )
end

local function StartMatch()
	SetGlobalInt( "CS16.Round", CS16.GetRoundNumber() + 1 )
	SetGlobalInt( "CS16.Winner", 0 )
	CS16.SetRoundEndReason( nil )

	DealSpawns()

	-- Before the spawn loop, not after: PlayerSetModel reads CS16PickedModel as
	-- the body is built, so a model dealt afterwards would not be worn until
	-- the match after this one.
	DealModels()

	--[[
		Everyone is spawned *before* the state goes live, and the order is not
		cosmetic.

		CanTakeBody refuses a body once the match is running - that is what stops
		a dead player rejoining by switching sides. Flipping the state first
		therefore means the spawn loop hands out no loadouts at all, and ten
		people start the match empty-handed with not even a knife. Which is
		exactly what happened.
	]]
	Playing( function( ply )
		ply:Spawn()
		ply:Freeze( false )
	end )

	SetState( ROUND_LIVE, nil )

	SpawnLoot()

	CS16.BroadcastSound( CS16.Config.Sounds.RoundStart )

	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( ("[CS 1.6] Battle royale: %d in, one out. Find a weapon."):format(
			#Contenders() ) )
	end
end

local function EndMatch( winner )
	SetState( ROUND_END, cfg.EndTime )

	SetGlobalBool( "CS16.MatchOver", true )
	SetGlobalInt( "CS16.MatchWinner", IsValid( winner ) and winner:Team() or 0 )
	SetGlobalString( "CS16.MatchWinnerName", IsValid( winner ) and winner:Nick() or "" )

	if IsValid( winner ) then
		CS16.SetRoundEndReason( "round.end.br.winner", winner:Nick() )

		-- The record, which is the whole point of turning up.
		if CS16.AddWin then CS16.AddWin( winner ) end

		CS16.BroadcastSound( CS16.Config.Sounds.RoundStart )
	else
		CS16.SetRoundEndReason( "round.end.br.nobody" )
		CS16.BroadcastSound( CS16.Config.Sounds.Draw )
	end

	for _, ply in ipairs( player.GetAll() ) do
		ply:Freeze( false )
		CS16.Msg( ply, CS16.EndReasonKey(), { player = GetGlobalString( "CS16.EndReasonArg", "" ) } )
	end

	--[[
		Another round, or the map, depending on how many have been played.

		Every round used to end in a changelevel. That reset the loot, the
		spawns dealt out and every scrap of per-match state in one go, which is
		correct and enormously heavy for something happening every few minutes -
		a full map load between every match. Rounds restart in place the way
		competitive's do, and the reload comes round once per set instead.

		StartWarmup does the resetting that the reload used to do for free:
		loot is cleared there and dealt fresh by StartMatch, and everybody is
		respawned on the way through.
	]]
	local played = CS16.GetRoundNumber()

	-- The banner says "changing map" or "next round" off this, because it is
	-- the only thing that knows which is about to happen.
	SetGlobalBool( "CS16.MapChanging", played >= cfg.Rounds )

	if played >= cfg.Rounds then
		for _, ply in ipairs( player.GetAll() ) do
			ply:ChatPrint( ("[CS 1.6] That's %d rounds. Reloading the map."):format( played ) )
		end

		timer.Simple( cfg.EndTime, function()
			game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
		end )

		return
	end

	timer.Simple( cfg.EndTime, function()
		-- Only if nothing else has moved the round on in the meantime - a mode
		-- change or a map change both leave this timer still pending.
		if CS16.GetRoundState() ~= ROUND_END then return end

		StartWarmup()
	end )
end

--[[ Driver ]]

hook.Add( "Think", "CS16.BRThink", function()
	local state = CS16.GetRoundState()

	if state == ROUND_END then return end

	--[[
		Enough people starts a countdown, not the match.

		Starting the instant the numbers are met punishes whoever was slowest to
		load: they arrive to find everybody already armed and hunting, in a mode
		with no respawns. Thirty seconds is roughly a map load on a slow
		machine.

		The countdown is the phase clock, so it draws on the HUD like any other
		timer and the pause feature stops it along with everything else.
	]]
	if state == ROUND_WARMUP then
		local counting = CS16.GetPhaseEnd() > 0

		if not Ready() then
			-- Lost the numbers again. Stand it down rather than starting a
			-- match that is about to be one person.
			if counting then
				SetState( ROUND_WARMUP, nil )
				CS16.SetRoundEndReason( "round.waiting" )
			end

			return
		end

		if not counting then
			SetState( ROUND_WARMUP, cfg.StartCountdown )
			CS16.SetRoundEndReason( "round.matchstarting" )

			--[[
				Held still for the wait, the way freeze time works in
				competitive. A countdown you can walk around during is not a
				countdown, it is a head start for whoever reads it first - and
				in a mode where the first weapon found decides the fight, that
				is the whole match.
			]]
			Playing( function( ply )
				if not ply:Alive() then ply:Spawn() end
				ply:Freeze( true )
			end )

			for _, ply in ipairs( player.GetAll() ) do
				ply:ChatPrint( ("[CS 1.6] Round %d of %d starting in %d seconds."):format(
					CS16.GetRoundNumber() + 1, cfg.Rounds, cfg.StartCountdown ) )
			end

			return
		end

		if CurTime() >= CS16.GetPhaseEnd() then StartMatch() end

		return
	end

	if state ~= ROUND_LIVE then return end

	local alive = Contenders()

	--[[
		One left, or none.

		Checked every tick rather than from PlayerDeath, because the last player
		can also be lost to a disconnect or a team change - neither of which is
		a death, and both of which end the match just the same.
	]]
	if #alive <= 1 then
		EndMatch( alive[ 1 ] )
	end
end )

hook.Add( "InitPostEntity", "CS16.BRStart", function()
	SetGlobalBool( "CS16.MatchOver", false )
	SetGlobalInt( "CS16.MatchWinner", 0 )
	SetGlobalString( "CS16.MatchWinnerName", "" )

	--[[
		Warmup begins after the zones have loaded, since whether the mode can
		start at all depends on there being spawns. Both run on InitPostEntity,
		and this one has to be second.
	]]
	timer.Simple( 0.5, StartWarmup )
end )
