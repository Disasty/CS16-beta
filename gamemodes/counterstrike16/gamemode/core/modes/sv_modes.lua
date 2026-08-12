--[[
	Choosing a game mode.

	Separate from sh_modes because commands need CS16.AddCommand, and the
	registry has to load well before that - the mode is settled before any
	module reads a setting off it.
]]

local SWITCH_DELAY = 5

CS16.AddCommand( "gamemode", {
	permission  = "mode",
	args        = "[name]",
	description = "Show or change the game mode. Changing it reloads the map.",

	callback = function( ply, args )
		local typed = args[ 1 ] or ""

		--[[
			No argument lists what's available. Worth having rather than making
			people guess at names, and it's the only place the registry is
			visible from in game.

			The short forms are listed with each mode, because a shortcut nobody
			can discover may as well not exist.
		]]
		if string.Trim( typed ) == "" then
			ply:ChatPrint( ("[CS 1.6] Playing %s. Available modes:"):format( CS16.Mode().label ) )

			for id, mode in SortedPairs( CS16.Modes ) do
				local short = #mode.aliases > 0
					and ( " (" .. table.concat( mode.aliases, ", " ) .. ")" ) or ""

				ply:ChatPrint( ("  %s%s%s - %s"):format(
					id,
					short,
					id == CS16.ModeID() and "  [current]" or "",
					mode.description or mode.label ) )
			end

			return
		end

		-- Accepts a full name or any of the mode's own short forms.
		local wanted = CS16.ResolveMode( typed )

		if not wanted then
			ply:ChatPrint( ("No such game mode: %s. Run /gamemode to list them."):format( typed ) )
			return
		end

		if wanted == CS16.ModeID() then
			ply:ChatPrint( ("Already playing %s."):format( CS16.Modes[ wanted ].label ) )
			return
		end

		--[[
			Written to disk before the map change rather than only set on the
			convar. The convar doesn't survive the changelevel reliably, and the
			file is what init.lua reads on the way back up.
		]]
		CS16.SaveMode( wanted )

		local label = CS16.Modes[ wanted ].label

		for _, other in ipairs( player.GetAll() ) do
			other:ChatPrint( ("[CS 1.6] %s switched the game mode to %s."):format(
				ply:Nick(), label ) )
			other:ChatPrint( ("[CS 1.6] The map reloads in %d seconds."):format( SWITCH_DELAY ) )
		end

		--[[
			A map change rather than swapping files at runtime. Hooks, timers
			and globals are all process-wide and a mode's state is spread
			across globals, networked player variables and live entities;
			unloading that correctly is the kind of thing that appears to work
			and then fails three rounds later. See core/modes/sh_modes.lua.
		]]
		timer.Simple( SWITCH_DELAY, function()
			game.ConsoleCommand( ("changelevel %s\n"):format( game.GetMap() ) )
		end )
	end,
} )
