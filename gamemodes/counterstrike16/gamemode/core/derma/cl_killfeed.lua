--[[
	Kill feed, drawn top-right under the money in the 1.6 layout:

		Killer  [icon] [hs]  Victim

	The icons are the original Counter-Strike death sprites. Their rectangles
	come from cstrike/sprites/hud.txt - entries like

		d_ak47   640   640hud1   192  80  48  16

	meaning sheet 640hud1, at x192 y80, 48x16. The sheets are 256x256 (the
	table's own maximums land exactly on 256), so UVs are simply the pixel
	coordinates over 256, which stays correct even if the addon's VTF
	conversions were rescaled.

	The materials are UnlitGeneric with $additive, so fading is done by scaling
	the draw colour toward black rather than by alpha, which additive blending
	largely ignores.
]]

local KILL_PLAYER  = 0
local KILL_SUICIDE = 1

local LIFETIME     = 6
local FADE         = 1
local MAX_ENTRIES  = 6
local LINE_HEIGHT  = 26
local GAP          = 8
local MARGIN       = 24
local TOP          = 64 -- clear of the money readout
local SHEET        = 256
local ICON_SCALE   = 1.4

local entries   = {}
local materials = {}

local function Sheet( name )
	if not materials[ name ] then materials[ name ] = Material( name ) end
	return materials[ name ]
end

-- sheet, x, y, w, h - straight from hud.txt.
local ICONS = {
	weapon_cs16_knife     = { "640hud1", 192,   0, 48, 16 },
	weapon_cs16_glock18   = { "640hud1", 192,  16, 32, 16 },
	weapon_cs16_usp       = { "640hud1", 192,  32, 32, 16 },
	weapon_cs16_m3        = { "640hud1", 192,  48, 48, 16 },
	weapon_cs16_mp5navy   = { "640hud1", 192,  64, 32, 16 },
	weapon_cs16_ak47      = { "640hud1", 192,  80, 48, 16 },
	weapon_cs16_m4a1      = { "640hud1", 192,  96, 48, 16 },
	weapon_cs16_sg552     = { "640hud1", 192, 112, 48, 16 },
	weapon_cs16_awp       = { "640hud1", 192, 128, 48, 16 },
	weapon_cs16_g3sg1     = { "640hud1", 192, 144, 48, 16 },
	weapon_cs16_m249      = { "640hud1", 192, 160, 48, 16 },
	weapon_cs16_p90       = { "640hud1", 192, 176, 48, 16 },
	weapon_cs16_flashbang = { "640hud1", 192, 192, 48, 16 },
	weapon_cs16_scout     = { "640hud1", 192, 208, 48, 16 },
	weapon_cs16_xm1014    = { "640hud1", 192, 224, 48, 16 },
	weapon_cs16_deagle    = { "640hud1", 224,  16, 32, 16 },
	weapon_cs16_p228      = { "640hud1", 224,  32, 32, 16 },
	weapon_cs16_tmp       = { "640hud1", 224,  64, 32, 16 },
	weapon_cs16_hegrenade = { "640hud1", 224, 192, 32, 16 },
	weapon_cs16_aug       = { "640hud1", 148, 240, 44, 16 },
	weapon_cs16_mac10     = { "640hud1", 109, 240, 34, 16 },
	weapon_cs16_elite     = { "640hud1",  52, 240, 57, 16 },
	weapon_cs16_fiveseven = { "640hud16", 192,  0, 32, 16 },
	weapon_cs16_sg550     = { "640hud16", 192, 48, 48, 16 },
	weapon_cs16_ump45     = { "640hud16", 192, 80, 48, 16 },
	weapon_cs16_famas     = { "640hud2", 192, 144, 48, 16 },
	weapon_cs16_galil     = { "640hud2", 192, 160, 48, 16 },

	-- 1.6 only ever had one knife icon, so the beta model borrows it rather
	-- than falling back to a text label.
	weapon_cs16_knife_beta = { "640hud1", 192, 0, 48, 16 },
}

local ICON_SKULL    = { "640hud1", 224, 240, 32, 16 }
local ICON_HEADSHOT = { "640hud1",   0, 240, 36, 16 }

-- Anything without a sprite falls back to a text label rather than nothing.
local FALLBACK_NAMES = {
	weapon_cs16_smokegrenade = "SMOKE",
	weapon_cs16_c4           = "C4",
}

local function IconSize( icon )
	return icon[ 4 ] * ICON_SCALE, icon[ 5 ] * ICON_SCALE
end

local function DrawIcon( icon, x, y, alpha )
	local w, h = IconSize( icon )

	surface.SetMaterial( Sheet( icon[ 1 ] ) )

	-- Additive: scale the colour, not the alpha, or it won't fade.
	surface.SetDrawColor( alpha, alpha, alpha, 255 )

	surface.DrawTexturedRectUV( x, y, w, h,
		icon[ 2 ] / SHEET,
		icon[ 3 ] / SHEET,
		( icon[ 2 ] + icon[ 4 ] ) / SHEET,
		( icon[ 3 ] + icon[ 5 ] ) / SHEET )
end

net.Receive( "CS16.Kill", function()
	local kind  = net.ReadUInt( 2 )
	local entry = { kind = kind, time = CurTime() }

	if kind == KILL_PLAYER then
		local ent = net.ReadEntity()

		entry.killer     = net.ReadString()
		entry.killerTeam = net.ReadUInt( 11 )
		entry.killerIsMe = ent == LocalPlayer()
	end

	local victimEnt = net.ReadEntity()

	entry.victim     = net.ReadString()
	entry.victimTeam = net.ReadUInt( 11 )
	entry.victimIsMe = victimEnt == LocalPlayer()

	local class = net.ReadString()
	entry.headshot = net.ReadBool()

	if kind == KILL_PLAYER then
		entry.icon = ICONS[ class ]
		if not entry.icon then entry.label = FALLBACK_NAMES[ class ] or "KILLED" end
	else
		-- Suicide and world deaths both get the skull.
		entry.icon = ICON_SKULL
	end

	entries[ #entries + 1 ] = entry

	-- Oldest falls off the bottom of the list.
	if #entries > MAX_ENTRIES then table.remove( entries, 1 ) end
end )

local function NameColour( isMe, teamID, alpha )
	-- Your own name stands out from the two team colours.
	local base = isMe and CS16.Colors.White
		or ( CS16.TeamColors[ teamID ] or CS16.Colors.Muted )

	return Color( base.r, base.g, base.b, alpha )
end

local function Text( str, x, y, col )
	draw.SimpleText( str, "CS16.Text", x + 1, y + 1, Color( 0, 0, 0, col.a ), TEXT_ALIGN_LEFT )
	draw.SimpleText( str, "CS16.Text", x, y, col, TEXT_ALIGN_LEFT )
end

-- Laid out right-aligned, so widths are measured before anything is drawn.
local function DrawEntry( entry, y, alpha )
	surface.SetFont( "CS16.Text" )

	local killerW = entry.killer and surface.GetTextSize( entry.killer ) or 0
	local victimW = surface.GetTextSize( entry.victim )

	local iconW, iconH = 0, 0
	if entry.icon then iconW, iconH = IconSize( entry.icon ) end

	local labelW = entry.label and surface.GetTextSize( entry.label ) or 0

	local headW, headH = 0, 0
	if entry.headshot then headW, headH = IconSize( ICON_HEADSHOT ) end

	local total = victimW + iconW + labelW + GAP
	if killerW > 0 then total = total + killerW + GAP end
	if headW > 0 then total = total + headW + GAP end

	local x = ScrW() - MARGIN - total

	-- Vertically centre the sprites against the text line.
	local iconY = y + ( 14 - iconH ) * 0.5

	if killerW > 0 then
		Text( entry.killer, x, y, NameColour( entry.killerIsMe, entry.killerTeam, alpha ) )
		x = x + killerW + GAP
	end

	if entry.icon then
		DrawIcon( entry.icon, x, iconY, alpha )
		x = x + iconW + GAP
	elseif entry.label then
		Text( entry.label, x, y, Color( 255, 215, 0, alpha ) )
		x = x + labelW + GAP
	end

	if headW > 0 then
		DrawIcon( ICON_HEADSHOT, x, y + ( 14 - headH ) * 0.5, alpha )
		x = x + headW + GAP
	end

	Text( entry.victim, x, y, NameColour( entry.victimIsMe, entry.victimTeam, alpha ) )
end

hook.Add( "HUDPaint", "CS16.KillFeed", function()
	local now = CurTime()

	-- Backwards so removals don't shuffle entries we haven't checked yet.
	for i = #entries, 1, -1 do
		if now - entries[ i ].time > LIFETIME then table.remove( entries, i ) end
	end

	local y = TOP

	for _, entry in ipairs( entries ) do
		local age   = now - entry.time
		local alpha = 255

		if age > LIFETIME - FADE then
			alpha = 255 * ( 1 - ( age - ( LIFETIME - FADE ) ) / FADE )
		end

		DrawEntry( entry, y, math.Clamp( alpha, 0, 255 ) )
		y = y + LINE_HEIGHT
	end
end )

-- Nothing from last round should linger into the next one.
hook.Add( "Think", "CS16.KillFeedClear", function()
	local round = CS16.GetRoundNumber()

	if round ~= ( CS16.KillFeedRound or 0 ) then
		CS16.KillFeedRound = round
		entries = {}
	end
end )
