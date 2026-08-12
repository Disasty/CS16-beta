--[[
	Experience, career kills, and the leaderboards built from them.

	Two rules shape everything here.

	Experience is stored and the level is derived, never both. A stored level is
	a second copy of a fact that can disagree with the first, and by the time
	anybody notices there is no way to know which one was right.

	Progression is per mode. Competitive and gun game keep separate experience,
	separate levels and separate leaderboards, the way RuneScape keeps separate
	skills - which is what makes it fine that a gun game kill comes eight times
	faster. You are only ever ranked against people playing the same game.

	Modes decide *when* to pay; this file decides how much and owns the storage.
	Nothing below knows what a bomb site is.
]]

local TABLE = "cs16_progression"

util.AddNetworkString( "CS16.MOTD" )

--[[ Storage ]]

--[[
	One row per identity per mode.

	Bots have no SteamID - every one of them returns the literal string "BOT" -
	so they are keyed on their name instead, which works precisely because we
	hand those names out ourselves from a fixed roster. The `bot` column exists
	so the two leaderboards can be pulled apart without parsing the key.

	Nick is display only, and refreshed on join: people rename themselves, and
	the leaderboard should show who they are now.
]]
local function EnsureTable()
	if sql.TableExists( TABLE ) then return end

	local ok = sql.Query( ([[
		CREATE TABLE %s (
			id     TEXT    NOT NULL,
			mode   TEXT    NOT NULL,
			bot    INTEGER NOT NULL DEFAULT 0,
			xp     INTEGER NOT NULL DEFAULT 0,
			kills  INTEGER NOT NULL DEFAULT 0,
			wins   INTEGER NOT NULL DEFAULT 0,
			nick   TEXT    NOT NULL DEFAULT '',
			PRIMARY KEY ( id, mode )
		)
	]]):format( TABLE ) )

	if ok == false then
		MsgN( "[CS 1.6] Could not create the progression table: " .. tostring( sql.LastError() ) )
	end
end

--[[
	A note on sql.Query's return value, because it reads backwards.

	  false  the query failed
	  nil    the query succeeded but produced no rows - which is every write
	  table  the query succeeded and produced rows

	So `nil` is success, not failure, and a write returns it every single time.
	Checking for nil the other way round meant every save announced itself as an
	error while working perfectly, which filled the console with a fault that was
	not happening and would have buried one that was.

	sql.LastError() is no help in deciding either: it is never cleared, so it
	keeps reporting the last real error long after later queries have succeeded.
	It is only meaningful immediately after a false.
]]

