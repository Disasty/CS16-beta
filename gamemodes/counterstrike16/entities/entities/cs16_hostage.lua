--[[
	A hostage.

	Built on base_nextbot rather than moved by hand, because following somebody
	across a map is exactly the problem NextBot exists to solve - it has the
	navmesh, the pathing and the locomotion already. Italy's mesh is 1799 areas
	and the walk from the upstairs rooms to the rescue point is sixty-seven
	waypoints; steering that by hand would be reinventing everything the bots
	already use.

	Use it as a Counter-Terrorist and it follows you. Use it again and it stays
	put. Walk it into a rescue zone and it's saved.
]]

AddCSLuaFile()

ENT.Base      = "base_nextbot"
ENT.Type      = "nextbot"
ENT.PrintName = "Hostage"
ENT.Spawnable = false

--[[
	The 1.6 pack's hostage, not Source's.

	This started out as models/player/hostage/hostage_01..04 - the Counter-Strike
	Source hostages, which are present on most installs and look nothing like the
	game this is a recreation of. The playermodels pack ships the real one.

	Its *playermodels* version rather than its npc one, and the difference
	matters: the npc model has walk_all and run_all but neither idle_all nor
	idle_all_01, so a hostage standing still would sit frozen in its reference
	pose. The playermodel carries the full set. See PlaySequence.

	One model where there were four, so what variety there is comes from its two
	skins - a fair trade for them being the right hostages.
]]
local MODEL = "models/cs/playermodels/hostage.mdl"
local SKINS = 2

function ENT:SetupDataTables()
	-- Networked so the HUD can say who is escorting what without asking.
	self:NetworkVar( "Entity", 0, "Follower" )
	self:NetworkVar( "Bool", 0, "Rescued" )
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end

	return
end

function ENT:Initialize()
	self:SetModel( self.HostageModel or MODEL )
	self:SetSkin( math.random( 0, SKINS - 1 ) )

	--[[
		No SetHullType here, however much it looks like it belongs.

		It's an NPC method and does not exist on a NextBot, so calling it threw
		and abandoned the rest of this function - silently, as far as the game
		was concerned. The hostages still spawned, walked and were rescued,
		because every line below happens to be setting something to roughly its
		default anyway, which is exactly why it went unnoticed. A NextBot takes
		its bounds from its model.
	]]
	self:SetHealth( 100 )

	--[[
		Walked through rather than bumped into.

		Four of them shuffling along a corridor behind you would otherwise be a
		moving wall, and the one place that matters most is the doorway you are
		both trying to get out of. Nothing can shoot them either, which is the
		intent for now - see the note on damage at the bottom.
	]]
	self:SetCollisionGroup( COLLISION_GROUP_DEBRIS_TRIGGER )
	self:SetUseType( SIMPLE_USE )

	self.loco:SetStepHeight( 24 )
	--[[
		Higher than a player's jump, because a hostage has to clear things a
		player would vault or crouch-jump over and it has neither. The balcony
		railings in Italy's hostage house are the case that set this: at a
		player's 58 the two upstairs hostages bounced along the balcony without
		ever getting over the rail.
	]]
	self.loco:SetJumpHeight( 80 )
	--[[
		Willing to take any drop on the map.

		A NextBot refuses to step off anything taller than this, and the route
		out of Italy's market descends far enough that a cautious value stopped
		the escort dead - the hostage stood at the edge while the player it was
		following walked down without a thought. Nothing falls to its death here
		anyway; damage is ignored entirely, see the bottom of this file.
	]]
	self.loco:SetDeathDropHeight( 1000 )
end

--[[
	Walking pace, reasserted every frame.

	Setting it once in Initialize does not survive: something downstream of the
	path follower puts the desired speed back to about 400, and a hostage moving
	at 400 outruns the player escorting it - they run at 320. Measured rather
	than assumed; set once it read back 400 and covered the map at ~280 u/s,
	set per frame it holds whatever it is given.

	BodyUpdate is the base's own per-frame hook, so this costs nothing extra -
	and unlike Think, overriding it is safe, as long as the BodyMoveXY call it
	exists to make still happens.
]]
function ENT:BodyUpdate()
	self.loco:SetDesiredSpeed( CS16.Config.Hostage.FollowSpeed )
	self:BodyMoveXY()
end

--[[
	Only Counter-Terrorists, and only one at a time.

	A Terrorist pressing use on a hostage should do nothing at all - they are
	guarding it, not moving it - and two Counter-Terrorists sharing one would
	just make it oscillate between them.
]]
function ENT:Use( activator )
	if not IsValid( activator ) or not activator:IsPlayer() then return end
	if activator:Team() ~= TEAM_CT or not activator:Alive() then return end
	if self:GetRescued() then return end

	if self:GetFollower() == activator then
		self:SetFollower( NULL )
		CS16.Msg( activator, "hostage.stay" )
		return
	end

	self:SetFollower( activator )
	CS16.Msg( activator, "hostage.follow" )

	hook.Run( "CS16HostageTaken", self, activator )
end

