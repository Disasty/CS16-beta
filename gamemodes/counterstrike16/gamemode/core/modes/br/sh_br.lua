--[[
	Battle Royale: ten in, one out.

	Everyone starts with a knife on a spawn of their own, guns are scattered
	across the map for whoever reaches them first, and there are no respawns. The
	last person standing wins, and the win goes on their record.

	Free for all, and one team to say so. Everyone damages everyone, a kill is a
	kill whoever it was, and the scoreboard is a single list of ten rather than
	two columns pretending a side won something.

	Registration only. The game itself is sv_br.lua, and the spawns and loot
	points are authored per map with /brspawn and /brloot.
]]

CS16.RegisterMode( "battleroyale", {
	label       = "Battle Royale",
	description = "Ten players, no respawns, guns on the floor. Last one alive wins.",
	aliases     = { "br", "royale" },

	--[[
		Everyone hurts everyone.

		PlayerShouldTakeDamage only blocks a shot between team-mates when this is
		off, so leaving it on is the whole of free-for-all as far as damage goes.
		What it does not do by itself is stop those kills being *treated* as team
		kills, which is what FreeForAll below is for.
	]]
	FriendlyFire = true,

	--[[
		There are no team-mates, so nothing is a team kill.

		Without this, half the kills in a match would cost the killer a frag,
		pay no experience and count for nothing - the penalties exist to stop you
		shooting people on your side, and here there is no such thing.
	]]
	FreeForAll = true,

	-- Nothing is bought. What you have is what you found.
	Buying = false,

	--[[
		Dropping stays on, unlike the other loose modes.

		Killing someone for their rifle is the point of the mode, and a floor
		full of guns is the mode's entire economy rather than a mess to clean up.
	]]
	Dropping = true,

	--[[
		Everybody on one team, called Battle Royale.

		This ran as five a side to begin with, on the grounds that the framework
		counts and fills per team and the sides were cosmetic anyway. They were
		not cosmetic where it counted: the scoreboard showed Counter-Terrorists
		against Terrorists and a score line for each, which is a description of
		a match that isn't being played. See TEAM_BR in sh_teams.lua.
	]]
	SoloTeam = true,

	-- Ten players, hard - and now that is ten on the one team rather than five
	-- against five.
	MaxPerTeam = 10,

	--[[
		No locks. There is one side, so there is nothing to switch to and
		nothing to protect.
	]]
	TeamLocks = false,

	--[[
		Death is final. Returning nothing means the framework never respawns you,
		which is what makes "last one standing" mean anything.
	]]
	RespawnDelay = function()
		return nil
	end,

	--[[
		A body only at the start of a match.

		The default hands one to anybody on a playing side the moment they ask,
		which in a mode with no respawns would let a dead player rejoin the fight
		by switching teams.
	]]
	CanTakeBody = function( ply )
		if ply:Team() == TEAM_DEV then return true end
		if not CS16.IsPlayingTeam( ply:Team() ) then return false end

		return CS16.GetRoundState() ~= ROUND_LIVE
	end,

	-- Bots fetch a gun before they go looking for a fight. See CS16.BRBotGoal.
	BotGoal = function( bot )
		return CS16.BRBotGoal( bot )
	end,

	-- A knife and nothing else. Everyone starts equal and the map decides.
	Loadout = function( ply )
		CS16.BREquip( ply )
	end,

	server = {
		"core/modes/br/sv_br.lua",
	},
} )
