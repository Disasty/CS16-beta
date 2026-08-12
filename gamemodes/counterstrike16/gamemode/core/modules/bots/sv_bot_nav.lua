--[[
	Bot navigation.

	GMod's PathFollower is built for NextBot NPCs, which have a `loco` object.
	Bots made with player.CreateNextBot are real Players and have no such thing,
	so we do our own A* across the navmesh and steer by hand.

	That's why the .nav file matters: no mesh, no routing, and bots fall back to
	standing their ground and shooting.
]]

--[[
	Expansion cap. dust2's generated mesh is roughly 2500 areas, so the old
	2000 was close enough to the whole map that a long route could plausibly
	run out of budget. With the heap below this is cheap to raise.
]]
local MAX_ITERATIONS = 8000

-- Anything above this much of a step up is treated as a climb, and charged
-- this many units of extra path cost per unit of height.
--[[
	What A* charges for going up.

	The bar is a height you would have to jump for rather than step over, so
	stairs and ramps are simply walking and cost nothing extra. Above it, each
	unit of the excess is worth this many units of walking - enough that a bot
	will happily go a long way round a crate, and not so much that it will cross
	the map to avoid a staircase.
]]
local CLIMB_THRESHOLD = 32
local CLIMB_PENALTY   = 25

function CS16.NavReady()
	return navmesh.IsLoaded()
end

--[[
	The areas you cannot stand up in.

	nav_generate flags an area CROUCH when it measured less headroom than a
	standing hull needs, and nothing here read that flag until it mattered.
	Assault's vent is one: 59 units of clearance against a 72 unit player, and
	it sits on the shortest route out of the hostage warehouse, so everything
	tried to go through it at full height.

	Cached, because a mesh cannot change while a map is running and this gets
	asked on every hostage repath.
]]
local crouchAreas, crouchMap

function CS16.CrouchAreas()
	if crouchMap == game.GetMap() and crouchAreas then return crouchAreas end

	crouchAreas, crouchMap = {}, game.GetMap()

	for _, area in ipairs( navmesh.GetAllNavAreas() ) do
		if area:HasAttributes( NAV_MESH_CROUCH ) then
			crouchAreas[ area:GetID() ] = true
		end
	end

	return crouchAreas
end

--[[ Places to go ]]

-- dust2's mesh is a couple of thousand areas, so this is fetched once.
local allAreas

function CS16.AllNavAreas()
	if not allAreas or #allAreas == 0 then
		allAreas = navmesh.GetAllNavAreas() or {}
	end

	return allAreas
end

--[[
	Areas you can only get onto by climbing: crate tops, ledges, the boxes at
	both bomb sites.

	The nav generator links them to the floor below, so A* considers them
	perfectly good places to be and a bot will happily pick one to stand on -
	then spend the round jumping at the side of a crate trying to reach the goal
	it chose. The waypoint timeout can't save it, because a bot's own goal is
	the one area it is never allowed to route around.

	The first version of this asked whether every neighbour of an area sat well
	below it. That works for a crate on its own and fails for a group of them:
	the boxes at bomb site B sit against each other at similar heights, so each
	one has a neighbour level with it and none of them looks like a perch, which
	is exactly where bots kept getting stuck.

	So the question is asked properly instead: walk out from the floor and see
	what you can get to. An area you cannot reach from a player spawn without
	climbing is a perch, whatever its neighbours look like. Stacks and clusters
	both fall out of that without needing to be special cases.
]]

-- What counts as a step rather than a climb. Stairs and ramps are well under
-- this; the crates are well over it.
local STEP_HEIGHT = 32

--[[
	How far up it is from one area to the next, measured where they actually
	meet.

	Not centre to centre. Two areas can share a perfectly flat boundary and
	still have centres tens of units apart in height - any ramp does, and so
	does any long area on a slope - so measuring centres marked a third of
	dust2 unreachable on the first attempt. The closest point on each area to
	the other's centre sits near their shared edge, which is the height a player
	would actually have to climb.
]]
local function StepUp( from, to )
	local a = from:GetClosestPointOnArea( to:GetCenter() )
	local b = to:GetClosestPointOnArea( from:GetCenter() )

	return b.z - a.z
end

local perchCache