--[[
	Animation by sequence name rather than activity.

	These are player models, so they carry the player animation set - the
	generic ACT_WALK a NextBot would reach for isn't in them, and asking for it
	leaves the model frozen in its reference pose.
]]
function ENT:PlaySequence( names )
	for _, name in ipairs( names ) do
		local id = self:LookupSequence( name )

		if id and id > 0 then
			if self:GetSequence() ~= id then self:ResetSequence( id ) end
			return
		end
	end
end

--[[
	Wedged against something the path can't get out of.

	Recovery is a shove to the nearest point on the navmesh. Blunt, but the
	alternative is a hostage standing at a wall for the rest of the round, and
	only somewhere already unreachable ever reaches this.
]]
--[[
	Put it somewhere it can actually walk from.

	The waypoint it was heading for, in preference to anything computed from
	where it is now. Projecting onto the nearest nav area sounds right and is
	circular: a hostage wedged on a ledge is nearest to the ledge it is wedged
	on, so it gets moved back to where it already was and sticks again a second
	later, forever. The route came out of CS16.FindPath, so every point on it is
	somewhere the map says you can stand.
]]
function ENT:Unwedge()
	local target = self.Route and self.Route[ self.RouteIndex ]

	if not target then
		local area = navmesh.GetNearestNavArea( self:GetPos() )
		if not area then return end

		target = area:GetClosestPointOnArea( self:GetPos() )
	end

	self.loco:ClearStuck()
	self:SetPos( target + Vector( 0, 0, 8 ) )

	-- Landing on the navmesh is not the same as landing on the ground - one of
	-- them ended up hanging in mid-air.
	self:DropToFloor()

	-- Advance past the waypoint that could not be reached on foot, so the next
	-- attempt is aiming somewhere new rather than back into the same corner.
	if self.Route then self.RouteIndex = self.RouteIndex + 1 end
	self.WaypointAt = CurTime()
end

--[[
	Actually going nowhere.

	Measured as distance covered over time, not by asking the locomotion whether
	it is stuck - that flag read false for a hostage hanging motionless forty-six
	units above the floor, gravity applied, reporting a velocity of 250 it was
	not using. The commanded velocity is not the same as movement, and the engine
	only counts a narrow definition of stuck.

	Position over time has no such opinion: it either got somewhere or it didn't.
	The bots learned this on the B site crates.
]]
local WEDGED_TIME = 2
local WEDGED_DIST = 16

function ENT:CheckWedged()
	local pos = self:GetPos()

	if not self.WedgeMark or pos:Distance( self.WedgeMark ) > WEDGED_DIST then
		self.WedgeMark  = pos
		self.WedgeSince = CurTime()
		return
	end

	if CurTime() - self.WedgeSince > WEDGED_TIME then
		self:Unwedge()
		self.WedgeMark = nil
	end
end

function ENT:OnStuck()
	self.loco:ClearStuck()
end

--[[
	Walk toward a point, using the gamemode's own pathfinder.

	Not MoveToPos, which is the obvious choice and the wrong one here. Its
	PathFollower refuses routes the bots take on this map every round: the
	hostages piled up against the same wall on the way out of Italy's market,
	all four of them, walking into it and getting nowhere - while the very
	Counter-Terrorists leading them had just walked that ground themselves.

	The difference is which pathfinder each was asking. CS16.FindPath is the A*
	already tuned for this map's climbs and drops, and reusing it means a
	hostage can go anywhere a bot can go, by construction, rather than by
	coincidence. See core/modules/bots/sv_bot_nav.lua.
]]
local WAYPOINT_REACHED = 48
local WAYPOINT_TIMEOUT = 3
local GOAL_MOVED_SQR   = 250 * 250

