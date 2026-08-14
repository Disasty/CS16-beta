--[[
	Shared look for every CS16 panel - team menu, buy menu, areas tool, HUD.

	The palette is taken from the addon scoreboard we replace, so the whole UI
	reads as one piece: gold on near-black, Verdana Bold, hard square corners.
	1.6 had no rounded edges or gradients anywhere.
]]

CS16.Colors = {
	Gold       = Color( 255, 215, 0 ),
	GoldDim    = Color( 150, 150, 50, 100 ),
	Panel      = Color( 10, 10, 10, 240 ),
	PanelLight = Color( 28, 28, 28, 240 ),
	Hover      = Color( 60, 55, 20, 240 ),
	White      = Color( 235, 235, 235 ),
	Muted      = Color( 140, 140, 140 ),
	Danger     = Color( 220, 60, 50 ),
	Shadow     = Color( 0, 0, 0, 200 ),

	-- 1.6 frames its scoreboard in a dull amber and writes the title and column
	-- labels in the same, not in the bright gold the rest of our panels use.
	Amber      = Color( 200, 145, 60 ),

	T          = Color( 235, 70, 60 ),
	CT         = Color( 105, 165, 245 ),
}

surface.CreateFont( "CS16.Title", {
	font = "Verdana Bold", size = 22, weight = 800,
} )

surface.CreateFont( "CS16.Heading", {
	font = "Verdana Bold", size = 17, weight = 800,
} )

surface.CreateFont( "CS16.Text", {
	font = "Verdana Bold", size = 14, weight = 800,
} )

surface.CreateFont( "CS16.Small", {
	font = "Verdana Bold", size = 12, weight = 500,
} )

surface.CreateFont( "CS16.HUDNumber", {
	font = "Verdana Bold", size = 34, weight = 900,
} )

-- The standard framed box every CS16 panel sits in.
function CS16.DrawPanel( x, y, w, h )
	surface.SetDrawColor( CS16.Colors.Panel )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( CS16.Colors.Gold )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

-- Text with a hard drop shadow, the way the 1.6 HUD rendered everything.
function CS16.DrawText( text, font, x, y, col, alignX, alignY )
	draw.SimpleText( text, font, x + 1, y + 1, CS16.Colors.Shadow, alignX, alignY )
	draw.SimpleText( text, font, x, y, col, alignX, alignY )
end