--[[
	Flood outward from the spawns, never climbing.

	Spawns are the one place on any map you can be certain is floor - the map
	itself says so - which saves guessing at which areas count as ground.
]]
--[[
	Who lists whom.

	Nav mesh connections are directional, and plenty are recorded only one way -
	a drop off a ledge is meant to be, but ordinary flat neighbours often are
	too, simply because of how the mesh was generated. Walking outward using
	only outgoing links therefore refuses to enter an area that happens to list
	its edge back toward you rather than forward, however flat the ground is.

	That was the whole bug: it left 301 of dust2's areas "unreachable" and was
	completely unaffected by how the step height was measured, because height
	was never what stopped it.

	So the walk uses connections in either direction and lets the step height
	decide, which is what actually determines whether a person could walk it.
]]
local function BuildNeighbours( areas )
	local neighbours = {}

	local function Link( a, b )
		neighbours[ a ] = neighbours[ a ] or {}
		neighbours[ a ][ b:GetID() ] = b
	end

	for _, area in ipairs( areas ) do
		if IsValid( area ) then
			for _, other in pairs( area:GetAdjacentAreas() ) do
				if IsValid( other ) then
					Link( area:GetID(), other )
					Link( other:GetID(), area )
				end
			end
		end
	end

	return neighbours
end

