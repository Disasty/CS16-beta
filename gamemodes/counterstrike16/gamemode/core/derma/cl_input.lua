--[[
	Menu key handling.

	PlayerButtonDown stops firing once a VGUI popup takes focus, which is what
	made the buy menu so hard to close: the engine still ran B's +zoom bind so
	the screen zoomed, but the Lua hook never saw the press. Reading raw key
	state in Think sidesteps focus entirely, so a key behaves the same whether
	a panel is open or not.

	Edge-detected, so holding a key fires once rather than every frame.
]]

CS16.ChatOpen = false

hook.Add( "StartChat",  "CS16.TrackChat", function() CS16.ChatOpen = true  end )
hook.Add( "FinishChat", "CS16.TrackChat", function() CS16.ChatOpen = false end )

local watched = {}

--[[
	callback runs once per press. release, if given, runs once when the key goes
	back up - which is what lets a menu be held open rather than toggled.
]]
function CS16.WatchKey( name, key, callback, release )
	watched[ name ] = { key = key, callback = callback, release = release, down = false }
end

-- Places where a keystroke belongs to something else entirely.
local function InputBlocked()
	return CS16.ChatOpen
		or gui.IsGameUIVisible()
		or gui.IsConsoleVisible()
end

hook.Add( "Think", "CS16.WatchKeys", function()
	local blocked = InputBlocked()

	for _, watch in pairs( watched ) do
		local down = input.IsKeyDown( watch.key )

		if down and not watch.down and not blocked then
			watch.callback()

		--[[
			Release deliberately ignores `blocked`. A held-open menu has to
			close when the key comes up whatever else is happening, or it can
			be left on screen with no key still down to close it.
		]]
		elseif not down and watch.down and watch.release then
			watch.release()
		end

		-- Tracked even while blocked, so releasing a key during chat doesn't
		-- fire the moment chat closes.
		watch.down = down
	end
end )

--[[
	The suit zoom is a Half-Life 2 leftover with no business in a CS gamemode,
	and B is bound to it out of the box - which is what was fighting the buy
	menu. Blocking the bind kills the zoom without needing anyone to rebind.
]]
hook.Add( "PlayerBindPress", "CS16.BlockSuitZoom", function( ply, bind, pressed )
	if string.find( bind, "+zoom", 1, true ) then return true end
end )
