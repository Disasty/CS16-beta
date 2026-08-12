--[[
	The 1.6 HUD: health and armour bottom-left, ammo bottom-right, nothing in
	the middle.

	The numbers and icons are the original 1.6 sprites, drawn out of the sheet
	the weapon pack already ships - see the note on SHEET below. This used to be
	primitives and a font, chosen so the HUD had no content dependencies at all;
	the sprites are close enough to free that the trade is worth it, since the
	pack is required for the gamemode to have any weapons in the first place.
]]

local HIDE = {
	CHudHealth        = true,
	CHudBattery       = true,
	CHudAmmo          = true,
	CHudSecondaryAmmo = true,
	--[[
		CHudCrosshair is deliberately NOT hidden.

		The addon's 1.6 crosshair - dynamic, per-weapon spread, its own colour
		and size convars - is drawn from SWEP:DoDrawCrosshair, and GMod only
		calls that while the crosshair HUD element is allowed to draw. Hiding
		it here suppressed the element, the SWEP hook never ran, and the result
		was no crosshair at all. The SWEP returns true from that hook, so the
		stock crosshair stays gone either way.
	]]
	CHudSuitPower     = true,
	CHudDamageIndicator = true,

	-- Takes the grey panel, filter button and scrollbar with it. cl_chat draws
	-- the log and owns the input line instead.
	CHudChat          = true,
}

function GM:HUDShouldDraw( name )
	if HIDE[ name ] then return false end
	return true
end

local MARGIN = 24

--[[
	The original 1.6 HUD sprites.

	The weapon pack ships the whole set of 640hud sheets - the real ones,
	converted to VTF - and never uses them for anything. Sheet 7 is the status
	sheet: the digits across the top, then the health cross and armour shield
	below them. Drawing from it is the difference between a HUD that resembles
	1.6 and one that simply is it, because these are the actual glyphs.

	Additive, which is the part that isn't obvious. GoldSrc sprites are drawn
	white-on-black and composited additively, so the black *is* the transparency
	- there is no alpha channel to rely on. Blitted normally they arrive as
	glyphs sitting in solid black tiles. Built here rather than shipped as a
	.vmt so the gamemode adds no files of its own and nothing in the addon is
	touched.
]]
local SHEET = CreateMaterial( "cs16_hud_status", "UnlitGeneric", {
	[ "$basetexture" ] = "640hud7",
	[ "$additive" ]    = 1,
	[ "$vertexcolor" ] = 1,
	[ "$vertexalpha" ] = 1,
	[ "$nolod" ]       = 1,
} )

-- Sheet 7 is 256x256. Cells measured off it rather than taken on faith.
local SHEET_SIZE = 256
local DIGIT_W, DIGIT_H = 24, 25

--[[
	The status icons sit in their own band of 24x24 tiles below the digits, and
	the tiles are black-backed exactly like the digits are.

	These are measured, and the measuring mattered: the first attempt guessed the
	band started at y=32 and cropped to 20 tall, which took a bite out of the top
	of both glyphs and the bottom of the shield - the cross came out as a stubby
	blob and the shield as a bare U. The band is y=24 to y=48, and the glyphs
	very nearly fill it, which is also why they need no scaling of their own.
]]
--[[
	Public, because the money readout at the top of the screen wants the same
	glyphs. It used to be drawn in a font, and once everything around it was
	sprites it was the one thing on screen that looked borrowed from elsewhere.

	The dollar sign lives in the same band on the same 24-wide grid as the
	status icons - tile eight - which is a good sign the grid is real rather
	than something read into three lucky measurements.
]]
CS16.HUDIcons = {
	shield  = {   0, 24, 24, 24 },
	cross   = {  48, 24, 24, 24 },
	divider = { 242,  0,  6, 25 },

	--[[
		Cropped to the glyph rather than given its whole tile.

		The cross and shield fill theirs, but the dollar sign is a narrow mark
		sitting in the middle of a 24-wide cell, so drawing the full tile padded
		it with black on both sides and left a gap before the figure that no
		amount of adjusting the spacing could close honestly.
	]]
	dollar  = { 194, 24, 16, 24 },
}

local ICON_SHIELD  = CS16.HUDIcons.shield
local ICON_CROSS   = CS16.HUDIcons.cross
local ICON_DIVIDER = CS16.HUDIcons.divider

-- Sized against 1080p and scaled from there, so it reads the same on any
-- monitor rather than shrinking into the corner on a tall one.
function CS16.HUDScale()
	return math.max( 1, ScrH() / 1080 ) * 1.7
end

-- Draws one cell of the sheet and returns the width it took, so callers can lay
-- out left to right without measuring anything twice.
function CS16.DrawHUDSprite( cell, x, y, scale, col )
	local sx, sy, sw, sh = cell[ 1 ], cell[ 2 ], cell[ 3 ], cell[ 4 ]

	surface.SetDrawColor( col )
	surface.SetMaterial( SHEET )
	surface.DrawTexturedRectUV( x, y, sw * scale, sh * scale,
		sx / SHEET_SIZE, sy / SHEET_SIZE,
		( sx + sw ) / SHEET_SIZE, ( sy + sh ) / SHEET_SIZE )

	return sw * scale
end

function CS16.HUDNumberWidth( n, scale )
	return #tostring( math.floor( n ) ) * ( DIGIT_W + 1 ) * scale
end

function CS16.DrawHUDNumber( n, x, y, scale, col )
	local text = tostring( math.floor( n ) )

	for i = 1, #text do
		local d = tonumber( text:sub( i, i ) )

		if d then
			CS16.DrawHUDSprite( { d * DIGIT_W, 0, DIGIT_W, DIGIT_H }, x, y, scale, col )
		end

		x = x + ( DIGIT_W + 1 ) * scale
	end
