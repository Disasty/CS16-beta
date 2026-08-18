--[[
	Client entry point. Everything drawn lives under core/derma.
]]

include( "shared.lua" )

include( "core/derma/cl_theme.lua" )
include( "core/derma/cl_chat.lua" )

-- Before the menus: they register their keys with it as they load.
include( "core/derma/cl_input.lua" )

include( "core/derma/cl_hud.lua" )

-- Before the team menu, which asks it whether to hold off on opening.
include( "core/derma/cl_motd.lua" )
include( "core/derma/cl_menuframe.lua" )
include( "core/derma/cl_teammenu.lua" )

-- After it, because the two are one choice between them: the team menu routes
-- through CS16.OpenJoinMenu, which this declares.
include( "core/derma/cl_modelmenu.lua" )
include( "core/derma/cl_scoreboard.lua" )
include( "core/derma/cl_killfeed.lua" )
include( "core/derma/cl_roundhud.lua" )
include( "core/derma/cl_buymenu.lua" )

include( "core/derma/cl_view.lua" )
include( "core/derma/cl_devmenu.lua" )

-- After it, because the prop menu opens and closes alongside the C menu and
-- the dev menu is what drives that.
include( "core/derma/cl_propmenu.lua" )

-- Positioning tool for the phaser's world model, opened with cs16_phaser_wm.
-- Only useful if the model ever needs refitting; it changes nothing on its own.
include( "core/derma/cl_phaser_wm.lua" )

-- Not drawn, but need cl_input above them for the drop and quick-switch keys.
include( "core/modules/weapons/cl_drop.lua" )
include( "core/modules/weapons/cl_switching.lua" )
include( "core/modules/zones/cl_authored.lua" )

--[[
	Every mode's client files, not only the active one's.

	Drawing has no state to conflict with, and each file guards its own hooks
	with CS16.IsMode - far simpler than getting conditional client includes
	right across a map change, where the replicated convar naming the mode may
	not have arrived by the time this runs.
]]
for _, path in ipairs( CS16.ModeClientFiles() ) do
	include( path )
end