function ENT:WalkTowards( goal )
	local pos = self:GetPos()

	-- Only ever checked while it is supposed to be walking somewhere. A hostage
	-- standing still because nobody has collected it is not wedged.
	self:CheckWedged()

	--[[
		Rebuilt when the target has actually gone somewhere else, not on a timer.

		A timer looks equivalent and is not: rebuilding the route also resets
		which waypoint we're on and when we started for it, so a route rebuilt
		every second means the stuck timeout below can never reach three and
		never fires. The hostage grinds against the same corner forever, at
		waypoint two of forty-three, having its escape hatch reset out from
		under it four times before it was ever allowed to open.
	]]
	local moved = not self.RouteGoal or goal:DistToSqr( self.RouteGoal ) > GOAL_MOVED_SQR

	if not self.Route or self.RouteIndex > #self.Route or moved then
		--[[
			Routed around anywhere too low to stand up in.

			A hostage is 81 units tall and has no crouch - there is no duck
			button on a NextBot - so an area the navmesh marks CROUCH isn't a
			slower way through, it's a wall. Assault's vent is one, and it was
			on the shortest route from every single hostage spot to the rescue
			point: they walked into it, stopped, and the round became
			unwinnable with four hostages nobody could move.

			The fallback matters as much as the avoidance. If ducking under
			something really is the only way out, shoving at it is worth a try
			- three of four got through that vent by brute force - whereas
			standing still fails every time.
		]]
		self.Route = CS16.FindPath( pos, goal, CS16.CrouchAreas() )
			or CS16.FindPath( pos, goal )

		self.RouteGoal  = goal
		self.RouteIndex = 1
		self.WaypointAt = CurTime()
	end

	local waypoint = self.Route and self.Route[ self.RouteIndex ]

	-- Nowhere to route to: walk at it directly rather than stand still.
	if not waypoint then
		self.loco:FaceTowards( goal )
		self.loco:Approach( goal, 1 )
		return
	end

	if pos:Distance( waypoint ) < WAYPOINT_REACHED then
		self.RouteIndex = self.RouteIndex + 1
		self.WaypointAt = CurTime()
		return
	end

	--[[
		Snagged on something between here and the next waypoint.

		Measured against the clock rather than against velocity, because a
		hostage grinding along a wall still reads as moving. The same trap the
		bots hit on the B site crates, and the same answer.
	]]
	if CurTime() > ( self.WaypointAt or 0 ) + WAYPOINT_TIMEOUT then
		-- Skipping the waypoint only. Getting physically unstuck is CheckWedged's
		-- job, and it decides on measured position rather than on loco:IsStuck,
		-- which cannot be relied on - see the note there.
		self.RouteIndex = self.RouteIndex + 1
		self.WaypointAt = CurTime()
		return
	end

	self.loco:FaceTowards( waypoint )
	self.loco:Approach( waypoint, 1 )

	--[[
		Jump at a step up, and at anything else that has stopped us.

		Only the first of those is obvious, and on its own it is not enough:
		Italy's balconies are railed, and a railing is not above the next
		waypoint, it is in the way of it. The hostages lined up against one and
		walked into it while the Counter-Terrorists leading them hopped over
		without breaking stride.

		Rather than try to recognise a railing, treat standing still while
		trying to walk as reason enough to jump - which is what the player
		holding W into it would do. Harmless when it's a real wall: the jump
		changes nothing and the waypoint timeout above still moves us on.
	]]
	if not self.loco:IsOnGround() then return end

	--[[
		Slow for a moment is not blocked - it's also what setting off looks
		like. Judging it per frame made them jump the instant they started
		walking, and a hostage in the air isn't being steered by Approach, so it
		landed just as slowly and jumped again: four of them bouncing on the
		spot outside the house, never leaving.

		So the stall has to persist before it counts.
	]]
	if self.loco:GetVelocity():Length2D() < 40 then
		self.StalledSince = self.StalledSince or CurTime()
	else
		self.StalledSince = nil
	end

	local climbing = waypoint.z - pos.z > 20
	local blocked  = self.StalledSince and CurTime() - self.StalledSince > 0.5

	if climbing or blocked then
		self.loco:Jump()
		self.StalledSince = nil
	end
end

function ENT:RunBehaviour()
	while true do
		local follower = self:GetFollower()

		-- Whoever was leading has died, left, or changed sides.
		if IsValid( follower ) and ( not follower:Alive() or follower:Team() ~= TEAM_CT ) then
			self:SetFollower( NULL )
			follower = nil
		end

		if IsValid( follower ) then
			local keep = CS16.Config.Hostage.FollowDistance
			local away = self:GetPos():Distance( follower:GetPos() )

			if away > keep then
				self:PlaySequence( { "walk_all", "walk_all_01", "run_all", "idle_all_01" } )
				self:WalkTowards( follower:GetPos() )
			else
				self:PlaySequence( { "idle_all_01", "idle_all", "walk_all" } )

				--[[
					Near enough not to be walking, but in the air rather than
					standing.

					The watchdog otherwise only runs while walking, and a hostage
					wedged on a ledge right beside the player escorting it is by
					definition close enough that it never walks - so it hung
					there for good, a few feet from the person waiting for it.
				]]
				if not self:IsOnGround() then self:CheckWedged() end
			end
		else
			self:PlaySequence( { "idle_all_01", "idle_all", "walk_all" } )
		end

		-- Never leave this loop without giving the frame back. See above.
		coroutine.yield()
	end
end

--[[
	Reaching the rescue zone is checked by the objective, in
	core/modes/competitive/sv_hostages.lua, not here.

	Partly because it's a rule about the round rather than about walking, but
	mostly because there is no room for it here: base_nextbot drives the
	behaviour coroutine from its own Think, so an ENT:Think of ours would
	replace it and the hostage would never take a step. That failure is silent -
	it stands there looking perfectly healthy - so it's worth the note.
]]
function ENT:Rescue( by )
	if self:GetRescued() then return end

	self:SetRescued( true )
	self:SetFollower( NULL )

	hook.Run( "CS16HostageRescued", self, by )

	-- Gone rather than left standing in the zone, so the count on screen and
	-- what you can see agree with each other.
	SafeRemoveEntity( self )
end

--[[
	Damage is ignored for now, deliberately.

	1.6 lets you shoot hostages and charges the shooter for it, but a dead
	hostage makes the rescue unwinnable and there is nothing yet that knows what
	to do about that. Better to be temporarily wrong about a rule than to hand
	somebody a round nobody can win.
]]
function ENT:OnTakeDamage( dmg )
	return 0
end
