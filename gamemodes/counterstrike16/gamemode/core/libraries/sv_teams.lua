--[[
	Who is allowed onto which side.

	Two rules, both aimed at the same thing - stopping people shopping around
	mid-match:

	  five a side, and
	  once you've picked, that's your side for the map.

	Leaving for spectator doesn't buy you a second choice either; it forfeits
	your slot for the rest of the map. Otherwise the lock is trivially defeated
	by bouncing through spectator, and someone can free up a place on the
	losing side and take one on the winning one.
]]

--[[
	Locks are held here rather than on the player.

	A map change is what clears them, and this table is rebuilt on load, so the
	reset is a property of the file rather than something that has to be
	remembered at every call site. Keyed by SteamID64 so a reconnect inside the
	same map doesn't launder it - bots have no SteamID64 and are exempt, which
	is correct: they're placed by CS16.AddBot, not by choice.
]]
local locked = {}

hook.Add( "InitPostEntity", "CS16.ClearTeamLocks", function()
	locked = {}
end )

local function LockKey( ply )
	return ply:SteamID64()
end

function CS16.GetTeamLock( ply )
	local key = LockKey( ply )
	return key and locked[ key ] or nil
end

function CS16.SetTeamLock( ply, value )
	local key = LockKey( ply )
	if key then locked[ key ] = value end
end

function CS16.TeamIsFull( teamID )
	return team.NumPlayers( teamID ) >= CS16.MaxPerTeam()
end

-- A bot on this side that can be removed to seat a person.
local function BotOn( teamID )
	for _, ply in ipairs( player.GetAll() ) do
		if ply.CS16Bot and not ply.CS16Removing and ply:Team() == teamID then
			return ply
		end
	end
end

--[[
	Returns allowed, reason.

	Spectating is always permitted - you can always step out, you just can't
	step back in.
]]
function CS16.CanJoinTeam( ply, teamID )
	if ply:Team() == teamID then return false, "team.already" end

	--[[
		The developer team is checked here rather than trusted from the menu.
		The menu only draws the option for developers, but the join is a net
		message and anyone can send one.
	]]
	if teamID == TEAM_DEV then
		if not CS16.IsDeveloper( ply ) then return false, "team.notforyou" end
		return true
	end

	if not CS16.IsPlayingTeam( teamID ) then return true end

	-- A mode with no sides worth protecting - a free-for-all deathmatch, say -
	-- has no reason to hold anyone to the team they picked.
	if not CS16.ModeSetting( "TeamLocks", true ) then return true end

	--[[
		Developers aren't held to the side lock. The lock exists to stop players
		switching to whichever team is winning; someone who can already set
		ranks and restart rounds doesn't need protecting from that, and being
		stuck on a side after stepping out to look at something would make the
		developer team useless.
	]]
	if CS16.IsDeveloper( ply ) then return true end

	local lock = CS16.GetTeamLock( ply )

	if lock == "spectator" then
		return false, "team.left"
	end

	if lock and lock ~= teamID then
		return false, "team.locked"
	end

	--[[
		A full side is only really full if people are filling it. Bots are
		making up the numbers, so one steps aside - which is the whole point of
		having them.
	]]
	if CS16.TeamIsFull( teamID ) and not IsValid( BotOn( teamID ) ) then
		return false, "team.full"
	end

	return true
end

--[[
	Put a player on a side, enforcing the rules above.

	CS16.SetTeam is the mechanical move and stays free of policy, because
	halftime and bot placement both need to bypass all of this.
]]
function CS16.JoinTeam( ply, teamID )
	local allowed, reason = CS16.CanJoinTeam( ply, teamID )

	if not allowed then
		if reason then CS16.Msg( ply, reason ) end
		return false
	end

	if CS16.IsPlayingTeam( teamID ) then
		-- Make room if the side is only full of bots.
		if CS16.TeamIsFull( teamID ) then
			local bot = BotOn( teamID )

			if IsValid( bot ) then
				bot.CS16Removing = true
				bot:Kick( "Making room for a player" )
			end
		end

		CS16.SetTeamLock( ply, teamID )
	elseif teamID ~= TEAM_DEV then
		-- Stepping out forfeits the slot for the rest of the map, but only if
		-- they actually held one. Stepping onto the developer team isn't
		-- stepping out, so it costs nothing.
		if CS16.IsPlayingTeam( ply:Team() ) then
			CS16.SetTeamLock( ply, "spectator" )
		end
	end

	CS16.SetTeam( ply, teamID )
	return true
end
