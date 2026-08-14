--[[
	Language support.

	Every piece of text a player reads is looked up by key rather than written
	inline, so a translator only ever edits core/languages/<code>.lua and never
	touches game logic.

	Two facts drive the design of this file, both verified on a live server
	rather than assumed:

	  1. The server can read any player's language with
	     ply:GetInfo( "gmod_language" ). That means translation happens where
	     the message is built, and nothing new goes over the wire. A broadcast
	     reaches ten players in whatever ten languages they run.
	  2. string.upper is byte-wise and has no UTF-8 awareness, so it turns
	     "começará" into "COMEçARá". CS16.Upper exists because of this, and
	     everything that shouts at the player goes through it.

	The three entry points:

	  CS16.Msg( target, key, vars )   server, chat, per-recipient language
	  CS16.L( key, vars )             client, anything drawn
	  CS16.Translate( lang, key, vars )  the core, when you have a code in hand
]]

CS16.ChatPrefix = "[CS 1.6] "

-- code -> { name = "Português (Brasil)", strings = { ... } }
CS16.Languages = CS16.Languages or {}

CS16.DefaultLanguage = "en"

--[[
	Codes arrive from a few places and agree on nothing: gmod_language reports
	"pt-br", a file might be named pt_BR, and somebody typing into a convar
	will use whatever they feel like. One spelling wins.
]]
function CS16.NormalizeLanguage( code )
	if not isstring( code ) or code == "" then return nil end
	return code:lower():gsub( "_", "-" ):Trim()
end

--[[
	Called from core/languages/<code>.lua. Registering the same code twice
	merges, so a server owner can add or correct strings from an addon without
	editing the shipped file.
]]
function CS16.RegisterLanguage( code, name, strings )
	code = CS16.NormalizeLanguage( code )
	if not code then return end

	local lang = CS16.Languages[ code ]

	if not lang then
		lang = { name = name or code, strings = {} }
		CS16.Languages[ code ] = lang
	elseif name then
		lang.name = name
	end

	for key, value in pairs( strings or {} ) do
		lang.strings[ key ] = value
	end
end

