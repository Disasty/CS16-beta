--[[
	Team Deathmatch: competitive's kit, none of its ceremony.

	You buy what you like for nothing, you keep it when you die, and the first
	side to the score limit takes it. No rounds, no bomb, no freeze time, no
	economy - just the two sides and a number going up.

	Registration only; everything that makes it work is in sv_tdm.lua and loads
	for this mode alone. Shared because the client needs the label, the buy rules
	and the free-shop flag.
]]

CS16.RegisterMode( "teamdeathmatch", {
	label       = "Team Deathmatch",
	description = "Free loadouts, instant respawns, first side to the score limit.",
	aliases     = { "tdm", "deathmatch", "dm" },

	--[[
		The buy menu is a loadout picker rather than a shop.

		Buying stays on so the whole menu works exactly as it does in
		competitive, and FreeBuying zeroes the prices - see CS16.PriceFor. That
		combination is the entire economy of this mode, and it means nothing in
		the menu needed changing to support it.
	]]
	Buying     = true,
	FreeBuying = true,

	--[[
		Off, as in gun game. Respawns are instant and the sides are mixed
		together across the whole map rather than lined up against each other, so
		shooting a team-mate is something that happens constantly rather than
		occasionally, and a mode this loose is the wrong place to punish it.
	]]
	FriendlyFire = false,

	--[[
		Nothing hits the floor, and it matters more here than anywhere.

		Competitive can afford dropped guns because a round wipes the map clean
		every couple of minutes. This mode never ends a round, so every weapon
		ever dropped stays exactly where it fell for the whole game - sixty-odd
		of them inside the first few minutes, littering the map with free rifles
		that make the loadout you chose irrelevant.

		Stopping the drop rather than the pickup, for the same reason gun game
		does: nothing dropped means nothing to find.
	]]
	Dropping = false,

	--[[
		Ten a side, and no locks.

		This is the casual mode - people should be able to join, leave and swap
		to even the sides up without a rule stopping them. Competitive locks
		precisely because it is trying to be a match.
	]]
	MaxPerTeam = 10,
	TeamLocks  = false,

	--[[
		Bots hunt rather than hold ground, the same reasoning as gun game: there
		is no ground worth holding when the score only counts kills, so a bot
		sitting on a bomb site is a bot in the wrong place by definition.
	]]
	BotGoal = function( bot )
		return CS16.BotRoamGoal( bot )
	end,

	-- Straight back in, while there is a game to go back to.
	RespawnDelay = function( ply )
		local state = CS16.GetRoundState()

		if state == ROUND_LIVE or state == ROUND_WARMUP then
			return CS16.Config.TDM.RespawnDelay
		end
	end,

	--[[
		Buy whenever you like, wherever you are.

		Competitive's buy window exists to make the opening of a round a decision
		you commit to. Nothing here is a round, and a loadout you can only change
		by waiting is just an obstacle between dying and playing again.
	]]
	InBuyTime = function()
		return true
	end,

	-- Whatever you last bought. Defined on the server; this only names the call.
	Loadout = function( ply )
		CS16.TDMEquip( ply )
	end,

	server = {
		"core/modes/tdm/sv_tdm.lua",
	},
} )
