--[[
	Server entry point.

	Everything lives under core/, in one of four places:

	  libraries/  the framework the gamemode is built on - config, teams,
	              commands, the player lifecycle, movement, spectating, and the
	              round-state vocabulary every mode speaks. Always loaded, and
	              nothing here knows what game is being played.
	  modules/    a feature apiece: weapons, bots, admin, kills, economy, map
	              zones. Available to any mode.
	  modes/      what makes a game a game: what follows what, how you win,
	              whether there's a bomb. Every mode registers; only the active
	              one's server files load. See core/modes/sh_modes.lua.
	  derma/      everything drawn.

	Load order is deliberate and worth preserving: shared first (it defines the
	CS16 table, every sh_ module and the mode registry), then libraries in
	dependency order, then modules, then the mode itself - which is last
	because it drives everything the rest of them provide.
]]

AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

-- Shared, in the same order shared.lua includes them.
AddCSLuaFile( "core/libraries/sh_config.lua" )
AddCSLuaFile( "core/libraries/sh_language.lua" )
AddCSLuaFile( "core/languages/en.lua" )
AddCSLuaFile( "core/languages/pt.lua" )
AddCSLuaFile( "core/libraries/sh_teams.lua" )
AddCSLuaFile( "core/libraries/sh_phase.lua" )
AddCSLuaFile( "core/libraries/sh_roundstate.lua" )
AddCSLuaFile( "core/modes/sh_modes.lua" )
AddCSLuaFile( "core/modes/competitive/sh_competitive.lua" )
AddCSLuaFile( "core/modes/gungame/sh_gungame.lua" )
AddCSLuaFile( "core/modes/tdm/sh_tdm.lua" )
AddCSLuaFile( "core/modes/br/sh_br.lua" )
AddCSLuaFile( "core/modules/admin/sh_admin.lua" )
AddCSLuaFile( "core/libraries/sh_commands.lua" )
AddCSLuaFile( "core/modules/zones/sh_zones.lua" )
AddCSLuaFile( "core/modules/props/sh_proplist.lua" )
AddCSLuaFile( "core/modules/progression/sh_levels.lua" )
AddCSLuaFile( "core/modules/zones/cl_authored.lua" )
AddCSLuaFile( "core/modules/weapons/sh_buymenu.lua" )
AddCSLuaFile( "core/modules/weapons/sh_slots.lua" )
AddCSLuaFile( "core/modules/weapons/sh_weaponfixes.lua" )
AddCSLuaFile( "core/modules/weapons/sh_accuracy.lua" )
AddCSLuaFile( "core/modules/weapons/cl_drop.lua" )
AddCSLuaFile( "core/modules/weapons/cl_switching.lua" )

-- Client.
AddCSLuaFile( "core/derma/cl_theme.lua" )
AddCSLuaFile( "core/derma/cl_chat.lua" )
AddCSLuaFile( "core/derma/cl_input.lua" )
AddCSLuaFile( "core/derma/cl_hud.lua" )
AddCSLuaFile( "core/derma/cl_motd.lua" )
AddCSLuaFile( "core/derma/cl_teammenu.lua" )
AddCSLuaFile( "core/derma/cl_modelmenu.lua" )
AddCSLuaFile( "core/derma/cl_scoreboard.lua" )
AddCSLuaFile( "core/derma/cl_killfeed.lua" )
AddCSLuaFile( "core/derma/cl_roundhud.lua" )
AddCSLuaFile( "core/derma/cl_buymenu.lua" )
AddCSLuaFile( "core/derma/cl_view.lua" )
AddCSLuaFile( "core/derma/cl_devmenu.lua" )
AddCSLuaFile( "core/derma/cl_propmenu.lua" )
AddCSLuaFile( "core/derma/cl_phaser_wm.lua" )

-- Every mode's client files, not just the active one's: they only draw, and
-- each guards itself with CS16.IsMode.
AddCSLuaFile( "core/modes/gungame/cl_gungame.lua" )

include( "shared.lua" )

--[[
	The mode chosen last time /gamemode ran, applied before anything reads it.

	Restoring it here rather than on InitPostEntity matters: the includes below
	depend on the answer, so it has to be settled before them.
]]
CS16.LoadSavedMode()

-- Libraries: the player has to exist before anything can happen to them.
include( "core/libraries/sv_spawns.lua" )
include( "core/libraries/sv_player.lua" )
include( "core/libraries/sv_movement.lua" )
include( "core/libraries/sv_voice.lua" )
include( "core/libraries/sv_teams.lua" )
include( "core/libraries/sv_spectate.lua" )
include( "core/libraries/sv_phase.lua" )
include( "core/libraries/sv_pause.lua" )
include( "core/libraries/sv_language.lua" )

-- Modules: services any mode can use.
include( "core/modules/admin/sv_admin.lua" )

-- After admin, because /gamemode is declared against a permission.
include( "core/modes/sv_modes.lua" )

--[[
	Not every file the gamemode loads is listed here, and this is the exception:
	core/modules/zones/maps/<map>.lua holds one shipped zone layout per map, and
	sv_authored includes whichever matches the map that's running. Adding a map
	means dropping a file in that folder, not editing this list.
]]
include( "core/modules/zones/sv_authored.lua" )

-- After admin, because everything in it is gated on the developer rank, and
-- after the mode, because the round hook it clears props on comes from there.
include( "core/modules/props/sv_props.lua" )

include( "core/modules/economy/sv_economy.lua" )

-- After the mode is settled, because progression is stored per mode and reads
-- CS16.ModeID the moment it loads a player.
include( "core/modules/progression/sv_progression.lua" )
include( "core/modules/weapons/sv_buy.lua" )
include( "core/modules/weapons/sv_drop.lua" )

-- The developer phaser. Ships with the gamemode rather than as an addon, so
-- there is nothing else to install; the weapon is entities/weapons and its
-- models are under content/.
include( "core/modules/weapons/sv_phaser.lua" )
include( "core/modules/flashlight/sv_flashlight.lua" )

-- Late, because it precaches from the weapon list and the prop list and both
-- have to exist first.
include( "core/modules/precache/sv_precache.lua" )
include( "core/modules/weapons/sv_switching.lua" )
include( "core/modules/weapons/sv_damage.lua" )
include( "core/modules/weapons/sv_flashbang.lua" )
include( "core/modules/kills/sv_killfeed.lua" )
include( "core/modules/kills/sv_announcer.lua" )
include( "core/modules/bots/sv_bot_nav.lua" )
include( "core/modules/bots/sv_bots.lua" )
include( "core/modules/bots/sv_autofill.lua" )

--[[
	The mode last, because it drives everything above rather than the other way
	round. Which files these are is declared in the mode's own registration.
]]
for _, path in ipairs( CS16.ModeServerFiles() ) do
	include( path )
end

MsgN( ("[CS 1.6] Game mode: %s."):format( CS16.Mode().label ) )

-- The map ships CS content references; make sure clients pull the models we
-- assign so nobody ends up as an ERROR sign.
function GM:InitPostEntity()
	for _, list in pairs( CS16.Config.Models ) do
		for _, mdl in ipairs( list ) do
			util.PrecacheModel( mdl )
		end
	end

	util.PrecacheModel( CS16.Config.Developer.Model )

	CS16.CacheSpawnPoints()
end
