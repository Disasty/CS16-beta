--[[
	Chat command router. Commands are declared once and picked up by both
	realms so the client can list what it is allowed to run, while the server
	stays the only place a callback actually fires.

	Both / and ! are accepted as prefixes.
]]

CS16.Commands = CS16.Commands or {}

CS16.CommandPrefixes = { "/", "!" }

--[[
	name       - the word typed after the prefix
	permission - required permission, or nil for everyone
	description/args - shown by /help
	callback   - function( ply, args, rawText ), server only
]]
function CS16.AddCommand( name, data )
	data.name = string.lower( name )
	CS16.Commands[ data.name ] = data
end

function CS16.GetCommand( name )
	return CS16.Commands[ string.lower( name or "" ) ]
end

function CS16.CanRunCommand( ply, cmd )
	if not cmd then return false end
	if not cmd.permission then return true end

	return CS16.HasPermission( ply, cmd.permission )
end

-- Splits a chat line into { command, args } or nil if it isn't a command.
function CS16.ParseCommand( text )
	text = string.Trim( text or "" )
	if text == "" then return nil end

	local prefix = string.sub( text, 1, 1 )
	if not table.HasValue( CS16.CommandPrefixes, prefix ) then return nil end

	local body = string.sub( text, 2 )
	if body == "" then return nil end

	local parts = string.Explode( " ", body )
	local name  = string.lower( table.remove( parts, 1 ) )

	-- Drop the empties that double spaces leave behind.
	local args = {}
	for _, part in ipairs( parts ) do
		if part ~= "" then args[ #args + 1 ] = part end
	end

	return name, args
end
