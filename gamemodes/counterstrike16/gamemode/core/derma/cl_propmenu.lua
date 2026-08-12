--[[
	The developer prop menu.

	Sandbox's spawn menu, cut down to one prop pack and dressed like the rest of
	this gamemode. It sits to the right of the C menu and comes up with it, so
	holding C gives you the tools on the left and the props on the right.

	Only the Half-Life 1 pack is in it, and deliberately so - a full spawn menu
	on a Counter-Strike server is a sandbox server with extra steps. See
	core/modules/props/sh_proplist.lua for the list and why it is baked.
]]

local ICON     = 64
local ICON_GAP = 4
local HEADER_H = 26
local PAD      = 12
local TITLE_H  = 44
local BAR_W    = 12

-- Level with the C menu and just clear of it: 60 for its left edge, 340 wide,
-- then a gap. Kept in step by hand because the two are separate panels.
local MENU_X = 60 + 340 + 12

local frame, canvas, layoutWidth

--[[
	Which categories are open, remembered between sessions.

	Stored as one archived string rather than a convar each, because the list of
	categories comes from the prop pack's folders and is not this file's to fix.
	Half-Life alone by default: opening all seven means building all 742 icons,
	which is the cost this exists to avoid.
]]
local openCvar = CreateClientConVar( "cs16_prop_categories", "Half-Life", true, false,
	"Which prop menu categories are expanded." )

local expanded

local function LoadExpanded()
	expanded = {}

	for _, name in ipairs( string.Explode( ",", openCvar:GetString() ) ) do
		if name ~= "" then expanded[ name ] = true end
	end
end

local function SaveExpanded()
	local names = {}

	for name, on in pairs( expanded ) do
		if on then names[ #names + 1 ] = name end
	end

	table.sort( names )
	RunConsoleCommand( "cs16_prop_categories", table.concat( names, "," ) )
end

--[[
	Built once and then shown and hidden, not rebuilt.

	There are 742 icons in here and each is a model rendered to a texture. Doing
	that on every press of C is a visible hitch every press of C; doing it once
	is a hitch the first time and nothing afterwards.
]]
local function BuildIcon( model )
	local icon = vgui.Create( "SpawnIcon", canvas )
	icon:SetSize( ICON, ICON )
	icon:SetModel( model )
	icon:SetTooltip( string.GetFileFromFilename( model ) )

	-- The class paints the model; this is only the frame around it, so it goes
	-- over the top rather than replacing Paint.
	icon.PaintOver = function( self, w, h )
		if not self:IsHovered() then return end

		surface.SetDrawColor( CS16.Colors.Gold )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end

	icon.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )

		net.Start( "CS16.SpawnProp" )
			net.WriteString( model )
		net.SendToServer()
	end

	-- Nothing useful behind it, and the default menu offers sandbox actions
	-- this gamemode has no equivalent for.
	icon.OpenMenu = function() end

	return icon
end

local Relayout

--[[
	A category heading, which is also the button that opens and closes it.

	The whole row rather than a small arrow: it is the obvious thing to click
	and there is no reason to make somebody hit a chevron.
]]
local function BuildHeader( name, count )
	local header = vgui.Create( "DButton", canvas )
	header:SetTall( HEADER_H )
	header:SetText( "" )

	header.Paint = function( self, w, h )
		local on   = expanded[ name ]
		local gold = self:IsHovered() and CS16.Colors.Gold or ( on and CS16.Colors.Gold or CS16.Colors.GoldDim )

		CS16.DrawText( ( on and "- " or "+ " ) .. string.upper( name ), "CS16.Small", 2, 7,
			gold, TEXT_ALIGN_LEFT )
		CS16.DrawText( count, "CS16.Small", w - 2, 7, CS16.Colors.Muted, TEXT_ALIGN_RIGHT )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( 0, h - 6, w, 1 )
	end

	header.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )

		expanded[ name ] = not expanded[ name ] or nil
		SaveExpanded()
		Relayout()
	end

	return header