local function BuildReachable( areas, neighbours )
	local reachable, queue = {}, {}
	local seeds = 0

	for _, list in pairs( CS16.SpawnPoints or {} ) do
		for _, ent in ipairs( list ) do
			if IsValid( ent ) then
				local area = navmesh.GetNearestNavArea( ent:GetPos() )

				if IsValid( area ) and not reachable[ area:GetID() ] then
					reachable[ area:GetID() ] = true
					queue[ #queue + 1 ] = area
					seeds = seeds + 1
				end
			end
		end
	end

	local i = 1

	while i <= #queue do
		local area = queue[ i ]
		i = i + 1

		for _, neighbour in pairs( neighbours[ area:GetID() ] or {} ) do
			if not reachable[ neighbour:GetID() ] then
				-- Dropping down is free; only going up is a climb.
				if StepUp( area, neighbour ) <= STEP_HEIGHT then
					reachable[ neighbour:GetID() ] = true
					queue[ #queue + 1 ] = neighbour
				end
			end
		end
	end

	return reachable, #queue, seeds
end

--[[
	Built once and cached, because it walks the whole mesh.

	If the flood reaches only a small part of the map then something is wrong
	with it rather than with the map - no spawns cached yet, a mesh in pieces -
	and marking most of the map unusable would be far worse than the bug this
	fixes. In that case nothing is a perch and the waypoint timeout goes back to
	being the only defence, which is where we were before.
]]
-- What the last walk did, for /botdebug. Diagnosing this from its verdict
-- alone was guesswork twice over.
CS16.PerchStats = { seeds = 0, reached = 0, perch = 0, leaks = 0, disabled = false }

local function PerchTable()
	if perchCache then return perchCache end

	local areas = CS16.AllNavAreas()
	perchCache  = {}

	if #areas == 0 then return perchCache end

	local neighbours = BuildNeighbours( areas )
	local reachable, reached, seeds = BuildReachable( areas, neighbours )

	local perch = {}

	for _, area in ipairs( areas ) do
		if IsValid( area ) and not reachable[ area:GetID() ] then
			perch[ #perch + 1 ] = area
		end
	end

	--[[
		The walk checking its own work.

		If an area was called unreachable while sitting a single step from
		somewhere reachable, the walk should have gone there and didn't - that's
		a contradiction in its own terms, not a judgement about the map. Every
		perch must be a genuine climb from everything the walk could reach.

		This replaces a guess about what fraction of a map can plausibly be
		ledges, which was the wrong question twice: first too lax to catch a
		broken answer, then strict enough to reject a good one. Testing the
		property that has to hold needs no guess about the map at all.
	]]
	local leaks = 0

	for _, area in ipairs( perch ) do
		for _, neighbour in pairs( neighbours[ area:GetID() ] or {} ) do
			if reachable[ neighbour:GetID() ]
				and StepUp( neighbour, area ) <= STEP_HEIGHT then
				leaks = leaks + 1
				break
			end
		end
	end

	CS16.PerchStats = {
		seeds    = seeds,
		reached  = reached,
		perch    = #perch,
		leaks    = leaks,
		disabled = leaks > 0,
	}

	if leaks > 0 then
		MsgN( ("[CS 1.6] Perch walk is inconsistent - %d of %d areas it called unreachable are one step from ground it reached. Disabling it.")
			:format( leaks, #perch ) )

		return perchCache
	end

	for _, area in ipairs( perch ) do perchCache[ area:GetID() ] = true end

	return perchCache
end

function CS16.IsPerchArea( area )
	if not IsValid( area ) then return true end
	return PerchTable()[ area:GetID() ] == true
end

hook.Add( "InitPostEntity", "CS16.ResetNavCache", function()
	allAreas   = nil
	perchCache = nil
end )

--[[
	Snap a position onto walkable ground.

	Bomb sites are tall brush volumes, so their AABB centre floats well above
	the floor. Walking a bot at a point in mid-air is what made them mill about
	underneath it, so every goal goes through here first.
]]
function CS16.GroundPoint( pos )
	local area = navmesh.GetNearestNavArea( pos )
	if not IsValid( area ) then return pos end

	return area:GetClosestPointOnArea( pos )
end

--[[
	Somewhere else to be. Sampled at random rather than scanning every area -
	with a couple of thousand to choose from, sixty draws almost always finds
	one in range, and falling back to anywhere on the map is no bad thing
	either: it just means the bot goes exploring.
]]
function CS16.RandomNavPointNear( pos, radius )
	local areas = CS16.AllNavAreas()
	if #areas == 0 then return nil end

	local radiusSqr = radius * radius
	local fallback

	for _ = 1, 60 do
		local area = areas[ math.random( #areas ) ]

		-- Filtered at the source, so every caller that asks for somewhere to be
		-- gets somewhere it can actually stand.
		if IsValid( area ) and not CS16.IsPerchArea( area ) then
			local centre = area:GetCenter()
			fallback = fallback or centre

			if centre:DistToSqr( pos ) <= radiusSqr then return centre end
		end
	end

	return fallback
end

--[[
	A binary min-heap for the open set.

	The first version scanned the open set linearly for the cheapest node,
	which put a hard ceiling on how many nodes we could afford to expand. With
	a heap the cap can be raised well past the size of dust2's mesh, so a
	cross-map route can't quietly run out of budget and come back empty.
]]
local Heap = {}
Heap.__index = Heap

local function NewHeap()
	return setmetatable( { n = 0 }, Heap )
end

function Heap:Push( item, cost )
	local i = self.n + 1
	self.n  = i
	self[ i ] = { item = item, cost = cost }

	while i > 1 do
		local parent = math.floor( i * 0.5 )
		if self[ parent ].cost <= self[ i ].cost then break end

		self[ parent ], self[ i ] = self[ i ], self[ parent ]
		i = parent
	end
end

function Heap:Pop()
	local n = self.n
	if n == 0 then return nil end

	local top = self[ 1 ]

	self[ 1 ] = self[ n ]
	self[ n ] = nil
	self.n    = n - 1
	n         = n - 1

	local i = 1
	while true do
		local left, right = i * 2, i * 2 + 1
		local best = i

		if left  <= n and self[ left  ].cost < self[ best ].cost then best = left  end
		if right <= n and self[ right ].cost < self[ best ].cost then best = right end
		if best == i then break end

		self[ i ], self[ best ] = self[ best ], self[ i ]
		i = best
	end

	return top.item
end

--[[
	A per-bot opinion about which way round is nicer.

	A* is deterministic: one cost function and one goal point give one answer,
	so every bot heading for the same bomb site walked the same line, whichever
	spawn it started from. All eighteen Terrorist spawns on dust2 produced a
	route through the same corridor - not because the alternatives were worse,
	but because nothing ever asked for a second opinion.

	This gives each bot a fixed, arbitrary preference for some areas over
	others, which is enough to tip a close decision between two corridors
	without making anybody take a route that is actually bad. Deterministic in
	the area and the seed, so a bot's route is stable while it walks it rather
	than changing every time it repaths.
]]
local function Noise( id, seed )
	local x = math.sin( id * 12.9898 + seed * 78.233 ) * 43758.5453
	return x - math.floor( x )
end

-- Filled in by the last FindPath call so /botdebug can report what happened.
CS16.LastPath = { result = "none", expanded = 0 }

--[[
	A* over nav areas. Returns a list of Vectors to walk through, or nil plus a
	reason if there's no route.

	avoid is an optional set of area IDs to route around - areas a particular
	bot has already proved it can't get through. See BotFollowPath.

	variety is an optional { seed, scale }, which tips close decisions between
	corridors so two bots don't walk the same line. See Noise above.

	Neighbours are walked with pairs rather than ipairs: if GetAdjacentAreas
	ever hands back a non-sequential table, ipairs would silently iterate
	nothing and every path would come back empty.
]]
function CS16.FindPath( startPos, goalPos, avoid, variety )
	if not navmesh.IsLoaded() then
		CS16.LastPath = { result = "no navmesh", expanded = 0 }
		return nil, "no navmesh"
	end

	local startArea = navmesh.GetNearestNavArea( startPos )
	local goalArea  = navmesh.GetNearestNavArea( goalPos )

	if not IsValid( startArea ) or not IsValid( goalArea ) then
		CS16.LastPath = { result = "no nav area at start or goal", expanded = 0 }
		return nil, "no nav area at start or goal"
	end

	local goalID     = goalArea:GetID()
	local goalCentre = goalArea:GetCenter()

	-- Already there; just walk at it.
	if startArea:GetID() == goalID then
		CS16.LastPath = { result = "same area", expanded = 0 }
		return { goalPos }
	end

	local closed   = {}
	local cameFrom = {}
	local gScore   = { [ startArea:GetID() ] = 0 }

	local open = NewHeap()
	open:Push( startArea, startArea:GetCenter():Distance( goalCentre ) )

	local expanded = 0

	while expanded < MAX_ITERATIONS do
		local current = open:Pop()
		if not current then break end

		local id = current:GetID()

		-- The heap can hold stale duplicates of a node we've already settled;
		-- skipping them here is cheaper than supporting decrease-key.
		if not closed[ id ] then
			closed[ id ] = true
			expanded     = expanded + 1

			if id == goalID then
				local points = {}
				local area   = current

				for _ = 1, MAX_ITERATIONS do
					if not area then break end

					table.insert( points, 1, area:GetCenter() )
					area = cameFrom[ area:GetID() ]
				end

				--[[
					Drop the first point.

					It's the centre of the area the bot is already standing in,
					and once it has walked toward the far edge that centre is
					behind it. Leaving it in meant every rebuilt path started by
					sending the bot backwards - and since the path was rebuilt
					on a timer, it never got past the second waypoint. That was
					the circling.
				]]
				if #points > 1 then table.remove( points, 1 ) end

				-- Finish on the real target rather than the area's centre.
				points[ #points + 1 ] = goalPos

				CS16.LastPath = { result = "ok", expanded = expanded, length = #points }
				return points
			end

			local centre = current:GetCenter()
			local g      = gScore[ id ] or math.huge

			for _, neighbour in pairs( current:GetAdjacentAreas() ) do
				if IsValid( neighbour ) then
					local nid = neighbour:GetID()

					--[[
						Somewhere this bot has already failed to get through.
						Never the goal area itself, though - refusing to path to
						where we're going would leave it with no route at all.
					]]
					local banned = avoid and avoid[ nid ] and nid ~= goalID

					if not closed[ nid ] and not banned then
						local nCentre = neighbour:GetCenter()
						local step    = centre:Distance( nCentre )

						--[[
							Climbing costs more than walking.

							Links up onto crates and ledges are legal routes,
							but a bot has to jump them and doesn't always make
							it - and when it doesn't, it bounces off the same
							box indefinitely. Charging for height makes A*
							prefer the way round, which is what a player would
							take anyway. Drops are free; only going up is
							penalised.
						]]
						--[[
							Three things about how that height was measured
							were wrong, and between them they decided routes by
							elevation rather than by distance.

							It's the step where the two areas meet, not the gap
							between their centres. A ramp has a flat join and
							centres tens of units apart, so measuring centres
							charged a climbing fee for walking up a slope - the
							same mistake the perch walk made.

							Only the excess over the bar is charged, so clearing
							it costs a little rather than suddenly costing
							everything.

							And the bar is now a height you would have to jump
							for. At twenty units it sat under every staircase on
							the map, so a single step up cost six hundred units
							of walking and A* would cross dust2 to avoid one -
							which is why Counter-Terrorists rotating from B to A
							went the long way through mid instead of back
							through their own spawn.
						]]
						local rise = StepUp( current, neighbour )

						if rise > CLIMB_THRESHOLD then
							step = step + ( rise - CLIMB_THRESHOLD ) * CLIMB_PENALTY
						end

						-- This bot's own preference, enough to break a tie
						-- between two corridors and not enough to send it
						-- somewhere daft.
						if variety then
							step = step + Noise( nid, variety.seed ) * variety.scale
						end

						local tentative = g + step

						if tentative < ( gScore[ nid ] or math.huge ) then
							gScore[ nid ]   = tentative
							cameFrom[ nid ] = current
							open:Push( neighbour, tentative + neighbour:GetCenter():Distance( goalCentre ) )
						end
					end
				end
			end
		end
	end

	local reason = ( expanded >= MAX_ITERATIONS ) and "hit expansion cap" or "no route"
	CS16.LastPath = { result = reason, expanded = expanded }

	return nil, reason
end

--[[ Path following ]]

--[[
	How long an area a bot has failed to cross stays off its route, and how long
	it may spend on one waypoint before deciding that's what has happened.

	Ordinary waypoints are a couple of hundred units apart, so five seconds of
	walking at one is already several times what it should take.
]]
local AVOID_TIME       = 25
local WAYPOINT_TIMEOUT = 5

--[[
	How long a bot may be wedged before it is simply moved.

	Measured across every attempt to free it rather than reset by each, so this
	is genuinely "nothing has worked for eight seconds" rather than "the last
	thing tried has not worked yet". Long enough that a crowded doorway sorts
	itself out first, short enough that nobody watches a bot vibrate against a
	staircase for a round.
]]
local UNWEDGE_TIME = 8

-- Expired entries go, so a bot doesn't spend the rest of the map avoiding
-- somewhere it failed once. Returns nil when there's nothing left to avoid.
local function PruneAvoid( bot )
	local avoid = bot.CS16Avoid
	if not avoid then return nil end

	local now, any = CurTime(), false

	for id, expires in pairs( avoid ) do
		if expires <= now then avoid[ id ] = nil else any = true end
	end

	return any and avoid or nil
end

function CS16.BotSetGoal( bot, goalPos )
	local avoid = PruneAvoid( bot )

	--[[
		Each bot carries its own seed, so two heading for the same place pick
		different ways of getting there. Without it they file along one line -
		A* has no reason to answer the same question twice differently.
	]]
	local scale   = CS16.Config.Bots.RouteVariety or 0
	local variety = scale > 0 and { seed = bot.CS16RouteSeed or 0, scale = scale } or nil

	local path = CS16.FindPath( bot:GetPos(), goalPos, avoid, variety )

	--[[
		Avoiding somewhere must never strand a bot. If the only route runs
		through it, take that route anyway - a bot shoving at a crate is still
		better than one standing in spawn doing nothing.
	]]
	if not path and avoid then
		path = CS16.FindPath( bot:GetPos(), goalPos, nil, variety )
	end

	bot.CS16Goal      = goalPos
	bot.CS16Path      = path
	bot.CS16PathIndex = 1
	bot.CS16NextPath  = CurTime() + CS16.Config.Bots.RepathInterval
end

local CROWD_RANGE = 56

--[[
	Is somebody stood in the way?

	A squad leaving spawn all wants the same doorway at the same moment, and
	players are solid to each other, so they wedge. Steering is naive enough
	that they'd otherwise just lean into one another indefinitely.
]]
function CS16.BlockedByPlayer( bot, dir )
	local pos = bot:GetPos()

	for _, other in ipairs( player.GetAll() ) do
		if other ~= bot and other:Alive() then
			local delta = other:GetPos() - pos
			delta.z = 0

			local dist = delta:Length()

			if dist > 0 and dist < CROWD_RANGE then
				if not dir or delta:GetNormalized():Dot( dir ) > 0.5 then
					return other, delta, dist
				end
			end
		end
	end
end

--[[
	Nudge the heading sideways around whoever is in front.

	The offset is the perpendicular of the vector to them, which separates two
	bots automatically: if A steers left of the line between them, B - looking
	back down the same line - steers the opposite way, so they slide past
	instead of mirroring into each other.
]]
local function AvoidCrowding( bot, dir )
	local other, delta = CS16.BlockedByPlayer( bot, dir )
	if not other then return dir end

	local perp = Vector( -delta.y, delta.x, 0 )
	if perp:LengthSqr() < 1 then return dir end

	perp:Normalize()

	return ( dir + perp * 0.9 ):GetNormalized()
end

-- Decompose a world direction into the forward/side the bot should press,
-- relative to wherever it is currently looking. This is what lets a bot walk
-- one way while aiming another.
function CS16.BotMoveToward( bot, cmd, target )
	local dir = target - bot:GetPos()
	dir.z = 0

	if dir:LengthSqr() < 1 then return end
	dir:Normalize()

	dir = AvoidCrowding( bot, dir )

	-- Remembered so the stuck handler can tell whether an obstruction is
	-- actually in our way or just stood nearby.
	bot.CS16MoveDir = dir

	local view  = cmd:GetViewAngles()
	local fwd   = view:Forward()
	local right = view:Right()

	fwd.z, right.z = 0, 0
	fwd:Normalize()
	right:Normalize()

	local speed = bot:GetWalkSpeed()
	cmd:SetForwardMove( fwd:Dot( dir ) * speed )
	cmd:SetSideMove( right:Dot( dir ) * speed )
end

--[[
	Jump, with the crouch tucked in just after take-off.

	Shared by the stuck handler and by deliberate climbs so both get the extra
	clearance, and so neither can spam the button - the cooldown lives here
	rather than at each call site.
]]
--[[
	crouch is only passed for a deliberate climb. Tucking on every stuck-jump
	as well meant a bot wedged against something crouched roughly half the time
	it was there, which reads as a nervous tic rather than an attempt to get
	over anything.
]]
function CS16.BotJump( bot, cmd, crouch )
	local now = CurTime()
	if ( bot.CS16NextJump or 0 ) > now then return end

	bot.CS16NextJump = now + 0.8

	if crouch then
		bot.CS16CrouchFrom  = now + 0.1
		bot.CS16CrouchUntil = now + 0.6
	end

	cmd:SetButtons( bit.bor( cmd:GetButtons(), IN_JUMP ) )
end

--[[
	Where to look while walking.

	Aiming at the waypoint you're about to step on is what made bots spin on
	the spot: the heading to it swings wildly as you close on it, and the view
	drags the movement basis around with it. Looking further down the path
	gives a stable heading.
]]
function CS16.PathLookAhead( bot )
	local path = bot.CS16Path
	if not path then return nil end

	local pos  = bot:GetPos()
	local last = math.min( bot.CS16PathIndex + 4, #path )

	for i = bot.CS16PathIndex, last do
		if path[ i ]:DistToSqr( pos ) > 90000 then return path[ i ] end
	end

	return path[ math.min( bot.CS16PathIndex, #path ) ]
end

--[[
	Watch for a waypoint the bot simply cannot reach, and route around it.

	Two things here are deliberate, and the bug needed both.

	It's keyed on the waypoint's *position*, not on the path index. A repath
	rebuilds the same path and resets the index to 1, and the brain repaths
	every few seconds anyway - so an index-based timer restarted before it could
	ever fire, and a waypoint the bot couldn't reach never timed out. That's
	how two of them ended up pogoing at the same crate at mid indefinitely.

	And it accumulates FrameTime while following rather than reading the clock,
	so time spent fighting or defusing doesn't count against a waypoint the bot
	wasn't walking to at the time.

	Returns true if it gave up and repathed, in which case this tick's path is
	already stale.
]]
local function WatchWaypoint( bot, goal )
	local last = bot.CS16Waypoint

	if not last or last:DistToSqr( goal ) > 256 then
		bot.CS16Waypoint    = goal
		bot.CS16WaypointFor = 0
		return false
	end

	bot.CS16WaypointFor = ( bot.CS16WaypointFor or 0 ) + FrameTime()
	if bot.CS16WaypointFor < WAYPOINT_TIMEOUT then return false end

	--[[
		Long enough. Whatever this is - a crate too high to climb, a ledge that
		needs a run-up - this bot isn't getting over it, so charge the area off
		its map for a while and let A* find the way round. Which is the route a
		player would have taken in the first place.
	]]
	local area = navmesh.GetNearestNavArea( goal )

	if IsValid( area ) then
		bot.CS16Avoid = bot.CS16Avoid or {}
		bot.CS16Avoid[ area:GetID() ] = CurTime() + AVOID_TIME
	end

	bot.CS16Waypoint    = nil
	bot.CS16WaypointFor = 0

	CS16.BotSetGoal( bot, bot.CS16Goal )
	return true
end

-- Returns false once the path is spent, so the brain knows to pick a new goal.
function CS16.BotFollowPath( bot, cmd )
	local path = bot.CS16Path
	if not path then return false end

	local goal = path[ bot.CS16PathIndex ]
	if not goal then
		bot.CS16Path = nil
		return false
	end

	-- Distance2D so a waypoint on a different floor height still counts.
	if bot:GetPos():Distance2D( goal ) < 40 then
		bot.CS16PathIndex = bot.CS16PathIndex + 1
		goal = path[ bot.CS16PathIndex ]

		if not goal then
			bot.CS16Path = nil
			return false
		end
	end

	-- Giving up on this waypoint replaces the path outright, so nothing below
	-- should run against the old one.
	if WatchWaypoint( bot, goal ) then return true end

	--[[
		A waypoint above us that we're nearly stood under is a step up - a
		crate, a ledge, the boxes at both bomb sites. Jump for it deliberately
		instead of walking into the side and waiting for the stuck handler to
		work out what happened, which is what made climbing look so hopeless.
	]]
	local pos = bot:GetPos()

	if goal.z - pos.z > 20 and pos:Distance2D( goal ) < 64 then
		CS16.BotJump( bot, cmd, true )
	end

	CS16.BotMoveToward( bot, cmd, goal )
	return true
end

--[[
	Whether the bot needs to be ducking right now.

	The area it is standing in, and the one it is about to step into - the duck
	has to start before the ceiling rather than on contact with it, or the bot
	arrives at full height and wedges, which is the thing this exists to stop.
	Only close to that waypoint, so a bot doesn't shuffle the length of a
	corridor because the far end is low.
]]
local CROUCH_LOOKAHEAD_SQR = 96 * 96

local function NeedsCrouch( bot )
	if not bot:Alive() then return false end

	local crouch = CS16.CrouchAreas()
	if not next( crouch ) then return false end

	local here = navmesh.GetNearestNavArea( bot:GetPos(), false, 64, false, true, -2 )
	if IsValid( here ) and crouch[ here:GetID() ] then return true end

	local waypoint = bot.CS16Path and bot.CS16Path[ bot.CS16PathIndex ]
	if not waypoint or bot:GetPos():DistToSqr( waypoint ) > CROUCH_LOOKAHEAD_SQR then return false end

	local ahead = navmesh.GetNearestNavArea( waypoint, false, 64, false, true, -2 )

	return IsValid( ahead ) and crouch[ ahead:GetID() ] or false
end

--[[
	Which way the bot is actually trying to walk, in world space.

	Read back off the command rather than from anything we stored, because
	this runs after every branch that might have set movement - path
	following, a knife charge, combat strafing - and only the command knows
	which of them won.
]]
local function IntendedDir( cmd )
	local fwd, side = cmd:GetForwardMove(), cmd:GetSideMove()
	if fwd * fwd + side * side < 1 then return end

	local view    = cmd:GetViewAngles()
	local forward = view:Forward()
	local right   = view:Right()

	forward.z, right.z = 0, 0
	forward:Normalize()
	right:Normalize()

	local dir = forward * fwd + right * side
	dir.z = 0

	if dir:LengthSqr() < 1 then return end

	dir:Normalize()

	return dir
end

--[[
	The ceiling in front of you, measured rather than looked up.

	The navmesh test above is predictive and only ever as good as the
	annotation. Assault's vent is a single 25x25 crouch area with perfectly
	ordinary areas on either side of it, so a bot stopped at the mouth is
	standing somewhere unremarkable with its next waypoint past the far end,
	and nothing about where it is says to duck. In practice some ducked and
	some walked straight into the lip, which is precisely as reliable as that
	sounds.

	So also just look. Sweep a standing hull the way we are trying to go; if
	that is blocked and the same sweep ducked is clear, the thing in the way
	is a low ceiling and ducking is the whole answer. It needs no annotation,
	so it catches gaps the generator never flagged, on any map.

	Walking at a wall fails both sweeps and correctly does nothing, and a
	crate too tall to duck under fails both as well - that one is the jump's
	problem, not this one's.
]]
local CROUCH_PROBE = 28

local function CeilingAhead( bot, cmd )
	if not bot:IsOnGround() then return false end

	local dir = IntendedDir( cmd )
	if not dir then return false end

	local mins, maxs = bot:GetHull()
	local _, duckMax = bot:GetHullDuck()

	local from = bot:GetPos()
	local to   = from + dir * CROUCH_PROBE

	local standing = util.TraceHull( {
		start = from, endpos = to, mins = mins, maxs = maxs,
		filter = bot, mask = MASK_PLAYERSOLID,
	} )

	if not standing.Hit then return false end

	local ducked = util.TraceHull( {
		start = from, endpos = to, mins = mins, maxs = duckMax,
		filter = bot, mask = MASK_PLAYERSOLID,
	} )

	return not ducked.Hit
end

--[[
	Duck where there is no room to stand.

	Called every tick from StartCommand rather than from the stuck handler,
	which was the first attempt and quietly did nothing: that handler sits
	inside the branch for bots with no enemy, so the one case that matters -
	two teams meeting at a vent mouth - never reached it. Fitting through a
	gap is a property of where you are, not of whether you are shooting.
]]
function CS16.BotCrouchForNav( bot, cmd )
	if NeedsCrouch( bot ) or CeilingAhead( bot, cmd ) then
		cmd:SetButtons( bit.bor( cmd:GetButtons(), IN_DUCK ) )
	end
end

--[[
	Stuck handling.

	Doors, corners and each other. If a bot is trying to move but isn't, jump
	first - that clears most ledges and doorframes - and repath if it's still
	going nowhere.
]]
function CS16.BotHandleStuck( bot, cmd, moving )
	local now = CurTime()

	--[[
		Crouch-jump.

		The duck is held for a moment *after* the jump rather than alongside it
		- tucking the legs mid-air is what clears dust2's crates, whereas
		ducking on the same tick just leaves you crouched and grounded.
	]]
	if ( bot.CS16CrouchFrom or 0 ) <= now and ( bot.CS16CrouchUntil or 0 ) > now then
		cmd:SetButtons( bit.bor( cmd:GetButtons(), IN_DUCK ) )
	end

	if not moving then
		bot.CS16StuckFor  = 0
		bot.CS16WedgedFor = 0
		return
	end

	if bot:GetVelocity():Length2D() > 30 then
		bot.CS16StuckFor  = 0
		bot.CS16WedgedFor = 0
		return
	end

	bot.CS16StuckFor = ( bot.CS16StuckFor or 0 ) + FrameTime()

	--[[
		Jump to clear ledges and doorframes, on a cooldown so being wedged is
		one hop rather than a pogo stick.

		Never jump when the obstruction is another player, though - it does
		nothing but land you back on their head, which is precisely what a
		squad leaving spawn together looked like. Crowding is handled by
		steering around them instead.
	]]
	--[[
		Only a player actually in our path suppresses the jump. The first pass
		checked for anyone within range in any direction, which meant two bots
		stood together on a ledge each saw the other and neither would jump -
		so they both got stuck on obstacles they used to clear easily.
	]]
	if bot.CS16StuckFor > 0.4 and not CS16.BlockedByPlayer( bot, bot.CS16MoveDir ) then
		CS16.BotJump( bot, cmd, false )
	end

	--[[
		Still going nowhere after a second and a half. Jumping clearly isn't
		it, so stop shoving forward into whatever this is and slide along it -
		a consistent direction per attempt, so the bot actually travels rather
		than jittering on the spot. This clears the corners and crate edges
		that a jump alone can't.
	]]
	if bot.CS16StuckFor > 1.5 then
		if not bot.CS16Wiggle then
			bot.CS16Wiggle = ( math.random() < 0.5 ) and -1 or 1
		end

		-- Forward is zeroed too: still pushing into whatever is in the way is
		-- what stops the sidestep actually sliding along it.
		cmd:SetForwardMove( 0 )
		cmd:SetSideMove( bot.CS16Wiggle * bot:GetWalkSpeed() )
	else
		bot.CS16Wiggle = nil
	end

	-- Long enough that the sidestep has had its chance; take a fresh route.
	if bot.CS16StuckFor > 3 and bot.CS16Goal then
		CS16.BotSetGoal( bot, bot.CS16Goal )
		bot.CS16StuckFor = 0
		bot.CS16Wiggle   = nil
	end

	--[[
		Last resort: put it back on the mesh.

		Everything above escalates and then resets its own clock at the repath,
		so a bot genuinely wedged in geometry cycles jump, sidestep, repath,
		jump, sidestep, repath for the rest of the round - a new route out of a
		place you cannot move from is still no route at all. Nothing was
		measuring the wedge across those attempts, which is why one under a
		staircase stayed there.

		This clock is not reset by the repath, only by actually moving. When it
		runs out the bot is placed on the nearest point the navmesh says can be
		stood on.

		Blunt, and the same answer the hostages needed on Italy's balconies for
		the same reason: by the time it runs, everything gentler has been tried
		and has not worked.
	]]
	bot.CS16WedgedFor = ( bot.CS16WedgedFor or 0 ) + FrameTime()

	if bot.CS16WedgedFor > UNWEDGE_TIME then
		local area = navmesh.GetNearestNavArea( bot:GetPos(), false, 600, false, true, -2 )

		if IsValid( area ) then
			-- Lifted slightly, or it can arrive inside the floor it was given.
			bot:SetPos( area:GetClosestPointOnArea( bot:GetPos() ) + Vector( 0, 0, 8 ) )
			bot:SetVelocity( vector_origin )
		end

		bot.CS16WedgedFor = 0
		bot.CS16StuckFor  = 0
		bot.CS16Wiggle    = nil
	end
end
