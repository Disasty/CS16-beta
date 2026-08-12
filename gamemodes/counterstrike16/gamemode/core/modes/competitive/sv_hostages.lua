--[[
	Hostage rescue.

	The same round competitive already plays - freeze, buy, MR12, no respawns -
	with a different thing to win it. Which is why this is an objective inside
	competitive rather than a mode of its own: everything a mode owns is
	identical, and only the win condition differs.

	Which objective a map gets is decided by the map, exactly as CS does it.
	Somewhere with bomb sites plays defusal; somewhere with hostage spots
	authored onto it plays rescue. Nobody switches anything.
]]

-- Which maps play this is decided by CS16.IsHostageMap, in the shared zone
-- module - it's a question about what was authored onto the map.

function CS16.ClearHostages()
	for _, ent in ipairs( ents.FindByClass( "cs16_hostage" ) ) do
		SafeRemoveEntity( ent )
	end
end

--[[
	Placed at the authored spots, one each.

	Dropped onto the floor from slightly above rather than spawned exactly where
	the position says: the spot was recorded from where a player stood, and a
	hostage hull is not a player hull, so the odd one ends up a unit inside the
	boards.
]]
function CS16.SpawnHostages()
	CS16.ClearHostages()

	if not CS16.IsHostageMap() then return end

	for _, spot in ipairs( CS16.HostageSpots ) do
		local ent = ents.Create( "cs16_hostage" )
		if not IsValid( ent ) then continue end

		ent:SetPos( spot.pos + Vector( 0, 0, 8 ) )
		ent:SetAngles( Angle( 0, spot.yaw, 0 ) )
		ent:Spawn()
		ent:Activate()

		ent:DropToFloor()
	end

	SetGlobalInt( "CS16.HostagesTotal", #CS16.HostageSpots )
	SetGlobalInt( "CS16.HostagesRescued", 0 )
end

--[[
	Has anybody got one home?

	Sweeping from here rather than from the entity, because the rescue zones are
	authored positions in a file rather than brush volumes in the map - there is
	nothing to touch, so nothing fires on its own. The entity cannot do it
	either: base_nextbot owns its Think to drive the behaviour coroutine.

	A quarter second is far tighter than anyone can cross a 250 unit radius, and
	it only runs on maps that have hostages on them.
]]
local nextCheck = 0

hook.Add( "Think", "CS16.HostageRescueCheck", function()
	if CurTime() < nextCheck then return end
	nextCheck = CurTime() + 0.25

	--[[
		Publish the objective for the client, which cannot work it out itself -
		the authored positions only go to developers.

		Recomputed here rather than settled once at map load so that a developer
		placing spots with /hostagespot sees the map become a rescue map while
		they're standing in it, without a reload.
	]]
	local rescue = CS16.IsHostageMap()
	if GetGlobalBool( "CS16.HostageMap", false ) ~= rescue then
		SetGlobalBool( "CS16.HostageMap", rescue )
	end

	local hostages = ents.FindByClass( "cs16_hostage" )
	if #hostages == 0 then return end

	for _, ent in ipairs( hostages ) do
		if IsValid( ent ) and not ent:GetRescued() then
			-- Only a hostage being escorted counts. One standing in the zone
			-- because that is where it was authored has not been rescued.
			local follower = ent:GetFollower()

			if IsValid( follower ) then
				for _, zone in ipairs( CS16.RescueZones ) do
					if ent:GetPos():DistToSqr( zone.pos ) < zone.radius ^ 2 then
						ent:Rescue( follower )
						break
					end
				end
			end
		end
	end
end )

--[[ Round wiring ]]

hook.Add( "CS16RoundStarted", "CS16.SpawnHostages", function()
	CS16.SpawnHostages()
end )

hook.Add( "CS16RoundEnded", "CS16.ClearHostages", function()
	CS16.ClearHostages()
end )

hook.Add( "CS16HostageTaken", "CS16.AnnounceHostage", function( hostage, ply )
	for _, other in ipairs( player.GetAll() ) do
		if other:Team() == TEAM_T then
			other:ChatPrint( "[CS 1.6] A hostage is being moved." )
		end
	end
end )

hook.Add( "CS16HostageRescued", "CS16.CountRescues", function( hostage, by )
	local rescued = GetGlobalInt( "CS16.HostagesRescued", 0 ) + 1
	SetGlobalInt( "CS16.HostagesRescued", rescued )

	if IsValid( by ) then
		CS16.AddMoney( by, CS16.Config.Hostage.RescueBonus )
	end

	local total = GetGlobalInt( "CS16.HostagesTotal", 0 )

	for _, ply in ipairs( player.GetAll() ) do
		ply:ChatPrint( ("[CS 1.6] Hostage rescued (%d of %d)."):format( rescued, total ) )
	end

	--[[
		All of them home wins it there and then, the way a defuse does. The
		round clock and elimination still apply until that happens.
	]]
	--[[
		The total has to be positive, not merely reached.

		With no hostages registered, "all of them are home" is vacuously true
		the instant anything counts as a rescue, and the round ends for the
		Counter-Terrorists out of nowhere. That should not be reachable in play
		on a map with no hostages - but it is one comparison to rule out, and a
		round ending for no visible reason is close to impossible to diagnose
		from the receiving end.
	]]
	if total > 0 and rescued >= total and CS16.GetRoundState() == ROUND_LIVE then
		CS16.EndRound( TEAM_CT, "All hostages rescued" )
	end
end )