--[[
	Fold away any rows written under the old legacy-format key.

	Runs once at load and normally does nothing at all. Where a player has a row
	under each format, the two halves are added together rather than one being
	preferred - both are experience they actually earned, split between two keys
	by a bug, and picking a winner would quietly delete a night's play.
]]
local function MigrateLegacyIDs()
	local rows = sql.Query( ("SELECT id, mode, xp, kills, nick FROM %s WHERE id LIKE 'STEAM_%%'"):format( TABLE ) )
	if not rows then return end

	for _, row in ipairs( rows ) do
		local target = util.SteamIDTo64( row.id )

		if target and target ~= "0" then
			local existing = sql.QueryRow( ("SELECT xp, kills FROM %s WHERE id = %s AND mode = %s"):format(
				TABLE, sql.SQLStr( target ), sql.SQLStr( row.mode ) ) )

			sql.Query( ("REPLACE INTO %s ( id, mode, bot, xp, kills, nick ) VALUES ( %s, %s, 0, %d, %d, %s )"):format(
				TABLE,
				sql.SQLStr( target ),
				sql.SQLStr( row.mode ),
				( tonumber( row.xp )    or 0 ) + ( existing and tonumber( existing.xp )    or 0 ),
				( tonumber( row.kills ) or 0 ) + ( existing and tonumber( existing.kills ) or 0 ),
				sql.SQLStr( row.nick ) ) )
		end

		sql.Query( ("DELETE FROM %s WHERE id = %s AND mode = %s"):format(
			TABLE, sql.SQLStr( row.id ), sql.SQLStr( row.mode ) ) )
	end

	MsgN( ("[CS 1.6] Migrated %d legacy progression row(s)."):format( #rows ) )
end

--[[
	Who this is, for storage purposes.

	See the note on EnsureTable for why bots are keyed on their name. A developer
	is deliberately not excluded here - they simply never earn anything, because
	every award below checks they are on a playing side first.
]]
--[[
	Resolved once per session and then remembered.

	This used to read `ply:SteamID64() or ply:SteamID()`, which is two different
	*formats* rather than two ways of asking the same question - SteamID64
	answers 76561197960287930 and SteamID answers STEAM_0:0:11101. SteamID64
	can come back empty for a moment early in a join, so a player loaded on the
	fallback and saved on the real thing ended up with a row under each, and
	appeared on their own leaderboard twice.

	Two defences, because either alone would have been enough and neither is
	expensive: the fallback is converted into the same format as the primary, so
	both paths agree on what the key is, and the answer is cached so that even a
	third way of resolving it could not disagree with the first two.
]]
function CS16.ProgressID( ply )
	if ply:IsBot() then return ply:Nick() end
	if ply.CS16ID then return ply.CS16ID end

	local id = ply:SteamID64()

	if not id or id == "" or id == "0" then
		local legacy = ply:SteamID()

		if legacy and legacy ~= "" and legacy ~= "BOT" then
			id = util.SteamIDTo64( legacy )
		end
	end

	if not id or id == "" or id == "0" then return nil end

	ply.CS16ID = id
	return id
end

--[[
	Read into memory once, on join.

	Everything during a round then works on the copy, and the row is written back
	when the round ends - a kill should not cost a disk write, and there are ten
	bots generating them.
]]
function CS16.LoadProgress( ply )
	local mode = CS16.ModeID()
	local id   = CS16.ProgressID( ply )

	if not id or id == "" then return end

	local row = sql.QueryRow( ("SELECT xp, kills, wins FROM %s WHERE id = %s AND mode = %s"):format(
		TABLE, sql.SQLStr( id ), sql.SQLStr( mode ) ) )

	-- Values come back as strings whether or not the column says INTEGER.
	ply.CS16XP    = row and tonumber( row.xp )    or 0
	ply.CS16Kills = row and tonumber( row.kills ) or 0
	ply.CS16Wins  = row and tonumber( row.wins )  or 0
	ply.CS16Dirty = not row

	CS16.PublishLevel( ply )
end

function CS16.SaveProgress( ply )
	if not ply.CS16Dirty then return end

	local id = CS16.ProgressID( ply )
	if not id or id == "" then return end

	-- REPLACE rather than UPDATE, so the first save a player ever makes creates
	-- the row instead of silently doing nothing.
	local ok = sql.Query( ("REPLACE INTO %s ( id, mode, bot, xp, kills, wins, nick ) VALUES ( %s, %s, %d, %d, %d, %d, %s )"):format(
		TABLE,
		sql.SQLStr( id ),
		sql.SQLStr( CS16.ModeID() ),
		ply:IsBot() and 1 or 0,
		math.floor( ply.CS16XP or 0 ),
		math.floor( ply.CS16Kills or 0 ),
		math.floor( ply.CS16Wins or 0 ),
		sql.SQLStr( ply:Nick() ) ) )

	-- See the note above EnsureTable: false is the failure, nil is a normal
	-- write. Left dirty on failure so the next round tries again.
	if ok == false then
		MsgN( "[CS 1.6] Could not save progression: " .. tostring( sql.LastError() ) )
		return
	end

	ply.CS16Dirty = false
end

function CS16.SaveAllProgress()
	for _, ply in ipairs( player.GetAll() ) do
		CS16.SaveProgress( ply )
	end
end

--[[
	The board, for one side of the house.

	Ordered by experience rather than by level, which is the same ordering below
	99 and the only one that still means anything above it - the top of a mature
	board is all nines, and the ranking has to come from somewhere.

	Ties break on kills and then on name, so the order is stable between refreshes
	rather than flickering whenever two people sit on the same number.
]]
function CS16.Leaderboard( bots, limit )
	limit = math.floor( limit or 10 )

	--[[
		More rows than places, because of the de-duplication below: throwing an
		entry away must not leave the board a place short.
	]]
	--[[
		Ordered by wins first in a mode that has them.

		Experience still decides everywhere else, but in battle royale the number
		anybody cares about is how many times you were the last one standing -
		putting a level above it would rank the board by attendance.
	]]
	local order = CS16.ModeSetting( "FreeForAll", false )
		and "wins DESC, xp DESC, kills DESC, nick ASC"
		or  "xp DESC, kills DESC, nick ASC"

	local rows = sql.Query( ([[
		SELECT id, nick, xp, kills, wins FROM %s
		WHERE mode = %s AND bot = %d
		ORDER BY %s
		LIMIT %d
	]]):format( TABLE, sql.SQLStr( CS16.ModeID() ), bots and 1 or 0, order, limit * 4 ) )

	local out = {}

	-- false means the table is simply empty, which is the normal state of a
	-- fresh server rather than a problem.
	if not rows then return out end

	--[[
		Nobody appears twice on the same board.

		The identity check is the correct one and is already guaranteed by the
		primary key; the name check is the one that actually earns its place,
		because it holds even if the key were ever wrong again - which is exactly
		how somebody came to be ranked first and second at once.

		Rows arrive best-first, so the entry kept is the better of any pair. The
		cost is that two genuinely different people sharing a display name would
		show as one, which on a server of this size is a far better failure than
		showing one person as two.
	]]
	local seenID, seenNick = {}, {}

	for _, row in ipairs( rows ) do
		if #out >= limit then break end

		if not seenID[ row.id ] and not seenNick[ row.nick ] then
			seenID[ row.id ]     = true
			seenNick[ row.nick ] = true

			out[ #out + 1 ] = {
				nick  = row.nick,
				xp    = tonumber( row.xp )    or 0,
				kills = tonumber( row.kills ) or 0,
				wins  = tonumber( row.wins )  or 0,
				level = CS16.LevelFromXP( tonumber( row.xp ) or 0 ),
			}
		end
	end

	return out
end

--[[ Awarding ]]

-- The scoreboard shows everyone's level, so it has to travel.
function CS16.PublishLevel( ply )
	ply:SetNWInt( "CS16.Level", CS16.LevelFromXP( ply.CS16XP or 0 ) )
	ply:SetNWInt( "CS16.CareerKills", ply.CS16Kills or 0 )
end

--[[
	Pay somebody.

	The level is read before and after so a level-up can be announced the moment
	it happens rather than at the end of the round, which is when it would stop
	feeling like it was your kill that did it.
]]
function CS16.AwardXP( ply, amount )
	if not IsValid( ply ) or amount <= 0 then return end
	if not CS16.IsPlayingTeam( ply:Team() ) then return end
	if not ply.CS16XP then return end

	local before = CS16.LevelFromXP( ply.CS16XP )

	ply.CS16XP    = math.min( ply.CS16XP + math.floor( amount ), CS16.Config.XP.Cap )
	ply.CS16Dirty = true

	local after = CS16.LevelFromXP( ply.CS16XP )

	CS16.PublishLevel( ply )

	if after > before then
		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s is now level %d."):format( ply:Nick(), after ) )
		end
	end
end

--[[
	A match won, recorded against whoever won it.

	Public because winning is a mode's business - battle royale is the only thing
	that calls it today, and what counts as a win in any other mode is that
	mode's to decide.
]]
function CS16.AddWin( ply )
	if not IsValid( ply ) or not ply.CS16Wins then return end
	if not CS16.IsPlayingTeam( ply:Team() ) then return end

	ply.CS16Wins  = ply.CS16Wins + 1
	ply.CS16Dirty = true

	-- Written immediately rather than at the next round end: the match is over,
	-- and the map reload that follows would otherwise take it with it.
	CS16.SaveProgress( ply )

	for _, other in ipairs( player.GetAll() ) do
		other:ChatPrint( ("[CS 1.6] %s now has %d win%s."):format(
			ply:Nick(), ply.CS16Wins, ply.CS16Wins == 1 and "" or "s" ) )
	end
end

--[[ Kills ]]

hook.Add( "PlayerDeath", "CS16.KillXP", function( victim, inflictor, attacker )
	if not IsValid( attacker ) or not attacker:IsPlayer() then return end
	if attacker == victim then return end
	if not CS16.IsPlayingTeam( attacker:Team() ) then return end

	--[[
		A team kill is worth nothing at all, and is not a kill.

		Without this the fastest progression in the game is knifing your own
		bots in spawn: they are friendly, they do not shoot back, and there are
		five of them. That is strictly easier than the bot farming the rate
		below exists to discourage.
	]]
	if attacker:Team() == victim:Team()
		and not CS16.ModeSetting( "FreeForAll", false )
	then
		return
	end

	attacker.CS16Kills = ( attacker.CS16Kills or 0 ) + 1
	attacker.CS16Dirty = true

	local xp = CS16.KillXP( CS16.LevelFromXP( attacker.CS16XP or 0 ) )

	-- Half for a bot. The kill still counts in full on the career total - it
	-- happened - only the experience is discounted.
	if victim:IsBot() then xp = xp * CS16.Config.XP.BotKillScale end

	CS16.AwardXP( attacker, xp )
end )

--[[ Rounds, matches and objectives ]]

hook.Add( "CS16RoundEnded", "CS16.RoundXP", function( winner )
	local cfg = CS16.Config.XP

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then
			CS16.AwardXP( ply, ply:Team() == winner and cfg.RoundWin or cfg.RoundLoss )
		end
	end

	-- The natural moment to write: it happens on a clock everybody is already
	-- waiting through, and it bounds how much a crash can cost to one round.
	CS16.SaveAllProgress()
end )

hook.Add( "CS16MatchEnded", "CS16.MatchXP", function( winner )
	local cfg = CS16.Config.XP

	for _, ply in ipairs( player.GetAll() ) do
		if CS16.IsPlayingTeam( ply:Team() ) then
			CS16.AwardXP( ply, ply:Team() == winner and cfg.MatchWin or cfg.MatchLoss )
		end
	end

	-- A match ends by reloading the map, so this is the last chance to write.
	CS16.SaveAllProgress()
end )

local function Objective( ply )
	CS16.AwardXP( ply, CS16.Config.XP.Objective )
end

hook.Add( "CS16BombPlanted",     "CS16.PlantXP",   function( bomb, planter ) Objective( planter ) end )
hook.Add( "CS16BombDefused",     "CS16.DefuseXP",  function( bomb, ply )     Objective( ply )     end )
hook.Add( "CS16HostageRescued",  "CS16.RescueXP",  function( ent, by )       Objective( by )      end )

--[[ Reporting ]]

-- What another mode has on file for somebody, without disturbing the copy the
-- one they're playing is using.
local function StoredXP( ply, mode )
	local row = sql.QueryRow( ("SELECT xp FROM %s WHERE id = %s AND mode = %s"):format(
		TABLE, sql.SQLStr( CS16.ProgressID( ply ) ), sql.SQLStr( mode ) ) )

	return row and tonumber( row.xp ) or 0
end

--[[
	Told to you and nobody else.

	Whether you are grinding, and how badly, is not something the server should
	announce on your behalf.
]]
CS16.AddCommand( "xp", {
	description = "Show your level, experience, and how far the next level is.",
	callback = function( ply )
		local xp    = ply.CS16XP or 0
		local level = CS16.LevelFromXP( xp )
		local into, span, left = CS16.LevelProgress( xp )

		ply:ChatPrint( ("[CS 1.6] %s - level %d, %s xp total, %s career kills.")
			:format( CS16.Mode().label, level, CS16.FormatXP( xp ), CS16.FormatXP( ply.CS16Kills or 0 ) ) )

		if level >= CS16.MaxLevel then
			ply:ChatPrint( ("Maximum level. %s xp toward the %s cap.")
				:format( CS16.FormatXP( xp ), CS16.FormatXP( CS16.Config.XP.Cap ) ) )
		else
			ply:ChatPrint( ("%s xp into this level of %s - %s to go until level %d.")
				:format( CS16.FormatXP( into ), CS16.FormatXP( span ), CS16.FormatXP( left ), level + 1 ) )
		end

		--[[
			Then a line apiece for the modes you are not currently playing.
			Progression is separate per mode, so leaving them out would make it
			look as though switching had cost you everything.
		]]
		for id, mode in pairs( CS16.Modes ) do
			if id ~= CS16.ModeID() then
				local other = StoredXP( ply, id )

				ply:ChatPrint( ("%s - level %d, %s xp.")
					:format( mode.label, CS16.LevelFromXP( other ), CS16.FormatXP( other ) ) )
			end
		end
	end,
} )

--[[ Wiping it ]]

--[[
	Reset every level, every kill count and both leaderboards.

	Server console only, and not a chat command: there is no rank this should be
	available at, because there is no undo. A developer with a slip of the finger
	should not be able to erase everybody's progress from inside the game, so the
	gate is being sat at the machine rather than being trusted.

	`confirm` is required for the same reason. The word costs a second to type
	and is the difference between clearing the board deliberately and clearing it
	because the console remembered the last thing you ran.
]]
concommand.Add( "cs16_truncate", function( ply, _, args )
	if IsValid( ply ) then
		ply:ChatPrint( "cs16_truncate can only be run from the server console." )
		return
	end

	local rows  = sql.Query( ("SELECT COUNT(*) AS n FROM %s"):format( TABLE ) )
	local count = rows and rows[ 1 ] and tonumber( rows[ 1 ].n ) or 0

	if count == 0 then
		MsgN( "[CS 1.6] Progression is already empty." )
		return
	end

	if ( args[ 1 ] or "" ):lower() ~= "confirm" then
		MsgN( ("[CS 1.6] This would erase %d progression row(s) - every level, every"):format( count ) )
		MsgN(  "         career kill, and both leaderboards. There is no undo." )
		MsgN(  "         Run  cs16_truncate confirm  to go ahead." )
		return
	end

	CS16.TruncateProgression( count )
end )

function CS16.TruncateProgression( count )
	if sql.Query( ("DELETE FROM %s"):format( TABLE ) ) == false then
		MsgN( "[CS 1.6] Could not clear progression: " .. tostring( sql.LastError() ) )
		return
	end

	--[[
		The table is only half of it.

		Everyone connected is still holding their old totals in memory, and the
		end of the very next round writes all of them straight back - so clearing
		the table alone looks like it worked and then quietly undoes itself a
		minute later. Bots make this certain rather than likely: there are always
		ten of them and they are always mid-round.

		Cleared rather than marked dirty, so nothing is written back at all.
	]]
	for _, target in ipairs( player.GetAll() ) do
		target.CS16XP    = 0
		target.CS16Kills = 0
		target.CS16Dirty = false

		CS16.PublishLevel( target )
	end

	MsgN( ("[CS 1.6] Progression cleared - %d row(s) erased. Everyone is level 1.")
		:format( count or 0 ) )

	for _, target in ipairs( player.GetAll() ) do
		if not target:IsBot() then
			target:ChatPrint( "[CS 1.6] Progression has been reset by the server." )
		end
	end
end

--[[ Lifecycle ]]

local function SendBoard( rows )
	net.WriteUInt( #rows, 8 )

	for _, row in ipairs( rows ) do
		net.WriteString( row.nick )
		net.WriteUInt( row.level, 7 )
		net.WriteUInt( row.xp, 32 )
		net.WriteUInt( row.kills, 32 )
		net.WriteUInt( row.wins, 16 )
	end
end

hook.Add( "PlayerInitialSpawn", "CS16.LoadProgress", function( ply )
	CS16.LoadProgress( ply )

	if ply:IsBot() then return end

	--[[
		The message of the day, which is really the two leaderboards.

		Sent a little ahead of the team menu, which sv_player puts on a one
		second timer for the same reason - a client is not ready for net
		messages on the tick it connects. Arriving first is what lets the client
		hold the team menu back until the board has been dismissed; if this
		never arrives, the team menu simply opens as it always did.

		Once per connection, which on this gamemode is once per match: a match
		ends by reloading the map.
	]]
	timer.Simple( 0.8, function()
		if not IsValid( ply ) then return end

		net.Start( "CS16.MOTD" )
			net.WriteString( GetHostName() )

			-- Whether the board should lead with wins rather than level. The
			-- client cannot work this out: it is a property of the mode.
			net.WriteBool( CS16.ModeSetting( "FreeForAll", false ) )

			SendBoard( CS16.Leaderboard( false, 10 ) )
			SendBoard( CS16.Leaderboard( true, 10 ) )
		net.Send( ply )
	end )
end )

hook.Add( "PlayerDisconnected", "CS16.SaveProgress", function( ply )
	CS16.SaveProgress( ply )
end )

--[[
	Bots are disconnected wholesale on a map change, and autofill removes them
	whenever a human takes their place, so their progression would otherwise be
	lost on exactly the events that happen most often.
]]
hook.Add( "ShutDown", "CS16.SaveProgress", function()
	CS16.SaveAllProgress()
end )

--[[
	Add the wins column to a table that predates it.

	Battle royale needed somewhere to record who survived, and every other mode
	gets the column for free. Servers running before this existed already have a
	table without it, and CREATE TABLE only runs when there is no table at all -
	so the column is added separately and the failure ignored, because "duplicate
	column name" is exactly what success looks like the second time.
]]
local function EnsureWinsColumn()
	local row = sql.QueryRow( ("SELECT * FROM %s LIMIT 1"):format( TABLE ) )

	-- No rows tells us nothing about the columns, so ask outright either way.
	if row and row.wins ~= nil then return end

	sql.Query( ("ALTER TABLE %s ADD COLUMN wins INTEGER NOT NULL DEFAULT 0"):format( TABLE ) )
end

EnsureTable()
EnsureWinsColumn()

-- After the table exists, and before anybody can be loaded from it.
MigrateLegacyIDs()