end

--[[
	Laid out by hand rather than with DIconLayout.

	The grid is interrupted by a full-width heading every group, which is the one
	thing that layout does not do - it flows everything into the same run of
	cells, headings included.
]]
--[[
	Only the open categories get icons built at all.

	This is the whole point of collapsing them. Every icon is a model rendered
	to its own texture, so 742 of them is a real wait - and it was being paid in
	full to look at one category. Half-Life alone is 68.

	Closing a category throws its icons away rather than hiding them, which
	sounds wasteful and is not: Garry's Mod caches the rendered icons to disk,
	so building the same category a second time is quick, and keeping seven
	categories' worth of panels alive to avoid that costs the memory all the
	time rather than the work occasionally.
]]
local function Layout( width )
	local cols = math.max( 1, math.floor( ( width + ICON_GAP ) / ( ICON + ICON_GAP ) ) )
	local y    = 0

	for _, group in ipairs( CS16.PropList ) do
		local header = BuildHeader( group.name, #group.models )
		header:SetPos( 0, y )
		header:SetWide( width )

		y = y + HEADER_H

		if expanded[ group.name ] then
			for i, model in ipairs( group.models ) do
				local col = ( i - 1 ) % cols
				local row = math.floor( ( i - 1 ) / cols )

				BuildIcon( model ):SetPos( col * ( ICON + ICON_GAP ), y + row * ( ICON + ICON_GAP ) )
			end

			y = y + math.ceil( #group.models / cols ) * ( ICON + ICON_GAP )
		end

		y = y + ICON_GAP
	end

	--[[
		Stated rather than left to the scroll panel to work out. With a category
		closed there is nothing below the headings for it to measure, so the
		canvas would keep the height of whatever was open last and scroll into
		empty space.
	]]
	if IsValid( canvas ) then canvas:SetTall( y ) end

	return y
end

--[[
	Rebuild the contents in place after a category is opened or closed.

	The frame and its scrollbar are left alone - only what is inside the canvas
	changes - so the menu does not blink or lose its scroll position when a
	heading is clicked.
]]
function Relayout()
	if not IsValid( canvas ) then return end

	canvas:Clear()
	Layout( layoutWidth )
end

--[[
	The scrollbar, restyled to match everything else.

	DVScrollBar paints a light grey trough and two arrow buttons by default,
	which is the one piece of stock Derma that would have shown through. The
	arrows are painted away rather than removed - they still take their space and
	still work, they just stop looking like Windows 98.
]]
local function StyleScrollBar( scroll )
	local bar = scroll:GetVBar()
	bar:SetWide( BAR_W )

	bar.Paint = function( self, w, h )
		surface.SetDrawColor( CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, w, h )
	end

	bar.btnUp.Paint   = function() end
	bar.btnDown.Paint = function() end

	bar.btnGrip.Paint = function( self, w, h )
		surface.SetDrawColor( self.Depressed and CS16.Colors.Gold
			or self:IsHovered() and CS16.Colors.Gold or CS16.Colors.GoldDim )
		surface.DrawRect( 0, 0, w, h )
	end
end

local function Build()
	local w = math.min( 1040, ScrW() - MENU_X - 60 )
	local h = math.min( 760, ScrH() * 0.78 )

	frame = vgui.Create( "DPanel" )
	frame:SetSize( w, h )
	frame:SetPos( MENU_X, ( ScrH() - h ) * 0.5 )

	local total = 0
	for _, group in ipairs( CS16.PropList ) do total = total + #group.models end

	frame.Paint = function( self, pw, ph )
		CS16.DrawPanel( 0, 0, pw, ph )
		CS16.DrawText( "PROPS", "CS16.Title", PAD, 12, CS16.Colors.Gold, TEXT_ALIGN_LEFT )
		CS16.DrawText( total .. " models", "CS16.Small", pw - PAD, 20, CS16.Colors.Muted, TEXT_ALIGN_RIGHT )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( PAD, TITLE_H - 8, pw - PAD * 2, 1 )
	end

	local scroll = vgui.Create( "DScrollPanel", frame )
	scroll:SetPos( PAD, TITLE_H )
	scroll:SetSize( w - PAD * 2, h - TITLE_H - PAD )
	StyleScrollBar( scroll )

	canvas = scroll:GetCanvas()

	-- Minus the bar, or the last column sits underneath it. Remembered so a
	-- category being opened can lay out to the same width.
	layoutWidth = w - PAD * 2 - BAR_W - ICON_GAP

	LoadExpanded()
	Layout( layoutWidth )
end

--[[
	Build it before it is asked for.

	The menu is already built once and then shown and hidden, so the cost is
	paid a single time - but it was paid on the first press of C, which is
	exactly when somebody is waiting to use it. Doing it shortly after spawning
	instead moves that hitch to a moment nobody is mid-anything.

	This is not what precaching fixes, and the two are worth keeping apart:
	util.PrecacheModel gets a model loaded, while the delay here is SpawnIcon
	rendering each of 742 models to its own texture. The engine caches those to
	disk, so this is slowest the very first time a client ever sees this map's
	prop list and quick from then on.

	Developers only, since nobody else can open it - there is no sense making a
	player wait for a menu they will never see.
]]
hook.Add( "InitPostEntity", "CS16.PrebuildPropMenu", function()
	timer.Simple( 8, function()
		if not IsValid( LocalPlayer() ) then return end
		if not CS16.IsDeveloper( LocalPlayer() ) then return end
		if not CS16.PropList then return end

		CS16.OpenPropMenu()
		CS16.ClosePropMenu()
	end )
end )

function CS16.OpenPropMenu()
	if not CS16.IsDeveloper( LocalPlayer() ) then return end

	--[[
		No list, no menu - and say so rather than throwing.

		sh_proplist is a shared file, so it only reaches a client that connected
		after the server registered it with AddCSLuaFile. That registration runs
		once when the gamemode loads, so adding the file to a running server
		leaves exactly this state: the client has this menu and not the list it
		needs, and every press of C is a Lua error. A map change fixes it.
	]]
	if not CS16.PropList then
		if not CS16.PropListWarned then
			CS16.PropListWarned = true
			chat.AddText( CS16.Colors.Gold, "[CS 1.6] ",
				color_white, "Prop list not loaded - the server needs a map change since it was added." )
		end

		return
	end

	if not IsValid( frame ) then Build() end

	frame:SetVisible( true )
	frame:MakePopup()

	-- Mouse only, for the same reason as the C menu: it is held open, so the
	-- keyboard has to stay with the game underneath.
	frame:SetKeyboardInputEnabled( false )
end

function CS16.ClosePropMenu()
	if not IsValid( frame ) then return end

	frame:SetVisible( false )
	frame:SetMouseInputEnabled( false )
end

--[[
	Undo, on Z.

	gmod_undo comes from the undo module, not from sandbox, so it is already
	there in this gamemode and already does the work - pops your own stack,
	refuses anyone else's. All that was missing was a key on it.

	Read through WatchKey like the menus, so it still fires while the prop menu
	is up and holding the mouse.
]]
CS16.WatchKey( "undoprop", KEY_Z, function()
	if not CS16.IsDeveloper( LocalPlayer() ) then return end

	--[[
		Only if nothing else is already doing it.

		Garry's Mod binds Z to undo out of the box, so on a default install this
		was the *second* undo of the same keypress - which is why one press took
		two props, and why holding it made that worse rather than better. The
		binding here exists for the case where somebody has cleared that bind,
		not to duplicate it.
	]]
	if input.LookupBinding( "undo" ) or input.LookupBinding( "gmod_undo" ) then return end

	RunConsoleCommand( "gmod_undo" )
end )
