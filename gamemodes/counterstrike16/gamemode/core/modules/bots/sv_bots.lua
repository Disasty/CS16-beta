--[[
	Bots.

	player.CreateNextBot makes real Player entities, which is the whole trick:
	they hold our actual SWEPs, take our damage, count in RoundCounts, buy from
	the same catalogue and show up on the scoreboard. Everything already built
	applies to them, so this file is only about deciding what buttons to press.

	Two clocks: expensive decisions (target selection, pathfinding, buying) run
	on a throttle, while StartCommand does nothing but execute the current
	decision every tick.
]]

local cfg = CS16.Config.Bots

local THINK_INTERVAL = 0.2

CS16.Bots = CS16.Bots or {}

--[[ Creation ]]

--[[
	The roster first, and only then the reserve.

	The ten are drawn in order rather than at random, so the same bots turn up
	in the same order every map - they carry progression now, and a leaderboard
	full of names you recognise is the entire appeal. Randomising it would mean
	whoever happened to be picked first got the play time.

	The reserve only comes into it when a human has taken one of the ten.
]]
local function PickName()
	local taken = {}
	for _, ply in ipairs( player.GetAll() ) do taken[ ply:Nick() ] = true end

	for _, list in ipairs( { cfg.Names, cfg.ReserveNames } ) do
		for _, name in ipairs( list ) do
			if not taken[ name ] then return name end
		end
	end

	return "Bot " .. math.random( 1000, 9999 )
end

function CS16.AddBot( teamID )
	if player.GetCount() >= game.MaxPlayers() then return nil, "Server is full." end
	if not CS16.NavReady() then
		-- Not fatal - they'll still fight, they just won't go anywhere.
		MsgN( "[CS 1.6] No navmesh loaded; bots will hold position. Run nav_generate." )
	end

	--[[
		Pick the side before creating anything, so a full server doesn't leave
		a spare bot standing in spectator. Asked for a specific side we respect
		it; left to choose, the smaller side unless it's full.
	]]
	local target = teamID

	if not target then
		target = CS16.SmallestTeam()

		-- Falling back to the other side only means something when there are
		-- two. Under a solo-team mode the one SmallestTeam returned is the only
		-- team playing, and flipping would seat the bot outside the match.
		if not CS16.SoloTeam() and CS16.TeamIsFull( target ) then
			target = ( target == TEAM_T ) and TEAM_CT or TEAM_T
		end
	end

	if CS16.TeamIsFull( target ) then return nil, "That team is full." end

	local bot = player.CreateNextBot( PickName() )
	if not IsValid( bot ) then return nil, "Couldn't create the bot." end

	bot.CS16Bot = true

	-- SetTeam, not JoinTeam: bots are placed, not choosing, so the locking and
	-- make-room rules don't apply to them.
	CS16.SetTeam( bot, target )

	return bot
end

--[[
	Kick doesn't drop the player until the end of the frame, so a bot stays in
	player.GetAll() after being removed. Both this and BotCount ignore anything
	already on its way out, or the fill/trim loops below would spin forever.
]]
function CS16.RemoveBot( name )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16Bot and not ply.CS16Removing
			and ( not name or string.find( string.lower( ply:Nick() ), string.lower( name ), 1, true ) )
		then
			ply.CS16Removing = true
			ply:Kick( "Removed" )
			return ply
		end
	end
end

--[[
	The same, but from one side.

	RemoveBot takes the first bot it finds anywhere, which is right when you
	just want one fewer bot and wrong whenever it matters which side loses one.
	Trimming a side that's over its share with RemoveBot took a Terrorist off
	the board because a Counter-Terrorist slot had filled up.
]]
function CS16.RemoveBotOn( teamID )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16Bot and not ply.CS16Removing and ply:Team() == teamID then
			ply.CS16Removing = true
			ply:Kick( "Removed" )
			return ply
		end
	end
end

function CS16.BotCount()
	local n = 0

	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16Bot and not ply.CS16Removing then n = n + 1 end
	end

	return n
end

--[[ Buying ]]

--[[
	One primary drawn at random per round, so a side isn't six identical
	rifles. The rifle is listed twice to weight it as the usual pick, and the
	cheaper entries double as what they end up with on a poor economy.
]]
local PRIMARIES = {
	[ TEAM_T ]  = { "ak47", "ak47", "mac10", "galil" },
	[ TEAM_CT ] = { "m4a1", "m4a1", "mp5navy", "famas" },
}

--[[
	Bought after the primary, in priority order.

	The HE is the only grenade on these lists, deliberately. A bot can be taught
	to throw one at somebody; knowing when a smoke helps, or how to flash a
	doorway for a team-mate rather than for itself, is a different problem
	entirely - and a bot blinding its own side is worse than one that never
	throws. If they pick a flashbang up off the floor they still won't use it:
	the throwing code only ever reaches for the HE.
]]
local GEAR = {
	[ TEAM_T ]  = { "kevlarhelm", "hegrenade", "deagle" },
	[ TEAM_CT ] = { "kevlarhelm", "defusekit", "hegrenade", "deagle" },
}

local function TryItem( bot, id )
	local item = CS16.GetBuyItem( id )

	-- TryBuy refuses anything unaffordable anyway; checking first just keeps
	-- the chat quiet.
	if item and CS16.CanAfford( bot, item.price ) then
		CS16.TryBuy( bot, id )
	end
end

--[[
	Top both slots back up to what they can carry.

	Survivors keep their weapons between rounds but were never refilling, so a
	bot that lived a few rounds eventually ran dry and stood there clicking at
	people. Buying is a magazine at a time, so this repeats until the count
	stops moving - which covers being full and being broke without needing to
	tell the two apart.
]]
local function BotBuyAmmo( bot )
	for _, kind in ipairs( { "primary", "secondary" } ) do
		local wep = CS16.GetOwnedOfKind( bot, kind )
		if not IsValid( wep ) then continue end

		local item = CS16.BuyItemsByClass[ wep:GetClass() ]
		if not item or not item.ammo then continue end

		-- Bounded: a purchase that quietly does nothing can't spin here.
		for _ = 1, 12 do
			local before = bot:GetAmmoCount( item.ammo )

			CS16.BuyAmmo( bot, kind )

			if bot:GetAmmoCount( item.ammo ) <= before then break end
		end
	end
end