--[[
	"pt-br" is tried, then "pt", then English. The middle step matters: it lets
	a European Portuguese translation stand in for Brazilian rather than
	dropping the player all the way back to English, and it costs nothing when
	only one of the two exists.
]]
local function chain( code )
	local order, seen = {}, {}

	local function add( c )
		if c and c ~= "" and not seen[ c ] then
			seen[ c ] = true
			order[ #order + 1 ] = c
		end
	end

	add( code )
	if code then add( code:match( "^(%a+)%-" ) ) end
	add( CS16.DefaultLanguage )

	return order
end

--[[
	A value is either a string, or a table of plural forms.

	Portuguese, Spanish and Dutch all split one/other exactly where English
	does, so that is the whole of it. Anything more elaborate is a problem for
	whichever language actually needs it.
]]
local function plural( entry, vars )
	if not istable( entry ) then return entry end

	local n = tonumber( vars and vars.count )
	if n == 1 then return entry.one or entry.other end

	return entry.other or entry.one
end

--[[
	Named placeholders, not string.format.

	Lua has no positional specifiers, so "%s killed %s" cannot be reordered by
	a translator whose language puts the object first. Worse, a translator who
	writes %d where the code passes a string crashes the server. {player}
	survives both, and reads as what it is.

	An unknown placeholder is left visible rather than blanked, so a typo shows
	up as {palyer} in chat instead of silently vanishing.
]]
local function interpolate( str, vars )
	if not vars or not str:find( "{", 1, true ) then return str end

	local out = str:gsub( "{(%w+)}", function( name )
		local value = vars[ name ]
		if value == nil then return "{" .. name .. "}" end

		return tostring( value )
	end )

	return out
end

--[[
	The core lookup. Falls through the chain, and returns the key itself if no
	language has it at all - a missing string should be obvious in testing, not
	an empty gap on the HUD.

	An empty translation counts as missing, which is what makes a
	partly-finished language file safe to ship: untranslated lines fall back to
	English instead of drawing nothing.
]]
function CS16.Translate( code, key, vars )
	if not isstring( key ) then return "" end

	for _, try in ipairs( chain( CS16.NormalizeLanguage( code ) ) ) do
		local lang = CS16.Languages[ try ]
		local entry = lang and lang.strings[ key ]
		local str = plural( entry, vars )

		if isstring( str ) and str ~= "" then
			return interpolate( str, vars )
		end
	end

	return key
end

--[[
	Which registered language actually answers for this code, if any.

	A regional code is served by its base file: pt-br and pt-pt are both
	answered by pt.lua, and only one Portuguese file has to exist. Asking
	whether CS16.Languages["pt-br"] exists is the wrong question, and asking it
	is what made /language pt-br silently do nothing.

	Returns nil when nothing but English would answer, which is what callers
	need in order to reject a code the player typed wrong.
]]
function CS16.LanguageInfo( code )
	code = CS16.NormalizeLanguage( code )
	if not code then return nil end

	if CS16.Languages[ code ] then return CS16.Languages[ code ], code end

	local base = code:match( "^(%a+)%-" )
	if base and CS16.Languages[ base ] then return CS16.Languages[ base ], base end

	return nil
end

--[[
	What language is this player reading?

	cs16_language wins if set, for the case of an English game client whose
	owner wants Portuguese text. It is a userinfo convar so the server can read
	it the same way it reads gmod_language.
]]
function CS16.PlayerLanguage( ply )
	if CLIENT and not IsValid( ply ) then ply = LocalPlayer() end
	if not IsValid( ply ) then return CS16.DefaultLanguage end

	local override = CS16.NormalizeLanguage( ply:GetInfo( "cs16_language" ) )
	if override and CS16.LanguageInfo( override ) then return override end

	return CS16.NormalizeLanguage( ply:GetInfo( "gmod_language" ) )
		or CS16.DefaultLanguage
end

--[[
	Client-side lookup, for everything drawn. Reads the local player's own
	language, so switching takes effect on the next frame with no server round
	trip.
]]
function CS16.L( key, vars )
	return CS16.Translate( CS16.PlayerLanguage(), key, vars )
end

--[[
	UTF-8 aware uppercase.

	Only the C3 block is handled - à through þ, which covers Portuguese,
	Spanish, Dutch, French, German and Italian. In UTF-8 those are two bytes,
	0xC3 followed by 0xA0..0xBE, and the capital is the same pair with 0x20
	taken off the second byte. 0xB7 is ÷ and 0xBF is ÿ, neither of which
	follows the rule, so both are skipped.

	Anything outside that block passes through untouched. A language that needs
	more (Polish, Czech, Turkish) can extend this when it arrives.
]]
function CS16.Upper( str )
	if not isstring( str ) then return "" end

	local out, i, n = {}, 1, #str

	while i <= n do
		local b = str:byte( i )

		if b == 0xC3 and i < n then
			local c = str:byte( i + 1 )

			if c >= 0xA0 and c <= 0xBE and c ~= 0xB7 then
				out[ #out + 1 ] = string.char( 0xC3, c - 0x20 )
			else
				out[ #out + 1 ] = str:sub( i, i + 1 )
			end

			i = i + 2
		elseif b < 0x80 then
			out[ #out + 1 ] = string.char( b ):upper()
			i = i + 1
		else
			-- Some other multi-byte sequence. Copy it whole and leave it be.
			local len = b >= 0xF0 and 4 or b >= 0xE0 and 3 or b >= 0xC0 and 2 or 1
			out[ #out + 1 ] = str:sub( i, i + len - 1 )
			i = i + len
		end
	end

	return table.concat( out )
end

if CLIENT then
	--[[
		Userinfo so the server can read it, archived so it survives a restart.
		Empty means "follow gmod_language", which is what almost everybody
		wants and nobody has to configure.
	]]
	CreateClientConVar( "cs16_language", "", true, true,
		"Language for Counter-Strike 1.6 text. Empty follows gmod_language." )
end

if SERVER then
	--[[
		Chat, in the recipient's own language.

		target is one player, a table of them, or nil for everybody. The loop
		lives here rather than at the call site, which is what makes a
		broadcast reach ten players in ten languages without any caller having
		to think about it - and incidentally replaces the fifty-odd
		hand-written player.GetAll() loops that used to do this in English.

		The [CS 1.6] prefix is added here rather than sitting in the strings.
		Translators never see it, so it cannot be translated by accident or
		dropped by mistake, and every message is prefixed the same way.
	]]
	function CS16.Msg( target, key, vars )
		local targets

		if target == nil then
			targets = player.GetAll()
		elseif istable( target ) then
			targets = target
		else
			targets = { target }
		end

		for _, ply in ipairs( targets ) do
			if IsValid( ply ) and ply:IsPlayer() then
				ply:ChatPrint( CS16.ChatPrefix
					.. CS16.Translate( CS16.PlayerLanguage( ply ), key, vars ) )
			end
		end
	end
end
