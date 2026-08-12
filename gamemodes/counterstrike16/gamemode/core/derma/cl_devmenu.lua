--[[
	The developer menu, on C.

	Same furniture as the team menu and the scoreboard - gold on near-black,
	Verdana Bold, square corners, a team-coloured flash down the left edge of
	each row - so it reads as part of the same gamemode rather than a debug
	panel bolted on.

	Items register themselves through CS16.AddDevMenuItem rather than being
	listed here, so the areas tool and anything else developer-only can add a
	button from its own file without this one needing to know it exists.
]]

local MENU_W  = 340
local ROW_H   = 46
local ROW_GAP = 6
local PAD     = 12
local TITLE_H = 48

local menu

--[[
	Two levels rather than one flat list.

	It was flat, which was fine for two toggles and stopped being fine the moment
	the battle royale tools arrived - six more rows of placement commands sharing
	a panel with third person and phase, none of which have anything to do with
	each other. So items belong to a page, and the menu opens on a list of pages.

	Pages register themselves the same way items do, so a tool can add its own
	section from its own file without this one knowing it exists.
]]
CS16.DevMenuItems = CS16.DevMenuItems or {}
CS16.DevMenuPages = CS16.DevMenuPages or {}

-- Which page is open, or nil for the list of pages.
local currentPage

