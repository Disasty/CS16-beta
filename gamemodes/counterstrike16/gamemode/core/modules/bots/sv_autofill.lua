--[[
	Keeping the match populated.

	The rules, in the order they matter:

	  * Nobody connected: no bots. An empty server runs empty rather than
	    burning a slot and a tick budget on ten bots nobody is watching.

	  * Somebody connected but still choosing: still no bots. Sitting in
	    spectator or unassigned on join isn't a match, so it doesn't start one.

	  * Anybody picks a team - either side, or the developer team - and the two
	    playing sides fill to a full 5v5 around them.

	  * Keep it there. Somebody dropping to spectator leaves a hole and a bot
	    takes it, so the game carries on at 5v5 whether they're in it or not.

	  * The last human disconnects and every bot is punted.

	Reconciled on a timer rather than hooked to each event. Joining, leaving,
	switching sides, disconnecting, being kicked to make room for a person and
	the halftime swap all move these counts, and one poll catches every one of
	them. It also sidesteps the awkward case: a disconnecting player is still in
	player.GetAll() when PlayerDisconnected runs, so counting humans from that
	hook would always be one out.
]]

local INTERVAL = 0.5

-- The runtime switch, and whether a match has actually started yet.
local enabled = CS16.Config.Bots.AutoFill
local armed   = false

function CS16.SetAutoFill( on )
	enabled = on and true or false

	-- Turning it off shouldn't leave it primed to refill the moment it comes
	-- back on; it re-arms the same way it did the first time.
	if not enabled then armed = false end
end

function CS16.AutoFillEnabled()
	return enabled
end

local function Humans()
	local n = 0

	for _, ply in ipairs( player.GetAll() ) do
		if not ply:IsBot() then n = n + 1 end
	end

	return n
end

--[[
	Has anybody committed to anything?

	HasBody rather than IsPlayingTeam, so joining the developer team fills the
	server too - the whole point of that team is watching a match happen, and
	there's no match to watch without one.
]]
local function AnyoneCommitted()
	for _, ply in ipairs( player.GetAll() ) do
		if not ply:IsBot() and CS16.HasBody( ply:Team() ) then return true end
	end

	return false
end

-- Bots on their way out still appear in player.GetAll() until the end of the
-- frame, so they're discounted here or we'd under-fill for a tick.
local function CountOn( teamID )
	local n = 0

	for _, ply in ipairs( player.GetAll() ) do
		if ply:Team() == teamID and not ply.CS16Removing then n = n + 1 end
	end

	return n
end

local function PuntEveryBot()
	for _ = 1, game.MaxPlayers() do
		if not CS16.RemoveBot() then break end
	end
end

timer.Create( "CS16.AutoFill", INTERVAL, 0, function()
	if not enabled then return end

	if Humans() == 0 then
		if armed then
			PuntEveryBot()
			armed = false
		end

		return
	end

	if not armed then
		if not AnyoneCommitted() then return end
		armed = true
	end

	--[[
		Each side is filled to its own share rather than the two being kept to a
		total between them.

		A total is satisfied by any split that adds up, so it had nothing to say
		about which side a bot should leave: somebody joining a full
		Counter-Terrorist side pushed the total over, and the trim took the
		first bot it found, which was a Terrorist. Ten players, five a side on
		paper, four against six on the scoreboard.

		Counting people rather than bots is what makes a person joining replace
		a bot rather than add to it.
	]]
	--[[
		One side to fill, or two.

		Battle royale runs ten on a single team, so its share is the whole
		roster rather than half of it. Filling TEAM_T and TEAM_CT there would
		seat every bot on teams that are not playing - IsPlayingTeam answers for
		TEAM_BR alone under that mode - and the match would sit permanently one
		short of being able to start.
	]]
	local solo  = CS16.SoloTeam()
	local sides = solo and { solo } or { TEAM_T, TEAM_CT }
	local share = solo and CS16.MaxPerTeam() or CS16.BotFillPerTeam()

	--[[
		Filled a place at a time onto whichever side is smallest.

		Doing one side and then the other looks equivalent and is not. If the
		server runs out of room part way, the first side has its full share and
		the second gets whatever was left - so a server too small for both
		played lopsided no matter who joined. Alternating means a shortfall is
		shared, and the sides come out level or one apart.

		Bounded rather than a while-loop, the same way the /bots command does
		it: if a bot ever fails to place we want the sides a few short, not a
		locked-up server.
	]]
	for _ = 1, share * #sides do
		local target, fewest

		for _, teamID in ipairs( sides ) do
			local n = CountOn( teamID )

			if n < share and ( not fewest or n < fewest ) then
				target, fewest = teamID, n
			end
		end

		-- Everybody is at their share.
		if not target then break end
		if not CS16.AddBot( target ) then break end
	end

	--[[
		Only bots, and only on a side that is over. A side above its share
		because people filled it keeps them: RemoveBotOn simply runs out of bots
		to take and stops.
	]]
	for _, teamID in ipairs( sides ) do
		for _ = 1, share do
			if CountOn( teamID ) <= share then break end
			if not CS16.RemoveBotOn( teamID ) then break end
		end
	end
end )

CS16.AddCommand( "autofill", {
	permission  = "bots",
	args        = "<on|off>",
	description = "Turn automatic match filling on or off.",
	callback = function( ply, args )
		local arg = string.lower( args[ 1 ] or "" )

		if arg ~= "on" and arg ~= "off" then
			ply:ChatPrint( ("Autofill is %s. Usage: /autofill <on|off>")
				:format( enabled and "on" or "off" ) )
			return
		end

		CS16.SetAutoFill( arg == "on" )

		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s turned autofill %s."):format( ply:Nick(), arg ) )
		end
	end,
} )
