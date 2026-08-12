--[[
	Buy menu, driven by the number keys as 1.6's was - or by the mouse.

	B opens the categories, a number picks one, a number buys, 0 goes back.
	O opens equipment directly, and , / . still top up ammo directly. Every one
	of those rows is also clickable, and right-click goes back, so nobody has to
	learn the numbers to play.

	Both routes share one layout: Layout() hands out the row rectangles, and the
	drawing and the hit test both read them. Nothing can drift out of line
	because there is only one set of positions.

	The numbers arrive through PlayerBindPress rather than raw key state, because
	1 to 9 are bound to slot1..slot9. Returning true from there both takes the
	press and stops it putting your weapon away underneath you.
]]

local MENU_W  = 420
local ROW_H   = 30
local PAD     = 14
local TITLE_H = 44

-- nil when closed, "root" at the top level, otherwise a category id.
local page

--[[
	Where a purchase returns you: "root" when opened with B, "equipment" when
	opened with O. Buying a grenade shouldn't throw you out to the categories
	when equipment is the menu you deliberately opened - you nearly always want
	a second one.
]]
local home

-- The invisible panel that lends us a cursor. See ShowCursor.
local cursor

--[[
	The top level, built from the catalogue rather than listed here.

	1.6's order is guns, then ammo, then equipment, and that falls out of
	walking the categories in order with equipment held back to the end. Doing
	it this way means a category only the developer team can see - explosives -
	appears in their menu and nobody else's without this file knowing which
	categories those are.

	Ammo isn't a set of things to browse, it's an action, so those two entries
	carry a slot to top up instead of a page to open.
]]
local function RootEntries()
	local teamID  = LocalPlayer():Team()
	local entries = {}
	local last    -- equipment, kept for the bottom

	for _, category in ipairs( CS16.BuyCategories ) do
		if CS16.CategoryAllowedForTeam( category, teamID ) then
			local entry = { label = string.upper( category.name ), category = category.id }

			if category.id == "equipment" then
				last = entry
			else
				entries[ #entries + 1 ] = entry
			end
		end
	end

	entries[ #entries + 1 ] = { label = "PRIMARY AMMO",   ammo = true }
	entries[ #entries + 1 ] = { label = "SECONDARY AMMO", ammo = false }

	if last then entries[ #entries + 1 ] = last end

	return entries
end

local function CategoryById( id )
	for _, category in ipairs( CS16.BuyCategories ) do
		if category.id == id then return category end
	end
end

-- Only what this side may buy, so the numbering matches what's on screen.
local function VisibleItems( category )
	local ply     = LocalPlayer()
	local visible = {}

	for _, item in ipairs( category.items ) do
		if CS16.ItemAllowedForTeam( item, ply:Team() ) then
			visible[ #visible + 1 ] = item
		end
	end

	return visible
end

--[[ Opening and closing ]]

function CS16.BuyMenuOpen()
	return page ~= nil
end

--[[
	A popup panel purely so there's a cursor to click with. It paints nothing -
	the menu is still drawn in HUDPaint - and it takes the mouse only.

	Keyboard input has to be switched off *after* MakePopup, which turns both on.
	Leaving the keyboard captured would send the number keys into VGUI, and
	PlayerBindPress would never see them - which would cost us the entire keyboard
	route the moment we added the mouse one.
]]
local ClickAt -- defined below, once Choose exists

local function ShowCursor()
	if IsValid( cursor ) then return end

	cursor = vgui.Create( "DPanel" )
	cursor:SetSize( ScrW(), ScrH() )
	cursor:SetPaintBackground( false )
	cursor:MakePopup()
	cursor:SetKeyboardInputEnabled( false )

	cursor.OnMousePressed = function( _, code )
		if code == MOUSE_RIGHT then ClickAt( nil ) return end

		local x, y = gui.MousePos()
		ClickAt( x, y )
	end
end

local function HideCursor()
	if IsValid( cursor ) then cursor:Remove() end
	cursor = nil
end

function CS16.CloseBuyMenu()
	page, home = nil, nil
	HideCursor()
end

function CS16.OpenBuyMenu( startPage )
	local allowed, reason = CS16.CanBuy( LocalPlayer() )

	if not allowed then
		chat.AddText( CS16.Colors.Gold, "[CS 1.6] ", CS16.Colors.White, reason )
		return
	end

	home = startPage or "root"
	page = home

	ShowCursor()
end

function CS16.ToggleBuyMenu()
	if CS16.BuyMenuOpen() then CS16.CloseBuyMenu() else CS16.OpenBuyMenu() end
end

--[[ Choosing ]]

local function BuyAmmo( primary )
	net.Start( "CS16.BuyAmmo" )
		net.WriteBool( primary )
	net.SendToServer()
end

local function Choose( index )
	--[[
		0 steps back a level, and closes from whichever page you opened on.
		Opening with O means equipment *is* the top level, so 0 closes from
		there rather than dropping you somewhere you never asked to be.
	]]
	if index == 0 then
		if page == home then CS16.CloseBuyMenu() else page = "root" end
		return
	end

	if page == "root" then
		local entry = RootEntries()[ index ]
		if not entry then return end

		surface.PlaySound( "buttons/button14.wav" )

		if entry.category then
			page = entry.category
		else
			BuyAmmo( entry.ammo )
		end

		return
	end

	local category = CategoryById( page )
	if not category then return end

	local item = VisibleItems( category )[ index ]
	if not item then return end

	surface.PlaySound( "buttons/button14.wav" )

	net.Start( "CS16.Buy" )
		net.WriteString( item.id )
	net.SendToServer()

	--[[
		Back to wherever this menu started, as 1.6 did. From B that's the
		categories, which is what makes a full buy a handful of keystrokes; from
		O it's equipment, so a flash and a smoke are two keys and not six.
	]]
	page = home
end

--[[ Layout ]]

-- Rows carry their own rectangle so drawing and clicking can't disagree.
local function Layout()
	local rows, title

	if page == "root" then
		rows, title = {}, "BUY MENU"

		for i, entry in ipairs( RootEntries() ) do
			rows[ #rows + 1 ] = { number = i, label = entry.label, affordable = true }
		end
	else
		local category = CategoryById( page )
		if not category then return nil end

		local ply   = LocalPlayer()
		local money = CS16.GetMoney( ply )

		rows, title = {}, "BUY " .. string.upper( category.name )

		for i, item in ipairs( VisibleItems( category ) ) do
			-- Asked rather than read off the item, so a developer sees the free
			-- prices they'll actually be charged.
			local price = CS16.PriceFor( ply, item )

			rows[ #rows + 1 ] = {
				number     = i,
				label      = string.upper( item.name ),
				price      = price,
				affordable = money >= price,
			}
		end
	end

	-- The back row sits below a gap, and is a row like any other so it clicks.
	rows[ #rows + 1 ] = {
		number     = 0,
		label      = ( page == home ) and "CANCEL" or "BACK",
		affordable = true,
		gap        = true,
	}

	local h = TITLE_H + #rows * ROW_H + PAD + 8
	local x = 60
	local y = ( ScrH() - h ) * 0.5

	local rowY = y + TITLE_H

	for _, row in ipairs( rows ) do
		if row.gap then rowY = rowY + 4 end

		row.x, row.y = x + PAD, rowY
		row.w, row.h = MENU_W - PAD * 2, ROW_H - 4

		rowY = rowY + ROW_H
	end

	return rows, title, x, y, h
end

function ClickAt( mx, my )
	-- Right-click, or a click on nothing much, is a step back.
	if not mx then Choose( 0 ) return end

	local rows = Layout()
	if not rows then return end

	for _, row in ipairs( rows ) do
		if mx >= row.x and mx <= row.x + row.w
			and my >= row.y and my <= row.y + row.h then
			Choose( row.number )
			return
		end
	end
end

--[[ Drawing ]]

local function DrawRow( row, hovered )
	surface.SetDrawColor( hovered and CS16.Colors.Hover or CS16.Colors.PanelLight )
	surface.DrawRect( row.x, row.y, row.w, row.h )

	surface.SetDrawColor( hovered and CS16.Colors.Gold or CS16.Colors.GoldDim )
	surface.DrawOutlinedRect( row.x, row.y, row.w, row.h, 1 )

	local col = row.affordable and CS16.Colors.Gold or CS16.Colors.Muted
	CS16.DrawText( row.number .. "  " .. row.label, "CS16.Text",
		row.x + 10, row.y + 5, col, TEXT_ALIGN_LEFT )

	if row.price then
		CS16.DrawText( "$" .. row.price, "CS16.Text", row.x + row.w - 10, row.y + 5,
			row.affordable and CS16.Colors.White or CS16.Colors.Danger, TEXT_ALIGN_RIGHT )
	end
end

hook.Add( "HUDPaint", "CS16.BuyMenu", function()
	if not CS16.BuyMenuOpen() then return end

	local rows, title, x, y, h = Layout()
	if not rows then return end

	CS16.DrawPanel( x, y, MENU_W, h )

	CS16.DrawText( title, "CS16.Title", x + PAD, y + 12, CS16.Colors.Gold, TEXT_ALIGN_LEFT )
	CS16.DrawText( "$" .. CS16.GetMoney( LocalPlayer() ), "CS16.Title",
		x + MENU_W - PAD, y + 12, CS16.Colors.Gold, TEXT_ALIGN_RIGHT )

	surface.SetDrawColor( CS16.Colors.GoldDim )
	surface.DrawRect( x + PAD, y + TITLE_H - 8, MENU_W - PAD * 2, 1 )

	local mx, my = gui.MousePos()

	for _, row in ipairs( rows ) do
		local hovered = mx >= row.x and mx <= row.x + row.w
			and my >= row.y and my <= row.y + row.h

		DrawRow( row, hovered )
	end
end )

--[[ Input ]]

concommand.Add( "cs16_buymenu", CS16.ToggleBuyMenu )

CS16.WatchKey( "buymenu", KEY_B, function()
	if not CS16.BuyMenuOpen() then CS16.OpenBuyMenu() return end

	-- From the equipment menu, B is how you reach the full buy menu rather than
	-- a second key that closes it. O is what closes equipment.
	if home == "equipment" then
		home, page = "root", "root"
		return
	end

	CS16.CloseBuyMenu()
end )

-- 1.6's shortcut straight to equipment, and the key that closes it again.
CS16.WatchKey( "buyequipment", KEY_O, function()
	if CS16.BuyMenuOpen() and home == "equipment" then
		CS16.CloseBuyMenu()
		return
	end

	if CS16.BuyMenuOpen() then
		home, page = "equipment", "equipment"
		return
	end

	CS16.OpenBuyMenu( "equipment" )
end )

-- , tops up your primary and . your secondary, without opening anything.
CS16.WatchKey( "buyammoprimary",   KEY_COMMA,  function() BuyAmmo( true ) end )
CS16.WatchKey( "buyammosecondary", KEY_PERIOD, function() BuyAmmo( false ) end )

hook.Add( "PlayerBindPress", "CS16.BuyMenuKeys", function( ply, bind, pressed )
	if not pressed or not CS16.BuyMenuOpen() then return end

	local slot = tonumber( string.match( bind, "^slot(%d+)$" ) or "" )
	if not slot then return end

	-- The zero key comes through as slot10.
	if slot == 10 then slot = 0 end

	Choose( slot )
	return true
end )

-- Buy time running out closes the menu under you, same as the round starting
-- would in 1.6.
hook.Add( "Think", "CS16.BuyMenuClose", function()
	if CS16.BuyMenuOpen() and not CS16.CanBuy( LocalPlayer() ) then
		CS16.CloseBuyMenu()
	end

	-- A cursor left up with no menu behind it would lock the mouse out of the
	-- game entirely, so it's swept up here rather than trusted to one caller.
	if not CS16.BuyMenuOpen() and IsValid( cursor ) then HideCursor() end
end )

-- Quiet prompt so players know buying is available without opening anything.
hook.Add( "HUDPaint", "CS16.BuyPrompt", function()
	if CS16.BuyMenuOpen() then return end
	if not CS16.CanBuy( LocalPlayer() ) then return end

	CS16.DrawText( "Press B to buy, O for equipment", "CS16.Text", ScrW() * 0.5, ScrH() - 96,
		CS16.Colors.Muted, TEXT_ALIGN_CENTER )
end )
