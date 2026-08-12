--[[
	Quake announcer.

	Two independent ladders, the way the old plugins did it:

	  multikill - kills chained within a few seconds of each other
	  spree     - total kills on your current life, reset when you die

	Only one clip plays per kill, picked by priority, so a good round doesn't
	turn into a wall of shouting. It goes out on CS16.Sound, the same flat
	two-dimensional channel the round announcements use.
]]

--[[
	Registered here rather than left to whichever mode happens to be running.

	It used to be registered by competitive's round machine, which is fine right
	up until a mode that doesn't load that file needs the message - and then
	net.Start throws, the error unwinds out of hook.Call, and every hook
	registered after this one silently stops running for that event. In gungame
	that meant kills never reached the ladder, which looked nothing like a
	missing net string.

	A module must own the strings it sends. AddNetworkString is idempotent, so
	competitive registering it too costs nothing.
]]
util.AddNetworkString( "CS16.Sound" )

--[[
	Play something flat in everybody's ears, wherever they are standing.

	Public because it isn't only the announcer's: the round machine calls it, and
	so does anything that has to be heard across the whole map rather than from a
	position - a bomb going down at A matters just as much to the player holding
	B, who cannot hear it and would otherwise only learn from the chat.

	It lives beside the network string it uses, for the reason set out above.
]]
function CS16.BroadcastSound( path )
	if not path or path == "" then return end

	net.Start( "CS16.Sound" )
		net.WriteString( path )
	net.Broadcast()
end

local cfg = CS16.Config.Announcer

-- Kills chained inside the window.
local MULTIKILL = {
	[ 2 ] = "doublekill",
	[ 3 ] = "triplekill",
	[ 4 ] = "multikill",
	[ 5 ] = "megakill",
	[ 6 ] = "ultrakill",
	[ 7 ] = "monsterkill",
	[ 8 ] = "ludicrouskill",
	[ 9 ] = "holyshit",
}

-- Kills on the current life.
local SPREE = {
	[ 3 ]  = "killingspree",
	[ 5 ]  = "rampage",
	[ 7 ]  = "dominating",
	[ 9 ]  = "unstoppable",
	[ 11 ] = "godlike",
	[ 13 ] = "wickedsick",
}

--[[
	Resolve a clip name to a path.

	Files are a mix of mp3 and wav, and the female set is missing several
	rungs, so we look for what actually exists and fall back to the standard
	set before giving up.
]]
local function Resolve( name )
	for _, set in ipairs( { cfg.Set, "standard" } ) do
		for _, ext in ipairs( { "mp3", "wav" } ) do
			local path = ("quake/%s/%s.%s"):format( set, name, ext )
			if file.Exists( "sound/" .. path, "GAME" ) then return path end
		end
	end
end

local function Announce( name )
	if not name then return end

	CS16.BroadcastSound( Resolve( name ) )
end

--[[ Tracking ]]

--[[
	First blood is claimed per round number rather than reset by a hook.

	Resetting on CS16RoundEnded meant a straggler kill during the five second
	end phase - a grenade already in the air, the bomb going off - claimed first
	blood a second time, which is why it sometimes played twice in a row. Keyed
	to the round number it can only ever fire once per round, and needs no reset
	at all.
]]
local firstBloodRound = -1

local function ClaimFirstBlood()
	local round = CS16.GetRoundNumber()
	if firstBloodRound == round then return false end

	firstBloodRound = round
	return true
end

local function ResetLife( ply )
	ply.CS16Spree     = 0
	ply.CS16Multi     = 0
	ply.CS16LastKill  = 0
end

hook.Add( "PlayerSpawn", "CS16.AnnouncerReset", function( ply )
	ResetLife( ply )
end )

hook.Add( "PlayerDeath", "CS16.Announcer", function( victim, inflictor, attacker )
	if not cfg.Enabled then return end

	-- Only a live round is worth announcing. Warmup and the end-of-round
	-- scramble would otherwise chatter over each other.
	if CS16.GetRoundState() ~= ROUND_LIVE then return end

	if not IsValid( attacker ) or not attacker:IsPlayer() then return end

	-- Suicides announce nothing.
	if attacker == victim then
		ResetLife( victim )
		return
	end

	--[[
		Not in a free-for-all, where sharing a side means nothing.

		Battle royale puts five people on each nominal team and has them fight
		everybody, so roughly half of all kills are between "team-mates" - and
		every one of them was being announced as a team kill and then skipping
		the multikill and spree tracking that any other kill would have got.
	]]
	if attacker:Team() == victim:Team()
		and not CS16.ModeSetting( "FreeForAll", false )
	then
		-- Claimed, not skipped: a team kill is still the round's first blood,
		-- so nobody gets the call handed to them a moment later.
		ClaimFirstBlood()
		Announce( "teamkiller" )
		return
	end

	local now = CurTime()

	-- Chain if this kill landed close behind the last one, otherwise start over.
	if now - ( attacker.CS16LastKill or 0 ) <= cfg.MultikillWindow then
		attacker.CS16Multi = ( attacker.CS16Multi or 0 ) + 1
	else
		attacker.CS16Multi = 1
	end

	attacker.CS16LastKill = now
	attacker.CS16Spree    = ( attacker.CS16Spree or 0 ) + 1

	--[[
		One clip per kill, most notable first. First blood only happens once a
		round so it outranks everything; a knife kill is humiliating enough to
		beat a plain headshot.
	]]
	if ClaimFirstBlood() then
		Announce( "firstblood" )
		return
	end

	local multi = attacker.CS16Multi
	if multi >= 2 then
		Announce( MULTIKILL[ math.min( multi, 9 ) ] )
		return
	end

	if SPREE[ attacker.CS16Spree ] then
		Announce( SPREE[ attacker.CS16Spree ] )
		return
	end

	local wep = attacker:GetActiveWeapon()
	if IsValid( wep ) and wep:GetClass() == CS16.KNIFE then
		Announce( "humiliation" )
		return
	end

	if victim:LastHitGroup() == HITGROUP_HEAD then
		Announce( "headshot" )
	end
end )
