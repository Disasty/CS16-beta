--[[
	Levels.

	RuneScape's experience curve, unchanged, because it is a known-good grind
	that somebody has already spent twenty years proving is satisfying - and
	because its shape is the point. Levels 1 to 40 go by in an evening, level 92
	is the halfway mark to 99, and the last nine levels are most of the work.

	Levels here are purely cosmetic. Nothing about how the game plays reads them,
	which is what makes it safe for the grind to be enormous.

	Only pure functions live in this file, on both realms, so anything that wants
	to turn experience into a level can - without asking the server, and without
	the answer ever being stored anywhere it could drift out of step. Experience
	is the fact; the level is a view of it.
]]

CS16.MaxLevel = 99

--[[
	The curve itself.

	  XP(L) = floor( 1/4 * sum over n=1..L-1 of floor( n + 300 * 2^(n/7) ) )

	Built once into a lookup table at load rather than evaluated on demand: it is
	a summation, it is asked for every kill and every scoreboard paint, and the
	answer never changes.
]]
local Thresholds = {}

do
	local total = 0
	Thresholds[ 1 ] = 0

	for n = 1, CS16.MaxLevel - 1 do
		total = total + math.floor( n + 300 * 2 ^ ( n / 7 ) )
		Thresholds[ n + 1 ] = math.floor( total / 4 )
	end
end

-- Experience needed to reach a level. Level 1 is free; level 99 is 13,034,431.
function CS16.XPForLevel( level )
	return Thresholds[ math.Clamp( level, 1, CS16.MaxLevel ) ] or 0
end

function CS16.LevelFromXP( xp )
	xp = xp or 0

	--[[
		Walked from the top down rather than binary searched. Ninety-nine
		comparisons of integers is nothing next to the work either caller was
		already doing, and this way the table stays the only thing to be wrong
		about.
	]]
	for level = CS16.MaxLevel, 1, -1 do
		if xp >= Thresholds[ level ] then return level end
	end

	return 1
end

--[[
	How much a kill is worth at this level.

	Banded by the tens digit, so 1-9 pay the first rate and 90-99 the last. Read
	before the experience is added, never after - a kill that takes you from 9 to
	10 is paid at level 9's rate, because that is the level you were when you
	took the shot.
]]
function CS16.KillXP( level )
	local bands = CS16.Config.XP.KillBands
	return bands[ math.floor( level / 10 ) + 1 ] or bands[ #bands ]
end

--[[
	Progress through the current level, for the HUD and /xp.

	Returns experience into this level, experience the level spans, and how much
	is left. All three are zero at 99 - there is no next level to be short of,
	and reporting a distance to one that does not exist reads as a bug.
]]
function CS16.LevelProgress( xp )
	local level = CS16.LevelFromXP( xp )
	if level >= CS16.MaxLevel then return 0, 0, 0 end

	local base = CS16.XPForLevel( level )
	local next = CS16.XPForLevel( level + 1 )

	return xp - base, next - base, next - xp
end

-- 13,034,431 reads as unreadable noise in chat.
function CS16.FormatXP( xp )
	local text = tostring( math.floor( xp or 0 ) )
	local runs

	repeat
		text, runs = text:gsub( "^(-?%d+)(%d%d%d)", "%1,%2" )
	until runs == 0

	return text
end
