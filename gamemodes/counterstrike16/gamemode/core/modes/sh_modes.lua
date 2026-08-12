--[[
	Game modes.

	A mode owns what makes a game a game: what follows what, how you win, when
	you respawn, whether there's a bomb. The framework underneath - spawning,
	teams, movement, menus, the HUD - is the same whichever is running.

	Two rules keep this safe.

	**Every mode registers, only one loads.** Each mode has a single shared
	registration file, named in shared.lua like everything else: a label, a
	handful of settings, and the list of server files that make it work.
	Registering costs nothing and has no side effects, so every mode registers
	on both realms and `/gamemode` can list and validate them. Only the active
	mode's server files - the hooks, timers and state, the things that would
	fight each other - are actually included.

	Anything the client needs from a mode therefore goes in that registration
	file, which is why it's shared rather than server-side.

	**Switching means a map change.** Hooks, timers and globals are all
	process-wide, and a mode's state is spread across globals, networked player
	variables and live entities. Unloading all that correctly at runtime is the
	kind of thing that appears to work and then fails three rounds later, as
	something that doesn't look like a mode switch at all. A changelevel is a
	guaranteed clean slate and costs seconds.

	Modules ask what the mode *is* rather than which mode it is:

		if not CS16.ModeSetting( "Buying" ) then ... end

	rather than comparing against "competitive". That's what stops a new mode
	meaning edits scattered through the buy menu, the bots and the HUD.
]]

CS16.Modes = CS16.Modes or {}

local DEFAULT_MODE = "competitive"
local MODE_FILE    = "cs16/mode.txt"

--[[
	The server's copy of the answer.

	A convar rather than anything cleverer because it has to be readable during
	include, before a single entity or player exists - init.lua asks which mode
	is active to decide what to load.
]]
if SERVER then
	CreateConVar( "cs16_mode", DEFAULT_MODE,
		{ FCVAR_ARCHIVE, FCVAR_NOTIFY },
		"The active CS 1.6 game mode. Set it with /gamemode, which reloads the map." )
end

--[[
	And the client's copy, on a global string.

	This was a replicated convar, which does not work: a replicated convar has
	to be declared on both realms, and ours was created inside an `if SERVER`.
	The client never had it, GetConVar returned nil, and ModeID quietly fell
	back to the default - so a client in gungame believed it was in competitive.
	It drew no gungame HUD and offered a buy prompt for a mode with no buying,
	for as long as gungame has existed.

	A global string is what the rest of the gamemode uses to tell the client
	things, it needs no matching declaration, and it is demonstrably reliable
	here. Published on load and again on InitPostEntity, since anyone
	connecting later reads whatever it says then.
]]
if SERVER then
	function CS16.PublishMode()
		SetGlobalString( "CS16.Mode", CS16.ModeID() )
	end

	hook.Add( "InitPostEntity", "CS16.PublishMode", function()
		CS16.PublishMode()
	end )
end

function CS16.RegisterMode( id, def )
	def.id      = id
	def.label   = def.label or id
	def.server  = def.server or {}
	def.client  = def.client or {}
	def.aliases = def.aliases or {}

	CS16.Modes[ id ] = def
end

--[[
	Turn whatever somebody typed into a mode id.

	Full names are unambiguous but nobody wants to type "teamdeathmatch" into
	chat, so each mode carries its own short forms and declares them beside
	everything else about itself. Keeping them on the mode rather than in a table
	here means adding a mode is still a single file.

	Returns nil for anything unrecognised, which the caller reports - guessing at
	a near match would eventually switch the map to the wrong game.
]]
function CS16.ResolveMode( input )
	input = string.lower( string.Trim( input or "" ) )
	if input == "" then return nil end

	-- An exact id always wins, so an alias can never shadow a real mode name.
	if CS16.Modes[ input ] then return input end

	for id, mode in pairs( CS16.Modes ) do
		for _, alias in ipairs( mode.aliases ) do
			if string.lower( alias ) == input then return id end
		end
	end

	-- Explicitly, rather than falling off the end returning nothing at all -
	-- which reads the same in an assignment and quite differently to anything
	-- that expects to be handed one argument.
	return nil
