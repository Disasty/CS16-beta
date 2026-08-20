--[[
	Shared entry point. Runs on both realms, and defines the CS16 table
	everything else hangs off.

	Order matters: config first, then teams (which the rest reference by
	TEAM_T / TEAM_CT), then admin before commands so permissions exist by the
	time commands are declared against them.
]]

GM.Name    = "Counter-Strike 1.6"
GM.Author  = "disastrous"
GM.Email   = ""
GM.Website = ""

DeriveGamemode( "base" )

CS16 = CS16 or {}
CS16.Version = "0.1.0"

include( "core/libraries/sh_config.lua" )

--[[
	Language, early, because everything after this point can look a string up
	and nothing here depends on anything but the CS16 table.

	English is loaded first and is the fallback every other language falls
	through to, so a half-finished translation shows English rather than gaps.
	Adding a language is a file in core/languages/ and a line here.
]]
include( "core/libraries/sh_language.lua" )
include( "core/languages/en.lua" )
include( "core/languages/pt.lua" )

include( "core/libraries/sh_teams.lua" )

--[[
	Before anything draws a model, and crucially before CreateTeams: DynaBase
	fires its animation load from there, so a pose registered any later is
	registered after the only moment it would be read.
]]
include( "core/modules/animations/sh_menuposes.lua" )
include( "core/libraries/sh_phase.lua" )
include( "core/libraries/sh_roundstate.lua" )

--[[
	The mode registry, then every mode's registration.

	All of them register on both realms - it's cheap and has no side effects -
	so /gamemode can list and validate names it isn't currently running. Only
	the active mode's server files are actually loaded, and init.lua does that.
]]
include( "core/modes/sh_modes.lua" )
include( "core/modes/competitive/sh_competitive.lua" )
include( "core/modes/gungame/sh_gungame.lua" )
include( "core/modes/tdm/sh_tdm.lua" )
include( "core/modes/br/sh_br.lua" )

include( "core/modules/admin/sh_admin.lua" )
include( "core/libraries/sh_commands.lua" )
include( "core/modules/zones/sh_zones.lua" )

-- Shared because both ends need it: the menu lists these, and the server checks
-- a spawn request against them rather than trusting the model name it is sent.
include( "core/modules/props/sh_proplist.lua" )
include( "core/modules/progression/sh_levels.lua" )
include( "core/modules/weapons/sh_buymenu.lua" )
include( "core/modules/weapons/sh_slots.lua" )
include( "core/modules/weapons/sh_weaponfixes.lua" )
include( "core/modules/weapons/sh_accuracy.lua" )

function GM:Initialize()
end
