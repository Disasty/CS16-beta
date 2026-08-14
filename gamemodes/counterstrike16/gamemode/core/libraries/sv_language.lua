--[[
	The two commands that make a translation workable.

	/language  lets anybody read the gamemode in a language their game client
	           is not set to.
	/langcheck is the safety net for whoever is writing a translation: it
	           reports what is missing, what has drifted, and - the one that
	           actually bites - any placeholder dropped or misspelled on the
	           way through, which would otherwise reach a player as a literal
	           {player} in the middle of a sentence.
]]

--[[
	The server cannot set a convar on a client, but it can ask the client to
	set it, which is what Player:ConCommand does. cs16_language is userinfo, so
	the new value comes back to the server by itself and the next message sent
	is already in the new language.
]]
CS16.AddCommand( "language", {
	description = "Read the gamemode in a chosen language, or show the current one.",

	callback = function( ply, args )
		local wanted = CS16.NormalizeLanguage( args and args[ 1 ] )

		if not wanted then
			local code = CS16.PlayerLanguage( ply )
			local lang = CS16.LanguageInfo( code )

			CS16.Msg( ply, "lang.current", {
				name = lang and lang.name or code,
				code = code,
			} )
			return
		end

		-- "auto", or anything that isn't a language, clears the override.
		if wanted == "auto" or wanted == "default" then
			ply:ConCommand( "cs16_language \"\"" )

			local code = CS16.NormalizeLanguage( ply:GetInfo( "gmod_language" ) )
				or CS16.DefaultLanguage
			local lang = CS16.LanguageInfo( code )

			CS16.Msg( ply, "lang.follow", { name = lang and lang.name or code } )
			return
		end

		local info = CS16.LanguageInfo( wanted )

		if not info then
			local list = {}
			for code in pairs( CS16.Languages ) do list[ #list + 1 ] = code end
			table.sort( list )

			CS16.Msg( ply, "lang.unknown", {
				code = wanted,
				list = table.concat( list, ", " ),
			} )
			return
		end

		ply:ConCommand( ("cs16_language %q"):format( wanted ) )
		CS16.Msg( ply, "lang.set", { name = info.name } )
	end,
} )

--[[
	Pull every {placeholder} out of a string, as a set.

	Comparing these between English and a translation catches the class of
	mistake that a human proof-reader reliably misses: the sentence reads
	perfectly, and one value never gets filled in.
]]
local function placeholders( str )
	local found = {}

	if isstring( str ) then
		for name in str:gmatch( "{(%w+)}" ) do found[ name ] = true end
	elseif istable( str ) then
		for _, form in pairs( str ) do
			for name in tostring( form ):gmatch( "{(%w+)}" ) do found[ name ] = true end
		end
	end

	return found
end

local function flatten( entry )
	if istable( entry ) then
		local parts = {}
		for _, form in pairs( entry ) do parts[ #parts + 1 ] = tostring( form ) end
		table.sort( parts )
		return table.concat( parts, "\1" )
	end

	return tostring( entry )
end

CS16.AddCommand( "langcheck", {
	description = "Check a translation against English for missing keys and placeholders.",

	callback = function( ply, args )
		local code = CS16.NormalizeLanguage( args and args[ 1 ] )
			or CS16.PlayerLanguage( ply )

		local target, resolved = CS16.LanguageInfo( code )
		if resolved then code = resolved end

		if not target then
			ply:ChatPrint( CS16.ChatPrefix .. ("No language called '%s'."):format( code ) )
			return
		end

		if code == CS16.DefaultLanguage then
			ply:ChatPrint( CS16.ChatPrefix
				.. "That is the reference language. Check a translation against it instead." )
			return
		end

		local english = CS16.Languages[ CS16.DefaultLanguage ].strings
		local missing, extra, broken, untranslated, total = {}, {}, {}, 0, 0

		for key, value in pairs( english ) do
			total = total + 1
			local mine = target.strings[ key ]

			if mine == nil or mine == "" then
				missing[ #missing + 1 ] = key
			else
				if flatten( mine ) == flatten( value ) then
					untranslated = untranslated + 1
				end

				local want, got = placeholders( value ), placeholders( mine )

				for name in pairs( want ) do
					if not got[ name ] then
						broken[ #broken + 1 ] = ("%s is missing {%s}"):format( key, name )
					end
				end

				for name in pairs( got ) do
					if not want[ name ] then
						broken[ #broken + 1 ] = ("%s has an unknown {%s}"):format( key, name )
					end
				end
			end
		end

		for key in pairs( target.strings ) do
			if english[ key ] == nil then extra[ #extra + 1 ] = key end
		end

		table.sort( missing )
		table.sort( extra )
		table.sort( broken )

		local done = total - untranslated - #missing

		ply:ChatPrint( CS16.ChatPrefix .. ("%s (%s): %d of %d translated.")
			:format( target.name, code, done, total ) )

		--[[
			Placeholder faults first, and always all of them. They are the only
			thing in this report that reaches a player as visible nonsense, so
			they are never the ones truncated away.
		]]
		if #broken > 0 then
			ply:ChatPrint( ("  %d placeholder problem(s) - these will show in game:"):format( #broken ) )
			for _, line in ipairs( broken ) do ply:ChatPrint( "    " .. line ) end
		end

		if #extra > 0 then
			ply:ChatPrint( ("  %d key(s) not in English, probably a typo or renamed:"):format( #extra ) )
			for i = 1, math.min( #extra, 10 ) do ply:ChatPrint( "    " .. extra[ i ] ) end
		end

		if #missing > 0 then
			ply:ChatPrint( ("  %d key(s) absent, showing English:"):format( #missing ) )
			for i = 1, math.min( #missing, 10 ) do ply:ChatPrint( "    " .. missing[ i ] ) end
			if #missing > 10 then ply:ChatPrint( ("    ... and %d more"):format( #missing - 10 ) ) end
		end

		if untranslated > 0 then
			ply:ChatPrint( ("  %d line(s) still reading as English."):format( untranslated ) )
		end

		if #broken == 0 and #extra == 0 and #missing == 0 and untranslated == 0 then
			ply:ChatPrint( "  Complete, with no problems." )
		end
	end,
} )
