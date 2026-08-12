--[[
	Competitive: MR12 bomb defusal, five a side. The mode this gamemode is for,
	and the one it runs out of the box.

	Registration only. Everything that makes it work is in the server files
	listed below, and those load for this mode alone - see core/modes/sh_modes.
	This file is shared because the client needs the settings and the buy-time
	rule to draw the buy menu honestly.
]]

CS16.RegisterMode( "competitive", {
	label       = "Competitive",
	description = "MR12 bomb defusal. Five a side, no respawns, plant or defuse.",
	aliases     = { "comp" },

	--[[
		What this mode is, for modules to ask about rather than checking its
		name. A deathmatch would answer differently on all three, and nothing
		in weapons/, teams or the HUD would need editing to cope.

		Only settings something actually reads are declared. A table full of
		flags nobody consults is worse than no table at all - it reads like the
		behaviour is configurable when it isn't.
	]]
	Buying    = true,   -- weapons/sh_buymenu, CS16.CanBuy
	TeamLocks = true,   -- libraries/sv_teams, CS16.CanJoinTeam

	--[[
		Bots play the objective: hold a site, escort the bomb, defend or defuse
		it. None of that generalises, which is why it's asked for by name rather
		than being what bots do by default.
	]]
	BotGoal = function( bot )
		return CS16.BotObjectiveGoal( bot )
	end,

	--[[
		There is deliberately no "Bomb" flag. The HUD needs no such thing: it
		asks CS16.IsBombPlanted, which reads a global that a mode without a
		bomb simply never sets, so it answers "no" on its own. That the flag
		turned out to be unnecessary is a good sign the vocabulary split is in
		the right place. The bots will want one in due course, since their
		goals really are bomb-shaped, and it can be added then.
	]]

	--[[
		Death is permanent for the round, except during warmup, which is a
		free-for-all and comes back.
	]]
	RespawnDelay = function( ply )
		if CS16.GetRoundState() == ROUND_WARMUP then
			return CS16.Config.Round.WarmupRespawn
		end
	end,

	--[[
		You only receive a body at the top of a round. Dying mid-round means
		sitting it out, and joining mid-round means waiting for the next one.

		A developer isn't in the round at all, so the round's rules about when
		you may have a body don't apply - they come and go whenever they like.
	]]
	CanTakeBody = function( ply )
		if ply:Team() == TEAM_DEV then return true end
		if not CS16.IsPlayingTeam( ply:Team() ) then return false end

		local state = CS16.GetRoundState()
		return state == ROUND_WARMUP or state == ROUND_FREEZE
	end,

	--[[
		Buying is allowed while frozen and for a short grace once the round
		starts, which is how 1.6 let you finish a purchase on the way out of
		spawn.
	]]
	InBuyTime = function()
		local state = CS16.GetRoundState()
		if state == ROUND_FREEZE then return true end

		if state == ROUND_LIVE then
			local elapsed = CS16.Config.Round.RoundTime - CS16.GetPhaseRemaining()
			return elapsed <= 15
		end

		return false
	end,

	-- Order matters here as much as it does in the entry points: the round
	-- machine before the objectives and the match layer that read it.
	server = {
		"core/modes/competitive/sv_rounds.lua",
		"core/modes/competitive/sv_match.lua",
		"core/modes/competitive/sv_objectives.lua",
		"core/modes/competitive/sv_defuse.lua",
		"core/modes/competitive/sv_hostages.lua",
	},
} )