local function BotBuy( bot )
	if not CS16.CanBuy( bot ) then return end

	-- A survivor already carrying a rifle shouldn't throw it away to buy
	-- another one.
	if not IsValid( CS16.GetOwnedOfKind( bot, "primary" ) ) then
		local pool = PRIMARIES[ bot:Team() ]
		if pool then TryItem( bot, pool[ math.random( #pool ) ] ) end
	end

	for _, id in ipairs( GEAR[ bot:Team() ] or {} ) do
		TryItem( bot, id )
	end

	-- Last, so a fresh weapon is paid for before ammo eats the remainder.
	BotBuyAmmo( bot )

	bot.CS16Bought = true

	-- Put the best thing they own in their hands.
	local primary = CS16.GetOwnedOfKind( bot, "primary" )
	if IsValid( primary ) then bot:SelectWeapon( primary:GetClass() ) end
end

--[[ Perception ]]

local function CanSee( bot, target )
	local eyes = bot:EyePos()
	local dir  = target:EyePos() - eyes
	local dist = dir:Length()

	if dist > cfg.ViewDistance then return false end

	dir:Normalize()

	-- No eyes in the back of their head.
	if bot:EyeAngles():Forward():Dot( dir ) < math.cos( math.rad( cfg.FOV * 0.5 ) ) then
		return false
	end

	local tr = util.TraceLine( {
		start  = eyes,
		endpos = target:EyePos(),
		filter = { bot, target },
		mask   = MASK_SHOT,
	} )

	return not tr.Hit
end

--[[
	Is this somebody the bot should be shooting at?

	Normally that means the other side. In a free-for-all it means anybody who
	isn't the bot - and the difference is not cosmetic: without it, the last two
	survivors of a battle royale on the same nominal side simply stand looking at
	each other, because neither will fire and the match cannot end.
]]
local function IsTarget( bot, other )
	if not CS16.IsPlayingTeam( other:Team() ) then return false end
	if CS16.ModeSetting( "FreeForAll", false ) then return true end

	return other:Team() ~= bot:Team()
end

--[[
	And the mirror of it: somebody whose line of fire is worth protecting.

	Nobody's, in a free-for-all - there are no team-mates to hit, so holding fire
	for one would just be a bot refusing to shoot.
]]
local function IsAlly( bot, other )
	if CS16.ModeSetting( "FreeForAll", false ) then return false end
	return other:Team() == bot:Team()
end

local function FindEnemy( bot )
	-- A flashbang takes their eyes for a moment, exactly as it takes yours.
	-- See core/modules/weapons/sv_flashbang.lua: the pack's own effect is client-side only,
	-- so this is the entire consequence of being flashed for a bot.
	if CS16.IsBlinded( bot ) then return nil end

	local best, bestDist

	for _, other in ipairs( player.GetAll() ) do
		if other ~= bot
			and other:Alive()
			and IsTarget( bot, other )
			and CanSee( bot, other )
		then
			local d = bot:GetPos():DistToSqr( other:GetPos() )
			if not bestDist or d < bestDist then best, bestDist = other, d end
		end
	end

	return best
end

--[[ Goals ]]

--[[
	The spot a bot should stand to plant.

	This drops straight down from the middle of the site volume rather than
	asking the navmesh for the nearest area. The AABB centre is inside the
	trigger by definition, so the floor beneath it is too - whereas the nearest
	nav area can easily be just outside it, which left carriers standing beside
	the site with AtBombSite never going true, so they never planted.
]]
local function SiteGround( site )
	if site.groundPoint then return site.groundPoint end

	local centre = ( site.mins + site.maxs ) * 0.5

	--[[
		The lowest navigable area inside the site volume - in other words, its
		floor.

		Tracing straight down from the centre finds whatever happens to be
		directly beneath it, which at B is the top of a crate. Since this point
		is the shared destination for both teams, that had every bot on the
		server converging on one box and trying to climb it.
	]]
	local best

	for _, area in ipairs( CS16.AllNavAreas() ) do
		if IsValid( area ) then
			local c = area:GetCenter()

			if c.x >= site.mins.x and c.x <= site.maxs.x
				and c.y >= site.mins.y and c.y <= site.maxs.y
				and c.z >= site.mins.z - 32 and c.z <= site.maxs.z
				and ( not best or c.z < best.z )
			then
				best = c
			end
		end
	end

	if best then
		site.groundPoint = best
		return best
	end

	-- Mesh doesn't cover the site; fall back to dropping from the centre.
	local tr = util.TraceLine( {
		start  = centre,
		endpos = centre - Vector( 0, 0, 4096 ),
		mask   = MASK_SOLID_BRUSHONLY,
	} )

	site.groundPoint = tr.Hit and ( tr.HitPos + Vector( 0, 0, 8 ) )
		or CS16.GroundPoint( centre )

	return site.groundPoint
end

local ARRIVE_DIST_SQR = 500 * 500
local PATROL_DIST_SQR = 80 * 80
local PATROL_RADIUS   = 1500

-- Comfortably inside the addon's own 32-unit completion check.
local DEFUSE_RANGE = 26

--[[
	A random nav area can easily be a rooftop, a ledge or a sealed-off pocket -
	diagnostics caught a bot picking one 240 units up that nothing could reach,
	then standing there craning at it. So candidates have to be roughly on our
	level and provably reachable before we commit to one.

	`accept` lets a caller add its own test, which is how fleeing asks for
	somewhere clear of the bomb.
]]
local function PickReachablePoint( bot, around, radius, accept )
	local pos = bot:GetPos()

	for _ = 1, 6 do
		local candidate = CS16.RandomNavPointNear( around, radius )

		if candidate
			and math.abs( candidate.z - pos.z ) < 250
			and ( not accept or accept( candidate ) )
			and CS16.FindPath( pos, candidate )
		then
			return candidate
		end
	end

	return nil
end

local function PickPatrolPoint( bot )
	return PickReachablePoint( bot, bot:GetPos(), PATROL_RADIUS )
end

--[[
	Goal selection.

	The important part is that a bot always has somewhere new to be. The first
	version handed back the same bomb site forever, so on arrival it would
	repath to a point a few feet away and shuffle around it indefinitely -
	which is exactly what it looked like in game.
]]
--[[
	What to do about a bomb that's already down.

	CTs go straight at it. Terrorists hold the ground around it rather than
	piling onto it, and then clear out before it detonates - the C4 kills well
	past the site, so standing on your own bomb is a good way to win the round
	and die anyway.
]]
local function BombGoal( bot, bombPos )
	if bot:Team() == TEAM_CT then
		bot.CS16Flee = nil

		--[[
			Somebody is already on it: hold the area rather than piling onto
			the bomb.

			This isn't just tidiness. The addon's defuse fails outright if the
			defuser ends up more than 32 units from the bomb, and a squad of
			bots crowding the same spot shoves them off it - a defuse would run
			the full ten seconds and then simply not happen.
		]]
		local defuser = CS16.GetDefuser()

		if IsValid( defuser ) and defuser ~= bot then
			if not bot.CS16Patrol
				or bot:GetPos():DistToSqr( bot.CS16Patrol ) < PATROL_DIST_SQR
				or bot.CS16Patrol:DistToSqr( bombPos ) > cfg.BombHoldRadius * cfg.BombHoldRadius
			then
				bot.CS16Patrol = PickReachablePoint( bot, bombPos, cfg.BombHoldRadius, function( point )
					-- Not right on top of them.
					return point:DistToSqr( bombPos ) > 160 * 160
				end )
			end

			if bot.CS16Patrol then return bot.CS16Patrol end
		end

		-- The raw bomb position, not the nearest nav area. FindPath already
		-- finishes on the exact target, and snapping to the navmesh first left
		-- CTs standing a good 60-odd units short - outside the range the defuse
		-- actually needs.
		return bombPos
	end

	local blastSqr = cfg.BlastRadius * cfg.BlastRadius

	if CS16.GetBombRemaining() < cfg.FleeAt then
		-- Keep the escape point until we're actually clear of the blast.
		if not bot.CS16Flee or bot.CS16Flee:DistToSqr( bombPos ) < blastSqr then
			bot.CS16Flee = PickReachablePoint( bot, bot:GetPos(), 2000, function( point )
				return point:DistToSqr( bombPos ) > blastSqr
			end )
		end

		if bot.CS16Flee then return bot.CS16Flee end
	else
		bot.CS16Flee = nil
	end

	local holdSqr = cfg.BombHoldRadius * cfg.BombHoldRadius

	-- Repick if we've arrived, or if the last point turned out to be off the
	-- site entirely.
	if not bot.CS16Patrol
		or bot:GetPos():DistToSqr( bot.CS16Patrol ) < PATROL_DIST_SQR
		or bot.CS16Patrol:DistToSqr( bombPos ) > holdSqr
	then
		bot.CS16Patrol = PickReachablePoint( bot, bombPos, cfg.BombHoldRadius )
	end

	return bot.CS16Patrol or CS16.GroundPoint( bombPos )
end

-- The C4 lying on the floor after its carrier was killed. Owner is NULL on a
-- dropped weapon, which is how we tell it from one somebody is holding.
local function DroppedBomb()
	for _, wep in ipairs( ents.FindByClass( "weapon_cs16_c4" ) ) do
		if IsValid( wep ) and not IsValid( wep:GetOwner() ) then return wep end
	end
end

-- Whoever is carrying the bomb right now, bot or human.
local function BombCarrier()
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() and ply:Team() == TEAM_T and ply:HasWeapon( "weapon_cs16_c4" ) then
			return ply
		end
	end
end

--[[
	Is this bot free to go and look somewhere else?

	Only if nothing is holding it where it is. A Terrorist with the bomb, or one
	escorting whoever has it, has a reason to be on that site and shouldn't
	wander off it - the round is decided there. Everyone else is just guessing
	about where the enemy might be, and a guess that's produced nothing for half
	a minute is a bad one.

	That makes Counter-Terrorists rotate in competitive, which they should have
	been doing anyway, and everybody rotate in a mode with no bomb at all.
]]
local function Rotates( bot )
	if #CS16.BombSites < 2 then return false end
	if bot:Team() ~= TEAM_T then return true end

	if bot:HasWeapon( "weapon_cs16_c4" ) then return false end

	-- A team-mate is carrying it, so this side has somewhere to be.
	return not IsValid( BombCarrier() )
end

local function RotateSite( bot )
	local options = {}

	for _, site in ipairs( CS16.BombSites ) do
		if site ~= bot.CS16Site then options[ #options + 1 ] = site end
	end

	if #options == 0 then return end

	bot.CS16Site      = options[ math.random( #options ) ]
	bot.CS16Patrol    = nil
	bot.CS16HeldSince = nil
	bot.CS16HoldFor   = nil
end

--[[
	Hostage rescue: fetch them, or stop them being fetched.

	The mirror of the bomb plan, and just as map-specific. Counter-Terrorists
	have somewhere definite to be twice over - out to a hostage, then all the
	way back - while the Terrorists have the easier job of standing between the
	two. That asymmetry is the mode.
]]
--[[
	How close a bot has to get before it takes the hostage.

	Deliberately generous, and measured rather than picked: bots plateau between
	140 and 210 units of a goal they've walked to, because that's where the path
	follower calls it arrived. At the 100 an arm's length would suggest, they
	stood next to the hostages indefinitely and no round was ever won by rescue.

	This only governs bots. A player still walks up and presses use.
]]
local GRAB_RANGE_SQR = 250 * 250
local GUARD_DIST_SQR = 600 * 600

local function NearestRescue( pos )
	local best, bestDist

	for _, zone in ipairs( CS16.RescueZones ) do
		local dist = pos:DistToSqr( zone.pos )
		if not bestDist or dist < bestDist then best, bestDist = zone, dist end
	end

	return best
end

-- The closest hostage nobody has picked up yet. Ignoring the ones already
-- being led stops the whole squad converging on the same one.
local function LooseHostage( bot )
	local best, bestDist

	for _, ent in ipairs( ents.FindByClass( "cs16_hostage" ) ) do
		if not ent:GetRescued() and not IsValid( ent:GetFollower() ) then
			local dist = bot:GetPos():DistToSqr( ent:GetPos() )
			if not bestDist or dist < bestDist then best, bestDist = ent, dist end
		end
	end

	return best
end

local function EscortedBy( bot )
	for _, ent in ipairs( ents.FindByClass( "cs16_hostage" ) ) do
		if ent:GetFollower() == bot then return ent end
	end
end

local function HostageGoal( bot )
	if bot:Team() == TEAM_CT then
		-- Already leading one: the only thing that matters now is getting it home.
		if IsValid( EscortedBy( bot ) ) then
			local zone = NearestRescue( bot:GetPos() )
			if zone then return zone.pos end
		end

		local target = LooseHostage( bot )

		if IsValid( target ) then
			--[[
				Standing next to it is the moment to take it. Routed through Use
				rather than setting the follower directly, so a bot is held to
				exactly the same rules a player is - and so there is only one
				place that decides who may lead a hostage.
			]]
			if bot:GetPos():DistToSqr( target:GetPos() ) < GRAB_RANGE_SQR then
				target:Use( bot )
			end

			return target:GetPos()
		end

		-- Nothing left to collect: cover the way home, where the round ends.
		local zone = NearestRescue( bot:GetPos() )
		if zone then return zone.pos end

		return nil
	end

	--[[
		Terrorists guard where the hostages are.

		One hostage apiece rather than the whole group, so the side spreads
		across the rooms instead of stacking on whichever is nearest. Sticky
		until it's rescued, for the same reason bots commit to a bomb site.
	]]
	if not IsValid( bot.CS16Guard ) or bot.CS16Guard:GetRescued() then
		local live = {}

		for _, ent in ipairs( ents.FindByClass( "cs16_hostage" ) ) do
			if not ent:GetRescued() then live[ #live + 1 ] = ent end
		end

		bot.CS16Guard  = live[ math.random( #live ) ]
		bot.CS16Patrol = nil
	end

	-- All of them gone: nothing left to guard, so go and find the enemy.
	if not IsValid( bot.CS16Guard ) then return CS16.BotRoamGoal( bot ) end

	local post = bot.CS16Guard:GetPos()

	if bot:GetPos():DistToSqr( post ) > GUARD_DIST_SQR then
		bot.CS16Patrol = nil
		return post
	end

	-- Arrived: work the ground around it rather than standing on the spot.
	if not bot.CS16Patrol or bot:GetPos():DistToSqr( bot.CS16Patrol ) < PATROL_DIST_SQR then
		bot.CS16Patrol = CS16.RandomNavPointNear( post, 400 ) or post
	end

	return bot.CS16Patrol
end

--[[
	Bomb defusal: hold a site, escort the bomb, defend or defuse it.

	This is the whole of competitive's plan and none of it generalises - a mode
	with no bomb has nothing to escort and no reason to prefer one end of the
	map. Modes pick which of these they want; see CS16.BotRoamGoal for the
	other.
]]
function CS16.BotObjectiveGoal( bot )
	if CS16.IsBombPlanted() and IsValid( CS16.Bomb ) then
		return BombGoal( bot, CS16.Bomb:GetPos() )
	end

	bot.CS16Flee = nil

	--[[
		The map decides which objective is being played, so it decides which plan
		the bots follow. Nothing below this line means anything on a map with no
		bomb: no sites to pick, nothing to escort, no reason to prefer one end.
	]]
	if CS16.IsHostageMap() then return HostageGoal( bot ) end

	--[[
		A dropped bomb outranks everything a Terrorist could otherwise be doing
		- until somebody picks it up the round cannot be won. Walking over it
		is enough; PlayerCanPickupWeapon already lets Terrorists take it.
	]]
	if bot:Team() == TEAM_T and not bot:HasWeapon( "weapon_cs16_c4" ) then
		local dropped = DroppedBomb()

		if dropped then
			bot.CS16Patrol = nil
			return dropped:GetPos()
		end

		--[[
			Follow the bomb, not your own plan.

			Each bot picks a site at the start of the round, which left the ones
			who picked the site the bomb never went to patrolling an empty
			corner for the rest of it - there is nothing to win there. Adopting
			the carrier's site keeps the side together on the only ground the
			round can actually be decided on.

			Only while somebody is carrying it: a loose bomb is handled above,
			and once it's planted BombGoal has already taken over.
		]]
		local carrier = BombCarrier()

		if IsValid( carrier ) and carrier ~= bot and carrier.CS16Site
			and carrier.CS16Site ~= bot.CS16Site
		then
			bot.CS16Site   = carrier.CS16Site
			bot.CS16Patrol = nil
		end
	end

	-- Each bot commits to a site rather than dithering between them.
	if not bot.CS16Site and #CS16.BombSites > 0 then
		bot.CS16Site = CS16.BombSites[ math.random( #CS16.BombSites ) ]
		bot.CS16HeldSince = nil
	end

	if bot.CS16Site then
		local site = SiteGround( bot.CS16Site )

		--[[
			Still crossing the map to it.

			The hold clock is deliberately not reset here. Patrolling ranges
			further than the arrival radius, so a bot standing its ground drifts
			in and out of this branch constantly - and clearing the clock on the
			way past meant it never reached twenty seconds and nobody ever
			rotated. The clock measures time committed to this site, and only a
			new site restarts it.
		]]
		if bot:GetPos():DistToSqr( site ) > ARRIVE_DIST_SQR then
			bot.CS16Patrol = nil
			return site
		end

		-- Carrying the bomb: hold the site and plant, don't wander off it.
		if bot:HasWeapon( "weapon_cs16_c4" ) then
			bot.CS16Patrol = nil
			return site
		end

		--[[
			Arrived, and holding. If nothing happens here for long enough, go
			and look somewhere else.

			Without this both squads settle at opposite ends of the map and stay
			there: everyone picks a site at the start, walks to it, and patrols
			within a few hundred units of it for the rest of the round. In
			competitive the bomb eventually forces the issue. In gungame nothing
			does, so five Counter-Terrorists sat at B and five Terrorists sat at
			A until the clock ran out.
		]]
		if Rotates( bot ) then
			bot.CS16HeldSince = bot.CS16HeldSince or CurTime()
			bot.CS16HoldFor   = bot.CS16HoldFor
				or math.Rand( cfg.RotateAfterMin, cfg.RotateAfterMax )

			if CurTime() - bot.CS16HeldSince > bot.CS16HoldFor then
				RotateSite( bot )
			end
		end
	end

	-- Arrived, or no sites to go to: keep moving around the area instead of
	-- standing on one tile. A new point is drawn each time one is reached.
	if not bot.CS16Patrol or bot:GetPos():DistToSqr( bot.CS16Patrol ) < PATROL_DIST_SQR then
		bot.CS16Patrol = PickPatrolPoint( bot )
	end

	-- Nowhere sensible to wander to: hold the site rather than freezing.
	if not bot.CS16Patrol and bot.CS16Site then
		return SiteGround( bot.CS16Site )
	end

	return bot.CS16Patrol
end

--[[
	No objective: go and find somebody.

	A mode with nothing to fight over needs bots that cross the map rather than
	settle on it. Holding a bomb site is the right instinct when the bomb
	decides the round and completely wrong when nothing does - two squads at
	opposite ends, waiting for a fight neither of them is walking to.

	This used to be pure wandering - somewhere else, far away, repeatedly, with
	nothing modelling where the enemy might be. It worked, in that fights
	happened, but measurement showed bots were only in contact about a quarter of
	the time and spent the rest walking past each other through empty corridors.
	A gun game ran seventeen minutes, and most of that was travel.

	So most trips are now toward somebody rather than merely somewhere. Not at
	them - at the ground near them, which is the difference between hunting and
	homing: they arrive in the right part of the map and find the fight there,
	rather than tracking a player through walls.

	The rest of the time they still wander, because a side that only ever walks
	at its enemies converges into one rolling scrum in the middle of the map and
	the rest of it goes unused.
]]
local ROAM_MIN_SQR    = 1200 * 1200
local ROAM_ARRIVE_SQR = 200 * 200

-- Enemies move, so a destination chosen for where somebody was is stale within
-- seconds. Re-picked on this clock as well as on arrival.
local ROAM_REFRESH = 6

--[[
	Who is worth walking toward.

	Asks IsTarget rather than comparing teams directly, and that is the whole
	point: in a free-for-all everybody shares a team, so a team comparison finds
	nobody, HuntPoint returns nil every time, and cfg.HuntChance quietly does
	nothing. Bots then fall back to random points across the entire map, which
	is why the last two survivors of a battle royale could wander for minutes
	without meeting.

	IsTarget already knows about free-for-all, and already checks IsPlayingTeam.
]]
local function HuntPoint( bot )
	local enemies = {}

	for _, ply in ipairs( player.GetAll() ) do
		if ply ~= bot and ply:Alive() and IsTarget( bot, ply ) then
			enemies[ #enemies + 1 ] = ply
		end
	end

	if #enemies == 0 then return end

	local mark = enemies[ math.random( #enemies ) ]
	local near = CS16.RandomNavPointNear( mark:GetPos(), cfg.HuntSpread )

	-- Only if we can actually get there; otherwise the caller falls back to
	-- wandering rather than standing still holding an impossible goal.
	if near and CS16.FindPath( bot:GetPos(), near ) then return near end
end

local function PickRoamPoint( bot )
	local pos = bot:GetPos()

	if math.random() < cfg.HuntChance then
		local hunt = HuntPoint( bot )
		if hunt then return hunt end
	end

	for _ = 1, 8 do
		-- Anywhere at all: the radius is the map.
		local candidate = CS16.RandomNavPointNear( pos, 100000 )

		--[[
			A route is the real test of whether somewhere can be reached, so
			unlike PickReachablePoint there's no height clamp here. On a map
			with tunnels running under it, a height limit rules out half the
			places worth walking to.
		]]
		if candidate
			and candidate:DistToSqr( pos ) > ROAM_MIN_SQR
			and CS16.FindPath( pos, candidate )
		then
			return candidate
		end
	end
end

function CS16.BotRoamGoal( bot )
	local stale = CurTime() > ( bot.CS16RoamAt or 0 )

	if not bot.CS16Roam or stale or bot:GetPos():DistToSqr( bot.CS16Roam ) < ROAM_ARRIVE_SQR then
		bot.CS16Roam   = PickRoamPoint( bot )
		bot.CS16RoamAt = CurTime() + ROAM_REFRESH
	end

	return bot.CS16Roam
end

--[[
	Which of those a mode wants.

	Roaming is the default because it needs nothing of the map - a mode that
	says nothing gets bots that go looking for each other, which is wrong for
	nobody. Competitive asks for the objective plan explicitly.
]]
local function ChooseGoal( bot )
	local goal = CS16.ModeSetting( "BotGoal" )
	return ( goal or CS16.BotRoamGoal )( bot )
end

--[[ Decisions ]]

local function BotDecide( bot )
	bot.CS16NextThink = CurTime() + THINK_INTERVAL

	local state = CS16.GetRoundState()

	if state == ROUND_FREEZE and not bot.CS16Bought then
		BotBuy( bot )
	end

	-- Aim wobble is refreshed on the slow clock, so it drifts like a hand
	-- rather than vibrating every frame.
	local spread = cfg.AimError
	bot.CS16AimError = Angle( math.Rand( -spread, spread ), math.Rand( -spread, spread ), 0 )

	local enemy = FindEnemy( bot )

	--[[
		A knife against a rifle is a loss, and in battle royale there are guns
		on the floor. While a bot still has one to fetch, it walks away from a
		fight it cannot win rather than charging in and dying to it.

		Gated on a live loot target, which only battle royale ever sets - so
		gungame, where the knife is the last rung and bots are meant to hunt
		with it, is untouched.

		Close enough and it commits anyway: disengaging at knife range just
		means being shot in the back.
	]]
	if IsValid( enemy ) and IsValid( bot.CS16BRTarget ) then
		local held = bot:GetActiveWeapon()

		if IsValid( held ) and CS16.WeaponSlot( held ) == CS16.SLOT_MELEE
			and bot:GetPos():DistToSqr( enemy:GetPos() )
				> cfg.MeleeAvoidRange * cfg.MeleeAvoidRange
		then
			enemy = nil
		end
	end

	--[[
		Contact resets the rotation clock, so "held this site and nothing
		happened" means literally that. A bot in a firefight is exactly where it
		should be, however long it has been standing there.
	]]
	if IsValid( enemy ) then bot.CS16HeldSince = CurTime() end

	if IsValid( enemy ) then
		if not IsValid( bot.CS16Enemy ) then
			-- Remember when this engagement started so reaction time can bite.
			bot.CS16SawEnemyAt = CurTime()

			-- Whether to throw is decided once here, per engagement. Rolling it
			-- in the tick loop instead would fire on the first frame every time
			-- and every bot would open with a grenade.
			bot.CS16WantsNade = math.random() < cfg.NadeChance
		end

		bot.CS16Enemy = enemy

		--[[
			Remember where they were, so losing sight leads to a pursuit rather
			than instant amnesia. Refreshed every tick they stay visible.
		]]
		bot.CS16LastSeenPos   = enemy:GetPos()
		bot.CS16LastSeenUntil = CurTime() + cfg.EnemyMemory
	else
		bot.CS16Enemy     = nil
		bot.CS16WantsNade = false
	end

	--[[
		Pursuit of somebody no longer visible.

		Deliberately separate from CS16Enemy, which stays strictly "can see them
		right now". Combat reads CS16Enemy, so folding memory into it would have
		bots aiming and firing through walls at a remembered position. This only
		ever produces a place to walk to.

		The memory is dropped on arrival as well as on timeout - standing where
		somebody used to be, still hunting them, is its own kind of stuck.
	]]
	if bot.CS16LastSeenPos and CurTime() > ( bot.CS16LastSeenUntil or 0 ) then
		bot.CS16LastSeenPos = nil
	end

	if bot.CS16LastSeenPos
		and bot:GetPos():DistToSqr( bot.CS16LastSeenPos ) < ROAM_ARRIVE_SQR
	then
		bot.CS16LastSeenPos = nil
	end

	local goal = ChooseGoal( bot )

	--[[
		Chasing a lost contact outranks whatever the bot was otherwise doing.
		Not while it can still see them: an enemy in view is handled by the
		combat code, which wants the bot holding its ground and shooting rather
		than walking onto the last place it saw somebody.
	]]
	if not IsValid( bot.CS16Enemy ) and bot.CS16LastSeenPos then
		goal = bot.CS16LastSeenPos
	end

	if goal then
		-- Repath when the goal changes, when the last path ran out, or on the
		-- periodic refresh. The "ran out" case is what keeps a bot that has
		-- reached its destination from stalling there.
		local needsPath = not bot.CS16Path
			or not bot.CS16Goal
			or bot.CS16Goal:DistToSqr( goal ) > 4096
			or ( bot.CS16NextPath or 0 ) < CurTime()

		if needsPath then CS16.BotSetGoal( bot, goal ) end
	end
end

--[[ Execution ]]

-- maxPitch caps how far up or down a bot will look; navigation passes one so a
-- waypoint on a rooftop can't leave it staring at the sky.
local function AimAt( bot, cmd, targetPos, maxPitch )
	local desired = ( targetPos - bot:EyePos() ):Angle()
	desired = desired + ( bot.CS16AimError or angle_zero )
	desired:Normalize()

	local current = bot.CS16Aim or bot:EyeAngles()
	local aim     = LerpAngle( math.Clamp( FrameTime() * cfg.AimSpeed, 0, 1 ), current, desired )
	aim:Normalize()
	aim.p = math.Clamp( aim.p, -89, 89 )
	aim.r = 0

	if maxPitch then aim.p = math.Clamp( aim.p, -maxPitch, maxPitch ) end

	bot.CS16Aim = aim
	cmd:SetViewAngles( aim )
	bot:SetEyeAngles( aim )
end

-- Burst discipline: 1.6 recoil makes holding the trigger useless past a few
-- rounds, so bots tap in bursts with a pause to let the spray settle.
--[[
	Order matters here, and getting it wrong is why bots were tapping single
	rounds instead of bursting.

	PauseUntil is always later than BurstUntil - it's the end of the burst plus
	the gap after it. So testing the pause first matched immediately on the
	very next tick of a burst and shut the trigger off. The burst window has to
	be checked before the pause window it sits inside.
]]
local function WantsToShoot( bot )
	local now = CurTime()

	-- Mid-burst: keep firing.
	if now < ( bot.CS16BurstUntil or 0 ) then return true end

	-- Burst finished, letting the spray settle.
	if now < ( bot.CS16PauseUntil or 0 ) then return false end

	bot.CS16BurstUntil = now + math.Rand( cfg.BurstMin, cfg.BurstMax )
	bot.CS16PauseUntil = bot.CS16BurstUntil + math.Rand( cfg.PauseMin, cfg.PauseMax )
	return true
end

--[[
	A knife has to be carried to the fight.

	Everything else here assumes a bot can hurt whatever it can see, which is
	true of every weapon in the game except one. On the last rung of a gungame
	ladder that assumption leaves a bot standing at rifle range swinging at the
	air, because nothing in the combat code knows the difference.
]]
local MELEE_REACH_SQR = 90 * 90

local function IsMelee( wep )
	return IsValid( wep ) and CS16.WeaponSlot( wep ) == CS16.SLOT_MELEE
end

--[[
	Is one of ours about to walk into it?

	Bots pushing a site together cross each other's lines constantly, and
	nothing stopped them pulling the trigger through a team-mate - so a group
	fight cost a couple of their own every time.

	Measured rather than traced. A trace would collide with the world, so a bot
	stood in a doorway would find the frame in its hull and refuse to fire at
	all; and a bullet passing a hair from a team-mate's shoulder is fine, while
	a trace can only answer hit or miss. This asks the question that actually
	matters: is a team-mate near the firing line, in front of me, and closer
	than what I'm shooting at.
]]
local function FriendlyInLine( bot, enemy )
	local eyes  = bot:EyePos()
	local dir   = bot:GetAimVector()
	local range = eyes:Distance( enemy:WorldSpaceCenter() )

	for _, other in ipairs( player.GetAll() ) do
		if other == bot or other == enemy then continue end
		if not other:Alive() or not IsAlly( bot, other ) then continue end

		local to    = other:WorldSpaceCenter() - eyes
		local along = to:Dot( dir )

		-- Behind us, or further away than what we're aiming at: not in the way.
		if along <= 0 or along > range then continue end

		--[[
			The margin grows with distance, because everything that makes a
			shot miss is angular. A bot's aim wanders by a couple of degrees
			and the weapon adds its own cone, so at arm's length a team-mate is
			safe an inch off the line and at the far end of long they are not.
			A fixed margin was right up close and far too tight at range, which
			is where the remaining team damage was coming from.
		]]
		local margin = CS16.Config.Bots.FriendlyClearance
			+ along * CS16.Config.Bots.FriendlySpread

		-- How far off the line they are, which is the whole question.
		if ( to - dir * along ):Length() < margin then return true end
	end

	return false
end

--[[
	Weapons that lob rather than shoot.

	Everything else in the pack is hitscan, so aiming at what you want to hit is
	the whole of it. The grenade launcher is not: its round leaves at 750 units a
	second under gravity, and aiming straight at somebody puts it in the floor
	well short of them. Bots emptied magazines into the ground a few feet in
	front of their target and could only score at point-blank range, where the
	drop had no distance to happen in.

	Both numbers are measured rather than taken from the addon's source: the
	speed is what the weapon gives the projectile, and 0.55 is the gravity scale
	read off a live one. The LAW is deliberately absent - it flies on
	MOVETYPE_FLY with no gravity at all, so it goes exactly where it is pointed.
]]
local PROJECTILE = {
	[ "weapon_cs16_mgl_mk1" ] = { speed = 750, gravity = 0.55 },
}

--[[
	Where to aim so the shot lands on the target rather than in front of it.

	Simple ballistics: the round is in the air for distance/speed, and falls
	half-g-t-squared in that time, so raise the aim point by exactly that much.

	First order only. Aiming higher lengthens the flight slightly, so this
	undershoots a little at long range - but the launcher's round detonates on a
	1.5 second fuse, which caps its useful reach around eleven hundred units, and
	across that span the error stays smaller than a player is tall.
]]
local function AimPointFor( bot, enemy )
	local target = enemy:WorldSpaceCenter()

	local wep = bot:GetActiveWeapon()
	if not IsValid( wep ) then return target end

	local shot = PROJECTILE[ wep:GetClass() ]
	if not shot then return target end

	local gravity = GetConVar( "sv_gravity" ):GetFloat() * shot.gravity
	local flight  = bot:EyePos():Distance( target ) / shot.speed

	return target + Vector( 0, 0, 0.5 * gravity * flight * flight )
end

local function Engage( bot, cmd, buttons )
	local enemy = bot.CS16Enemy

	--[[
		Aim at the chest, not the head.

		WorldSpaceCenter is roughly torso height. Aiming at EyePos meant every
		shot that landed was a headshot, which made them lethal rather than
		difficult - a bot that hits you three times in the chest is a fight, one
		that removes your head instantly is not.

		AimPointFor raises that for anything that arcs; for every other weapon it
		hands the chest straight back.
	]]
	AimAt( bot, cmd, AimPointFor( bot, enemy ) )

	-- Reaction delay before the first shot of an engagement.
	if CurTime() - ( bot.CS16SawEnemyAt or 0 ) < cfg.ReactionTime then return buttons end

	local wep = bot:GetActiveWeapon()
	if not IsValid( wep ) then return buttons end

	--[[
		Out of ammo altogether: change weapon instead of clicking an empty gun.

		The reload below only covers an empty clip with reserve left, so a bot
		that burned through everything just stood there pulling the trigger.
		BestWeapon skips the weapon it's holding and treats the knife as always
		loaded, so this walks rifle to pistol to knife on its own.
	]]
	if not CS16.WeaponHasAmmo( wep ) then
		local better = CS16.BestWeapon( bot, wep )

		if IsValid( better ) then
			bot:SelectWeapon( better:GetClass() )
			return buttons
		end
	end

	-- Reload rather than dry-firing.
	if wep:Clip1() == 0 and bot:GetAmmoCount( wep:GetPrimaryAmmoType() ) > 0 then
		return bit.bor( buttons, IN_RELOAD )
	end

	--[[
		Swinging a knife at somebody across the map achieves nothing but noise,
		and the burst timer would have them doing it constantly. Wait until it
		can reach; getting there is handled in the tick, which walks them in.
	]]
	if IsMelee( wep ) and bot:GetPos():DistToSqr( enemy:GetPos() ) > MELEE_REACH_SQR then
		return buttons
	end

	--[[
		Hold fire while one of ours is in the way.

		Only the trigger, deliberately - the bot keeps tracking the enemy, so it
		shoots the instant the line clears rather than losing the engagement
		while it reconsiders.
	]]
	if FriendlyInLine( bot, enemy ) then return buttons end

	-- Only pull the trigger once actually pointed at them. Measured against the
	-- same point they're aiming at, or the check fights the aim.
	local dir = ( enemy:WorldSpaceCenter() - bot:EyePos() ):GetNormalized()

	if bot:GetAimVector():Dot( dir ) > 0.98 and WantsToShoot( bot ) then
		buttons = bit.bor( buttons, IN_ATTACK )
	end

	return buttons
end

--[[
	Grenades.

	The pack's grenades arm on attack and throw on release, so a bot can't just
	press a button - it has to select the grenade, wait for it to actually be in
	its hands, hold, and let go. Hence a small state machine rather than a
	single call.

	Only ever the HE. Reaching for it by class here is what stops a bot throwing
	a flashbang or a smoke it happened to pick up off the floor.
]]
local NADE      = "weapon_cs16_hegrenade"
local NADE_AMMO = "CS16_HEGRENADE"

local function ShouldThrow( bot, enemy )
	-- Rolled once when the engagement started, not every tick, or they'd all
	-- throw the instant anyone came into view.
	if not bot.CS16WantsNade then return false end

	if not bot:HasWeapon( NADE ) then return false end
	if bot:GetAmmoCount( NADE_AMMO ) < 1 then return false end
	if ( bot.CS16NextNade or 0 ) > CurTime() then return false end

	local dist = bot:GetPos():Distance( enemy:GetPos() )

	-- Too close and they blow themselves up; too far and it lands nowhere near.
	if dist < cfg.NadeMinRange or dist > cfg.NadeMaxRange then return false end

	--[[
		And not into our own side.

		Holding fire covers bullets and does nothing for a grenade, which
		doesn't care where it was aimed once it lands. A bot lobbing an HE at
		somebody its own squad is pushing toward is the worst of the team
		damage in one throw, and the squad is pushing toward the enemy by
		definition.
	]]
	for _, other in ipairs( player.GetAll() ) do
		if other ~= bot and other:Alive() and IsAlly( bot, other )
			and other:GetPos():DistToSqr( enemy:GetPos() ) < cfg.NadeSafeRange ^ 2
		then
			return false
		end
	end

	return true
end

-- Returns the buttons to press, and whether this took over the tick.
local function ThrowGrenade( bot, cmd, enemy, buttons )
	local now = CurTime()

	--[[
		Already cooking one. Keep holding until the timer is up; releasing is
		simply not setting the button next tick, which is what throws it.
	]]
	if bot.CS16NadeUntil then
		-- Lob above them - the throw arcs, so aiming flat drops it short.
		local dist = bot:GetPos():Distance( enemy:GetPos() )
		AimAt( bot, cmd, enemy:WorldSpaceCenter() + Vector( 0, 0, dist * 0.25 ) )

		if now < bot.CS16NadeUntil then
			return bit.bor( buttons, IN_ATTACK ), true
		end

		bot.CS16NadeUntil = nil
		bot.CS16WantsNade = false
		bot.CS16NextNade  = now + cfg.NadeCooldown

		-- Released this tick. The grenade removes itself and the switch back to
		-- a gun is handled by CS16_SelectBestWeapon.
		return buttons, true
	end

	if not ShouldThrow( bot, enemy ) then return buttons, false end

	local wep = bot:GetActiveWeapon()

	if IsValid( wep ) and wep:GetClass() == NADE then
		bot.CS16NadeUntil = now + math.Rand( 0.2, 0.5 )
		return bit.bor( buttons, IN_ATTACK ), true
	end

	--[[
		Not in hand yet. Ask for it and shoot at nothing this tick while the
		switch happens - with a deadline, so a grenade that can't be selected
		for any reason can't leave a bot standing there asking forever.
	]]
	if not bot.CS16NadeSwitchBy then
		bot.CS16NadeSwitchBy = now + 1.5
	elseif now > bot.CS16NadeSwitchBy then
		bot.CS16NadeSwitchBy = nil
		bot.CS16WantsNade    = false
		bot.CS16NextNade     = now + cfg.NadeCooldown
		return buttons, false
	end

	bot:SelectWeapon( NADE )
	return buttons, true
end

-- Standing perfectly still in a firefight looks robotic; drift sideways.
local function CombatStrafe( bot, cmd )
	if ( bot.CS16NextStrafe or 0 ) < CurTime() then
		bot.CS16NextStrafe  = CurTime() + math.Rand( 0.4, 1.1 )
		bot.CS16StrafeDir   = ( math.random() < 0.5 ) and -1 or 1
	end

	cmd:SetSideMove( ( bot.CS16StrafeDir or 1 ) * bot:GetWalkSpeed() * 0.6 )
end

local function ObjectiveButtons( bot, cmd, buttons )
	--[[
		CT stood on a live bomb: hold use to defuse.

		Two things the addon's C4 demands that caught us out. It only starts on
		a fresh +use press (SIMPLE_USE fires once per press, not per tick), and
		its completion check throws the defuse away if you're more than 32 units
		from it - so bots have to walk right onto the bomb, not merely near it.
	]]
	if bot:Team() == TEAM_CT and CS16.IsBombPlanted() and IsValid( CS16.Bomb ) then
		local bombPos = CS16.Bomb:GetPos()

		-- Leave whoever is on it alone; interrupting restarts their countdown.
		local defuser = CS16.GetDefuser()
		if IsValid( defuser ) and defuser ~= bot then return buttons end

		if bot:GetPos():Distance( bombPos ) < DEFUSE_RANGE then
			AimAt( bot, cmd, bombPos )
			cmd:ClearMovement()

			-- Same trick as planting: blip until the defuse has engaged, then
			-- hold, because releasing mid-defuse cancels it.
			if not bot.m_bIsDefusing then
				bot.CS16UseHeld = not bot.CS16UseHeld
				if not bot.CS16UseHeld then return buttons end
			end

			return bit.bor( buttons, IN_USE )
		end
	end

	-- T stood in a site holding the bomb: plant it.
	if bot:Team() == TEAM_T
		and not CS16.IsBombPlanted()
		and bot:GetNWBool( "CS16.AtBombSite", false )
		and bot:HasWeapon( "weapon_cs16_c4" )
	then
		local wep = bot:GetActiveWeapon()

		if not IsValid( wep ) or wep:GetClass() ~= "weapon_cs16_c4" then
			bot:SelectWeapon( "weapon_cs16_c4" )
			return buttons
		end

		cmd:ClearMovement()

		--[[
			The C4 is semi-automatic: the plant only *starts* on a fresh press,
			and once started it must be held or Think cancels it.

			So while the state machine hasn't engaged (Plant still 0) we blip
			the trigger on and off to keep producing new presses, and only once
			it's underway do we hold the button down properly.
		]]
		if ( wep.Plant or 0 ) == 0 then
			bot.CS16PlantHeld = not bot.CS16PlantHeld
			if not bot.CS16PlantHeld then return buttons end
		end

		return bit.bor( buttons, IN_ATTACK )
	end

	return buttons
end

--[[
	Put the best thing they are carrying in their hands.

	Bots only ever changed weapon when the one they held ran dry, which is fine
	for a rifle and useless for a knife: a knife never runs out, so a battle
	royale bot that started with one and picked a rifle up off the floor kept
	the knife for the rest of the round.

	Deliberately narrow about when it fires. A bot holding a grenade or the
	bomb chose that on purpose and is probably part way through using it, so
	those are left alone entirely - snatching a rifle back into their hands
	mid-throw would be worse than the problem this fixes.

	Throttled because it runs from StartCommand, which is every tick for every
	bot, and nothing about a bot's inventory changes at that rate.
]]
local UPGRADE_INTERVAL = 0.5

local function UpgradeWeapon( bot )
	if ( bot.CS16NextUpgrade or 0 ) > CurTime() then return end
	bot.CS16NextUpgrade = CurTime() + UPGRADE_INTERVAL

	-- Defusing pins them in place and takes no weapon; interrupting is rude.
	if bot.m_bIsDefusing then return end

	local wep = bot:GetActiveWeapon()

	if IsValid( wep ) then
		local slot = CS16.WeaponSlot( wep )

		-- A grenade or the bomb is a decision, not a fallback.
		if slot == CS16.SLOT_OTHER then return end

		-- Already holding a primary: there is nothing better to reach for.
		if slot == CS16.SLOT_PRIMARY then return end
	end

	local best = CS16.BestWeapon( bot )
	if not IsValid( best ) or best == wep then return end

	if IsValid( wep ) then
		local a, b = CS16.WeaponSlot( best ), CS16.WeaponSlot( wep )
		if a and b and a >= b then return end
	end

	bot:SelectWeapon( best:GetClass() )
end

hook.Add( "StartCommand", "CS16.BotCommand", function( bot, cmd )
	if not bot.CS16Bot then return end

	cmd:ClearMovement()
	cmd:ClearButtons()

	--[[
		Paused: the clear above is the whole of it.

		Checked here rather than left to the pause module's own hook, because
		two hooks on StartCommand run in no guaranteed order - if that one went
		first this would cheerfully write the movement back in. See sv_pause.
	]]
	if CS16.IsPaused and CS16.IsPaused() then return end

	if not bot:Alive() then return end
	if not CS16.IsPlayingTeam( bot:Team() ) then return end

	if ( bot.CS16NextThink or 0 ) < CurTime() then BotDecide( bot ) end

	local buttons = 0
	local state   = CS16.GetRoundState()

	-- Frozen at the top of the round: aim around, but don't try to walk.
	if state == ROUND_FREEZE then
		if IsValid( bot.CS16Enemy ) then AimAt( bot, cmd, bot.CS16Enemy:EyePos() ) end
		return
	end

	buttons = ObjectiveButtons( bot, cmd, buttons )

	local planting = bit.band( buttons, IN_ATTACK ) ~= 0 and bot:Team() == TEAM_T
		and IsValid( bot:GetActiveWeapon() )
		and bot:GetActiveWeapon():GetClass() == "weapon_cs16_c4"

	local defusing = bit.band( buttons, IN_USE ) ~= 0

	if not planting and not defusing then
		if IsValid( bot.CS16Enemy ) and bot.CS16Enemy:Alive() then
			-- A grenade takes over the whole engagement while it's in hand;
			-- otherwise fall through to shooting as normal.
			local threw
			buttons, threw = ThrowGrenade( bot, cmd, bot.CS16Enemy, buttons )

			if not threw then buttons = Engage( bot, cmd, buttons ) end

			--[[
				Charge with a knife, hold ground with anything else.

				Strafing is the right instinct in a gunfight and exactly the
				wrong one when your weapon reaches two feet - it keeps a bot
				dancing at a distance it can never do anything from. Aim is
				already set by Engage above, which BotMoveToward needs: it
				splits the walk direction against the current view angles.
			]]
			if IsMelee( bot:GetActiveWeapon() ) then
				CS16.BotMoveToward( bot, cmd, bot.CS16Enemy:GetPos() )
			else
				CombatStrafe( bot, cmd )
			end
		else
			--[[
				Nobody to shoot: walk the path, looking where we're going.

				Aim is set before movement on purpose - BotMoveToward splits the
				walk direction against the current view angles, so aiming
				afterwards would steer using last tick's heading.
			]]
			local look = CS16.PathLookAhead( bot ) or bot.CS16Goal

			if look then
				-- Look level toward the waypoint, not at it. Waypoints sit on
				-- the floor and some are well above or below the bot, which is
				-- what had them staring at the sky while they ran.
				AimAt( bot, cmd, Vector( look.x, look.y, bot:EyePos().z ), cfg.NavPitchLimit )
			end

			local moving = CS16.BotFollowPath( bot, cmd )

			if moving then
				bot.CS16NoPathFor = 0
			elseif bot.CS16Goal then
				--[[
					No route. Steering straight at the goal keeps them pushing
					in roughly the right direction, but if the goal is genuinely
					unreachable that means grinding into a wall while the stuck
					handler jumps forever - which is what the jumping-on-the-spot
					was. So give it a couple of seconds, then throw the goal
					away and let the brain pick somewhere else.
				]]
				bot.CS16NoPathFor = ( bot.CS16NoPathFor or 0 ) + FrameTime()

				if bot.CS16NoPathFor > 2 then
					bot.CS16NoPathFor = 0
					bot.CS16Goal      = nil
					bot.CS16Patrol    = nil
					bot.CS16Flee      = nil
				else
					CS16.BotMoveToward( bot, cmd, bot.CS16Goal )
					moving = true
				end
			end

			CS16.BotHandleStuck( bot, cmd, moving )
		end
	end

	--[[
		Out here, past every branch above, because a bot in a crouch-height gap
		has to duck whether it is walking a path, fighting, planting or
		defusing. Tucked inside the no-enemy branch it never fired for the one
		case that actually jams: two teams meeting in assault's vent.
	]]
	CS16.BotCrouchForNav( bot, cmd )

	--[[
		Out here for the same reason as the crouch above: a bot that walks over
		a rifle should end up holding it whether it was patrolling, hunting or
		standing still when it happened.
	]]
	UpgradeWeapon( bot )

	cmd:SetButtons( bit.bor( cmd:GetButtons(), buttons ) )
end )

--[[ Lifecycle ]]

hook.Add( "PlayerSpawn", "CS16.BotReset", function( bot )
	if not bot.CS16Bot then return end

	bot.CS16Bought    = false
	bot.CS16Site      = nil
	bot.CS16Patrol    = nil
	bot.CS16Flee      = nil
	bot.CS16Enemy     = nil
	bot.CS16Path      = nil
	bot.CS16Goal      = nil
	bot.CS16StuckFor  = 0

	-- Somebody seen last round is not somebody to go looking for in this one.
	bot.CS16LastSeenPos   = nil
	bot.CS16LastSeenUntil = 0
	bot.CS16NoPathFor = 0
	bot.CS16Wiggle    = nil
	bot.CS16Aim       = bot:EyeAngles()

	-- Areas it couldn't get through last round say nothing about this one: the
	-- crate it failed at may have been a crate with a bot stood on it.
	bot.CS16Avoid       = nil
	bot.CS16Waypoint    = nil
	bot.CS16WaypointFor = 0

	bot.CS16BlindUntil   = 0
	bot.CS16NadeUntil    = nil
	bot.CS16NadeSwitchBy = nil
	bot.CS16WantsNade    = false
	bot.CS16NextNade     = 0

	-- A fresh round is a fresh guess about where to be.
	bot.CS16HeldSince    = nil
	bot.CS16Roam         = nil

	-- A fresh opinion about which way round each round, so the same two bots
	-- don't walk the same pair of routes all match.
	bot.CS16RouteSeed    = math.random( 1, 1000000 )
	bot.CS16HoldFor      = nil

	-- Stagger the slow clock so a squad of bots doesn't all run A* on the same
	-- tick every time.
	bot.CS16NextThink = CurTime() + math.Rand( 0, THINK_INTERVAL )
end )

--[[ Commands ]]

--[[
	Naming a bot count by hand is an explicit instruction, so it stands autofill
	down. Without this the two would fight, and autofill would win: it
	reconciles twice a second, so anything set by hand would be undone before
	you could look at it. /autofill on hands control back.
]]
local function TakeManualControl( ply )
	if not CS16.AutoFillEnabled or not CS16.AutoFillEnabled() then return end

	CS16.SetAutoFill( false )
	ply:ChatPrint( "Autofill turned off - use /autofill on to hand it back." )
end

CS16.AddCommand( "addbot", {
	permission  = "bots",
	args        = "[t|ct]",
	description = "Add a bot, optionally to a specific side.",
	callback = function( ply, args )
		TakeManualControl( ply )

		local side = string.lower( args[ 1 ] or "" )
		local teamID

		if side == "t" then teamID = TEAM_T
		elseif side == "ct" then teamID = TEAM_CT end

		local bot, err = CS16.AddBot( teamID )
		if not bot then
			ply:ChatPrint( err or "Couldn't add a bot." )
			return
		end

		ply:ChatPrint( "Added bot " .. bot:Nick() .. "." )
	end,
} )

CS16.AddCommand( "removebot", {
	permission  = "bots",
	args        = "[name]",
	description = "Remove one bot, by name if given.",
	callback = function( ply, args )
		TakeManualControl( ply )

		local bot = CS16.RemoveBot( args[ 1 ] )
		ply:ChatPrint( bot and ( "Removed " .. bot:Nick() .. "." ) or "No matching bot." )
	end,
} )

CS16.AddCommand( "kickbots", {
	permission  = "bots",
	description = "Remove every bot.",
	callback = function( ply )
		local n = 0

		-- Bounded by the player limit so a bad state can't hang the server.
		for _ = 1, game.MaxPlayers() do
			if not CS16.RemoveBot() then break end
			n = n + 1
		end

		ply:ChatPrint( ("Removed %d bot%s."):format( n, n == 1 and "" or "s" ) )
	end,
} )

--[[
	Diagnostics.

	Bot movement has been wrong twice now, so rather than guess a third time
	this reports what the navigation layer is actually doing - whether the mesh
	loaded, whether areas have neighbours, and whether a route to each bot's
	current goal can be computed at all.
]]
CS16.AddCommand( "botdebug", {
	permission  = "debug",
	description = "Print bot navigation diagnostics to console.",
	callback = function( ply )
		local function Line( text )
			ply:PrintMessage( HUD_PRINTCONSOLE, text )
		end

		Line( "===== CS 1.6 bot diagnostics =====" )
		Line( ("navmesh loaded : %s"):format( tostring( navmesh.IsLoaded() ) ) )
		Line( ("nav areas      : %d"):format( #CS16.AllNavAreas() ) )
		Line( ("bomb sites     : %d"):format( #CS16.BombSites ) )

		--[[
			What the perch walk actually did, rather than only its verdict.

			The verdict alone was diagnosed wrong twice: an unchanged count
			could mean the measurement didn't help, or that the server was still
			running the old file, and there was no way to tell those apart. The
			seed and reached counts say which.
		]]
		local areas = CS16.AllNavAreas()

		-- Force the walk before reading its numbers.
		for _, area in ipairs( areas ) do CS16.IsPerchArea( area ) end

		local stats = CS16.PerchStats

		Line( ("perch walk     : %d seeds, %d of %d reached, %d perches, %d leaks%s"):format(
			stats.seeds, stats.reached, #areas, stats.perch, stats.leaks,
			stats.disabled and " (DISABLED - inconsistent)" or "" ) )

		--[[
			Where the bomb is. "nobody is going to fetch it" and "there is
			nothing on the floor to fetch" look identical from the bots' goals
			alone, and they need completely different fixes.
		]]
		local loose   = DroppedBomb()
		local carrier = BombCarrier()

		Line( ("bomb carrier   : %s"):format(
			IsValid( carrier ) and carrier:Nick() or "none" ) )
		Line( ("loose bomb     : %s"):format(
			IsValid( loose ) and tostring( loose:GetPos() ) or "none" ) )
		Line( ("planted        : %s"):format( tostring( CS16.IsBombPlanted() ) ) )

		-- The point bots are actually sent to, not a fresh guess - the two
		-- disagreed, which made this line lie about what was going on.
		for _, site in ipairs( CS16.BombSites ) do
			Line( ("  site %s ground %s"):format( site.letter, tostring( SiteGround( site ) ) ) )
		end

		for _, bot in ipairs( player.GetAll() ) do
			if not bot.CS16Bot then continue end

			local goal = bot.CS16Goal
			local area = navmesh.GetNearestNavArea( bot:GetPos() )

			Line( ("[%s] %s"):format( bot:Nick(), team.GetName( bot:Team() ) ) )

			-- If this reports 0 neighbours the mesh connectivity is the
			-- problem, not the search.
			-- "perch yes" means it's stood on a crate: a couple of neighbours
			-- and a long drop to all of them.
			Line( ("    area %s, %d adjacent, perch %s"):format(
				IsValid( area ) and area:GetID() or "NONE",
				IsValid( area ) and #area:GetAdjacentAreas() or 0,
				IsValid( area ) and ( CS16.IsPerchArea( area ) and "yes" or "no" ) or "-" ) )

			Line( ("    goal %s  path %s  index %d"):format(
				goal and tostring( goal ) or "none",
				bot.CS16Path and #bot.CS16Path or "nil",
				bot.CS16PathIndex or 0 ) )

			--[[
				How long it has been walking at the current waypoint, and what
				it has given up on. An index that won't move plus a climbing
				waypoint time is a bot stuck on something; a long avoid list is
				a mesh problem rather than a bot one.
			]]
			local avoided = {}

			for id in pairs( bot.CS16Avoid or {} ) do
				avoided[ #avoided + 1 ] = id
			end

			Line( ("    waypoint %.1fs  avoiding %s"):format(
				bot.CS16WaypointFor or 0,
				#avoided > 0 and table.concat( avoided, "," ) or "-" ) )

			-- Every gate the plant has to pass, so a stalled carrier can be
			-- pinned to one condition instead of guessed at.
			if bot:Team() == TEAM_T then
				local wep  = bot:GetActiveWeapon()
				local c4   = bot:GetWeapon( "weapon_cs16_c4" )
				local site = CS16.GetBombSiteAt( bot:GetPos() )

				Line( ("    C4 %s  held %s  atSite(nw) %s  atSite(real) %s  ground %s  plantStage %s"):format(
					bot:HasWeapon( "weapon_cs16_c4" ) and "yes" or "no",
					IsValid( wep ) and wep:GetClass() or "none",
					tostring( bot:GetNWBool( "CS16.AtBombSite", false ) ),
					site and site.letter or "no",
					tostring( bot:IsOnGround() ),
					IsValid( c4 ) and tostring( c4.Plant ) or "-" ) )
			end

			if goal then
				local path, reason = CS16.FindPath( bot:GetPos(), goal )

				Line( ("    test path: %s (%s, expanded %d)"):format(
					path and ( #path .. " points" ) or "FAILED",
					reason or "ok",
					CS16.LastPath.expanded or 0 ) )
			end
		end

		Line( "================================" )
		ply:ChatPrint( "Bot diagnostics written to your console." )
	end,
} )

CS16.AddCommand( "bots", {
	permission  = "bots",
	args        = "<count>",
	description = "Fill or trim the server to this many bots.",
	callback = function( ply, args )
		local wanted = tonumber( args[ 1 ] )
		if not wanted or wanted < 0 then
			ply:ChatPrint( "Give a number of bots." )
			return
		end

		TakeManualControl( ply )

		-- Capped rather than while-loops: if a bot ever fails to register we
		-- want a wrong answer, not a locked-up server.
		for _ = 1, game.MaxPlayers() do
			if CS16.BotCount() >= wanted then break end
			if not CS16.AddBot() then break end
		end

		for _ = 1, game.MaxPlayers() do
			if CS16.BotCount() <= wanted then break end
			if not CS16.RemoveBot() then break end
		end

		ply:ChatPrint( ("Now running %d bot%s."):format(
			CS16.BotCount(), CS16.BotCount() == 1 and "" or "s" ) )
	end,
} )
