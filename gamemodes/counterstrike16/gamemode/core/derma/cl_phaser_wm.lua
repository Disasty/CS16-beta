--[[
	World-model placement tool.

	A ported GoldSrc p_ model is authored in player space, so it has no sensible
	relationship to a hand attachment and has to be positioned by hand. Rather
	than guess-and-recompile, this drives the live weapon's WorldModelPos and
	WorldModelAng from sliders so the model moves in the world as you drag, then
	prints a paste-ready snippet.

	Open with:  cs16_phaser_wm
	Third person is required to see anything - the tool turns it on for you.

	Nothing here affects gameplay; it only writes to the clientside copy of the
	weapon table. The values are not saved until they are pasted into the SWEP.
]]

local WEP = "weapon_cs16_phaser"

local function ActiveWeapon()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local w = ply:GetActiveWeapon()
	if IsValid( w ) and w:GetClass() == WEP then return w end
end

local frame

concommand.Add( "cs16_phaser_wm", function()
	local wep = ActiveWeapon()
	if not wep then
		chat.AddText( Color( 255, 100, 100 ),
			"[phaser] Hold the phaser first (weapon_cs16_phaser)." )
		return
	end

	if IsValid( frame ) then frame:Remove() end

	-- Start from whatever the weapon is currently using, so reopening the tool
	-- continues from where you left off rather than snapping back.
	local pos = Vector( wep.WorldModelPos or vector_origin )
	local ang = Angle( wep.WorldModelAng or angle_zero )

	-- Tall enough for six sliders plus both buttons; at 330 the roll slider
	-- ended up underneath them and could not be dragged at all.
	frame = vgui.Create( "DFrame" )
	frame:SetSize( 360, 470 )
	frame:SetPos( 40, 120 )
	frame:SetTitle( "Phaser - world model placement" )
	frame:SetSizable( true )
	frame:MakePopup()

	--[[
		Keep the mouse free for the sliders without locking the player in place:
		MakePopup grabs the cursor, which is what we want here.
	]]
	local help = vgui.Create( "DLabel", frame )
	help:Dock( TOP )
	help:DockMargin( 6, 4, 6, 4 )
	help:SetText( "Drag to move the phaser in the holder's hand." )
	help:SetTextColor( color_white )

	local function apply()
		local w = ActiveWeapon()
		if not w then return end
		w.WorldModelPos = Vector( pos )
		w.WorldModelAng = Angle( ang )
	end

	local function slider( label, minv, maxv, get, set )
		local s = vgui.Create( "DNumSlider", frame )
		s:Dock( TOP )
		s:DockMargin( 6, 2, 6, 2 )
		s:SetText( label )
		s:SetMinMax( minv, maxv )
		s:SetDecimals( 2 )
		s:SetTall( 36 )
		s:SetValue( get() )
		s.OnValueChanged = function( _, v )
			set( math.Round( v, 1 ) )
			apply()
		end
		return s
	end

	slider( "X (fwd)",  -30, 30,  function() return pos.x end, function( v ) pos.x = v end )
	slider( "Y (right)",-30, 30,  function() return pos.y end, function( v ) pos.y = v end )
	slider( "Z (up)",   -30, 30,  function() return pos.z end, function( v ) pos.z = v end )
	slider( "Pitch",   -360, 360, function() return ang.p end, function( v ) ang.p = v end )
	slider( "Yaw",     -360, 360, function() return ang.y end, function( v ) ang.y = v end )
	slider( "Roll",    -360, 360, function() return ang.r end, function( v ) ang.r = v end )

	local out = vgui.Create( "DButton", frame )
	out:Dock( BOTTOM )
	out:DockMargin( 6, 4, 6, 6 )
	out:SetTall( 30 )
	out:SetText( "Print values to console" )
	out.DoClick = function()
		local a = string.format(
			"SWEP.WorldModelPos = Vector( %.1f, %.1f, %.1f )", pos.x, pos.y, pos.z )
		local b = string.format(
			"SWEP.WorldModelAng = Angle( %.1f, %.1f, %.1f )", ang.p, ang.y, ang.r )
		MsgC( Color( 120, 255, 120 ), "\n[phaser] paste these into weapon_cs16_phaser.lua:\n" )
		MsgC( Color( 255, 255, 255 ), a .. "\n" .. b .. "\n\n" )
		chat.AddText( Color( 120, 255, 120 ), "[phaser] printed to console (~ key)." )
	end

	local reset = vgui.Create( "DButton", frame )
	reset:Dock( BOTTOM )
	reset:DockMargin( 6, 4, 6, 2 )
	reset:SetTall( 24 )
	reset:SetText( "Reset to zero" )
	reset.DoClick = function()
		pos = Vector( 0, 0, 0 )
		ang = Angle( 0, 0, 0 )
		apply()
		frame:Remove()
		RunConsoleCommand( "cs16_phaser_wm" )
	end

	apply()

	-- Nothing to look at in first person.
	if not LocalPlayer():ShouldDrawLocalPlayer() then
		RunConsoleCommand( "thirdperson" )
		chat.AddText( Color( 255, 220, 120 ),
			"[phaser] switched to third person - 'firstperson' to go back." )
	end
end, nil, "Open the phaser world-model placement tool." )