end

--[[
	Is this the mode being played?

	For client files, which are loaded for every mode rather than only the
	active one. Drawing has no state to conflict with - two modes' HUDs can sit
	in memory harmlessly - and guarding a hook with this is far simpler than
	getting conditional client includes right across a map change, where the
	replicated convar may not have arrived by the time Lua runs.

	Server files are a different matter, and stay conditional: hooks and timers
	really would fight.
]]
function CS16.IsMode( id )
	return CS16.ModeID() == id
end

--[[
	Which mode is running, asked of whichever source that realm has.

	Both fall back rather than failing: an unrecognised name must not leave
	either end with no rules at all.
]]
function CS16.ModeID()
	local id

	if SERVER then
		local convar = GetConVar( "cs16_mode" )
		id = convar and convar:GetString()
	else
		id = GetGlobalString( "CS16.Mode", "" )
	end

	return CS16.Modes[ id ] and id or DEFAULT_MODE
end

function CS16.Mode()
	return CS16.Modes[ CS16.ModeID() ]
end

--[[
	A setting off the active mode, or the given fallback.

	The fallback matters as much as the setting: a mode that says nothing about
	buying shouldn't crash the buy menu, it should get a sensible default.
]]
function CS16.ModeSetting( key, fallback )
	local mode = CS16.Mode()
	if not mode then return fallback end

	local value = mode[ key ]
	if value == nil then return fallback end

	return value
end

--[[
	Policy the framework asks the mode about.

	Both have defaults that describe the most permissive mode imaginable, so a
	mode only has to speak up where it wants to restrict something. Competitive
	restricts both; a deathmatch would leave them alone.
]]

--[[
	May this player have a body right now?

	The default is "anyone who belongs in the world" - the two sides and the
	developer team, but not spectators, who would otherwise be handed a body by
	a mode that simply didn't mention it. Competitive narrows it further to the
	top of a round; a mode with respawns wants exactly the default.
]]
function CS16.CanTakeBody( ply )
	local fn = CS16.ModeSetting( "CanTakeBody" )
	if fn then return fn( ply ) end

	return CS16.HasBody( ply:Team() )
end

-- Is buying allowed at this moment? Nothing to do with *what* you may buy.
function CS16.InBuyTime()
	local fn = CS16.ModeSetting( "InBuyTime" )
	if fn then return fn() end

	return true
end

--[[ Choosing one ]]

if SERVER then
	--[[
		The choice outlives the map change that applies it, so it's on disk
		rather than only in the convar - a convar set before a changelevel is
		not something to trust a match to.
	]]
	function CS16.SaveMode( id )
		file.CreateDir( "cs16" )
		file.Write( MODE_FILE, id )
	end

	function CS16.LoadSavedMode()
		local saved = file.Read( MODE_FILE, "DATA" )
		saved = saved and string.Trim( saved ) or nil

		if not saved or not CS16.Modes[ saved ] then return DEFAULT_MODE end

		--[[
			Written straight onto the ConVar rather than through
			RunConsoleCommand, which queues the command for the next frame.
			init.lua reads the mode back on the very next line to decide what to
			include, so a deferred write would load the mode we were on before
			the switch - and it would work perfectly on the second map change,
			which is a miserable thing to debug.
		]]
		local convar = GetConVar( "cs16_mode" )
		if convar then convar:SetString( saved ) end

		-- Tell the client too, in case anything reads it before InitPostEntity.
		CS16.PublishMode()

		return saved
	end
end

-- The server files the active mode is made of. init.lua includes these and
-- nothing else conditional; every other mode's stay on disk.
function CS16.ModeServerFiles()
	local mode = CS16.Mode()
	return mode and mode.server or {}
end

-- Every mode's client files, because they only draw. See CS16.IsMode.
function CS16.ModeClientFiles()
	local files = {}

	for _, mode in SortedPairs( CS16.Modes ) do
		for _, path in ipairs( mode.client ) do files[ #files + 1 ] = path end
	end

	return files
end