end

-- Local aliases, purely so the drawing below reads as it did before.
local Scale       = CS16.HUDScale
local DrawCell    = CS16.DrawHUDSprite
local DrawNumber  = CS16.DrawHUDNumber
local NumberWidth = CS16.HUDNumberWidth

--[[
	Health and armour, bottom left, the way 1.6 lays them out: icon then figure,
	armour to the right of health and hidden when you have none.
]]
local function DrawStatus( ply )
	local scale = Scale()
	local y     = ScrH() - MARGIN - DIGIT_H * scale

	local health = math.max( 0, ply:Health() )
	local col    = health <= 25 and CS16.Colors.Danger or CS16.Colors.Gold

	-- A hair down, so a 24-tall icon sits level with a 25-tall digit.
	local iconY = y + ( DIGIT_H - ICON_CROSS[ 4 ] ) * scale
	local x     = MARGIN

	x = x + DrawCell( ICON_CROSS, x, iconY, scale, col ) + 8 * scale

	DrawNumber( health, x, y, scale, col )
	x = x + NumberWidth( health, scale )

	local armor = ply:Armor()
	if armor <= 0 then return end

	x = x + 26 * scale
	x = x + DrawCell( ICON_SHIELD, x, iconY, scale, CS16.Colors.Gold ) + 8 * scale

	DrawNumber( armor, x, y, scale, CS16.Colors.Gold )
end

--[[
	Ammunition, bottom right: magazine, the sheet's own divider bar, then what
	is left in reserve. Right-aligned against the margin, so the figure grows
	leftward and the last digit never moves.
]]
local function DrawAmmo( ply )
	local wep = ply:GetActiveWeapon()
	if not IsValid( wep ) then return end

	local clip = wep:Clip1()
	if clip < 0 then return end -- knife, grenades: no magazine to show

	local reserve = ply:GetAmmoCount( wep:GetPrimaryAmmoType() )
	local scale   = Scale()
	local y       = ScrH() - MARGIN - DIGIT_H * scale

	local reserveW = NumberWidth( reserve, scale )
	local dividerW = ICON_DIVIDER[ 3 ] * scale
	local clipW    = NumberWidth( clip, scale )
	local gap      = 12 * scale

	local right = ScrW() - MARGIN
	local x     = right - reserveW

	DrawNumber( reserve, x, y, scale, CS16.Colors.Gold )

	x = x - gap - dividerW
	DrawCell( ICON_DIVIDER, x, y, scale, CS16.Colors.GoldDim )

	x = x - gap - clipW
	DrawNumber( clip, x, y, scale, CS16.Colors.Gold )
end

--[[
	Who you're following, and how to follow somebody else.

	The target comes from GetObserverTarget rather than anything we network -
	the engine already replicates it to the client doing the watching, so the
	whole spectator camera needs no messages of its own.
]]
--[[
	Built as a list and drawn upward from the bottom, rather than each line
	claiming a position of its own.

	They used to. The health of whoever you were following sat at ScrH() - 48
	and "Press M to choose a team" at ScrH() - 46, two pixels apart, so they
	drew straight through each other - but only while actually following
	somebody, which is why it survived until there was a bot to watch.

	Stacking them means a line that isn't drawn takes no space, and nothing has
	to know what else is on screen.
]]
local LINE_GAP = 6

local function DrawSpectating( ply )
	local target = ply:GetObserverTarget()
	local lines  = {}

	if IsValid( target ) and target:IsPlayer() then
		lines[ #lines + 1 ] = {
			text = target:Nick(),
			font = "CS16.Title",
			col  = CS16.TeamColors[ target:Team() ] or CS16.Colors.Gold,
			h    = 22,
		}

		-- Their health, since the whole point is watching them play.
		lines[ #lines + 1 ] = {
			text = target:Health() .. " HP",
			font = "CS16.Text",
			col  = target:Health() <= 30 and CS16.Colors.Danger or CS16.Colors.Muted,
			h    = 16,
		}
	else
		lines[ #lines + 1 ] = {
			text = "FREE LOOK", font = "CS16.Title", col = CS16.Colors.Gold, h = 22,
		}
	end

	-- Only a spectator needs telling how to join; somebody sitting out a round
	-- already has a side.
	if not CS16.IsPlayingTeam( ply:Team() ) then
		lines[ #lines + 1 ] = {
			text = "Press M to choose a team",
			font = "CS16.Text", col = CS16.Colors.Muted, h = 16,
		}
	end

	--[[
		The cycling keys are only worth mentioning when there is somebody to
		cycle to. Offering them in free look reads as a control that doesn't
		work rather than one with nothing to act on.
	]]
	lines[ #lines + 1 ] = {
		text = IsValid( target ) and "ATTACK next   ATTACK2 previous   JUMP change view"
			or "Nobody left to watch",
		font = "CS16.Small", col = CS16.Colors.Muted, h = 14,
	}

	-- Measure first, then draw down from a top that puts the last line on the
	-- bottom margin.
	local total = 0
	for _, line in ipairs( lines ) do total = total + line.h + LINE_GAP end

	local y = ScrH() - 24 - total

	for _, line in ipairs( lines ) do
		CS16.DrawText( line.text, line.font, ScrW() * 0.5, y, line.col, TEXT_ALIGN_CENTER )
		y = y + line.h + LINE_GAP
	end
end

function GM:HUDPaint()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end

	-- Spectators and the dead get the same camera furniture.
	if not CS16.HasBody( ply:Team() ) or not ply:Alive() then
		DrawSpectating( ply )
		return
	end

	DrawStatus( ply )
	DrawAmmo( ply )
end
