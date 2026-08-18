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

--[[
	The join menus size themselves to the screen, so their text has to as well.

	A font cannot be resized after it is made, so these are cut once from the
	screen height at the proportions 1.6 uses: the title about a thirtieth of
	the screen, the numbered items about a sixtieth. On 1080p that lands on the
	34 and 17 pixels the original draws.
]]
surface.CreateFont( "CS16.MenuTitle", {
	font = "Verdana Bold", size = math.max( 20, ScrH() / 31 ), weight = 800,
} )

surface.CreateFont( "CS16.MenuItem", {
	font = "Verdana Bold", size = math.max( 12, ScrH() / 63 ), weight = 800,
} )

surface.CreateFont( "CS16.MenuBody", {
	font = "Verdana Bold", size = math.max( 11, ScrH() / 68 ), weight = 500,
} )

--[[
	Smaller again, for the labels under the model grid.

	Six cells across leaves each about 167 pixels wide at 1080p, and
	"PHOENIX CONNEXION" in the item font is wider than that. It overhung its
	cell and ran into the next one.
]]
surface.CreateFont( "CS16.MenuLabel", {
	font = "Verdana Bold", size = math.max( 10, ScrH() / 78 ), weight = 800,
} )

--[[
	Break a paragraph into lines that fit a width, returning them.

	Word wrapping rather than character wrapping, and it returns rather than
	draws, so the caller decides the line spacing and the colour. Needed because
	a translated paragraph is a different length from the English one and no
	amount of hand-placed line breaks survives that: Portuguese runs a fifth
	longer than English and would spill straight out of the panel.

	A single word longer than the whole width is left to overflow rather than
	cut in half, on the grounds that no real sentence contains one and a
	half-word is worse than a wide line.
]]
function CS16.WrapText( text, font, maxWidth )
	local lines = {}
	if not isstring( text ) or text == "" then return lines end

	surface.SetFont( font )

	local line = ""

	for word in text:gmatch( "%S+" ) do
		local try = ( line == "" ) and word or ( line .. " " .. word )

		if surface.GetTextSize( try ) <= maxWidth or line == "" then
			line = try
		else
			lines[ #lines + 1 ] = line
			line = word
		end
	end

	if line ~= "" then lines[ #lines + 1 ] = line end

	return lines
end

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