--[[
	page = {
		id       = "br",
		label    = "BATTLE ROYALE",
		subtitle = "Place spawns and loot.",
		colour   = Color( ... ),          -- optional, edge flash
		order    = 2,                     -- optional, sorts the root list
	}
]]
function CS16.AddDevMenuPage( page )
	CS16.DevMenuPages[ #CS16.DevMenuPages + 1 ] = page
end

--[[
	item = {
		page     = "developer",           -- which section it belongs to
		label    = "THIRD PERSON",
		subtitle = "Watch yourself from behind.",   -- string, or a function
		colour   = Color( ... ),          -- optional, edge flash
		state    = function() end,        -- optional, makes it a toggle
		click    = function() end,
		visible  = function() end,        -- optional, hides the row entirely
	}
]]
function CS16.AddDevMenuItem( item )
	item.page = item.page or "developer"
	CS16.DevMenuItems[ #CS16.DevMenuItems + 1 ] = item
end

local function VisibleItems( pageID )
	local visible = {}

	for _, item in ipairs( CS16.DevMenuItems ) do
		if item.page == pageID and ( not item.visible or item.visible() ) then
			visible[ #visible + 1 ] = item
		end
	end

	return visible
end

-- A page with nothing to show in it is left off the list rather than opening
-- onto an empty panel.
local function VisiblePages()
	local pages = {}

	for _, page in ipairs( CS16.DevMenuPages ) do
		if #VisibleItems( page.id ) > 0 then pages[ #pages + 1 ] = page end
	end

	table.sort( pages, function( a, b )
		return ( a.order or 99 ) < ( b.order or 99 )
	end )

	return pages
end

-- Subtitles may be a function, so a row can report a live count without the
-- menu needing to be rebuilt when it changes.
local function Subtitle( item )
	if isfunction( item.subtitle ) then return item.subtitle() or "" end
	return item.subtitle or ""
end

local function AddRow( parent, item )
	local btn = parent:Add( "DButton" )
	btn:Dock( TOP )
	btn:DockMargin( 0, 0, 0, ROW_GAP )
	btn:SetTall( ROW_H )
	btn:SetText( "" )

	btn.Paint = function( self, w, h )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Hover or CS16.Colors.PanelLight )
		surface.DrawRect( 0, 0, w, h )
		surface.SetDrawColor( self:IsHovered() and CS16.Colors.Gold or CS16.Colors.GoldDim )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )

		surface.SetDrawColor( item.colour or CS16.TeamColors[ TEAM_DEV ] )
		surface.DrawRect( 0, 0, 3, h )

		CS16.DrawText( item.label, "CS16.Heading", 14, 10, CS16.Colors.Gold, TEXT_ALIGN_LEFT )
		CS16.DrawText( Subtitle( item ), "CS16.Small", 14, 28,
			CS16.Colors.Muted, TEXT_ALIGN_LEFT )

		-- A page row points onward rather than reporting a state.
		if item.arrow then
			CS16.DrawText( ">", "CS16.Heading", w - 16, h * 0.5 - 9,
				CS16.Colors.GoldDim, TEXT_ALIGN_RIGHT )
		end

		--[[
			Toggles read their state every frame rather than being told when it
			changes. Anything that can turn a setting off from outside the menu
			- third person dropping out when you die, say - then shows here
			without having to know the menu exists.
		]]
		if item.state then
			local on = item.state()

			CS16.DrawText( on and "ON" or "OFF", "CS16.Heading", w - 14, h * 0.5 - 9,
				on and CS16.TeamColors[ TEAM_DEV ] or CS16.Colors.Muted, TEXT_ALIGN_RIGHT )
		end
	end

	btn.DoClick = function()
		surface.PlaySound( "buttons/button14.wav" )
		item.click()
	end

	return btn
end

function CS16.CloseDevMenu()
	if IsValid( menu ) then menu:Remove() end
	menu = nil

	-- The prop menu sits beside this one and belongs to the same keypress.
	-- Guarded because cl_propmenu loads after this file.
	if CS16.ClosePropMenu then CS16.ClosePropMenu() end
end

--[[
	A plain popup panel rather than a DFrame.

	DFrame reserves room for a title bar and close button by setting its own
	dock padding in PerformLayout - about 29 pixels at the top - whether or not
	it is showing either. Sizing a frame to exactly fit its rows therefore
	leaves them squeezed into what's left, which is why the first version of
	this menu appeared with the row cut in half. Nothing here uses a DFrame
	feature, so the panel goes away and the padding is ours to state.
]]
--[[
	Built fresh on every navigation rather than showing and hiding panels.

	The panel is sized to exactly fit its rows, so a page with a different number
	of them needs a different height - and rebuilding is both simpler and cheaper
	than resizing and re-laying-out something that is only ever a handful of
	buttons.
]]
local function Build()
	if not CS16.IsDeveloper( LocalPlayer() ) then return end

	CS16.CloseDevMenu()

	local title, rows = "DEVELOPER", {}

	if currentPage then
		local page = nil
		for _, p in ipairs( CS16.DevMenuPages ) do
			if p.id == currentPage then page = p break end
		end

		title = page and page.label or "DEVELOPER"
		rows  = VisibleItems( currentPage )

		-- Back sits at the bottom, so the rows above it don't move when you
		-- arrive from different pages.
		rows[ #rows + 1 ] = {
			label    = "BACK",
			subtitle = "Return to the menu.",
			colour   = CS16.Colors.Muted,
			click    = function() currentPage = nil Build() end,
		}
	else
		for _, page in ipairs( VisiblePages() ) do
			rows[ #rows + 1 ] = {
				label    = page.label,
				subtitle = page.subtitle,
				colour   = page.colour,
				arrow    = true,
				click    = function() currentPage = page.id Build() end,
			}
		end
	end

	local items = rows

	local h = TITLE_H + #items * ( ROW_H + ROW_GAP ) + PAD

	local frame = vgui.Create( "DPanel" )
	menu = frame

	frame:SetSize( MENU_W, h )

	-- Down the left, level with the middle, matching the buy menu.
	frame:SetPos( 60, ( ScrH() - h ) * 0.5 )
	frame:MakePopup()

	--[[
		Mouse only, and set after MakePopup because that turns both on.

		The menu is held open rather than toggled, so the keyboard has to stay
		with the game underneath - otherwise holding C would stop you walking,
		and the key state that closes the menu again is read raw in Think, not
		through VGUI.
	]]
	frame:SetKeyboardInputEnabled( false )

	-- Explicit, so the rows get exactly the space the height was calculated for.
	frame:DockPadding( PAD, TITLE_H, PAD, PAD )

	frame.Paint = function( self, w, ph )
		CS16.DrawPanel( 0, 0, w, ph )
		CS16.DrawText( title, "CS16.Title", w * 0.5, 14,
			CS16.Colors.Gold, TEXT_ALIGN_CENTER )

		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawRect( 12, TITLE_H - 8, w - 24, 1 )
	end

	for _, item in ipairs( items ) do
		AddRow( frame, item )
	end
end

function CS16.OpenDevMenu()
	-- Always on the front page. Reopening onto wherever you happened to leave it
	-- makes the same keypress do different things depending on history.
	currentPage = nil

	-- C clears a stray prompt as well as opening the menu. A panel that asks
	-- for a number should never be the thing standing between you and your
	-- own tools, whatever else has gone wrong.
	if CS16.ClosePrompt then CS16.ClosePrompt() end

	Build()

	if CS16.OpenPropMenu then CS16.OpenPropMenu() end
end

function CS16.ToggleDevMenu()
	if IsValid( menu ) then CS16.CloseDevMenu() else CS16.OpenDevMenu() end
end

--[[
	Held open on C, the way a context menu should be: down to open, up to close.

	Read through WatchKey like every other menu here, and this is the case that
	needs it most - the panel is a popup, so PlayerButtonDown stops firing the
	moment it appears, and a menu that can only be opened is no use. WatchKey
	reads the raw key state in Think, which a popup can't intercept.
]]
CS16.WatchKey( "devmenu", KEY_C, CS16.OpenDevMenu, CS16.CloseDevMenu )

concommand.Add( "cs16_devmenu", CS16.ToggleDevMenu )

-- Losing the rank shouldn't leave the panel on screen.
hook.Add( "Think", "CS16.DevMenuGuard", function()
	if IsValid( menu ) and not CS16.IsDeveloper( LocalPlayer() ) then
		CS16.CloseDevMenu()
	end
end )

--[[ Pages ]]

CS16.AddDevMenuPage( {
	id       = "developer",
	label    = "DEVELOPER",
	subtitle = "Camera and visibility.",
	order    = 1,
} )

CS16.AddDevMenuPage( {
	id       = "br",
	label    = "BATTLE ROYALE",
	subtitle = "Place spawns and weapon drops.",
	colour   = Color( 235, 170, 60 ),
	order    = 2,
} )

CS16.AddDevMenuPage( {
	id       = "hostage",
	label    = "HOSTAGE RESCUE",
	subtitle = "Place hostages and the rescue point.",
	colour   = Color( 90, 200, 90 ),
	order    = 3,
} )

--[[ Items ]]

CS16.AddDevMenuItem( {
	page     = "developer",
	label    = "THIRD PERSON",
	subtitle = "Watch yourself from behind.",
	state    = function() return CS16.ThirdPerson end,
	click    = function() CS16.SetThirdPerson( not CS16.ThirdPerson ) end,
} )

--[[
	Phase is server state, not a local draw trick - being unseen has to be true
	for everybody else - so this asks and reads the answer back rather than
	keeping its own idea of whether it's on.
]]
CS16.AddDevMenuItem( {
	page     = "developer",
	label    = "PHASE",
	subtitle = "Unseen, unheard, and walked straight through.",
	visible  = function() return LocalPlayer():Team() == TEAM_DEV end,
	state    = function() return CS16.IsPhased( LocalPlayer() ) end,

	click = function()
		net.Start( "CS16.Phase" )
			net.WriteBool( not CS16.IsPhased( LocalPlayer() ) )
		net.SendToServer()
	end,
} )

--[[
	Pause, which is server state for the same reason phase is - everybody has to
	agree the game has stopped - so it reads the answer back rather than keeping
	a local idea of it.
]]
CS16.AddDevMenuItem( {
	page     = "developer",
	label    = "PAUSE GAME",
	subtitle = "Freeze the match and stop the clock. Developers keep moving.",
	visible  = function() return LocalPlayer():Team() == TEAM_DEV end,
	state    = function() return GetGlobalBool( "CS16.Paused", false ) end,

	click = function() RunConsoleCommand( "say", "/pause" ) end,
} )

--[[ Battle royale placement ]]

--[[
	These run the chat commands rather than reaching for the server directly.

	The commands already exist, already check the permission and already save and
	republish - going around them would mean a second path to the same data that
	could drift out of step with the first. The command system swallows its own
	chat line, so nothing appears in the log.

	Counts come from the client's synced copy of the zones, so a row can tell you
	how many are down without asking the server anything.
]]
local function ZoneCommand( text )
	return function() RunConsoleCommand( "say", text ) end
end

--[[
	Ask for a number, then run a command with it.

	A panel of its own rather than a field in the menu, and that is forced
	rather than chosen: the C menu is held open and runs with keyboard input
	disabled, so that holding C doesn't also stop you walking. You cannot type
	into a panel that has no keyboard, and you cannot let go of C to get one
	without the menu closing underneath you.

	So the menu closes as normal and this stands on its own with the keyboard,
	focused and waiting. Enter accepts, Escape backs out.
]]
local PROMPT_W = 260
local PROMPT_H = 104

function CS16.ClosePrompt()
	if IsValid( CS16.Prompt ) then CS16.Prompt:Remove() end
	CS16.Prompt = nil
end

function CS16.PromptNumber( title, hint, onAccept )
	CS16.ClosePrompt()

	--[[
		A DFrame, and this is the one panel here that has to be one.

		Everything else in this gamemode is a DPanel popup, deliberately - DFrame
		reserves dock padding for a title bar it may never draw, which eats a row
		off anything sized to fit exactly. That reasoning does not apply here
		because this positions its children outright rather than docking them,
		and something else does: a bare DPanel popup has no focus management, so
		RequestFocus on a child of one is quietly ignored.

		Measured rather than guessed. On a DPanel the field never took focus by
		any route - not immediately, not deferred, not by simulating the click,
		not after handing the panel's own keyboard away - and the prompt sat on
		screen refusing to be typed into or dismissed. The identical test on a
		stock DFrame focused the field first time.

		The title bar is turned off and the paint replaced, so it still looks
		like everything else here.
	]]
	local frame = vgui.Create( "DFrame" )
	CS16.Prompt = frame

	frame:SetSize( PROMPT_W, PROMPT_H )
	frame:SetPos( 60, ( ScrH() - PROMPT_H ) * 0.5 )
	frame:SetTitle( "" )
	frame:ShowCloseButton( false )
	frame:SetDraggable( false )
	frame:MakePopup()

	frame.Paint = function( self, w, h )
		CS16.DrawPanel( 0, 0, w, h )
		CS16.DrawText( title, "CS16.Heading", w * 0.5, 12, CS16.Colors.Gold, TEXT_ALIGN_CENTER )
		CS16.DrawText( hint, "CS16.Small", w * 0.5, 34, CS16.Colors.Muted, TEXT_ALIGN_CENTER )
		CS16.DrawText( "ENTER to remove, ESC to cancel", "CS16.Small", w * 0.5, h - 16,
			CS16.Colors.Muted, TEXT_ALIGN_CENTER )
	end

	--[[
		Escape taken at the panel as well as at the field below.

		Belt and braces on purpose: the field only hears keys while it has the
		focus, and not having the focus is precisely the failure that stranded
		this thing on screen with no way to shift it.
	]]
	frame.OnKeyCodePressed = function( self, key )
		if key == KEY_ESCAPE then CS16.ClosePrompt() return true end
	end

	local entry = vgui.Create( "DTextEntry", frame )
	entry:SetPos( 16, 58 )
	entry:SetSize( PROMPT_W - 32, 28 )
	entry:SetNumeric( true )
	entry:SetFont( "CS16.Text" )
	entry:SetDrawBackground( false )
	entry:SetTextColor( CS16.Colors.White )

	entry.PaintOver = function( self, w, h )
		surface.SetDrawColor( CS16.Colors.GoldDim )
		surface.DrawOutlinedRect( 0, 0, w, h, 1 )
	end

	entry.OnEnter = function( self )
		local value = string.Trim( self:GetValue() )
		CS16.ClosePrompt()

		if value ~= "" then onAccept( value ) end
	end

	--[[
		Escape, chained onto the field's own key handling rather than replacing
		it.

		DTextEntry turns Enter into OnEnter from inside OnKeyCodeTyped, so
		assigning a fresh one over the top quietly removed the accept key -
		typing worked, because characters arrive by another route entirely, and
		nothing happened when you pressed Enter. Which is a strange thing to
		conclude about a text box you can type in.
	]]
	local KeyTyped = entry.OnKeyCodeTyped

	entry.OnKeyCodeTyped = function( self, key )
		if key == KEY_ESCAPE then
			CS16.ClosePrompt()
			return true
		end

		if KeyTyped then return KeyTyped( self, key ) end
	end

	-- Straight away, which is all a DFrame needs. The retry loop that used to be
	-- here was treating the symptom of the panel type being wrong.
	entry:RequestFocus()
end

--[[
	One row that opens the prompt above and feeds its answer to a command.

	The count is read at click time rather than baked into the hint, so it says
	what is actually placed right now.
]]
local function RemoveByIDRow( label, subtitle, colour, command, list )
	return {
		page     = "br",
		label    = label,
		subtitle = subtitle,
		colour   = colour,

		click = function()
			local n = #( list() or {} )

			if n == 0 then
				chat.AddText( CS16.Colors.Gold, "[CS 1.6] ", color_white, "Nothing placed to remove." )
				return
			end

			CS16.CloseDevMenu()

			--[[
				Next frame, not this one. The menu above is still being removed
				as this runs, and a popup created alongside that teardown does
				not reliably come up with the keyboard - which left the prompt
				on screen, untypeable and unclosable.
			]]
			timer.Simple( 0, function()
				CS16.PromptNumber( label, ("1 to %d, as numbered in the world"):format( n ), function( value )
					RunConsoleCommand( "say", command .. " remove " .. value )
				end )
			end )
		end,
	}
end

CS16.AddDevMenuItem( {
	page     = "br",
	label    = "PLACE SPAWN",
	subtitle = function()
		return ("Where you stand, facing where you look.  %d placed."):format( #( CS16.BRSpawns or {} ) )
	end,
	colour   = Color( 235, 170, 60 ),
	click    = ZoneCommand( "/brspawn" ),
} )

CS16.AddDevMenuItem( {
	page     = "br",
	label    = "UNDO SPAWN",
	subtitle = "Remove the last spawn placed.",
	colour   = Color( 235, 170, 60 ),
	click    = ZoneCommand( "/brspawn undo" ),
} )

CS16.AddDevMenuItem( RemoveByIDRow(
	"REMOVE SPAWN",
	"Type the number shown on its marker.",
	Color( 235, 170, 60 ),
	"/brspawn",
	function() return CS16.BRSpawns end
) )

CS16.AddDevMenuItem( {
	page     = "br",
	label    = "PLACE LOOT",
	subtitle = function()
		return ("A weapon spawn where you stand.  %d placed."):format( #( CS16.BRLoot or {} ) )
	end,
	colour   = Color( 200, 100, 220 ),
	click    = ZoneCommand( "/brloot" ),
} )

CS16.AddDevMenuItem( {
	page     = "br",
	label    = "UNDO LOOT",
	subtitle = "Remove the last loot point placed.",
	colour   = Color( 200, 100, 220 ),
	click    = ZoneCommand( "/brloot undo" ),
} )

CS16.AddDevMenuItem( RemoveByIDRow(
	"REMOVE LOOT",
	"Type the number shown on its marker.",
	Color( 200, 100, 220 ),
	"/brloot",
	function() return CS16.BRLoot end
) )

--[[
	Both clears are last and ask twice.

	They throw away an afternoon of placement in one click, and they sit on the
	same panel as the button you press dozens of times in a row - which is
	exactly the arrangement that eventually gets mis-clicked.
]]
local armed = {}

local function ClearRow( page, label, subtitle, command, colour )
	CS16.AddDevMenuItem( {
		page     = page,
		label    = label,
		colour   = colour,

		subtitle = function()
			if armed[ command ] then return "Click again to confirm." end
			return subtitle
		end,

		click = function()
			if not armed[ command ] then
				armed[ command ] = true

				-- Forgets after a few seconds, so it can't stay armed from
				-- something you clicked and thought better of.
				timer.Simple( 4, function() armed[ command ] = nil end )
				return
			end

			armed[ command ] = nil
			RunConsoleCommand( "say", command )
		end,
	} )
end

ClearRow( "br", "CLEAR SPAWNS", "Remove every spawn on this map.", "/brspawn clear", Color( 200, 90, 90 ) )
ClearRow( "br", "CLEAR LOOT",   "Remove every loot point on this map.", "/brloot clear", Color( 200, 90, 90 ) )

--[[
	Showing the markers is a toggle rather than something tied to your team.

	They are drawn in the world for anybody with the rank, which is what you want
	while placing them and a hedge of purple posts between you and the map every
	other minute. Kept per marker set, because the two are placed in separate
	sittings and turning one on has no business bringing the other with it.
]]
CS16.AddDevMenuItem( {
	page     = "br",
	label    = "SHOW MARKERS",
	subtitle = "Draw spawns and loot points in the world.",
	colour   = Color( 235, 170, 60 ),
	state    = function() return CS16.ShowBRMarkers() end,

	click = function()
		RunConsoleCommand( "cs16_show_br_markers", CS16.ShowBRMarkers() and "0" or "1" )
	end,
} )

--[[ Hostage rescue ]]

CS16.AddDevMenuItem( {
	page     = "hostage",
	label    = "PLACE HOSTAGE",
	colour   = Color( 90, 200, 90 ),
	subtitle = function()
		return ("Where you stand, facing where you look.  %d placed."):format( #( CS16.HostageSpots or {} ) )
	end,
	click = ZoneCommand( "/hostagespot" ),
} )

CS16.AddDevMenuItem( {
	page     = "hostage",
	label    = "PLACE RESCUE ZONE",
	colour   = Color( 108, 160, 220 ),
	subtitle = function()
		return ("Where hostages are taken.  %d placed."):format( #( CS16.RescueZones or {} ) )
	end,
	click = ZoneCommand( "/rescuezone" ),
} )

CS16.AddDevMenuItem( {
	page     = "hostage",
	label    = "SHOW MARKERS",
	subtitle = "Draw hostage spots and rescue zones in the world.",
	colour   = Color( 90, 200, 90 ),
	state    = function() return CS16.ShowHostageMarkers() end,

	click = function()
		RunConsoleCommand( "cs16_show_hostage_markers", CS16.ShowHostageMarkers() and "0" or "1" )
	end,
} )

ClearRow( "hostage", "CLEAR HOSTAGES", "Remove every hostage spot on this map.",
	"/hostagespot clear", Color( 200, 90, 90 ) )

ClearRow( "hostage", "CLEAR RESCUE ZONES", "Remove every rescue zone on this map.",
	"/rescuezone clear", Color( 200, 90, 90 ) )

--[[
	Reloading the map, behind the same two-press confirm as the clears.

	It is not destructive in the way they are - nothing authored is lost - but
	it drops everybody on the server for a few seconds and throws away the match
	in progress. That is enough to be worth asking twice about, and it sits on
	the developer page rather than a mode's because every mode wants it.
]]
ClearRow( "developer", "RELOAD MAP", "Restart the current map. Everyone reconnects.",
	"/reloadmap", Color( 200, 90, 90 ) )
