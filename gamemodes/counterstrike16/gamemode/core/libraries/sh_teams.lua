--[[
	Team definitions. TEAM_SPECTATOR / TEAM_UNASSIGNED are engine-provided
	(1002 / 1001), so we only claim the low ids.
]]

TEAM_T  = 1
TEAM_CT = 2

--[[
	A developer walking around a live round.

	Deliberately not a playing team. Everything that runs the match asks
	IsPlayingTeam - the roster count, the win checks, the side swap at halftime,
	the buy menu, the bomb, the economy, and the bots' own target search - so
	staying outside that answer keeps a developer out of all of it at once,
	rather than needing an exception in each. A 5v5 with someone wandering
	through it is still a 5v5.

	Two useful things fall out for free: PlayerShouldTakeDamage already refuses
	damage to anyone off a playing team, and the bots' FindEnemy already
	requires its targets to be on one.
]]
TEAM_DEV = 3

--[[
	Everybody, in the modes that have no sides.

	Battle royale used to run as five Terrorists against five Counter-Terrorists
	with the sides declared cosmetic, which was fine for the spawn logic and a
	lie everywhere a person could see it: a free-for-all scoreboard reading
	"Counter-Terrorists 4 - Terrorists 6" describes a match that did not happen.
	Ten people in one list, sorted by who is winning, is what the mode actually
	is.
]]
TEAM_BR = 4

--[[
	Red and blue, because that is what 1.6 is.

	Terrorists used to be a gold-orange, which put them at the same colour as
	the panel frames and the headings, and a scoreboard drawn in one colour
	does not read as two teams facing each other. The red-against-blue split is
	most of what makes 1.6's scoreboard legible at a glance, and it belongs
	here rather than in the scoreboard alone: the kill feed, the chat, the
	target ID and the round result all name a side, and all of them were gold.

	Battle royale keeps the amber. There are no sides in it to tell apart, and
	red would read as one.
]]
CS16.TeamColors = {
	[TEAM_T]         = Color( 235, 70, 60 ),
	[TEAM_CT]        = Color( 105, 165, 245 ),
	[TEAM_DEV]       = Color( 90, 200, 90 ),
	[TEAM_BR]        = Color( 224, 176, 64 ),
	[TEAM_SPECTATOR] = Color( 160, 160, 160 ),
	[TEAM_UNASSIGNED]= Color( 160, 160, 160 ),
}

function GM:CreateTeams()
	team.SetUp( TEAM_T, "Terrorists", CS16.TeamColors[ TEAM_T ] )
	team.SetSpawnPoint( TEAM_T, "info_player_terrorist" )

	team.SetUp( TEAM_CT, "Counter-Terrorists", CS16.TeamColors[ TEAM_CT ] )
	team.SetSpawnPoint( TEAM_CT, "info_player_counterterrorist" )

	team.SetUp( TEAM_DEV, "Developer", CS16.TeamColors[ TEAM_DEV ] )

	--[[
		Registered on every map rather than only under battle royale, because
		team.SetUp runs once at load and the mode can be switched afterwards.
		A team nobody is on costs nothing.

		The spawn class is a fallback that should never be reached: battle
		royale deals its own authored spawns through PlayerSelectSpawn, and
		refuses to start at all on a map with none.
	]]
	team.SetUp( TEAM_BR, "Battle Royale", CS16.TeamColors[ TEAM_BR ] )
	team.SetSpawnPoint( TEAM_BR, "info_player_terrorist" )

	team.SetUp( TEAM_SPECTATOR, "Spectators", CS16.TeamColors[ TEAM_SPECTATOR ] )
	team.SetSpawnPoint( TEAM_SPECTATOR, "info_player_start" )
end

--[[
	The single team, in modes that declare one - otherwise nil.

	Asked before anything reasons about sides, so "which of the two" becomes
	"is there more than one" in exactly one place rather than at every call
	site. Modes opt in with SoloTeam; only battle royale does.
]]
function CS16.SoloTeam()
	return CS16.ModeSetting( "SoloTeam", false ) and TEAM_BR or nil
end

-- True for the teams that actually play the game, however many that is.
function CS16.IsPlayingTeam( t )
	local solo = CS16.SoloTeam()
	if solo then return t == solo end

	return t == TEAM_T or t == TEAM_CT
end

--[[
	True for everyone who walks around with a body.

	The distinction that matters: IsPlayingTeam answers "is this person in the
	match", HasBody answers "does this person exist in the world". A developer
	is the only case where those differ, and the places that care about bodies
	rather than the match - spawning, models, movement speed, the HUD - ask
	this one instead.
]]
function CS16.HasBody( t )
	return CS16.IsPlayingTeam( t ) or t == TEAM_DEV
end

-- Short code used to index Config.Models / Config.Loadout.
function CS16.TeamCode( t )
	if t == TEAM_T then return "T" end
	if t == TEAM_CT then return "CT" end
	return nil
end

--[[
	How many may be on one side.

	The mode's call, because it isn't always the same number as the one the bots
	fill to: gungame runs 5v5 with bots but opens up to ten a side when there
	are enough people to want it, so the cap and the fill target are separate
	ideas that happen to be equal in competitive.
]]
function CS16.MaxPerTeam()
	local wanted = CS16.ModeSetting( "MaxPerTeam", CS16.Config.Teams.MaxPerTeam )

	--[[
		The mode's number is what it would like, not what the server can hold.

		Five a side needs ten slots. Asked for on a server with eight it cannot
		be had, and the shortfall lands entirely on whichever side fills second
		- eight slots played five against three, and no arrangement of people
		ever fixed it because the imbalance was arithmetic rather than about who
		had joined.

		So it is a ceiling, and the real cap is half of what the server holds.
		Eight slots plays four a side, ten or more plays the five it asked for.
	]]
	if CS16.SoloTeam() then
		-- One team is the whole server rather than half of it.
		return math.min( wanted, game.MaxPlayers() )
	end

	return math.max( 1, math.min( wanted, math.floor( game.MaxPlayers() / 2 ) ) )
end

-- How many bots fill a side, which can never be more than fits on one.
function CS16.BotFillPerTeam()
	return math.max( 0, math.min( CS16.Config.Teams.BotFillPerTeam, CS16.MaxPerTeam() ) )
end

-- The team with fewer players, tie-broken toward CT the way auto-select does.
function CS16.SmallestTeam()
	-- Nothing to balance when there is only one side to be on.
	local solo = CS16.SoloTeam()
	if solo then return solo end

	local t, ct = team.NumPlayers( TEAM_T ), team.NumPlayers( TEAM_CT )
	if t < ct then return TEAM_T end
	if ct < t then return TEAM_CT end
	return math.random() < 0.5 and TEAM_T or TEAM_CT
end

-- CS16.CanJoinTeam and CS16.JoinTeam live in core/libraries/sv_teams.lua. The rules they
-- enforce - slot limits, and being locked to a side for the map - need server
-- state, so there's no shared half worth keeping here.
